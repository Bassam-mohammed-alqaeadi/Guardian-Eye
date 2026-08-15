import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GCLOUD_PROJECT ?? 'guardian-eye-emulator';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const functionsBaseUrl = process.env.FUNCTIONS_EMULATOR_URL ?? `http://127.0.0.1:5001/${projectId}/us-central1`;
process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;

const app = initializeApp({projectId}, `functions-emulator-test-${Date.now()}`);
const db = getFirestore(app);

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitForDocument(path, predicate, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const snapshot = await db.doc(path).get();
    if (snapshot.exists && predicate(snapshot.data())) return snapshot.data();
    await sleep(150);
  }
  throw new Error(`timed out waiting for ${path}`);
}

async function signUp(email) {
  const response = await fetch(`http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=guardian-emulator`, {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({email, password: 'Phase8-pass-123!', returnSecureToken: true}),
  });
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return body;
}

async function call(name, token, data) {
  const response = await fetch(`${functionsBaseUrl}/${name}`, {
    method: 'POST',
    headers: {'content-type': 'application/json', authorization: `Bearer ${token}`},
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

before(async () => {
  await db.doc('families/family-functions').set({ownerUid: 'seed-owner', status: 'active'});
});

after(async () => { await deleteApp(app); });

test('incident and SOS creates produce durable notification events without claiming FCM delivery', async () => {
  await db.doc('families/family-functions/incidents/incident-functions').set({familyId: 'family-functions', deviceId: 'device-functions', status: 'queued'});
  const incidentEvent = await waitForDocument('families/family-functions/notification_events/incident_incident-functions', (data) => data.status === 'noActiveToken');
  assert.equal(incidentEvent.kind, 'incident');
  assert.equal(incidentEvent.sourceId, 'incident-functions');

  await db.doc('families/family-functions/sos/sos-functions').set({familyId: 'family-functions', deviceId: 'device-functions', status: 'queued'});
  const sosEvent = await waitForDocument('families/family-functions/notification_events/sos_sos-functions', (data) => data.status === 'noActiveToken');
  assert.equal(sosEvent.kind, 'sos');
  assert.equal(sosEvent.sourceId, 'sos-functions');
});

test('child provisioning binds a distinct child UID once and rejects replay', async () => {
  const parent = await signUp('phase8-parent@example.test');
  const child = await signUp('phase8-child@example.test');
  await db.doc('families/family-functions/members/' + parent.localId).set({familyId: 'family-functions', memberId: parent.localId, memberUid: parent.localId, role: 'primaryParent', status: 'active'});
  // Option D: no remote child member exists before issuance; the child is
  // local-only until redemption creates the UID-keyed member document.

  const issued = await call('createChildDeviceProvisioning', parent.idToken, {familyId: 'family-functions', targetMemberId: 'child-member-functions', displayName: 'Child'});
  assert.equal(issued.status, 200, JSON.stringify(issued.body));
  assert.match(issued.body.result.code, /^\d{6}$/);

  const sessionBefore = await db.doc('families/family-functions/device_pairings/' + issued.body.result.pairingId).get();
  assert.equal(sessionBefore.get('displayName'), 'Child');
  assert.equal(sessionBefore.get('targetMemberId'), 'child-member-functions');
  assert.equal(sessionBefore.get('status'), 'pending');

  const redeemed = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId: issued.body.result.pairingId, code: issued.body.result.code, deviceId: 'child-device-functions'});
  assert.equal(redeemed.status, 200, JSON.stringify(redeemed.body));
  assert.equal(redeemed.body.result.state, 'enrolled');

  const childBinding = await db.doc('families/family-functions/members/' + child.localId).get();
  assert.equal(childBinding.exists, true);
  assert.equal(childBinding.get('memberUid'), child.localId);
  assert.equal(childBinding.get('memberId'), 'child-member-functions');
  assert.equal(childBinding.get('role'), 'child');
  assert.equal(childBinding.get('status'), 'active');
  assert.equal(childBinding.get('displayName'), 'Child');
  const device = await db.doc('families/family-functions/devices/child-device-functions').get();
  assert.equal(device.get('memberUid'), child.localId);
  assert.equal(device.get('ownerUid'), parent.localId);

  const replay = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId: issued.body.result.pairingId, code: issued.body.result.code, deviceId: 'child-device-functions'});
  assert.notEqual(replay.status, 200);
  assert.equal(replay.body.error.status, 'FAILED_PRECONDITION');
});

test('child provisioning rejects wrong code, expired code, lockout, wrong family, child issuer, and unauthenticated redemption', async () => {
  const parent = await signUp('phase8b-parent@example.test');
  const child = await signUp('phase8b-child@example.test');
  const stranger = await signUp('phase8b-stranger@example.test');
  await db.doc('families/family-functions/members/' + parent.localId).set({familyId: 'family-functions', memberId: parent.localId, memberUid: parent.localId, role: 'primaryParent', status: 'active'});

  // Wrong family: a parent of another family cannot issue into this family.
  const wrongFamily = await call('createChildDeviceProvisioning', stranger.idToken, {familyId: 'family-functions', targetMemberId: 'child-x', displayName: 'X'});
  assert.notEqual(wrongFamily.status, 200);
  assert.equal(wrongFamily.body.error.status, 'PERMISSION_DENIED');

  // A child-role account cannot issue provisioning.
  await db.doc('families/family-functions/members/' + child.localId).set({familyId: 'family-functions', memberId: 'child-x', memberUid: child.localId, role: 'child', status: 'active'});
  const childIssuer = await call('createChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', targetMemberId: 'child-x', displayName: 'X'});
  assert.notEqual(childIssuer.status, 200);
  assert.equal(childIssuer.body.error.status, 'PERMISSION_DENIED');

  // Issuance without a pre-existing remote child member succeeds (Option D).
  const issued = await call('createChildDeviceProvisioning', parent.idToken, {familyId: 'family-functions', targetMemberId: 'child-member-b', displayName: 'Child B'});
  assert.equal(issued.status, 200, JSON.stringify(issued.body));
  const pairingId = issued.body.result.pairingId;

  // Wrong code → permission-denied (pairing_invalid_code).
  const wrongCode = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId, code: '000000', deviceId: 'child-device-b'});
  assert.notEqual(wrongCode.status, 200);
  assert.equal(wrongCode.body.error.status, 'PERMISSION_DENIED');

  // Unauthenticated redemption rejected.
  const noAuth = await fetch(`http://127.0.0.1:5001/${process.env.GCLOUD_PROJECT ?? 'guardian-eye-emulator'}/us-central1/redeemChildDeviceProvisioning`, {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({data: {familyId: 'family-functions', pairingId, code: issued.body.result.code, deviceId: 'child-device-b'}}),
  });
  assert.equal(noAuth.status, 401);

  // Expired session → expired (failed-precondition pairing_expired).
  const expiredIssued = await call('createChildDeviceProvisioning', parent.idToken, {familyId: 'family-functions', targetMemberId: 'child-member-c', displayName: 'Child C'});
  assert.equal(expiredIssued.status, 200);
  await db.doc('families/family-functions/device_pairings/' + expiredIssued.body.result.pairingId).update({expiresAt: new Date(Date.now() - 60_000)});
  const expired = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId: expiredIssued.body.result.pairingId, code: expiredIssued.body.result.code, deviceId: 'child-device-c'});
  assert.notEqual(expired.status, 200);
  assert.equal(expired.body.error.status, 'FAILED_PRECONDITION');

  // Fifth failed attempt locks the session.
  const lockedIssued = await call('createChildDeviceProvisioning', parent.idToken, {familyId: 'family-functions', targetMemberId: 'child-member-d', displayName: 'Child D'});
  assert.equal(lockedIssued.status, 200);
  for (let attempt = 1; attempt <= 5; attempt++) {
    const bad = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId: lockedIssued.body.result.pairingId, code: '111111', deviceId: 'child-device-d'});
    assert.notEqual(bad.status, 200);
  }
  const lockedSession = await db.doc('families/family-functions/device_pairings/' + lockedIssued.body.result.pairingId).get();
  assert.equal(lockedSession.get('status'), 'rejected');
  assert.equal(lockedSession.get('attemptCount'), 5);

  // Duplicate redemption is idempotent: after a successful redeem, a second
  // redeem of the same enrolled session is rejected without creating a second
  // member or device.
  const firstRedeem = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId, code: issued.body.result.code, deviceId: 'child-device-b'});
  assert.equal(firstRedeem.status, 200, JSON.stringify(firstRedeem.body));
  const second = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId, code: issued.body.result.code, deviceId: 'child-device-b'});
  assert.notEqual(second.status, 200);
  assert.equal(second.body.error.status, 'FAILED_PRECONDITION');
});
