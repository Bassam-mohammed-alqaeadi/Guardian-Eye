# FS-008 One-Way Audio — Signaling & Transport Protocol

## 1. Objective
Establish a production-ready, authenticated, and privacy-compliant path for real-time (or near real-time) one-way audio from a child device to a parent device.

## 2. Signaling Path (Firestore)
We use Firestore as the signaling plane to avoid new WebSocket infrastructure and leverage existing `FamilyRuntimeContext` rules.

### 2.1 Start Request (Parent -> Child)
Parent writes to: `families/{fid}/monitoring_requests/{rid}`
```json
{
  "kind": "audio_start",
  "childId": "{cid}",
  "deviceId": "{did}",
  "requestedByUid": "{uid}",
  "requestedAt": "timestamp",
  "status": "pending",
  "maxDurationSeconds": 60,
  "config": {
    "bitrate": 128000,
    "sampleRate": 44100
  }
}
```

### 2.2 Response & Consent (Child -> Parent)
Child updates the request or writes a session: `families/{fid}/audio_sessions/{sid}`
```json
{
  "requestId": "{rid}",
  "status": "active",
  "startedAt": "timestamp",
  "consentStatus": "granted",
  "transportUrl": "https://guardian-backend.onrender.com/api/audio/stream/{sid}"
}
```

## 3. Transport Path (Render Relay)
Since direct P2P (WebRTC) is complex across mobile NATs and background states, we use an authenticated chunked relay.

### 3.1 Upload (Child -> Render)
`POST /api/audio/upload/{sessionId}`
- **Auth**: Firebase ID Token (Child).
- **Body**: Binary chunk (m4a/aac).
- **Headers**: `Content-Type: audio/aac`, `X-Chunk-Index: 0`.

### 3.2 Download (Parent -> Render)
`GET /api/audio/stream/{sessionId}`
- **Auth**: Firebase ID Token (Parent).
- **Response**: `Transfer-Encoding: chunked`, `Content-Type: audio/aac`.

## 4. Security & Privacy
1. **Authorization**: Every request to Render is verified via `firebase-admin` against the family membership in Firestore.
2. **Consent**: The child device MUST have a `DigitalPolicy` allowing audio and MUST show a persistent notification during capture.
3. **Honest State**: The parent UI must show "Connecting", "Live", or "Disconnected" based on the relay status.
4. **Retention**: Render does NOT store audio files; it only pipes chunks between streams.

## 5. Implementation Steps
1. **Backend**: Add `/api/audio/upload/:sid` and `/api/audio/stream/:sid` to `guardian_backend/index.js`.
2. **Child**: Implement `AudioCaptureService` to POST chunks to the relay.
3. **Parent**: Implement `AudioMonitorService` to GET the chunked stream from the relay.
4. **Signaling**: Update both services to use Firestore `monitoring_requests`.
