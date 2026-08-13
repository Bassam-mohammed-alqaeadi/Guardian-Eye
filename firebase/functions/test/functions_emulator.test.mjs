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

async function waitForDocument(path, predicate, timeoutMs = 10000) {
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
  await db.doc('families/family-functions/members/child-member-functions').set({familyId: 'family-functions', memberId: 'child-member-functions', role: 'child', displayName: 'Child', status: 'active'});

  const issued = await call('createChildDeviceProvisioning', parent.idToken, {familyId: 'family-functions', targetMemberId: 'child-member-functions'});
  assert.equal(issued.status, 200, JSON.stringify(issued.body));
  assert.match(issued.body.result.code, /^\d{6}$/);

  const redeemed = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId: issued.body.result.pairingId, code: issued.body.result.code, deviceId: 'child-device-functions'});
  assert.equal(redeemed.status, 200, JSON.stringify(redeemed.body));
  assert.equal(redeemed.body.result.state, 'enrolled');

  const childBinding = await db.doc('families/family-functions/members/' + child.localId).get();
  assert.equal(childBinding.get('memberUid'), child.localId);
  assert.equal(childBinding.get('memberId'), 'child-member-functions');
  const device = await db.doc('families/family-functions/devices/child-device-functions').get();
  assert.equal(device.get('memberUid'), child.localId);
  assert.equal(device.get('ownerUid'), parent.localId);

  const replay = await call('redeemChildDeviceProvisioning', child.idToken, {familyId: 'family-functions', pairingId: issued.body.result.pairingId, code: issued.body.result.code, deviceId: 'child-device-functions'});
  assert.notEqual(replay.status, 200);
  assert.equal(replay.body.error.status, 'FAILED_PRECONDITION');
});
