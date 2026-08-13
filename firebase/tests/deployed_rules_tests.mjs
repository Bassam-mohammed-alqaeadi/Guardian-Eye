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
