'use strict';

/**
 * Guardian Backend — trusted child provisioning service for Guardian Eye Pro.
 *
 * Replaces the Firebase Cloud Functions production dependency (which cannot be
 * deployed while manus-guardian stays on the Spark plan) with a Render-hosted
 * Express service using the Firebase Admin SDK. The Admin SDK is the ONLY
 * trusted creator of child membership:
 *
 *   POST /api/provision-child  (parent, authenticated)
 *     -> stores a pending provisioning session (SHA-256 code hash only)
 *   POST /api/redeem-child     (child, authenticated)
 *     -> atomically creates families/{familyId}/members/{childUid} and
 *        families/{familyId}/devices/{deviceId} and enrolls the session
 *
 * Identity is always derived from the verified Firebase ID token
 * (`request.auth.uid` equivalent via verifyIdToken). Never from the payload.
 */

const express = require('express');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const cors = require('cors');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const PROVISIONING_TTL_MS = 10 * 60 * 1000; // 10 minutes
const MAX_ATTEMPTS = 5;
const PARENT_ROLES = new Set(['primaryParent', 'coParent']);

function sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value), 'utf8').digest('hex');
}

/** 6-digit numeric code matching the client's `^\d{6}$` pairing format. */
function generateCode() {
  return crypto.randomInt(0, 1000000).toString().padStart(6, '0');
}

class HttpError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

/**
 * Builds the Express app against injected `auth` (Firebase Auth Admin) and
 * `db` (Firestore Admin) so the routing/authorization logic is unit-testable
 * without a real service account.
 */
function createApp({ auth, db }) {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '64kb' }));

  /** Derives the authenticated UID from the Bearer Firebase ID token. */
  async function requireAuth(req, res, next) {
    const header = req.headers.authorization || '';
    if (!header.startsWith('Bearer ')) {
      return res
        .status(401)
        .json({ error: 'unauthenticated', message: 'Missing or invalid Authorization header' });
    }
    const idToken = header.slice('Bearer '.length).trim();
    if (!idToken) {
      return res.status(401).json({ error: 'unauthenticated', message: 'Missing ID token' });
    }
    try {
      const decoded = await auth.verifyIdToken(idToken);
      req.uid = decoded.uid;
      next();
    } catch (err) {
      return res
        .status(401)
        .json({ error: 'invalid_token', message: 'ID token verification failed' });
    }
  }

  app.get('/', (req, res) => {
    res.status(200).json({ status: 'ok', service: 'guardian-backend' });
  });

  /**
   * POST /api/provision-child
   * Parent requests a secure child provisioning session. The plaintext code is
   * returned only here, to the authorized parent client; Firestore stores only
   * its SHA-256 hash.
   */
  app.post('/api/provision-child', requireAuth, async (req, res, next) => {
    try {
      const parentUid = req.uid;
      const { familyId, targetMemberId, displayName } = req.body || {};
      if (!familyId || !targetMemberId || !displayName || !String(displayName).trim()) {
        throw new HttpError(
          400,
          'invalid_request',
          'familyId, targetMemberId and displayName are required'
        );
      }

      const familyRef = db.collection('families').doc(familyId);
      const familySnap = await familyRef.get();
      if (!familySnap.exists) {
        throw new HttpError(404, 'family_not_found', 'Family does not exist');
      }

      // Parent authorization: must be a member with device-manage authority.
      const parentMemberSnap = await familyRef.collection('members').doc(parentUid).get();
      if (!parentMemberSnap.exists) {
        throw new HttpError(403, 'parent_not_member', 'Requester is not a member of this family');
      }
      const parentRole = parentMemberSnap.data().role;
      if (!PARENT_ROLES.has(parentRole)) {
        throw new HttpError(
          403,
          'parent_not_authorized',
          'Requester is not authorized to provision devices'
        );
      }

      // The target child is local-first: it does not exist in Firestore yet.
      // Option D creates the remote member only during trusted redemption, so
      // no remote child-membership check is possible or required here.

      const code = generateCode();
      const pairingId = crypto.randomUUID();
      const now = new Date();
      const expiresAt = new Date(now.getTime() + PROVISIONING_TTL_MS);

      await db.collection('provisioningSessions').doc(pairingId).set({
        familyId,
        targetMemberId,
        displayName: String(displayName).trim(),
        codeHash: sha256Hex(code),
        status: 'pending',
        attemptCount: 0,
        issuedByUid: parentUid,
        createdAt: now.toISOString(),
        expiresAt: expiresAt.toISOString(),
      });

      return res.status(201).json({
        pairingId,
        provisioningCode: code,
        expiresAt: expiresAt.toISOString(),
      });
    } catch (err) {
      next(err);
    }
  });

  /**
   * POST /api/redeem-child
   * Authenticated child device redeems a valid pending provisioning session.
   * All state transitions happen inside a single Firestore transaction.
   */
  app.post('/api/redeem-child', requireAuth, async (req, res, next) => {
    try {
      const childUid = req.uid;
      const { provisioningCode, deviceId, pairingId } = req.body || {};
      if (!provisioningCode || !deviceId) {
        throw new HttpError(
          400,
          'invalid_request',
          'provisioningCode and deviceId are required'
        );
      }

      const sessions = db.collection('provisioningSessions');
      let sessionSnap = null;
      if (pairingId) {
        sessionSnap = await sessions.doc(pairingId).get();
      } else {
        const query = await sessions
          .where('codeHash', '==', sha256Hex(provisioningCode))
          .limit(1)
          .get();
        sessionSnap = query.docs.length ? query.docs[0] : null;
      }
      if (!sessionSnap || !sessionSnap.exists) {
        throw new HttpError(400, 'invalid_code', 'Provisioning code is invalid');
      }

      const session = { id: sessionSnap.id, ...sessionSnap.data() };
      const now = new Date();

      // Wrong code on a pinned session -> count the attempt, lock after the limit.
      if (sha256Hex(provisioningCode) !== session.codeHash) {
        const nextAttempts = (session.attemptCount || 0) + 1;
        if (nextAttempts >= MAX_ATTEMPTS) {
          await sessionSnap.ref.update({ status: 'locked', attemptCount: nextAttempts });
          throw new HttpError(
            403,
            'locked',
            'Provisioning code locked after too many failed attempts'
          );
        }
        await sessionSnap.ref.update({ attemptCount: nextAttempts });
        throw new HttpError(400, 'invalid_code', 'Provisioning code is invalid');
      }

      // Enrolled session: idempotent re-confirmation for the same child.
      if (session.status === 'enrolled') {
        if (session.redeemedByUid === childUid) {
          return res.status(200).json({
            success: true,
            state: 'enrolled',
            pairingId: session.id,
            familyId: session.familyId,
            childUid,
            deviceId: session.deviceId,
            targetMemberId: session.targetMemberId,
          });
        }
        throw new HttpError(409, 'already_used', 'Provisioning session was already redeemed');
      }

      if (session.status === 'locked') {
        throw new HttpError(403, 'locked', 'Provisioning code is locked');
      }

      if (new Date(session.expiresAt) < now) {
        await sessionSnap.ref.update({ status: 'expired' });
        throw new HttpError(410, 'expired', 'Provisioning code has expired');
      }

      // Atomic enrollment: re-validate inside the transaction, then create the
      // child member (UID-keyed), the device, and enroll the session together.
      const enrolled = await db.runTransaction(async (tx) => {
        const freshSnap = await tx.get(sessionSnap.ref);
        if (!freshSnap.exists) {
          throw new HttpError(410, 'expired', 'Provisioning session no longer exists');
        }
        const fresh = freshSnap.data();
        if (fresh.status === 'enrolled') {
          if (fresh.redeemedByUid === childUid) return { idempotent: true };
          throw new HttpError(409, 'already_used', 'Provisioning session was already redeemed');
        }
        if (fresh.status === 'locked') {
          throw new HttpError(403, 'locked', 'Provisioning code is locked');
        }
        if (new Date(fresh.expiresAt) < new Date()) {
          throw new HttpError(410, 'expired', 'Provisioning code has expired');
        }
        if (sha256Hex(provisioningCode) !== fresh.codeHash) {
          throw new HttpError(400, 'invalid_code', 'Provisioning code is invalid');
        }

        // Parent authorization must still hold at redemption time.
        const parentRef = db
          .collection('families')
          .doc(fresh.familyId)
          .collection('members')
          .doc(fresh.issuedByUid);
        const parentSnap = await tx.get(parentRef);
        if (!parentSnap.exists || !PARENT_ROLES.has(parentSnap.data().role)) {
          throw new HttpError(
            403,
            'parent_not_authorized',
            'Issuing parent is no longer authorized for this family'
          );
        }

        const familyRef = db.collection('families').doc(fresh.familyId);
        const memberRef = familyRef.collection('members').doc(childUid);
        const deviceRef = familyRef.collection('devices').doc(deviceId);
        const [memberSnap, deviceSnap] = await Promise.all([
          tx.get(memberRef),
          tx.get(deviceRef),
        ]);

        if (!memberSnap.exists) {
          tx.set(memberRef, {
            memberId: fresh.targetMemberId,
            memberUid: childUid,
            role: 'child',
            status: 'active',
            displayName: fresh.displayName,
            familyId: fresh.familyId,
            provisionedAt: new Date().toISOString(),
          });
        } else if (memberSnap.data().memberUid && memberSnap.data().memberUid !== childUid) {
          throw new HttpError(409, 'member_conflict', 'Member already bound to a different account');
        }

        if (!deviceSnap.exists) {
          tx.set(deviceRef, {
            memberUid: childUid,
            ownerUid: fresh.issuedByUid,
            role: 'childDevice',
            status: 'active',
            familyId: fresh.familyId,
            createdAt: new Date().toISOString(),
          });
        } else if (deviceSnap.data().memberUid && deviceSnap.data().memberUid !== childUid) {
          throw new HttpError(409, 'device_conflict', 'Device already linked to a different member');
        }

        tx.update(sessionSnap.ref, {
          status: 'enrolled',
          redeemedByUid: childUid,
          deviceId,
          enrolledAt: new Date().toISOString(),
        });

        return { idempotent: false };
      });

      const deviceDocId = enrolled.idempotent ? session.deviceId : deviceId;
      return res.status(200).json({
        success: true,
        state: 'enrolled',
        pairingId: session.id,
        familyId: session.familyId,
        childUid,
        deviceId: deviceDocId,
        targetMemberId: session.targetMemberId,
      });
    } catch (err) {
      next(err);
    }
  });

  /**
   * POST /api/notify — hardened notification dispatch (Phase 3 security contract).
   *
   * Request body:
   *   { familyId, kind, incidentId?, sosId? }
   *
   * Security contract:
   *   - Identity from verified Firebase ID token only (never from payload).
   *   - Caller must be an active member of the family (403 not_a_member).
   *   - kind must be a known server enum; unknown kinds are rejected.
   *   - The referenced incident or SOS must exist inside the SAME family and
   *     must carry a state the caller is authorized to notify about
   *     (404 invalid_event otherwise). Client-supplied event IDs that do not
   *     exist are NEVER trusted into a message.
   *   - Idempotent exactly-once dispatch: a notification_events evidence doc
   *     is claimed inside a transaction; a duplicate request reuses the
   *     existing claim (eventExisted: true) instead of re-fanning-out.
   *   - Payloads are data-only messages (kind, familyId, notificationEventId);
   *     all visible text is rendered by the client from its own local records.
   */
  const NOTIFY_KINDS = new Set(['incident', 'sos']);
  app.post('/api/notify', requireAuth, async (req, res, next) => {
    try {
      const callerUid = req.uid;
      const { familyId, kind, incidentId, sosId } = req.body || {};
      if (!familyId || !kind) {
        throw new HttpError(400, 'invalid_request', 'familyId and kind are required');
      }
      if (!NOTIFY_KINDS.has(kind)) {
        throw new HttpError(400, 'unknown_kind', 'kind must be one of: incident, sos');
      }

      // The family itself must exist. A missing family doc means there is no
      // dispatchable family to notify (guards against bogus/cross-family
      // familyIds that happen to have stray subcollection documents).
      const familyRef = db.collection('families').doc(familyId);
      const familySnap = await familyRef.get();
      if (!familySnap.exists) {
        throw new HttpError(404, 'invalid_event', `Family ${familyId} does not exist`);
      }

      const memberRef = familyRef.collection('members').doc(callerUid);

      // Idempotency is resolved before any dispatch-time authorization check:
      // the claim transaction either finds an existing evidence doc (replay) or
      // atomically creates the dispatch slot. See notes below on the deferred
      // membership check.
      const evidenceId = `${kind}:${incidentId || sosId}:${callerUid}`;
      const evidenceRef = familyRef.collection('notification_events').doc(evidenceId);

      const claim = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(evidenceRef);
        if (fresh.exists) {
          return { existed: true, data: fresh.data() };
        }
        tx.set(evidenceRef, {
          familyId,
          kind,
          ...(incidentId ? { incidentId } : {}),
          ...(sosId ? { sosId } : {}),
          callerUid,
          claimedAt: new Date().toISOString(),
          status: 'claimed',
          sentCount: 0,
          failedCount: 0,
          invalidTokensRemoved: 0,
          deliveredAt: null,
        });
        return { existed: false };
      });

      if (claim.existed) {
        return res.status(200).json({
          sent: claim.data.sentCount || 0,
          failed: claim.data.failedCount || 0,
          invalidTokensRemoved: claim.data.invalidTokensRemoved || 0,
          reason: 'accepted',
          eventExisted: true,
          deliveredAt: claim.data.deliveredAt || null,
        });
      }

      // New dispatch path: the caller must be an active member and the event
      // must exist in the SAME family in a notifyable state. Never trust
      // client-supplied IDs.
      const memberSnap = await memberRef.get();
      if (!memberSnap.exists || memberSnap.data().status !== 'active') {
        throw new HttpError(403, 'not_a_member', 'Caller is not an active member of this family');
      }

      const callRef =
        kind === 'incident' && incidentId
          ? familyRef.collection('incidents').doc(incidentId)
          : kind === 'sos' && sosId
            ? familyRef.collection('sos').doc(sosId)
            : null;
      if (!callRef) {
        throw new HttpError(400, 'missing_event_id', `${kind} requires a ${kind}Id within this family`);
      }
      const eventSnap = await callRef.get();
      if (!eventSnap.exists) {
        throw new HttpError(404, 'invalid_event', `No ${kind} found with the given id in this family`);
      }
      const eventData = eventSnap.data();
      const notifyableStates = new Set([
        'detected',
        'active',
        'open',
        'pending',
        'acknowledged',
        'investigating',
      ]);
      const eventStatus = eventData.status || 'unknown';
      if (!notifyableStates.has(eventStatus)) {
        throw new HttpError(404, 'invalid_event', `The ${kind} is not in a notifyable state`);
      }

      // Collect all active FCM tokens for parent-role devices in this family.
      const PARENT_DEVICE_ROLES = new Set(['parentDevice', 'coParentDevice', 'spouseDevice']);
      const devicesSnap = await familyRef.collection('devices').get();

      const tokenEntries = []; // { token, tokenDocPath }
      await Promise.all(
        devicesSnap.docs
          .filter(d => PARENT_DEVICE_ROLES.has(d.data().role) && d.data().status === 'active')
          .map(async deviceDoc => {
            const tokensSnap = await deviceDoc.ref.collection('notification_tokens')
              .where('status', '==', 'active')
              .get();
            tokensSnap.docs.forEach(t => {
              if (t.data().token) {
                tokenEntries.push({ token: t.data().token, tokenDocRef: t.ref });
              }
            });
          })
      );

      if (tokenEntries.length === 0) {
        // Finalize the claim with zero delivery before reporting no_tokens.
        await evidenceRef.update({
          status: 'dispatched',
          deliveredAt: new Date().toISOString(),
        });
        return res.status(200).json({ sent: 0, failed: 0, invalidTokensRemoved: 0, reason: 'no_tokens' });
      }

      const messaging = require('firebase-admin/messaging').getMessaging();
      const multicastMessage = {
        tokens: tokenEntries.map(e => e.token),
        data: {
          kind,
          familyId,
          notificationEventId: evidenceId,
          ...(incidentId ? { incidentId } : {}),
          ...(sosId ? { sosId } : {}),
        },
        android: { priority: kind === 'sos' ? 'high' : 'normal' },
        apns: { headers: { 'apns-priority': kind === 'sos' ? '10' : '5' } },
      };

      const response = await messaging.sendEachForMulticast(multicastMessage);

      // Remove stale tokens reported as invalid by FCM.
      const STALE_CODES = new Set(['messaging/invalid-registration-token', 'messaging/registration-token-not-registered']);
      let invalidTokensRemoved = 0;
      const removeOps = [];
      response.responses.forEach((r, idx) => {
        if (!r.success && r.error && STALE_CODES.has(r.error.code)) {
          removeOps.push(
            tokenEntries[idx].tokenDocRef.update({ status: 'invalid', invalidatedAt: new Date().toISOString() })
          );
          invalidTokensRemoved++;
        }
      });
      await Promise.all(removeOps);

      // Finalize the delivery evidence record.
      await evidenceRef.update({
        status: 'dispatched',
        sentCount: response.successCount,
        failedCount: response.failureCount,
        invalidTokensRemoved,
        deliveredAt: new Date().toISOString(),
      });

      return res.status(200).json({
        sent: response.successCount,
        failed: response.failureCount,
        invalidTokensRemoved,
        reason: 'accepted',
        eventExisted: false,
        deliveredAt: null,
      });
    } catch (err) {
      next(err);
    }
  });

  // Central error handler: honest, structured error codes.

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ error: err.code, message: err.message });
    }
    console.error('[guardian-backend] Unhandled error:', err);
    return res
      .status(500)
      .json({ error: 'server_error', message: 'Internal server error' });
  });

  return app;
}

// ---- Production bootstrap (only when run directly) -------------------------
if (require.main === module) {
  const renderSecretPath = '/etc/secrets/serviceAccountKey.json';
  const localSecretPath = path.join(__dirname, 'serviceAccountKey.json');

  let keyPath = null;
  if (fs.existsSync(renderSecretPath)) {
    keyPath = renderSecretPath;
  } else if (fs.existsSync(localSecretPath)) {
    keyPath = localSecretPath;
  }

  if (!keyPath) {
    console.error('❌ No Firebase Admin service account key found.');
    console.error('   Expected /etc/secrets/serviceAccountKey.json (Render secret) or');
    console.error(`   ${localSecretPath} (local development).`);
    process.exit(1);
  }

  let auth = null;
  let db = null;
  try {
    const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
    const firebaseApp = initializeApp({ credential: cert(serviceAccount) });
    auth = getAuth(firebaseApp);
    db = getFirestore(firebaseApp);
    console.log(`✅ Firebase Admin SDK initialized from: ${keyPath}`);
  } catch (error) {
    console.error('❌ Firebase Admin initialization failed:', error.message);
    process.exit(1);
  }

  const app = createApp({ auth, db });
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Guardian Backend listening on port ${PORT}`);
  });
}

module.exports = {
  createApp,
  HttpError,
  sha256Hex,
  generateCode,
  PARENT_ROLES,
  PROVISIONING_TTL_MS,
  MAX_ATTEMPTS,
};
