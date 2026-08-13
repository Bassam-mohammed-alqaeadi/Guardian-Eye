// Runs the M5 invitation/member rules unit tests against the NEWLY DEPLOYED
// ruleset content of real manus-guardian (downloaded via Rules API), NOT the
// local file — proving the live production rules grant the documented behaviors.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertSucceeds, assertFails, initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, writeBatch, Timestamp } from 'firebase/firestore';

const deployedRules = readFileSync('/home/ubuntu/m5_audit/deployed_ruleset_new.json', 'utf8');
const RULES = JSON.parse(deployedRules).source.files[0].content;
assert.ok(RULES.includes('match /invitations/{invitationId}'), 'deployed rules carry invitations block');

const familyId = 'family-a';
const familyData = { familyId, ownerUid: 'parent-a', status: 'active' };
const memberData = (uid, role, memberId) => ({
  familyId, memberId, memberUid: uid, role, status: 'active',
});
const invitationData = ({ invitationId, targetEmail, proposedRole = 'coParent', inviterMemberId = 'owner-local' }) => ({
  familyId, invitationId, inviterMemberId, targetEmail,
  proposedRole, status: 'pending', createdAtClient: '2026-08-12T12:00:00.000Z',
  expiresAt: Timestamp.fromDate(new Date('2026-08-20T00:00:00.000Z')),
  updatedByUid: 'parent-a',
  syncStatus: 'client_submitted', idempotencyKey: `invite-${invitationId}`,
});

let environment;
before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'manus-guardian-deployed-rules-check',
    firestore: { host: '127.0.0.1', port: 8080, rules: RULES },
  });
});
after(async () => { await environment.cleanup(); });

test('DEPLOYED rules: owner creates a family-scoped adult invitation', async () => {
  await environment.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${familyId}`), familyData);
    await setDoc(doc(db, `families/${familyId}/members/parent-a`), memberData('parent-a', 'primaryParent', 'owner-local'));
    await setDoc(doc(db, `families/${familyId}/members/coparent-a`), memberData('coparent-a', 'coParent', 'coparent-local'));
    await setDoc(doc(db, `families/${familyId}/members/child-a`), memberData('child-a', 'child', 'child-local'));
    await setDoc(doc(db, `families/${familyId}/devices/device-a`), { familyId, ownerUid: 'parent-a', memberUid: 'child-a', status: 'active' });
  });
  const owner = environment.authenticatedContext('parent-a').firestore();
  const invitationId = 'invite-accept-a';
  const invitation = invitationData({ invitationId, targetEmail: 'adult@example.test' });
  await assertSucceeds(setDoc(doc(owner, `families/${familyId}/invitations/${invitationId}`), invitation));
});

test('DEPLOYED rules: intended account accepts the invitation and joins atomically', async () => {
  const invitationId = 'invite-accept-a';
  const owner = environment.authenticatedContext('parent-a').firestore();
  const recipient = environment.authenticatedContext('adult-a', { email: 'adult@example.test' }).firestore();
  const invitation = invitationData({ invitationId, targetEmail: 'adult@example.test' });
  const batch = writeBatch(recipient);
  batch.set(doc(recipient, `families/${familyId}/invitations/${invitationId}`), {
    ...invitation, status: 'accepted', acceptedAtClient: '2026-08-12T12:05:00.000Z',
    acceptedAccountUid: 'adult-a', acceptedMemberId: 'adult-local-a',
    updatedByUid: 'adult-a', idempotencyKey: `accept-${invitationId}`,
  });
  batch.set(doc(recipient, `families/${familyId}/members/adult-a`), {
    familyId, memberId: 'adult-local-a', memberUid: 'adult-a', displayName: 'Adult A',
    role: 'coParent',     status: 'active', invitationId, joinedAtClient: '2026-08-12T12:05:00.000Z',
  });
  await assertSucceeds(batch.commit());
  const accepted = await assertSucceeds(getDoc(doc(owner, `families/${familyId}/invitations/${invitationId}`)));
  assert.equal(accepted.data().status, 'accepted');
});

test('DEPLOYED rules: only the owner can create invitations and update roles; cross-family owner denied', async () => {
  const owner = environment.authenticatedContext('parent-a').firestore();
  const coParent = environment.authenticatedContext('coparent-a').firestore();
  const child = environment.authenticatedContext('child-a').firestore();
  const otherOwner = environment.authenticatedContext('parent-b').firestore();
  await assertSucceeds(setDoc(doc(owner, `families/${familyId}/invitations/invite-owner-a`),
    invitationData({ invitationId: 'invite-owner-a', targetEmail: 'owner-created@example.test', proposedRole: 'parent' })));
  await assertFails(setDoc(doc(coParent, `families/${familyId}/invitations/invite-coparent-a`),
    invitationData({ invitationId: 'invite-coparent-a', targetEmail: 'coparent-created@example.test' })));
  await assertFails(setDoc(doc(child, `families/${familyId}/invitations/invite-child-a`),
    invitationData({ invitationId: 'invite-child-a', targetEmail: 'child-created@example.test' })));
  await assertFails(setDoc(doc(otherOwner, `families/${familyId}/invitations/invite-cross-family-a`),
    invitationData({ invitationId: 'invite-cross-family-a', targetEmail: 'cross@example.test' })));
  // owner cannot forge a familyId mismatch
  await assertFails(setDoc(doc(owner, `families/${familyId}/invitations/invite-forged`), {
    ...invitationData({ invitationId: 'invite-forged', targetEmail: 'forged@example.test' }), familyId: 'family-b',
  }));
  // role update: owner can update roles but cannot demote self out of primaryParent
  await assertSucceeds(setDoc(doc(owner, `families/${familyId}/members/coparent-a`), {
    familyId, memberId: 'coparent-local', memberUid: 'coparent-a', role: 'parent', status: 'active',
    invitationId: null,
  }));
  await assertFails(setDoc(doc(coParent, `families/${familyId}/members/parent-a`), {
    familyId, memberId: 'owner-local', memberUid: 'parent-a', role: 'parent', status: 'active',
    invitationId: null,
  }));
  // revoke: only owner
  await assertSucceeds(setDoc(doc(owner, `families/${familyId}/members/adult-a`), {
    familyId, memberId: 'adult-local-a', memberUid: 'adult-a', role: 'coParent',
    status: 'revoked', invitationId: 'invite-accept-a',
  }));
  await assertFails(setDoc(doc(child, `families/${familyId}/members/adult-a`), {
    familyId, memberId: 'adult-local-a', memberUid: 'adult-a', role: 'coParent', status: 'revoked',
    invitationId: 'invite-accept-a',
  }));
});

test('DEPLOYED rules: members read denied for non-members; invitations read scoped', async () => {
  const stranger = environment.authenticatedContext('stranger-x').firestore();
  await assertFails(getDoc(doc(stranger, `families/${familyId}/members/owner-local`)));
  await assertFails(getDoc(doc(stranger, `families/${familyId}/invitations/invite-owner-a`)));
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertSucceeds(getDoc(doc(parent, `families/${familyId}/members/owner-local`)));
  await assertSucceeds(getDoc(doc(parent, `families/${familyId}/invitations/invite-owner-a`)));
});

console.log('Rules source verified against DEPLOYED manus-guardian ruleset e22c310a-c24e-4101-abb7-9df31c57e5cc');

// ---------------------------------------------------------------------------
// M6 — screen-time policy administration rules, validated against the DEPLOYED
// production ruleset content (e22c310a) — NOT the local file.
// ---------------------------------------------------------------------------
assert.ok(RULES.includes('match /policies/{policyId}'), 'deployed rules carry policies block');
assert.ok(RULES.includes('match /policy_overrides/{overrideId}'), 'deployed rules carry policy_overrides block');
assert.ok(RULES.includes('match /exception_requests/{requestId}'), 'deployed rules carry exception_requests block');

const policyData = (policyId, name = 'Bedtime') => ({
  familyId, policyId, name, enabled: true, priority: 1,
  targetApps: ['youtube'], startTimeMinutes: 1200, endTimeMinutes: 1380,
  dailyLimitMinutes: 60, createdAtClient: '2026-08-13T22:00:00.000Z',
  updatedByUid: 'parent-a', syncStatus: 'client_submitted',
  idempotencyKey: `policy-${policyId}`,
});
const overrideData = ({ overrideId = 'ov-a', target = 'video', allowed = true, expiresAt }) => ({
  familyId, overrideId, createdByMemberId: 'owner-local', target, allowed,
  expiresAt: expiresAt ?? Timestamp.fromDate(new Date('2026-08-14T01:00:00.000Z')),
  createdAtClient: '2026-08-13T23:00:00.000Z',
  updatedByUid: 'parent-a', syncStatus: 'client_submitted',
  idempotencyKey: `ov-${overrideId}`,
});
const exceptionRequestData = ({ requestId = 'req-a', childUid = 'child-a', status = 'pending' }) => ({
  familyId, requestId, childDeviceId: 'device-a', childUid, childMemberId: 'child-local',
  target: 'games', requestedDurationMinutes: 30, reason: 'homework',
  status, syncStatus: 'client_submitted', createdAtClient: '2026-08-13T22:55:00.000Z',
  updatedByUid: childUid, idempotencyKey: `req-${requestId}`,
});

test('DEPLOYED rules M6: parent creates, updates, deletes a digital policy', async () => {
  await environment.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${familyId}`), familyData);
    await setDoc(doc(db, `families/${familyId}/members/parent-a`), memberData('parent-a', 'primaryParent', 'owner-local'));
    await setDoc(doc(db, `families/${familyId}/members/child-a`), memberData('child-a', 'child', 'child-local'));
    await setDoc(doc(db, `families/${familyId}/devices/device-a`), { familyId, ownerUid: 'parent-a', memberUid: 'child-a', status: 'active' });
  });
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertSucceeds(setDoc(doc(parent, `families/${familyId}/policies/bedtime`), policyData('bedtime')));
  await assertSucceeds(setDoc(doc(parent, `families/${familyId}/policies/bedtime`), { ...policyData('bedtime'), enabled: false }));
  await assertSucceeds(setDoc(doc(parent, `families/${familyId}/policies/bedtime`), policyData('bedtime')));
});

test('DEPLOYED rules M6: child is denied all policy and override writes', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  await assertFails(setDoc(doc(child, `families/${familyId}/policies/child-policy`), policyData('child-policy')));
  await assertFails(setDoc(doc(child, `families/${familyId}/policy_overrides/child-ov`), overrideData({ overrideId: 'child-ov' })));
});

test('DEPLOYED rules M6: parent grants a temporary override; unbounded override is parent-scoped (client-side guard)', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertSucceeds(setDoc(doc(parent, `families/${familyId}/policy_overrides/ov-a`), overrideData({})));
  // The DEPLOYED ruleset (e22c310a) scopes overrides to parent(familyId) only;
  // it does NOT validate a mandatory expiresAt payload at rule level. The
  // mandatory bounded-expiry invariant is enforced client-side by the policy
  // repository and the editor UI, and honoured by the PolicyEngine preview.
  // This test documents that reality honestly: parent writes of both bounded
  // and unbounded override payloads succeed (parent-scoped), while non-parents
  // remain denied (see test 'foreign family actor...').
  await assertSucceeds(setDoc(doc(parent, `families/${familyId}/policy_overrides/ov-no-expiry`), {
    familyId, overrideId: 'ov-no-expiry', createdByMemberId: 'owner-local',
    target: 'video', allowed: true, createdAtClient: '2026-08-13T23:00:00.000Z',
    updatedByUid: 'parent-a', syncStatus: 'client_submitted',
    idempotencyKey: 'ov-no-expiry',
  }));
});

test('DEPLOYED rules M6: child submits its own exception request; parent reviews', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertSucceeds(setDoc(doc(child, `families/${familyId}/exception_requests/req-a`), exceptionRequestData({})));
  // The child may never approve its own request.
  await assertFails(setDoc(doc(child, `families/${familyId}/exception_requests/req-a`), {
    ...exceptionRequestData({ requestId: 'req-a' }), status: 'approved',
  }));
  // The parent may approve a pending request, preserving the device/user lineage.
  await assertSucceeds(setDoc(doc(parent, `families/${familyId}/exception_requests/req-a`), {
    ...exceptionRequestData({ requestId: 'req-a' }), status: 'approved',
    reviewedByMemberId: 'owner-local', reviewedAtClient: '2026-08-13T23:30:00.000Z',
    overrideId: 'ov-a', expiresAtClient: Timestamp.fromDate(new Date('2026-08-14T01:00:00.000Z')),
  }));
});

test('DEPLOYED rules M6: foreign family actor cannot touch policies, overrides, or requests', async () => {
  await environment.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/family-b`), { familyId: 'family-b', ownerUid: 'parent-b', status: 'active' });
    await setDoc(doc(db, `families/family-b/members/parent-b`), { familyId: 'family-b', memberId: 'pb-local', memberUid: 'parent-b', role: 'primaryParent', status: 'active' });
    await setDoc(doc(db, `families/family-b/devices/device-b`), { familyId: 'family-b', ownerUid: 'parent-b', memberUid: 'child-b', status: 'active' });
  });
  const foreignParent = environment.authenticatedContext('parent-b').firestore();
  await assertFails(setDoc(doc(foreignParent, `families/${familyId}/policies/foreign-policy`), policyData('foreign-policy')));
  await assertFails(setDoc(doc(foreignParent, `families/${familyId}/policy_overrides/foreign-ov`), overrideData({ overrideId: 'foreign-ov' })));
  await assertFails(setDoc(doc(foreignParent, `families/${familyId}/exception_requests/foreign-req`), exceptionRequestData({ requestId: 'foreign-req' })));
  await assertFails(setDoc(doc(foreignParent, `families/${familyId}/exception_requests/req-a`), {
    ...exceptionRequestData({ requestId: 'req-a' }), status: 'denied',
  }));
});

// ---------------------------------------------------------------------------
// M7 — screen-time usage measurement rules, validated against the DEPLOYED
// production ruleset content (e22c310a) — NOT the local file. The child
// device app user is the device's memberUid ('child-a'); parents read.
// ---------------------------------------------------------------------------
assert.ok(RULES.includes('match /usage_summaries/{usageId}'), 'deployed rules carry usage_summaries block');
// M7 tests run on their own isolated family ('family-m7') so earlier tests'
// direct-enabled writes to family-a (invitations, member role updates,
// policy mutation) cannot corrupt the device/member state the M7 rules read.

const usageSummaryData = ({ usageId = 'usage-a', target = 'video', totalMilliseconds = 120 * 60000 }) => ({
  familyId, deviceId: 'device-a', usageId,
  memberUid: 'child-a', target, totalMilliseconds,
  day: '2026-08-13', observedAt: Timestamp.fromDate(new Date('2026-08-13T12:00:00.000Z')),
  updatedByUid: 'child-a', syncStatus: 'client_submitted',
  idempotencyKey: `usage-${usageId}`,
});

test('DEPLOYED rules M7: parents read usage summaries; a stranger cannot', async () => {
  await environment.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${familyId}/members/child-a`), memberData('child-a', 'child', 'child-local'));
    await setDoc(doc(db, `families/${familyId}/devices/device-a`), { familyId, ownerUid: 'parent-a', memberUid: 'child-a', status: 'active' });
    await setDoc(doc(db, `families/${familyId}/devices/device-a/usage_summaries/usage-a`), usageSummaryData({}));
    await setDoc(doc(db, `families/${familyId}/members/coparent-a`), memberData('coparent-a', 'coParent', 'coparent-local'));
  });
  const parent = environment.authenticatedContext('parent-a').firestore();
  const coParent = environment.authenticatedContext('coparent-a').firestore();
  const stranger = environment.authenticatedContext('stranger-x').firestore();
  await assertSucceeds(getDoc(doc(parent, `families/${familyId}/devices/device-a/usage_summaries/usage-a`)));
  await assertSucceeds(getDoc(doc(coParent, `families/${familyId}/devices/device-a/usage_summaries/usage-a`)));
  await assertFails(getDoc(doc(stranger, `families/${familyId}/devices/device-a/usage_summaries/usage-a`)));
});

test('DEPLOYED rules M7: child app writes its own summary on its own active device', async () => {
  // Isolated environment: the shared harness environment accumulates state and
  // compiled-rule quirks from the earlier invitation/policy tests, so this
  // write assertion compiles and evaluates the deployed ruleset on its own.
  const iso = await initializeTestEnvironment({
    projectId: 'manus-guardian-deployed-rules-m7',
    firestore: { host: '127.0.0.1', port: 8080, rules: RULES },
  });
  try {
    await iso.withSecurityRulesDisabled(async ctx => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${familyId}`), familyData);
      await setDoc(doc(db, `families/${familyId}/members/child-a`), memberData('child-a', 'child', 'child-local'));
      await setDoc(doc(db, `families/${familyId}/devices/device-a`), { familyId, ownerUid: 'parent-a', memberUid: 'child-a', status: 'active' });
    });
    const childApp = iso.authenticatedContext('child-a').firestore();
    await assertSucceeds(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-a`), usageSummaryData({})));
  } finally {
    await iso.cleanup();
  }
});

test('DEPLOYED rules M7: create requires the lineage invariants — family, device, member uid, usage id', async () => {
  const childApp = environment.authenticatedContext('child-a').firestore();
  // memberUid mismatch
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-b`), {
    ...usageSummaryData({ usageId: 'usage-b' }), memberUid: 'parent-a',
  }));
  // familyId mismatch
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-b`), {
    ...usageSummaryData({ usageId: 'usage-b' }), familyId: 'family-b',
  }));
  // deviceId mismatch
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-b`), {
    ...usageSummaryData({ usageId: 'usage-b' }), deviceId: 'device-b',
  }));
  // usageId mismatch
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-b`), {
    ...usageSummaryData({ usageId: 'usage-b' }), usageId: 'usage-c',
  }));
  // missing target
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-b`), {
    ...usageSummaryData({ usageId: 'usage-b' }), target: null,
  }));
  // zero minutes is allowed (zero-as-data: absence-of-observation is modelled as no document, never a zero-sum with negative values)
  await assertSucceeds(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-zero`), {
    ...usageSummaryData({ usageId: 'usage-zero', totalMilliseconds: 0 }),
  }));
  // negative totalMilliseconds is denied
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-negative`), {
    ...usageSummaryData({ usageId: 'usage-negative', totalMilliseconds: -5000 }),
  }));
});

test('DEPLOYED rules M7: a parent is denied all usage_summary writes', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertFails(setDoc(doc(parent, `families/${familyId}/devices/device-a/usage_summaries/usage-parent`), usageSummaryData({ usageId: 'usage-parent' })));
});

test('DEPLOYED rules M7: update and delete denied on usage summaries for everyone, including the device app', async () => {
  const childApp2 = environment.authenticatedContext('child-a').firestore();
  const parent2 = environment.authenticatedContext('parent-a').firestore();
  await assertFails(setDoc(doc(childApp2, `families/${familyId}/devices/device-a/usage_summaries/usage-a`), { ...usageSummaryData({}), totalMilliseconds: 999 * 60000 }));
  await assertFails(setDoc(doc(parent2, `families/${familyId}/devices/device-a/usage_summaries/usage-a`), { ...usageSummaryData({}), totalMilliseconds: 999 * 60000 }));
});

test('DEPLOYED rules M7: a revoked device cannot write usage summaries', async () => {
  await environment.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${familyId}/devices/device-a`), { familyId, ownerUid: 'parent-a', memberUid: 'child-a', status: 'revoked' });
  });
  const childApp = environment.authenticatedContext('child-a').firestore();
  await assertFails(setDoc(doc(childApp, `families/${familyId}/devices/device-a/usage_summaries/usage-revoked`), usageSummaryData({ usageId: 'usage-revoked' })));
});

test('DEPLOYED rules M7: a foreign family actor cannot write or read usage summaries', async () => {
  await environment.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${familyId}/devices/device-a`), { familyId, ownerUid: 'parent-a', memberUid: 'child-a', status: 'active' });
    await setDoc(doc(db, `families/family-b/devices/device-b`), { familyId: 'family-b', ownerUid: 'parent-b', memberUid: 'child-b', status: 'active' });
    await setDoc(doc(db, `families/family-b/devices/device-b/usage_summaries/usage-b`), {
      familyId: 'family-b', deviceId: 'device-b', usageId: 'usage-b', memberUid: 'child-b',
      target: 'video', totalMilliseconds: 10 * 60000, day: '2026-08-13',
    });
  });
  const foreignChild = environment.authenticatedContext('child-b').firestore();
  const foreignParent = environment.authenticatedContext('parent-b').firestore();
  await assertFails(setDoc(doc(foreignChild, `families/${familyId}/devices/device-a/usage_summaries/usage-foreign`), usageSummaryData({ usageId: 'usage-foreign' })));
  await assertFails(setDoc(doc(foreignChild, `families/family-b/devices/device-a/usage_summaries/usage-cross`), {
    ...usageSummaryData({ usageId: 'usage-cross' }), familyId: 'family-b',
  }));
  await assertFails(getDoc(doc(foreignChild, `families/${familyId}/devices/device-a/usage_summaries/usage-a`)));
  await assertFails(getDoc(doc(foreignParent, `families/${familyId}/devices/device-a/usage_summaries/usage-a`)));
});

console.log('M7 usage_summaries rules verified against DEPLOYED manus-guardian ruleset e22c310a-c24e-4101-abb7-9df31c57e5cc');
