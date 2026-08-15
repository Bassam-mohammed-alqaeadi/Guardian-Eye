import { randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

const root = new URL('../..', import.meta.url);
const androidConfig = JSON.parse(
  readFileSync(new URL('android/app/google-services.json', root), 'utf8'),
);
const projectId = androidConfig.project_info?.project_id;
const apiKey = androidConfig.client?.[0]?.api_key?.[0]?.current_key;
const packageName = androidConfig.client?.[0]?.client_info?.android_client_info?.package_name;

if (projectId !== 'manus-guardian' || packageName !== 'com.guardianeye.app' || !apiKey) {
  throw new Error('real_backend_config_identity_invalid');
}

const runId = randomUUID().replaceAll('-', '').slice(0, 16);
const parentEmail = `guardian.real.${runId}@example.invalid`;
const boundaryEmail = `guardian.boundary.${runId}@example.invalid`;
const password = `Gep!${randomBytes(18).toString('base64url')}`;
const familyId = `real_family_${runId}`;
const childId = `child_${runId}`;
const deviceId = `parent_device_${runId}`;
const tokenId = `token_${runId}`;
const authBase = 'https://identitytoolkit.googleapis.com/v1';
const tokenBase = 'https://securetoken.googleapis.com/v1';
const documentBase = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
const outcomes = [];

function string(value) {
  return { stringValue: value };
}

function nil() {
  return { nullValue: null };
}

function record(name, expected, actual, status) {
  outcomes.push({ name, expected, actual, status });
}

function requireStatus(name, response, allowed) {
  if (!allowed.includes(response.status)) {
    throw new Error(`${name}_unexpected_status_${response.status}`);
  }
}

async function request(url, { method = 'POST', token, body, form = false } = {}) {
  const headers = {};
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers['content-type'] = form
    ? 'application/x-www-form-urlencoded'
    : 'application/json';
  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : (form ? body : JSON.stringify(body)),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text.length ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: response.status, json };
}

async function auth(path, body) {
  return request(`${authBase}/${path}?key=${apiKey}`, { body });
}

async function firestore(path, options = {}) {
  return request(`${documentBase}${path}`, options);
}

let parent;
let boundary;
let anonymous;

try {
  parent = await auth('accounts:signUp', {
    email: parentEmail,
    password,
    returnSecureToken: true,
  });
  requireStatus('email_registration', parent, [200]);
  record('email_registration', '200 with Firebase session', `HTTP ${parent.status}`, 'PASS');

  const login = await auth('accounts:signInWithPassword', {
    email: parentEmail,
    password,
    returnSecureToken: true,
  });
  requireStatus('email_login', login, [200]);
  parent = login.json;
  record('email_login', '200 with Firebase session', `HTTP ${login.status}`, 'PASS');

  const refresh = await request(`${tokenBase}/token?key=${apiKey}`, {
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(parent.refreshToken)}`,
    form: true,
  });
  requireStatus('token_refresh', refresh, [200]);
  record('token_refresh', '200 refreshed Firebase token', `HTTP ${refresh.status}`, 'PASS');

  anonymous = await auth('accounts:signUp', { returnSecureToken: true });
  requireStatus('anonymous_auth', anonymous, [200]);
  record('anonymous_auth', '200 anonymous Firebase session', `HTTP ${anonymous.status}`, 'PASS');

  boundary = await auth('accounts:signUp', {
    email: boundaryEmail,
    password,
    returnSecureToken: true,
  });
  requireStatus('boundary_account_registration', boundary, [200]);

  const familyPath = `families/${familyId}`;
  const parentMemberPath = `${familyPath}/members/${parent.localId}`;
  const created = await request(`${documentBase}:commit`, {
    token: parent.idToken,
    body: {
      writes: [
        {
          update: {
            name: `projects/${projectId}/databases/(default)/documents/${familyPath}`,
            fields: {
              familyId: string(familyId),
              name: string('Guardian Real Backend Validation'),
              ownerUid: string(parent.localId),
              primaryParentId: string(parent.localId),
              primaryParentName: string('Validation Parent'),
            },
          },
          currentDocument: { exists: false },
        },
        {
          update: {
            name: `projects/${projectId}/databases/(default)/documents/${parentMemberPath}`,
            fields: {
              familyId: string(familyId),
              memberId: string(parent.localId),
              memberUid: string(parent.localId),
              displayName: string('Validation Parent'),
              role: string('primaryParent'),
              status: string('active'),
            },
          },
          currentDocument: { exists: false },
        },
      ],
    },
  });
  requireStatus('family_bootstrap_write', created, [200]);
  record('family_bootstrap_write', 'atomic family + primary parent write', `HTTP ${created.status}`, 'PASS');

  const readBack = await firestore(`/${familyPath}`, { method: 'GET', token: parent.idToken });
  requireStatus('family_read_back', readBack, [200]);
  record('family_read_back', 'parent can read own family', `HTTP ${readBack.status}`, 'PASS');

  // M5 Option D: a parent client MUST NOT be able to create a child member
  // document directly. The deployed rules deny third-party member creation;
  // the remote child member is created only by the trusted backend inside
  // redeemChildDeviceProvisioning. This assertion documents the denial.
  const childCreated = await firestore(`/${familyPath}/members?documentId=${childId}`, {
    token: parent.idToken,
    body: {
      fields: {
        familyId: string(familyId),
        memberId: string(childId),
        memberUid: nil(),
        displayName: string('Validation Child'),
        role: string('child'),
        status: string('active'),
      },
    },
  });
  requireStatus('child_member_write_denied', childCreated, [403]);
  record('child_member_write_denied', '403 direct parent child-member create denied', `HTTP ${childCreated.status}`, 'PASS');

  const roleEscalation = await firestore(`/${familyPath}/members/${childId}?updateMask.fieldPaths=role`, {
    method: 'PATCH',
    token: parent.idToken,
    body: { fields: { role: string('primaryParent') } },
  });
  requireStatus('role_escalation_denied', roleEscalation, [403]);
  record('role_escalation_denied', '403 when parent changes child role', `HTTP ${roleEscalation.status}`, 'PASS');

  const foreignRead = await firestore(`/${familyPath}`, { method: 'GET', token: boundary.json.idToken });
  requireStatus('cross_family_read_denied', foreignRead, [403]);
  record('cross_family_read_denied', '403 for unrelated authenticated account', `HTTP ${foreignRead.status}`, 'PASS');

  const anonymousRead = await firestore(`/${familyPath}`, { method: 'GET' });
  requireStatus('unauthenticated_read_denied', anonymousRead, [401, 403]);
  record('unauthenticated_read_denied', '401 or 403 without Firebase token', `HTTP ${anonymousRead.status}`, 'PASS');

  const deviceCreated = await firestore(`/${familyPath}/devices?documentId=${deviceId}`, {
    token: parent.idToken,
    body: {
      fields: {
        familyId: string(familyId),
        deviceId: string(deviceId),
        memberId: string(parent.localId),
        memberUid: nil(),
        ownerUid: string(parent.localId),
        role: string('parentDevice'),
        status: string('active'),
      },
    },
  });
  requireStatus('parent_device_write', deviceCreated, [200]);

  const revoke = await firestore(`/${familyPath}/devices/${deviceId}?updateMask.fieldPaths=status`, {
    method: 'PATCH',
    token: parent.idToken,
    body: { fields: { status: string('revoked') } },
  });
  requireStatus('device_revocation', revoke, [200]);

  const revokedTokenWrite = await firestore(`/${familyPath}/devices/${deviceId}/notification_tokens?documentId=${tokenId}`, {
    token: parent.idToken,
    body: {
      fields: {
        familyId: string(familyId),
        userUid: string(parent.localId),
        token: string('validation-token-not-a-real-device-token'),
        status: string('active'),
      },
    },
  });
  requireStatus('revoked_device_write_denied', revokedTokenWrite, [403]);
  record('revoked_device_write_denied', '403 token write from revoked device', `HTTP ${revokedTokenWrite.status}`, 'PASS');

  const forgedIncident = await firestore(`/${familyPath}/incidents?documentId=forged_${runId}`, {
    token: boundary.json.idToken,
    body: {
      fields: {
        familyId: string(familyId),
        deviceId: string(deviceId),
        status: string('queued'),
      },
    },
  });
  requireStatus('unauthorized_device_write_denied', forgedIncident, [403]);
  record('unauthorized_device_write_denied', '403 incident write from unrelated account', `HTTP ${forgedIncident.status}`, 'PASS');
} finally {
  if (parent?.idToken) {
    const familyPath = `families/${familyId}`;
    for (const path of [
      `/${familyPath}/devices/${deviceId}`,
      `/${familyPath}/members/${childId}`,
      `/${familyPath}`,
      `/${familyPath}/members/${parent.localId}`,
    ]) {
      try {
        await firestore(path, { method: 'DELETE', token: parent.idToken });
      } catch {
        // Preserve the original validation outcome; cleanup failures are not proof of backend success.
      }
    }
  }
  for (const account of [parent, boundary?.json, anonymous?.json]) {
    if (account?.idToken) {
      try {
        await auth('accounts:delete', { idToken: account.idToken });
      } catch {
        // The caller will record any remaining cleanup task separately.
      }
    }
  }
}

console.log(JSON.stringify({
  level: 'REAL_FIREBASE',
  projectId,
  runId: 'redacted',
  checks: outcomes,
  status: 'PASS',
}, null, 2));
