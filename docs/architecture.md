# FerriScribe Mobile — Architecture

## 1. Components

```
┌─────────────────────────────┐         HTTP          ┌──────────────────────────────────┐
│  Flutter app (iOS/Android)  │  over Tailscale       │  FerriScribe desktop (server)    │
│  · recorder (streaming enc) │  ─────────▶           │  · medical-sharing office mode   │
│  · encrypted audio cache    │                       │  · whisper.cpp STT               │
│  · document review/editor   │  ◀─────────           │  · SOAP / referral / letter /    │
│  · SQLCipher offline cache  │    JSON + SSE         │    synopsis / peer-discussion    │
│  · PDF/DOCX export + share  │                       │  · medical-export (PDF/DOCX)     │
└─────────────────────────────┘                       └──────────────────────────────────┘
```

## 2. Server side (delta — mostly net-new)

`medical-sharing` already implements office-server mode: mDNS + Tailscale discovery, QR pairing, a whisper binary supervisor, and a vocab/template sharing HTTP API. The v1 delta is **mostly new API surface** built on top of that existing HTTP infrastructure:

### What already exists in `medical-sharing`:
- `/pair` — QR/token pairing
- `/vocab`, `/templates` — sharing API

### What must be built (net-new):
- **Recording ingestion** — receive encrypted audio blob, store it, enqueue the existing processing pipeline.
- **Job queue + status** — a job-tracking system with SSE stream of progress events per pipeline stage.
- **Document read/write** — endpoints for the 5 doc types, so mobile can fetch results and save edits.
- **Export** — invoke `medical-export` to PDF/DOCX and stream the file back.
- **Unpair** — server-side device revocation endpoint.

### Actual pipeline stages (from `core/src/types/pipeline.rs`):

The **ingestion pipeline** has these stages:
`Transcription → IcdCoding → DemographicsExtraction → PatientMatching → ClinicalValidation → RagIndexing → Complete`

Each stage emits `Queued → Started → Completed` progress events.

**Document generation** (the 5 doc types: soap, referral, letter, synopsis, peer_discussion) is a **separate pipeline** that runs after ingestion completes — it is NOT part of the ingestion pipeline stages above. The mobile SSE stream must cover both: ingestion progress first, then document generation progress.

### Transport clarification:
The protocol is **HTTP over Tailscale** (plain TCP, no TLS layer in the app). Tailscale WireGuard encrypts the wire at the network level. Do not add app-level TLS — it's redundant crypto and creates a cert-management burden.

## 3. API contract (HTTP/JSON over Tailscale)

Auth: pairing yields a bearer token (QR → token exchange, same flow as the existing office-server pairing). Every request carries `Authorization: Bearer *** Session tokens are short-lived with refresh; the pairing secret enables refresh.

### Existing endpoints (reuse as-is):
| Method | Path | Purpose |
|---|---|---|
| POST | `/pair` | QR/token pairing → session token |
| GET | `/vocab`, `/templates` | existing sharing API |

### Net-new endpoints (must be built):
| Method | Path | Purpose |
|---|---|---|
| POST | `/recordings` | upload encrypted audio (AES-GCM blob) → `{ recording_id, job_id }` |
| GET | `/jobs/{job_id}` | SSE progress events (Queued→Started→Completed per pipeline stage, then per doc-type generation) |
| GET | `/recordings/{id}/documents` | fetch all 5 doc types + metadata |
| PUT | `/recordings/{id}/documents/{type}` | save an edited document back |
| POST | `/recordings/{id}/export` | `{ format: pdf\|docx, doc_type }` → streamed file |
| DELETE | `/devices/{device_id}` | unpair/revoke a device |

Doc types: `soap | referral | letter | synopsis | peer_discussion`.

SSE constraint: event payloads carry **IDs only**, never patient names or transcript content. Content is fetched via separate GET calls.

## 4. Mobile data model

- `Recording { id, title, started_at, duration_s, audio_path, status }` — `audio_path` points at an AES-256-GCM-encrypted blob.
- `Document { recording_id, doc_type, body, edited, synced_at }`
- `PatientContext { recording_id, meds, allergies, conditions, notes }` — background context, mirrors desktop.
- `ServerConfig { tailscale_host, port, token, paired_at }`

Local storage: SQLCipher (AES-256) via `sqlcipher_flutter_libs` (pin `^2.1.0`) + `drift`. Audio blobs encrypted with a key held in `flutter_secure_storage`.

## 5. Security / PHI invariants (carry over from desktop, unchanged)

1. **No hosted AI** — all inference is the physician's local FerriScribe server. The mobile app makes zero calls to any cloud AI provider.
2. **No telemetry / phone-home** — only the paired server is contacted, over Tailscale. No Sentry/Crashlytics/Firebase — crash stack traces can carry transcript fragments.
3. **PHI at rest** — audio AES-256-GCM; local DB SQLCipher. No plaintext temp files. Audio capture must **stream directly into the encryptor** (the `record` package's default temp-file path leaks plaintext PHI on disk between capture and encryption).
4. **No PHI in logs** — IDs/counts/lengths only, on both client and server. No PHI in SSE event payloads or push notifications.
5. **Screen protection** — Android `FLAG_SECURE`; iOS screen-capture block; **app-switcher snapshot masking** (blur overlay on `AppLifecycleState.inactive` — iOS snapshots the last frame to disk unencrypted).
6. **Backup exclusion** — SQLCipher DB and cached documents excluded from iCloud backup (`NSURLIsExcludedFromBackupKey`) and Android Auto Backup (`android:allowBackup="false"` + extraction rules). Encrypted DB + keychain entry restored to a new device defeats the at-rest model.
7. **Clipboard** — never auto-copy PHI to the OS clipboard (iOS clipboard is readable by any foreground app and syncs via Universal Clipboard). Explicit user-initiated copies only.
8. **Token hygiene** — short-lived session tokens in `flutter_secure_storage`; server-side unpair endpoint for lost-phone revocation; server tokens never logged.

## 6. Decisions & open questions

- **Transport v1:** HTTP + JSON REST over Tailscale, matching the existing `medical-sharing` HTTP patterns (plain TCP, Tailscale handles encryption). gRPC is a v2 candidate (lower-latency streaming) but does not gate v1.
- **Server mode:** v1 uses the desktop app in office-server mode. A dedicated headless `ferriscribe-server` daemon (no GUI) is a v2 candidate.
- **Offline:** v1 cache is read-only review of already-fetched documents. Offline *generation* is out of scope — the server is required for AI.
- **Critical path:** the server-side API delta is the critical path — the mobile app is useless until recordings + jobs + documents + export endpoints exist. Phase 1 mobile depends on the parallel server track delivering first.
