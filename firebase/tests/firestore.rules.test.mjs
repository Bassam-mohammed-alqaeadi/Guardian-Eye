import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, doc, getDoc, setDoc, writeBatch } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

let environment;
before(async () => {
  environment = await initializeTestEnvironment({projectId: 'guardian-eye-emulator', firestore: {host: '127.0.0.1', port: 8080, rules: readFileSync('../firestore.rules', 'utf8')}});
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'families/family-a'), {ownerUid: 'parent-a', status: 'active'});
    await setDoc(doc(db, 'families/family-a/members/parent-a'), {role: 'primaryParent', memberUid: 'parent-a', memberId: 'owner-local', status: 'active'});
    await setDoc(doc(db, 'families/family-a/members/child-a'), {role: 'child', memberUid: 'child-a', memberId: 'child-local', status: 'active'});
    await setDoc(doc(db, 'families/family-a/members/coparent-a'), {role: 'coParent', memberUid: 'coparent-a', memberId: 'coparent-local', status: 'active'});
    await setDoc(doc(db, 'families/family-a/devices/device-a'), {familyId: 'family-a', ownerUid: 'parent-a', memberUid: 'child-a', status: 'active'});
    await setDoc(doc(db, 'families/family-a/devices/revoked-a'), {familyId: 'family-a', ownerUid: 'parent-a', memberUid: 'child-a', status: 'revoked'});
    await setDoc(doc(db, 'families/family-b'), {ownerUid: 'parent-b', status: 'active'});
    await setDoc(doc(db, 'families/family-b/members/parent-b'), {role: 'primaryParent', memberUid: 'parent-b', memberId: 'owner-b-local', status: 'active'});
  });
});
after(async () => { await environment?.cleanup(); });

test('parent reads own family and cannot read another family', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertSucceeds(getDoc(doc(parent, 'families/family-a')));
  await assertFails(getDoc(doc(parent, 'families/family-b')));
});

test('new parent creates family and own primary-member record atomically', async () => {
  const db = environment.authenticatedContext('parent-new').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'families/family-new'), {ownerUid: 'parent-new', status: 'active'});
  batch.set(doc(db, 'families/family-new/members/parent-new'), {role: 'primaryParent', memberUid: 'parent-new', memberId: 'owner-new-local', status: 'active'});
  await assertSucceeds(batch.commit());
});

test('child cannot escalate own role or change policy', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  await assertFails(setDoc(doc(child, 'families/family-a/members/child-a'), {role: 'primaryParent', memberUid: 'child-a'}, {merge: true}));
  await assertFails(setDoc(doc(child, 'families/family-a/policies/policy-a'), {familyId: 'family-a', priority: 10}));
});

test('primary parent cannot escalate a child role or rebind its Firebase UID', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  const child = doc(parent, 'families/family-a/members/child-a');
  await assertFails(setDoc(child, {role: 'primaryParent', memberUid: 'child-a'}, {merge: true}));
  await assertFails(setDoc(child, {memberUid: 'parent-a'}, {merge: true}));
});

function invitationData({invitationId, targetEmail, proposedRole = 'coParent', expiresAt = new Date('2030-01-01T00:00:00.000Z')}) {
  return {
    familyId: 'family-a', invitationId, inviterMemberId: 'owner-local', targetEmail,
    proposedRole, status: 'pending', createdAtClient: '2026-08-12T12:00:00.000Z',
    expiresAt: Timestamp.fromDate(expiresAt), updatedByUid: 'parent-a',
    syncStatus: 'client_submitted', idempotencyKey: `invite-${invitationId}`,
  };
}

function acceptanceBatch(db, {invitationId, uid, memberId, displayName, role, invitation}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `families/family-a/invitations/${invitationId}`), {
    ...invitation, status: 'accepted', acceptedAtClient: '2026-08-12T12:05:00.000Z',
    acceptedAccountUid: uid, acceptedMemberId: memberId, updatedByUid: uid,
    syncStatus: 'client_submitted', idempotencyKey: `accept-${invitationId}`,
  });
  batch.set(doc(db, `families/family-a/members/${uid}`), {
    familyId: 'family-a', memberId, memberUid: uid, displayName, role,
    status: 'active', invitationId, joinedAtClient: '2026-08-12T12:05:00.000Z',
    idempotencyKey: `accept-${invitationId}`,
  });
  return batch;
}

test('owner creates a family-scoped adult invitation and intended account accepts it atomically', async () => {
  const owner = environment.authenticatedContext('parent-a').firestore();
  const recipient = environment.authenticatedContext('adult-a', {email: 'adult@example.test'}).firestore();
  const invitationId = 'invite-accept-a';
  const invitation = invitationData({invitationId, targetEmail: 'adult@example.test'});
  await assertSucceeds(setDoc(doc(owner, `families/family-a/invitations/${invitationId}`), invitation));
  await assertSucceeds(acceptanceBatch(recipient, {
    invitationId, uid: 'adult-a', memberId: 'adult-local-a', displayName: 'Adult A',
    role: 'coParent', invitation,
  }).commit());
  const acceptedInvitation = await assertSucceeds(getDoc(doc(owner, `families/family-a/invitations/${invitationId}`)));
  const createdMember = await assertSucceeds(getDoc(doc(owner, 'families/family-a/members/adult-a')));
  const existingChild = await assertSucceeds(getDoc(doc(owner, 'families/family-a/members/child-a')));
  assert.equal(acceptedInvitation.data().acceptedAccountUid, 'adult-a');
  assert.equal(acceptedInvitation.data().acceptedMemberId, 'adult-local-a');
  assert.equal(createdMember.data().familyId, 'family-a');
  assert.equal(createdMember.data().memberUid, 'adult-a');
  assert.equal(createdMember.data().memberId, 'adult-local-a');
  assert.equal(createdMember.data().role, 'coParent');
  assert.equal(createdMember.data().status, 'active');
  assert.equal(existingChild.data().role, 'child');
});

test('only the family owner can create a valid adult invitation for that family', async () => {
  const owner = environment.authenticatedContext('parent-a').firestore();
  const coParent = environment.authenticatedContext('coparent-a').firestore();
  const child = environment.authenticatedContext('child-a').firestore();
  const otherOwner = environment.authenticatedContext('parent-b').firestore();
  await assertSucceeds(setDoc(doc(owner, 'families/family-a/invitations/invite-owner-a'),
    invitationData({invitationId: 'invite-owner-a', targetEmail: 'owner-created@example.test', proposedRole: 'parent'})));
  await assertFails(setDoc(doc(coParent, 'families/family-a/invitations/invite-coparent-a'),
    invitationData({invitationId: 'invite-coparent-a', targetEmail: 'coparent-created@example.test'})));
  await assertFails(setDoc(doc(child, 'families/family-a/invitations/invite-child-a'),
    invitationData({invitationId: 'invite-child-a', targetEmail: 'child-created@example.test'})));
  await assertFails(setDoc(doc(otherOwner, 'families/family-a/invitations/invite-cross-family-a'),
    invitationData({invitationId: 'invite-cross-family-a', targetEmail: 'cross@example.test'})));
  await assertFails(setDoc(doc(owner, 'families/family-b/invitations/invite-forged-family-b'), {
    ...invitationData({invitationId: 'invite-forged-family-b', targetEmail: 'forged@example.test'}), familyId: 'family-a',
  }));
  await assertFails(setDoc(doc(owner, 'families/family-a/invitations/invite-escalated-a'),
    invitationData({invitationId: 'invite-escalated-a', targetEmail: 'escalated@example.test', proposedRole: 'primaryParent'})));
});

test('invitation acceptance rejects wrong, replayed, expired, cancelled, and child identities', async () => {
  const owner = environment.authenticatedContext('parent-a').firestore();
  const target = environment.authenticatedContext('adult-target-a', {email: 'target@example.test'}).firestore();
  const wrongUser = environment.authenticatedContext('adult-wrong-a', {email: 'wrong@example.test'}).firestore();
  const child = environment.authenticatedContext('child-a', {email: 'child@example.test'}).firestore();

  const wrongId = 'invite-wrong-a';
  const wrongInvitation = invitationData({invitationId: wrongId, targetEmail: 'target@example.test'});
  await assertSucceeds(setDoc(doc(owner, `families/family-a/invitations/${wrongId}`), wrongInvitation));
  await assertFails(acceptanceBatch(wrongUser, {invitationId: wrongId, uid: 'adult-wrong-a', memberId: 'adult-wrong-local-a', displayName: 'Wrong', role: 'coParent', invitation: wrongInvitation}).commit());

  const acceptedId = 'invite-replay-a';
  const acceptedInvitation = invitationData({invitationId: acceptedId, targetEmail: 'target@example.test', proposedRole: 'parent'});
  await assertSucceeds(setDoc(doc(owner, `families/family-a/invitations/${acceptedId}`), acceptedInvitation));
  await assertSucceeds(acceptanceBatch(target, {invitationId: acceptedId, uid: 'adult-target-a', memberId: 'adult-target-local-a', displayName: 'Target', role: 'parent', invitation: acceptedInvitation}).commit());
  await assertFails(acceptanceBatch(target, {invitationId: acceptedId, uid: 'adult-target-a', memberId: 'adult-target-local-a', displayName: 'Target', role: 'parent', invitation: acceptedInvitation}).commit());

  const expiredId = 'invite-expired-a';
  const expiredInvitation = invitationData({invitationId: expiredId, targetEmail: 'target@example.test', expiresAt: new Date('2020-08-11T00:00:00.000Z')});
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `families/family-a/invitations/${expiredId}`), expiredInvitation);
  });
  await assertFails(acceptanceBatch(target, {invitationId: expiredId, uid: 'adult-target-a', memberId: 'adult-expired-local-a', displayName: 'Target', role: 'coParent', invitation: expiredInvitation}).commit());

  const cancelledId = 'invite-cancelled-a';
  const cancelledInvitation = invitationData({invitationId: cancelledId, targetEmail: 'target@example.test'});
  await assertSucceeds(setDoc(doc(owner, `families/family-a/invitations/${cancelledId}`), cancelledInvitation));
  await assertSucceeds(setDoc(doc(owner, `families/family-a/invitations/${cancelledId}`), {
    ...cancelledInvitation, status: 'cancelled', cancelledAtClient: '2026-08-12T12:02:00.000Z',
    updatedByUid: 'parent-a', syncStatus: 'client_submitted', idempotencyKey: `cancel-${cancelledId}`,
  }));
  await assertFails(acceptanceBatch(target, {invitationId: cancelledId, uid: 'adult-target-a', memberId: 'adult-cancelled-local-a', displayName: 'Target', role: 'coParent', invitation: cancelledInvitation}).commit());

  const childId = 'invite-child-accept-a';
  const childInvitation = invitationData({invitationId: childId, targetEmail: 'child@example.test'});
  await assertSucceeds(setDoc(doc(owner, `families/family-a/invitations/${childId}`), childInvitation));
  await assertFails(acceptanceBatch(child, {invitationId: childId, uid: 'child-a', memberId: 'forged-child-adult-local-a', displayName: 'Child', role: 'coParent', invitation: childInvitation}).commit());
});

test('parent can manage family policies while child and another family are denied', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  const child = environment.authenticatedContext('child-a').firestore();
  const otherParent = environment.authenticatedContext('parent-b').firestore();
  const policy = {
    familyId: 'family-a', policyId: 'bedtime-a', name: 'Bedtime', priority: 50,
    enabled: true, startMinute: 1260, endMinute: 420, restrictedTargets: ['video'], version: 1,
  };
  await assertSucceeds(setDoc(doc(parent, 'families/family-a/policies/bedtime-a'), policy));
  await assertSucceeds(setDoc(doc(parent, 'families/family-a/policy_overrides/override-a'), {
    familyId: 'family-a', target: 'video', allowed: true, expiresAtClient: '2026-08-13T00:00:00.000Z',
  }));
  await assertFails(setDoc(doc(child, 'families/family-a/policies/child-write'), policy));
  await assertFails(setDoc(doc(otherParent, 'families/family-a/policies/cross-family-write'), policy));
});

test('parent cannot bind a child UID directly to a device outside provisioning', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertFails(setDoc(doc(parent, 'families/family-a/devices/direct-bind'), {familyId: 'family-a', deviceId: 'direct-bind', ownerUid: 'parent-a', memberId: 'child-a', memberUid: 'child-a', role: 'childDevice', status: 'active'}));
});

test('parent may register a token only for an owned parent device', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertSucceeds(setDoc(doc(parent, 'families/family-a/devices/parent-device-a'), {familyId: 'family-a', deviceId: 'parent-device-a', ownerUid: 'parent-a', memberId: 'parent-a', memberUid: null, role: 'parentDevice', status: 'active'}));
  await assertSucceeds(setDoc(doc(parent, 'families/family-a/devices/parent-device-a/notification_tokens/token-a'), {familyId: 'family-a', userUid: 'parent-a', token: 'test-token', status: 'active'}));
  await assertFails(setDoc(doc(parent, 'families/family-a/devices/device-a/notification_tokens/forged-token'), {familyId: 'family-a', userUid: 'parent-a', token: 'forged-token', status: 'active'}));
});

test('active device can create incident while revoked device cannot', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  await assertSucceeds(setDoc(doc(child, 'families/family-a/incidents/incident-a'), {familyId: 'family-a', deviceId: 'device-a', status: 'queued'}));
  await assertFails(setDoc(doc(child, 'families/family-a/incidents/incident-r'), {familyId: 'family-a', deviceId: 'revoked-a', status: 'queued'}));
});

test('only the active child device can report its scoped enforcement status', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  const parent = environment.authenticatedContext('parent-a').firestore();
  const status = {
    familyId: 'family-a', deviceId: 'device-a', memberUid: 'child-a', lifecycle: 'offline',
    requiredPolicyVersion: 4, reportedAtClient: '2026-08-12T22:00:00.000Z',
  };
  await assertSucceeds(setDoc(doc(child, 'families/family-a/devices/device-a/enforcement_status/current'), status));
  await assertSucceeds(getDoc(doc(parent, 'families/family-a/devices/device-a/enforcement_status/current')));
  await assertFails(setDoc(doc(parent, 'families/family-a/devices/device-a/enforcement_status/current'), {
    ...status, memberUid: 'parent-a', lifecycle: 'active',
  }));
  await assertFails(setDoc(doc(child, 'families/family-a/devices/revoked-a/enforcement_status/current'), {
    ...status, deviceId: 'revoked-a',
  }));
  await assertFails(setDoc(doc(child, 'families/family-b/devices/device-a/enforcement_status/current'), status));
});

test('only an active child device may create its scoped usage summary', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  const parent = environment.authenticatedContext('parent-a').firestore();
  const summary = {
    familyId: 'family-a', deviceId: 'device-a', memberUid: 'child-a',
    usageId: 'usage-a', target: 'com.google.android.youtube',
    dayStartClient: '2026-08-12T00:00:00.000Z', totalMilliseconds: 3480000,
    capturedAtClient: '2026-08-12T17:00:00.000Z',
  };
  const path = 'families/family-a/devices/device-a/usage_summaries/usage-a';
  await assertSucceeds(setDoc(doc(child, path), summary));
  await assertSucceeds(getDoc(doc(parent, path)));
  await assertFails(setDoc(doc(parent, 'families/family-a/devices/device-a/usage_summaries/usage-parent'), {
    ...summary, usageId: 'usage-parent', memberUid: 'parent-a',
  }));
  await assertFails(setDoc(doc(child, 'families/family-a/devices/revoked-a/usage_summaries/usage-r'), {
    ...summary, deviceId: 'revoked-a', usageId: 'usage-r',
  }));
  await assertFails(setDoc(doc(child, 'families/family-b/devices/device-a/usage_summaries/usage-b'), {
    ...summary, familyId: 'family-b', usageId: 'usage-b',
  }));
});

test('child exception request is owned by its active device and parent review is constrained', async () => {
  const child = environment.authenticatedContext('child-a').firestore();
  const parent = environment.authenticatedContext('parent-a').firestore();
  const otherParent = environment.authenticatedContext('parent-b').firestore();
  const path = 'families/family-a/exception_requests/request-a';
  const request = {
    familyId: 'family-a', requestId: 'request-a', childDeviceId: 'device-a',
    childMemberId: 'child-a', childUid: 'child-a', target: 'com.google.android.youtube',
    requestedDurationMinutes: 30, reason: 'homework', createdAtClient: '2026-08-12T12:00:00.000Z',
    requestExpiresAtClient: '2026-08-13T12:00:00.000Z', status: 'pending',
    updatedByUid: 'child-a', syncStatus: 'client_submitted', idempotencyKey: 'exception-create-a',
  };
  await assertSucceeds(setDoc(doc(child, path), request));
  await assertSucceeds(getDoc(doc(child, path)));
  await assertSucceeds(getDoc(doc(parent, path)));
  await assertFails(setDoc(doc(child, 'families/family-a/exception_requests/request-forged'), {
    ...request, requestId: 'request-forged', childUid: 'another-child', idempotencyKey: 'forged-child',
  }));
  await assertFails(setDoc(doc(child, 'families/family-a/exception_requests/request-revoked'), {
    ...request, requestId: 'request-revoked', childDeviceId: 'revoked-a', idempotencyKey: 'revoked-child',
  }));
  await assertFails(setDoc(doc(child, 'families/family-b/exception_requests/request-cross'), {
    ...request, familyId: 'family-b', requestId: 'request-cross', idempotencyKey: 'cross-family',
  }));
  await assertFails(setDoc(doc(child, path), {
    ...request, status: 'approved', reviewedAtClient: '2026-08-12T12:05:00.000Z',
    updatedByUid: 'child-a', idempotencyKey: 'child-self-approval',
  }));
  await assertSucceeds(setDoc(doc(parent, path), {
    ...request, status: 'approved', reviewedByMemberId: 'parent-a',
    reviewedAtClient: '2026-08-12T12:05:00.000Z', overrideId: 'override-a',
    expiresAtClient: '2026-08-12T12:35:00.000Z', updatedByUid: 'parent-a',
    idempotencyKey: 'parent-approval',
  }));
  await assertFails(setDoc(doc(otherParent, path), {
    ...request, status: 'denied', reviewedByMemberId: 'parent-b',
    reviewedAtClient: '2026-08-12T12:06:00.000Z', updatedByUid: 'parent-b',
    idempotencyKey: 'cross-family-review',
  }));
});

test('mobile client cannot write notification event directly', async () => {
  const parent = environment.authenticatedContext('parent-a').firestore();
  await assertFails(setDoc(doc(parent, 'families/family-a/notification_events/n-a'), {familyId: 'family-a', status: 'pendingBackend'}));
  assert.ok(true);
});
