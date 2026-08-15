"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fanoutNotification = exports.requestSosNotification = exports.requestIncidentNotification = exports.redeemChildDeviceProvisioning = exports.createChildDeviceProvisioning = void 0;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const firebase_functions_1 = require("firebase-functions");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const node_crypto_1 = require("node:crypto");
if ((0, app_1.getApps)().length === 0)
    (0, app_1.initializeApp)();
const parentRoles = new Set(['primaryParent', 'parent', 'coParent']);
const pairingLifetimeMs = 10 * 60 * 1000;
function requiredString(value, field, maxLength = 128) {
    if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > maxLength) {
        throw new https_1.HttpsError('invalid-argument', `${field} is required.`);
    }
    return value.trim();
}
function hashPairingCode(code) {
    return (0, node_crypto_1.createHash)('sha256').update(code, 'utf8').digest('hex');
}
async function requireParent(familyId, uid) {
    const member = await (0, firestore_1.getFirestore)().doc(`families/${familyId}/members/${uid}`).get();
    if (!member.exists || !parentRoles.has(member.get('role'))) {
        throw new https_1.HttpsError('permission-denied', 'family_parent_role_required');
    }
}
exports.createChildDeviceProvisioning = (0, https_1.onCall)(async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError('unauthenticated', 'authentication_required');
    const familyId = requiredString(request.data?.familyId, 'familyId');
    const targetMemberId = requiredString(request.data?.targetMemberId, 'targetMemberId');
    const displayName = requiredString(request.data?.displayName, 'displayName', 64);
    await requireParent(familyId, request.auth.uid);
    // The child member is local-only until redemption: the pairing targets the
    // parent's local child UUID (targetMemberId) and the trusted backend creates
    // the UID-keyed member document inside the redemption transaction. No remote
    // child member is required to exist before issuance (Option D architecture).
    const db = (0, firestore_1.getFirestore)();
    const pairingId = (0, node_crypto_1.randomUUID)();
    const code = (0, node_crypto_1.randomInt)(0, 1000000).toString().padStart(6, '0');
    const expiresAt = new Date(Date.now() + pairingLifetimeMs);
    await db.doc(`families/${familyId}/device_pairings/${pairingId}`).create({
        familyId,
        pairingId,
        targetMemberId,
        displayName,
        ownerUid: request.auth.uid,
        issuedByUid: request.auth.uid,
        requestedRole: 'childDevice',
        codeHash: hashPairingCode(code),
        status: 'pending',
        attemptCount: 0,
        expiresAt,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    firebase_functions_1.logger.info('child device provisioning created', { familyId, pairingId, ownerUid: request.auth.uid });
    return { pairingId, code, expiresAt: expiresAt.toISOString() };
});
exports.redeemChildDeviceProvisioning = (0, https_1.onCall)(async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError('unauthenticated', 'authentication_required');
    const familyId = requiredString(request.data?.familyId, 'familyId');
    const pairingId = requiredString(request.data?.pairingId, 'pairingId');
    const code = requiredString(request.data?.code, 'code', 6);
    const deviceId = requiredString(request.data?.deviceId, 'deviceId');
    if (!/^[A-Za-z0-9_-]{8,128}$/.test(deviceId)) {
        throw new https_1.HttpsError('invalid-argument', 'deviceId is invalid.');
    }
    const db = (0, firestore_1.getFirestore)();
    const result = await db.runTransaction(async (transaction) => {
        const sessionRef = db.doc(`families/${familyId}/device_pairings/${pairingId}`);
        const session = await transaction.get(sessionRef);
        if (!session.exists || session.get('status') !== 'pending')
            return { state: 'rejected' };
        const expiresAt = session.get('expiresAt')?.toDate?.();
        if (!expiresAt || expiresAt.getTime() <= Date.now()) {
            transaction.update(sessionRef, { status: 'expired', expiredAt: firestore_1.FieldValue.serverTimestamp() });
            return { state: 'expired' };
        }
        const attemptCount = session.get('attemptCount');
        if (hashPairingCode(code) !== session.get('codeHash')) {
            const nextAttempts = attemptCount + 1;
            transaction.update(sessionRef, { attemptCount: nextAttempts, status: nextAttempts >= 5 ? 'rejected' : 'pending' });
            return { state: nextAttempts >= 5 ? 'locked' : 'invalid_code' };
        }
        const targetMemberId = session.get('targetMemberId');
        const ownerUid = session.get('ownerUid');
        const displayName = session.get('displayName');
        const childMemberRef = db.doc(`families/${familyId}/members/${request.auth.uid}`);
        const deviceRef = db.doc(`families/${familyId}/devices/${deviceId}`);
        const [childMember, existingDevice] = await Promise.all([transaction.get(childMemberRef), transaction.get(deviceRef)]);
        // The remote child member document is UID-keyed and created here by the
        // trusted backend (Option D). A parent can never write it; an attacker can
        // never bind a victim's UID because the key is the redeeming account's own
        // request.auth.uid. Idempotent: an existing matching child member is reused.
        if (childMember.exists) {
            if (childMember.get('role') !== 'child' || childMember.get('memberUid') !== request.auth.uid || childMember.get('familyId') !== familyId) {
                return { state: 'member_conflict' };
            }
        }
        else {
            transaction.set(childMemberRef, {
                familyId,
                memberId: targetMemberId,
                memberUid: request.auth.uid,
                displayName: displayName ?? 'Child',
                role: 'child',
                status: 'active',
                provisionedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        if (existingDevice.exists && (existingDevice.get('familyId') !== familyId || existingDevice.get('memberId') !== targetMemberId || existingDevice.get('ownerUid') !== ownerUid || existingDevice.get('role') !== 'childDevice')) {
            return { state: 'device_conflict' };
        }
        transaction.set(deviceRef, {
            familyId,
            deviceId,
            memberId: targetMemberId,
            memberUid: request.auth.uid,
            ownerUid,
            role: 'childDevice',
            status: 'active',
            provisionedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.update(sessionRef, {
            status: 'enrolled',
            redeemedByUid: request.auth.uid,
            enrolledDeviceId: deviceId,
            redeemedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return { state: 'enrolled', deviceId, targetMemberId };
    });
    if (result.state !== 'enrolled') {
        const code = result.state === 'invalid_code' || result.state === 'locked' ? 'permission-denied' : 'failed-precondition';
        throw new https_1.HttpsError(code, `pairing_${result.state}`);
    }
    firebase_functions_1.logger.info('child device provisioned', { familyId, pairingId, deviceId: result.deviceId, childUid: request.auth.uid });
    return result;
});
async function createNotificationRequest(familyId, sourceId, kind) {
    const db = (0, firestore_1.getFirestore)();
    const eventId = `${kind}_${sourceId}`;
    const event = db.doc(`families/${familyId}/notification_events/${eventId}`);
    try {
        await event.create({ familyId, eventId, kind, sourceId, status: 'pendingBackend', requestedAt: firestore_1.FieldValue.serverTimestamp() });
    }
    catch (error) {
        const code = error.code;
        if (code !== 6 && code !== 'already-exists')
            throw error;
    }
}
exports.requestIncidentNotification = (0, firestore_2.onDocumentCreated)('families/{familyId}/incidents/{incidentId}', async (event) => {
    await createNotificationRequest(event.params.familyId, event.params.incidentId, 'incident');
});
exports.requestSosNotification = (0, firestore_2.onDocumentCreated)('families/{familyId}/sos/{sosId}', async (event) => {
    await createNotificationRequest(event.params.familyId, event.params.sosId, 'sos');
});
exports.fanoutNotification = (0, firestore_2.onDocumentCreated)('families/{familyId}/notification_events/{eventId}', async (event) => {
    const notification = event.data?.data();
    if (!notification || notification.status !== 'pendingBackend')
        return;
    const db = (0, firestore_1.getFirestore)();
    const claimed = await db.runTransaction(async (transaction) => {
        const current = await transaction.get(event.data.ref);
        if (!current.exists || current.get('status') !== 'pendingBackend')
            return false;
        transaction.update(event.data.ref, { status: 'processing', processingAt: firestore_1.FieldValue.serverTimestamp() });
        return true;
    });
    if (!claimed)
        return;
    const tokens = await db.collectionGroup('notification_tokens').where('familyId', '==', event.params.familyId).where('status', '==', 'active').get();
    const values = tokens.docs.map((doc) => ({ token: doc.get('token'), path: doc.ref.path })).filter((value) => value.token.length > 0);
    if (values.length === 0) {
        await event.data?.ref.update({ status: 'noActiveToken', processedAt: firestore_1.FieldValue.serverTimestamp() });
        return;
    }
    if (process.env.FUNCTIONS_EMULATOR === 'true') {
        await event.data?.ref.update({ status: 'fcmNotExercisedInEmulator', processedAt: firestore_1.FieldValue.serverTimestamp(), tokenCount: values.length });
        firebase_functions_1.logger.info('notification FCM intentionally skipped in Emulator', { familyId: event.params.familyId, eventId: event.params.eventId, tokenCount: values.length });
        return;
    }
    let response;
    try {
        response = await (0, messaging_1.getMessaging)().sendEachForMulticast({ tokens: values.map((value) => value.token), data: { kind: notification.kind, familyId: event.params.familyId, sourceId: notification.sourceId, notificationEventId: event.params.eventId } });
    }
    catch (error) {
        await event.data?.ref.update({ status: 'backendFailed', processedAt: firestore_1.FieldValue.serverTimestamp(), failureKind: 'messaging_request_failed' });
        throw error;
    }
    const batch = db.batch();
    response.responses.forEach((result, index) => { if (!result.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(result.error?.code ?? ''))
        batch.update(db.doc(values[index].path), { status: 'revoked', revokedAt: firestore_1.FieldValue.serverTimestamp() }); });
    batch.update(event.data.ref, { status: response.successCount > 0 ? 'backendAccepted' : 'backendFailed', processedAt: firestore_1.FieldValue.serverTimestamp(), failureKind: response.successCount > 0 ? null : 'messaging_all_tokens_rejected', tokenCount: values.length, acceptedCount: response.successCount, failedCount: response.failureCount });
    await batch.commit();
    firebase_functions_1.logger.info('notification backend processing completed', { familyId: event.params.familyId, eventId: event.params.eventId, kind: notification.kind, successCount: response.successCount, failureCount: response.failureCount });
});
