import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { createHash, randomInt, randomUUID } from 'node:crypto';

if (getApps().length === 0) initializeApp();

type NotificationKind = 'incident' | 'sos';
type ParentRole = 'primaryParent' | 'parent' | 'coParent';

const parentRoles = new Set<ParentRole>(['primaryParent', 'parent', 'coParent']);
const pairingLifetimeMs = 10 * 60 * 1000;

function requiredString(value: unknown, field: string, maxLength = 128): string {
  if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > maxLength) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  return value.trim();
}

function hashPairingCode(code: string): string {
  return createHash('sha256').update(code, 'utf8').digest('hex');
}

async function requireParent(familyId: string, uid: string): Promise<void> {
  const member = await getFirestore().doc(`families/${familyId}/members/${uid}`).get();
  if (!member.exists || !parentRoles.has(member.get('role') as ParentRole)) {
    throw new HttpsError('permission-denied', 'family_parent_role_required');
  }
}

export const createChildDeviceProvisioning = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'authentication_required');
  const familyId = requiredString(request.data?.familyId, 'familyId');
  const targetMemberId = requiredString(request.data?.targetMemberId, 'targetMemberId');
  const displayName = requiredString(request.data?.displayName, 'displayName', 64);
  await requireParent(familyId, request.auth.uid);
  // The child member is local-only until redemption: the pairing targets the
  // parent's local child UUID (targetMemberId) and the trusted backend creates
  // the UID-keyed member document inside the redemption transaction. No remote
  // child member is required to exist before issuance (Option D architecture).
  const db = getFirestore();
  const pairingId = randomUUID();
  const code = randomInt(0, 1000000).toString().padStart(6, '0');
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
    createdAt: FieldValue.serverTimestamp(),
  });
  logger.info('child device provisioning created', {familyId, pairingId, ownerUid: request.auth.uid});
  return {pairingId, code, expiresAt: expiresAt.toISOString()};
});

export const redeemChildDeviceProvisioning = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'authentication_required');
  const familyId = requiredString(request.data?.familyId, 'familyId');
  const pairingId = requiredString(request.data?.pairingId, 'pairingId');
  const code = requiredString(request.data?.code, 'code', 6);
  const deviceId = requiredString(request.data?.deviceId, 'deviceId');
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(deviceId)) {
    throw new HttpsError('invalid-argument', 'deviceId is invalid.');
  }
  const db = getFirestore();
  const result = await db.runTransaction(async (transaction) => {
    const sessionRef = db.doc(`families/${familyId}/device_pairings/${pairingId}`);
    const session = await transaction.get(sessionRef);
    if (!session.exists || session.get('status') !== 'pending') return {state: 'rejected'};
    const expiresAt = session.get('expiresAt')?.toDate?.() as Date | undefined;
    if (!expiresAt || expiresAt.getTime() <= Date.now()) {
      transaction.update(sessionRef, {status: 'expired', expiredAt: FieldValue.serverTimestamp()});
      return {state: 'expired'};
    }
    const attemptCount = session.get('attemptCount') as number;
    if (hashPairingCode(code) !== session.get('codeHash')) {
      const nextAttempts = attemptCount + 1;
      transaction.update(sessionRef, {attemptCount: nextAttempts, status: nextAttempts >= 5 ? 'rejected' : 'pending'});
      return {state: nextAttempts >= 5 ? 'locked' : 'invalid_code'};
    }
    const targetMemberId = session.get('targetMemberId') as string;
    const ownerUid = session.get('ownerUid') as string;
    const displayName = session.get('displayName') as string | undefined;
    const childMemberRef = db.doc(`families/${familyId}/members/${request.auth!.uid}`);
    const deviceRef = db.doc(`families/${familyId}/devices/${deviceId}`);
    const [childMember, existingDevice] = await Promise.all([transaction.get(childMemberRef), transaction.get(deviceRef)]);
    // The remote child member document is UID-keyed and created here by the
    // trusted backend (Option D). A parent can never write it; an attacker can
    // never bind a victim's UID because the key is the redeeming account's own
    // request.auth.uid. Idempotent: an existing matching child member is reused.
    if (childMember.exists) {
      if (childMember.get('role') !== 'child' || childMember.get('memberUid') !== request.auth!.uid || childMember.get('familyId') !== familyId) {
        return {state: 'member_conflict'};
      }
    } else {
      transaction.set(childMemberRef, {
        familyId,
        memberId: targetMemberId,
        memberUid: request.auth!.uid,
        displayName: displayName ?? 'Child',
        role: 'child',
        status: 'active',
        provisionedAt: FieldValue.serverTimestamp(),
      });
    }
    if (existingDevice.exists && (existingDevice.get('familyId') !== familyId || existingDevice.get('memberId') !== targetMemberId || existingDevice.get('ownerUid') !== ownerUid || existingDevice.get('role') !== 'childDevice')) {
      return {state: 'device_conflict'};
    }
    transaction.set(deviceRef, {
      familyId,
      deviceId,
      memberId: targetMemberId,
      memberUid: request.auth!.uid,
      ownerUid,
      role: 'childDevice',
      status: 'active',
      provisionedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.update(sessionRef, {
      status: 'enrolled',
      redeemedByUid: request.auth!.uid,
      enrolledDeviceId: deviceId,
      redeemedAt: FieldValue.serverTimestamp(),
    });
    return {state: 'enrolled', deviceId, targetMemberId};
  });
  if (result.state !== 'enrolled') {
    const code = result.state === 'invalid_code' || result.state === 'locked' ? 'permission-denied' : 'failed-precondition';
    throw new HttpsError(code, `pairing_${result.state}`);
  }
  logger.info('child device provisioned', {familyId, pairingId, deviceId: result.deviceId, childUid: request.auth.uid});
  return result;
});

async function createNotificationRequest(familyId: string, sourceId: string, kind: NotificationKind): Promise<void> {
  const db = getFirestore();
  const eventId = `${kind}_${sourceId}`;
  const event = db.doc(`families/${familyId}/notification_events/${eventId}`);
  try {
    await event.create({familyId, eventId, kind, sourceId, status: 'pendingBackend', requestedAt: FieldValue.serverTimestamp()});
  } catch (error) {
    const code = (error as {code?: number | string}).code;
    if (code !== 6 && code !== 'already-exists') throw error;
  }
}

export const requestIncidentNotification = onDocumentCreated('families/{familyId}/incidents/{incidentId}', async (event) => {
  await createNotificationRequest(event.params.familyId, event.params.incidentId, 'incident');
});

export const requestSosNotification = onDocumentCreated('families/{familyId}/sos/{sosId}', async (event) => {
  await createNotificationRequest(event.params.familyId, event.params.sosId, 'sos');
});

export const fanoutNotification = onDocumentCreated('families/{familyId}/notification_events/{eventId}', async (event) => {
  const notification = event.data?.data();
  if (!notification || notification.status !== 'pendingBackend') return;
  const db = getFirestore();
  const claimed = await db.runTransaction(async (transaction) => {
    const current = await transaction.get(event.data!.ref);
    if (!current.exists || current.get('status') !== 'pendingBackend') return false;
    transaction.update(event.data!.ref, {status: 'processing', processingAt: FieldValue.serverTimestamp()});
    return true;
  });
  if (!claimed) return;
  const tokens = await db.collectionGroup('notification_tokens').where('familyId', '==', event.params.familyId).where('status', '==', 'active').get();
  const values = tokens.docs.map((doc) => ({token: doc.get('token') as string, path: doc.ref.path})).filter((value) => value.token.length > 0);
  if (values.length === 0) { await event.data?.ref.update({status: 'noActiveToken', processedAt: FieldValue.serverTimestamp()}); return; }
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    await event.data?.ref.update({status: 'fcmNotExercisedInEmulator', processedAt: FieldValue.serverTimestamp(), tokenCount: values.length});
    logger.info('notification FCM intentionally skipped in Emulator', {familyId: event.params.familyId, eventId: event.params.eventId, tokenCount: values.length});
    return;
  }
  let response;
  try {
    response = await getMessaging().sendEachForMulticast({tokens: values.map((value) => value.token), data: {kind: notification.kind, familyId: event.params.familyId, sourceId: notification.sourceId, notificationEventId: event.params.eventId}});
  } catch (error) {
    await event.data?.ref.update({status: 'backendFailed', processedAt: FieldValue.serverTimestamp(), failureKind: 'messaging_request_failed'});
    throw error;
  }
  const batch = db.batch();
  response.responses.forEach((result, index) => { if (!result.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(result.error?.code ?? '')) batch.update(db.doc(values[index].path), {status: 'revoked', revokedAt: FieldValue.serverTimestamp()}); });
  batch.update(event.data!.ref, {status: response.successCount > 0 ? 'backendAccepted' : 'backendFailed', processedAt: FieldValue.serverTimestamp(), failureKind: response.successCount > 0 ? null : 'messaging_all_tokens_rejected', tokenCount: values.length, acceptedCount: response.successCount, failedCount: response.failureCount});
  await batch.commit();
  logger.info('notification backend processing completed', {familyId: event.params.familyId, eventId: event.params.eventId, kind: notification.kind, successCount: response.successCount, failureCount: response.failureCount});
});
