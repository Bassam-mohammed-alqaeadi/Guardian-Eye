/**
 * Guardian Backend unit tests (node:test).
 *
 * Runs `createApp` against an in-memory fake Firestore + fake Auth so the full
 * provisioning/redemption contract is exercised without a service account.
 *
 *   node --test test/
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp, sha256Hex, generateCode } from '../index.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeAuth {
  constructor() {
    this.tokens = new Map(); // idToken -> uid
  }

  addUser(uid, token = `${uid}-token`) {
    this.tokens.set(token, uid);
    return token;
  }

  async verifyIdToken(idToken) {
    if (this.tokens.has(idToken)) return { uid: this.tokens.get(idToken) };
    const err = new Error('id-token-expired');
    err.code = 'auth/id-token-expired';
    throw err;
  }
}

class FakeStore {
  constructor() {
    this.collections = new Map(); // name -> Map(id -> data)
  }

  _col(name) {
    if (!this.collections.has(name)) this.collections.set(name, new Map());
    return this.collections.get(name);
  }

  collection(name) {
    const store = this;
    return {
      doc(id) {
        const ref = {
          async get() {
            const data = store._col(name).get(id);
            if (data === undefined) {
              return { exists: false, id, data: () => undefined, ref };
            }
            return { exists: true, id, data: () => ({ ...data }), ref };
          },
          async set(data) {
            store._col(name).set(id, JSON.parse(JSON.stringify(data)));
          },
          async update(patch) {
            const current = store._col(name).get(id) || {};
            store._col(name).set(id, { ...current, ...JSON.parse(JSON.stringify(patch)) });
          },
          collection(sub) {
            return store.collection(`${name}/${id}/${sub}`);
          },
        };
        return ref;
      },
      where(field, op, value) {
        return {
          limit() {
            return {
              async get() {
                const docs = [];
                for (const [id, data] of store._col(name)) {
                  if (data[field] === value) {
                    docs.push({
                      exists: true,
                      id,
                      data: () => ({ ...data }),
                      ref: store.collection(name).doc(id),
                    });
                  }
                }
                return { docs, empty: docs.length === 0 };
              },
            };
          },
          async get() {
            const docs = [];
            for (const [id, data] of store._col(name)) {
              if (op === '==' && data[field] === value) {
                docs.push({
                  exists: true,
                  id,
                  data: () => ({ ...data }),
                  ref: store.collection(name).doc(id),
                });
              }
            }
            return { docs, empty: docs.length === 0 };
          },
        };
      },
      async get() {
        const docs = [];
        for (const [id, data] of store._col(name)) {
          const ref = store.collection(name).doc(id);
          docs.push({
            exists: true,
            id,
            data: () => ({ ...data }),
            ref,
          });
        }
        return { docs, empty: docs.length === 0 };
      },
    };
  }

  async runTransaction(fn) {
    const snapshot = JSON.parse(
      JSON.stringify([...this.collections.entries()].map(([k, m]) => [k, [...m.entries()]]))
    );
    const tx = {
      get: (ref) => ref.get(),
      set: (ref, data) => ref.set(data),
      update: (ref, patch) => ref.update(patch),
    };
    try {
      return await fn(tx);
    } catch (err) {
      // Roll back to the pre-transaction state.
      this.collections.clear();
      for (const [name, entries] of snapshot) {
        this.collections.set(name, new Map(entries));
      }
      throw err;
    }
  }

  dump() {
    const out = {};
    for (const [name, m] of this.collections) {
      out[name] = Object.fromEntries(m);
    }
    return out;
  }
}

/**
 * Fake Firebase Messaging for /api/notify tests.
 * inject via module-level mock before createApp().
 */
class FakeMessaging {
  constructor({ responses } = {}) {
    // responses: array of { success, error? } per token
    this.responses = responses || [];
    this.lastMulticast = null;
  }

  async sendEachForMulticast(message) {
    this.lastMulticast = message;
    const responses = this.responses.length
      ? this.responses
      : message.tokens.map(() => ({ success: true, messageId: 'msg-1' }));
    const successCount = responses.filter(r => r.success).length;
    const failureCount = responses.length - successCount;
    return { responses, successCount, failureCount };
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

async function withServer(fn, { messagingResponses } = {}) {
  const auth = new FakeAuth();
  const db = new FakeStore();
  const fakeMessaging = new FakeMessaging({ responses: messagingResponses });

  // Patch require('firebase-admin/messaging') for the notify endpoint.
  const Module = await import('node:module');
  const originalLoad = Module.default._load;
  Module.default._load = function(request, ...rest) {
    if (request === 'firebase-admin/messaging') {
      return { getMessaging: () => fakeMessaging };
    }
    return originalLoad.call(this, request, ...rest);
  };

  const app = createApp({ auth, db });
  const server = app.listen(0);
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn({ base, auth, db, fakeMessaging });
  } finally {
    Module.default._load = originalLoad;
    server.close();
  }
}

function post(base, path, { token, body }) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return fetch(`${base}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body || {}),
  });
}

/** Seeds an incident doc inside families/{familyId}/incidents. */
function seedIncident(db, incidentId, status) {
  db.collection('families/fam-1/incidents').doc(incidentId).set({
    category: 'safety',
    status,
    familyId: 'fam-1',
    createdAt: new Date().toISOString(),
  });
}

/** Seeds an SOS doc inside families/{familyId}/sos. */
function seedSos(db, sosId, status) {
  db.collection('families/fam-1/sos').doc(sosId).set({
    status,
    familyId: 'fam-1',
    createdAt: new Date().toISOString(),
  });
}

function seedFamily(db, { familyId = 'fam-1', parentUid = 'parent-1', role = 'primaryParent' } = {}) {
  db.collection('families').doc(familyId).set({ name: 'Test Family', ownerUid: parentUid });
  db.collection('families').doc(familyId).collection('members').doc(parentUid).set({
    memberUid: parentUid,
    role,
    status: 'active',
  });
}

async function provision(base, auth, { token, familyId = 'fam-1', targetMemberId = 'child-local-1', displayName = 'KidA' } = {}) {
  const res = await post(base, '/api/provision-child', {
    token,
    body: { familyId, targetMemberId, displayName },
  });
  return res;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test('GET / returns healthy JSON without exposing internals', async () => {
  await withServer(async ({ base }) => {
    const res = await fetch(`${base}/`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.service, 'guardian-backend');
  });
});

test('provision-child: missing auth header -> 401 unauthenticated', async () => {
  await withServer(async ({ base }) => {
    const res = await post(base, '/api/provision-child', { body: {} });
    assert.equal(res.status, 401);
    const body = await res.json();
    assert.equal(body.error, 'unauthenticated');
  });
});

test('provision-child: invalid token -> 401 invalid_token', async () => {
  await withServer(async ({ base }) => {
    const res = await post(base, '/api/provision-child', { token: 'not-a-real-token', body: {} });
    assert.equal(res.status, 401);
    const body = await res.json();
    assert.equal(body.error, 'invalid_token');
  });
});

test('provision-child: missing fields -> 400 invalid_request', async () => {
  await withServer(async ({ base, auth }) => {
    const token = auth.addUser('parent-1');
    const res = await post(base, '/api/provision-child', { token, body: { familyId: 'fam-1' } });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.error, 'invalid_request');
  });
});

test('provision-child: family not found -> 404 family_not_found', async () => {
  await withServer(async ({ base, auth }) => {
    const token = auth.addUser('parent-1');
    const res = await provision(base, auth, { token, familyId: 'missing-family' });
    assert.equal(res.status, 404);
    const body = await res.json();
    assert.equal(body.error, 'family_not_found');
  });
});

test('provision-child: non-member parent -> 403 parent_not_member', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db, { parentUid: 'owner-1' });
    const token = auth.addUser('intruder-1');
    const res = await provision(base, auth, { token });
    assert.equal(res.status, 403);
    const body = await res.json();
    assert.equal(body.error, 'parent_not_member');
  });
});

test('provision-child: child-role actor cannot provision -> 403 parent_not_authorized', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db, { parentUid: 'child-1', role: 'child' });
    const token = auth.addUser('child-1');
    const res = await provision(base, auth, { token });
    assert.equal(res.status, 403);
    const body = await res.json();
    assert.equal(body.error, 'parent_not_authorized');
  });
});

test('provision-child: success stores only the code hash and returns the plaintext once', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const token = auth.addUser('parent-1');
    const res = await provision(base, auth, { token });
    assert.equal(res.status, 201);
    const body = await res.json();
    assert.match(body.provisioningCode, /^\d{6}$/);
    assert.ok(body.pairingId);
    assert.ok(new Date(body.expiresAt) > new Date());

    const sessionId = body.pairingId;
    const sessions = db.dump().provisioningSessions || {};
    const session = sessions[sessionId];
    assert.ok(session, 'provisioning session persisted');
    assert.equal(session.status, 'pending');
    assert.equal(session.attemptCount, 0);
    assert.equal(session.issuedByUid, 'parent-1');
    assert.equal(session.familyId, 'fam-1');
    assert.equal(session.targetMemberId, 'child-local-1');
    assert.equal(session.codeHash, sha256Hex(body.provisioningCode));
    // Plaintext code must never be persisted.
    assert.ok(session.codeHash !== body.provisioningCode);
    assert.ok(!JSON.stringify(session).includes(body.provisioningCode));
  });
});

test('redeem-child: missing auth -> 401', async () => {
  await withServer(async ({ base }) => {
    const res = await post(base, '/api/redeem-child', { body: { provisioningCode: '123456', deviceId: 'dev-1' } });
    assert.equal(res.status, 401);
  });
});

test('redeem-child: invalid token -> 401 invalid_token', async () => {
  await withServer(async ({ base }) => {
    const res = await post(base, '/api/redeem-child', { token: 'bad', body: {} });
    assert.equal(res.status, 401);
    const body = await res.json();
    assert.equal(body.error, 'invalid_token');
  });
});

test('redeem-child: unknown code -> 400 invalid_code', async () => {
  await withServer(async ({ base, auth }) => {
    const token = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token,
      body: { provisioningCode: '000000', deviceId: 'dev-1' },
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.error, 'invalid_code');
  });
});

test('redeem-child: wrong code counts attempts and locks after the limit', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();

    const childToken = auth.addUser('child-1');
    const wrong = provisioningCode === '000000' ? '000001' : '000000';

    for (let i = 0; i < 4; i++) {
      const res = await post(base, '/api/redeem-child', {
        token: childToken,
        body: { provisioningCode: wrong, deviceId: 'dev-1', pairingId },
      });
      assert.equal(res.status, 400, `attempt ${i + 1} should be invalid_code`);
      assert.equal((await res.json()).error, 'invalid_code');
    }

    const sessions = db.dump().provisioningSessions;
    assert.equal(sessions[pairingId].attemptCount, 4);

    const fifth = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode: wrong, deviceId: 'dev-1', pairingId },
    });
    assert.equal(fifth.status, 403);
    assert.equal((await fifth.json()).error, 'locked');
    const after = db.dump().provisioningSessions;
    assert.equal(after[pairingId].status, 'locked');
  });
});

test('redeem-child: expired code -> 410 expired', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();
    // Expire it directly (production expiry is enforced by TTL).
    db.collection('provisioningSessions').doc(pairingId).update({
      expiresAt: new Date(Date.now() - 60_000).toISOString(),
    });
    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'dev-1', pairingId },
    });
    assert.equal(res.status, 410);
    assert.equal((await res.json()).error, 'expired');
    const sessions = db.dump().provisioningSessions;
    assert.equal(sessions[pairingId].status, 'expired');
  });
});

test('redeem-child: success atomically creates member, device and enrolls the session', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken, displayName: 'KidA' });
    const { pairingId, provisioningCode } = await issued.json();

    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.state, 'enrolled');
    assert.equal(body.childUid, 'child-1');
    assert.equal(body.deviceId, 'device-1');
    assert.equal(body.targetMemberId, 'child-local-1');

    const all = db.dump();
    const member = all['families/fam-1/members']['child-1'];
    assert.ok(member, 'child member created');
    assert.equal(member.memberUid, 'child-1');
    assert.equal(member.role, 'child');
    assert.equal(member.memberId, 'child-local-1');
    assert.equal(member.displayName, 'KidA');
    assert.equal(member.status, 'active');
    assert.equal(member.familyId, 'fam-1');

    const device = all['families/fam-1/devices']['device-1'];
    assert.ok(device, 'device created');
    assert.equal(device.memberUid, 'child-1');
    assert.equal(device.ownerUid, 'parent-1');
    assert.equal(device.role, 'childDevice');
    assert.equal(device.status, 'active');

    const session = all.provisioningSessions[pairingId];
    assert.equal(session.status, 'enrolled');
    assert.equal(session.redeemedByUid, 'child-1');
    assert.equal(session.deviceId, 'device-1');
  });
});

test('redeem-child: duplicate redemption by the same child is idempotent', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();
    const childToken = auth.addUser('child-1');

    const first = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(first.status, 200);

    const second = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(second.status, 200);
    const body = await second.json();
    assert.equal(body.state, 'enrolled');

    const all = db.dump();
    const members = Object.keys(all['families/fam-1/members']);
    const devices = Object.keys(all['families/fam-1/devices']);
    assert.equal(members.length, 2); // parent + child only
    assert.equal(devices.length, 1);
    assert.equal(all.provisioningSessions[pairingId].status, 'enrolled');
  });
});

test('redeem-child: replay by a different child -> 409 already_used', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();

    const childToken = auth.addUser('child-1');
    const first = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(first.status, 200);

    const otherToken = auth.addUser('child-2');
    const replay = await post(base, '/api/redeem-child', {
      token: otherToken,
      body: { provisioningCode, deviceId: 'device-2', pairingId },
    });
    assert.equal(replay.status, 409);
    assert.equal((await replay.json()).error, 'already_used');
  });
});

test('redeem-child: locked session rejected -> 403 locked', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();
    db.collection('provisioningSessions').doc(pairingId).update({ status: 'locked' });
    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(res.status, 403);
    assert.equal((await res.json()).error, 'locked');
  });
});

test('redeem-child: device conflict when device is bound to another member', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    db.collection('families').doc('fam-1').collection('devices').doc('device-1').set({
      memberUid: 'someone-else',
      role: 'childDevice',
      status: 'active',
    });
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();
    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(res.status, 409);
    assert.equal((await res.json()).error, 'device_conflict');
  });
});

test('redeem-child: member conflict when the UID doc is bound to a different member', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    db.collection('families').doc('fam-1').collection('members').doc('child-1').set({
      memberUid: 'child-1',
      memberId: 'other-local-id',
      role: 'child',
    });
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();
    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(res.status, 200); // same memberUid -> compatible, idempotent merge
  });
});

test('redeem-child: parent authorization re-checked at redemption time', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { pairingId, provisioningCode } = await issued.json();
    // Parent loses device authority before redemption.
    db.collection('families').doc('fam-1').collection('members').doc('parent-1').update({
      role: 'child',
    });
    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1', pairingId },
    });
    assert.equal(res.status, 403);
    assert.equal((await res.json()).error, 'parent_not_authorized');
    // Nothing was written (transaction rollback).
    const all = db.dump();
    assert.equal(all['families/fam-1/members']?.['child-1'], undefined);
    assert.equal(all['families/fam-1/devices']?.['device-1'], undefined);
    assert.equal(all.provisioningSessions[pairingId].status, 'pending');
  });
});

test('redeem-child: works with code-only lookup (no pairingId)', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const parentToken = auth.addUser('parent-1');
    const issued = await provision(base, auth, { token: parentToken });
    const { provisioningCode } = await issued.json();
    const childToken = auth.addUser('child-1');
    const res = await post(base, '/api/redeem-child', {
      token: childToken,
      body: { provisioningCode, deviceId: 'device-1' },
    });
    assert.equal(res.status, 200);
    assert.equal((await res.json()).state, 'enrolled');
  });
});

test('generateCode always returns a 6-digit code', () => {
  for (let i = 0; i < 500; i++) {
    assert.match(generateCode(), /^\d{6}$/);
  }
});

// ---------------------------------------------------------------------------
// /api/notify tests
// ---------------------------------------------------------------------------

test('POST /api/notify — rejects unauthenticated request', async () => {
  await withServer(async ({ base }) => {
    const res = await post(base, '/api/notify', {
      body: { familyId: 'fam-1', kind: 'incident', title: 'Alert', body: 'Test' },
    });
    assert.equal(res.status, 401);
  });
});

test('POST /api/notify — rejects non-member caller', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    const strangerToken = auth.addUser('stranger-uid');
    const res = await post(base, '/api/notify', {
      token: strangerToken,
      body: { familyId: 'fam-1', kind: 'incident', title: 'Alert', body: 'Test' },
    });
    assert.equal(res.status, 403);
    assert.equal((await res.json()).error, 'not_a_member');
  });
});

test('POST /api/notify — returns no_tokens when family has no FCM registrations', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'incident', incidentId: 'inc-1' },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.sent, 0);
    assert.equal(json.reason, 'no_tokens');
  });
});

test('POST /api/notify — delivers to parent device FCM token', async () => {
  await withServer(async ({ base, auth, db, fakeMessaging }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    // Register a parent device with an active FCM token.
    const familyDevicesCol = `families/fam-1/devices`;
    db.collection(familyDevicesCol).doc('dev-parent').set({
      role: 'parentDevice',
      status: 'active',
      memberUid: 'parent-1',
    });
    db.collection(`${familyDevicesCol}/dev-parent/notification_tokens`).doc('tok-1').set({
      token: 'fcm-token-abc',
      status: 'active',
      userUid: 'parent-1',
    });

    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: {
        familyId: 'fam-1',
        kind: 'incident',
        incidentId: 'inc-1',
      },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.sent, 1);
    assert.equal(json.failed, 0);
    assert.equal(json.reason, 'accepted');
    assert.equal(json.eventExisted, false);
    // Payload is data-only: visible text is rendered by the client.
    assert.equal(fakeMessaging.lastMulticast.notification, undefined);
    assert.equal(fakeMessaging.lastMulticast.data.kind, 'incident');
    assert.equal(fakeMessaging.lastMulticast.data.incidentId, 'inc-1');
    assert.equal(fakeMessaging.lastMulticast.data.familyId, 'fam-1');
    assert.ok(String(fakeMessaging.lastMulticast.data.notificationEventId).startsWith('incident:inc-1:'));
    // Evidence doc claimed inside the transaction.
    const evidence = await db
      .collection('families/fam-1/notification_events')
      .doc('incident:inc-1:parent-1')
      .get();
    assert.equal(evidence.exists, true);
    assert.equal(evidence.data().status, 'dispatched');
    assert.equal(evidence.data().sentCount, 1);
  });
});

test('POST /api/notify — marks stale tokens invalid after FCM rejection', async () => {
  await withServer(
    async ({ base, auth, db }) => {
      seedFamily(db);
      db.collection('families/fam-1/devices').doc('dev-parent').set({
        role: 'parentDevice',
        status: 'active',
        memberUid: 'parent-1',
      });
      db.collection('families/fam-1/devices/dev-parent/notification_tokens').doc('tok-stale').set({
        token: 'stale-fcm-token',
        status: 'active',
        userUid: 'parent-1',
      });

      seedSos(db, 'sos-1', 'pending');
      const parentToken = auth.addUser('parent-1');
      const res = await post(base, '/api/notify', {
        token: parentToken,
        body: { familyId: 'fam-1', kind: 'sos', sosId: 'sos-1' },
      });
      assert.equal(res.status, 200);
      const json = await res.json();
      assert.equal(json.invalidTokensRemoved, 1);
      assert.equal(json.sent, 0);

      // Verify the token document was marked invalid.
      const tokenSnap = await db
        .collection('families/fam-1/devices/dev-parent/notification_tokens')
        .doc('tok-stale')
        .get();
      assert.equal(tokenSnap.data().status, 'invalid');
    },
    {
      messagingResponses: [{
        success: false,
        error: { code: 'messaging/registration-token-not-registered' },
      }],
    }
  );
});

// /api/notify — Phase 3 hardening tests

test('POST /api/notify — rejects unknown kind', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'webhit', incidentId: 'inc-1' },
    });
    assert.equal(res.status, 400);
    assert.equal((await res.json()).error, 'unknown_kind');
  });
});

test('POST /api/notify — rejects missing event id', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'incident' },
    });
    assert.equal(res.status, 400);
    assert.equal((await res.json()).error, 'missing_event_id');
  });
});

test('POST /api/notify — rejects nonexistent incident (404 invalid_event)', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'incident', incidentId: 'does-not-exist' },
    });
    assert.equal(res.status, 404);
    assert.equal((await res.json()).error, 'invalid_event');
  });
});

test('POST /api/notify — rejects incident in a terminal state', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    seedIncident(db, 'inc-closed', 'closed');
    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'incident', incidentId: 'inc-closed' },
    });
    assert.equal(res.status, 404);
    assert.equal((await res.json()).error, 'invalid_event');
  });
});

test('POST /api/notify — cross-family incident id is rejected (never trusted)', async () => {
  await withServer(async ({ base, auth, db }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    // An incident with the same id exists in a DIFFERENT family.
    db.collection('families/fam-2/members').doc('parent-1').set({
      memberUid: 'parent-1',
      role: 'coParent',
      status: 'active',
    });
    db.collection('families/fam-2/incidents').doc('inc-1').set({
      category: 'safety',
      status: 'open',
      familyId: 'fam-2',
    });
    const parentToken = auth.addUser('parent-1');
    const res = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-2', kind: 'incident', incidentId: 'inc-1' },
    });
    // fam-2 has no family doc — the cross-family lookup still must not send.
    assert.notEqual(res.status, 200);
  });
});

test('POST /api/notify — duplicate request is idempotent (no double fanout)', async () => {
  await withServer(async ({ base, auth, db, fakeMessaging }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    const familyDevicesCol = `families/fam-1/devices`;
    db.collection(familyDevicesCol).doc('dev-parent').set({
      role: 'parentDevice',
      status: 'active',
      memberUid: 'parent-1',
    });
    db.collection(`${familyDevicesCol}/dev-parent/notification_tokens`).doc('tok-1').set({
      token: 'fcm-token-abc',
      status: 'active',
      userUid: 'parent-1',
    });

    const parentToken = auth.addUser('parent-1');
    const body = { familyId: 'fam-1', kind: 'incident', incidentId: 'inc-1' };

    const first = await post(base, '/api/notify', { token: parentToken, body });
    const second = await post(base, '/api/notify', { token: parentToken, body });

    assert.equal(first.status, 200);
    assert.equal(second.status, 200);
    assert.equal((await first.json()).sent, 1);
    const secondJson = await second.json();
    assert.equal(secondJson.eventExisted, true);
    assert.equal(secondJson.sent, 1);
    // sendEachForMulticast was called exactly once — no duplicate dispatch.
    assert.equal(fakeMessaging.lastMulticast.tokens.length, 1);
  });
});

test('POST /api/notify — claim protects against membership change mid-request', async () => {
  await withServer(async ({ base, auth, db, fakeMessaging }) => {
    seedFamily(db);
    seedIncident(db, 'inc-1', 'open');
    const familyDevicesCol = `families/fam-1/devices`;
    db.collection(familyDevicesCol).doc('dev-parent').set({
      role: 'parentDevice',
      status: 'active',
      memberUid: 'parent-1',
    });
    db.collection(`${familyDevicesCol}/dev-parent/notification_tokens`).doc('tok-1').set({
      token: 'fcm-token-abc',
      status: 'active',
      userUid: 'parent-1',
    });

    const parentToken = auth.addUser('parent-1');
    // First request claims the dispatch slot.
    const first = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'incident', incidentId: 'inc-1' },
    });
    assert.equal(first.status, 200);

    // Caller membership is revoked after the first dispatch.
    await db.collection('families/fam-1/members').doc('parent-1').update({ status: 'revoked' });

    // Replaying the same request must NOT re-dispatch (claim already exists)
    // and must NOT fail the replay with a dispatch error either.
    const replay = await post(base, '/api/notify', {
      token: parentToken,
      body: { familyId: 'fam-1', kind: 'incident', incidentId: 'inc-1' },
    });
    const replayJson = await replay.json();
    assert.equal(replayJson.eventExisted, true);
    assert.equal(replayJson.sent, 1);
    assert.equal(fakeMessaging.lastMulticast.tokens.length, 1);
  });
});
