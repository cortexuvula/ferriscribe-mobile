# FerriScribe Mobile — Architecture

## 1. Components

```
┌─────────────────────────────┐         HTTP          ┌──────────────────────────────────┐
│  Flutter app (iOS/Android)  │  over Tailscale       │  FerriScribe desktop (server)    │
│  · recorder                 │  ─────────▶           │  · medical-sharing :11436         │
│  · pending-audio store      │                       │    (pairing router + proxies)    │
│  · document review/editor   │  ◀─────────           │  · sharing_vocab_api :11437       │
│  · SQLCipher offline cache  │    JSON + SSE         │    (vocab/content/audio data API)│
│  · export download + share  │                       │  · whisper.cpp STT + LLM gen     │
└─────────────────────────────┘                       └──────────────────────────────────┘
```

## 2. Server side — as it exists today (verified against the repo)

The server is the FerriScribe desktop app (`~/Development/rustMedicalAssistant`) in office-server mode. Two separate HTTP services are relevant:

### `medical-sharing` crate — pairing router on :11436
- `POST /pair/enroll` — QR/token exchange → bearer token (TokenStore).
- `GET /pair/clients`, `POST /pair/revoke/:id` — device list/revocation, **gated to loopback only**.
- `GET /info` — unauthenticated discovery/readiness probe.
- Also owns: mDNS + Tailscale discovery, whisper binary supervision, Ollama/LM Studio proxying (ports 11435/8081/8001).

### `src-tauri/src/sharing_vocab_api/` — data API on :11437 (Tauri app module, NOT the medical-sharing crate)
Router verified in `mod.rs::build_router`:
- `/v1/vocabulary`, `/v1/vocabulary/count`, `/v1/vocabulary/{id}` — vocabulary CRUD
- `/v1/context-templates{,/upsert,/rename,/delete}`
- `/v1/user-dictionary{,/{word},/sync,/sync-full,/events}` — includes SSE
- `/v1/condition-chips{,/sync,/events}` — condition chip sync
- `/v1/content/sync` (GET/POST), `/v1/content/sync/meta`, `/v1/content/events` (SSE), `/v1/content/audio/{recording_id}` (GET/PUT) — bidirectional **recording content** sync at per-field LWW granularity. Synced fields include `transcript, soap_note, referral, letter, peer_discussion, chat, …` (synopsis is **not** a synced field).
- **Audio upload (`PUT /v1/content/audio/{id}`) receives plaintext bytes**; the server encrypts in memory and writes atomically (FE1 envelope, `medical_security::file_crypto`) — with a 1 GiB body limit. First upload wins; re-upload → 409.
- Auth: `Authorization: Bearer <token>` validated against `TokenStore`; no TTL/expiry/refresh exists today; failed attempts consume a rate-limit budget → 429.

### Processing reality (verified)
- `process_recording` (`src-tauri/src/commands/pipeline.rs`) = **transcribe → SOAP only**, two stages, progress reported as Tauri `pipeline-progress` events (`transcribing` / `generating_soap` / `completed` / `failed`).
- Referral, letter, synopsis, peer-discussion are **separate Tauri commands** (`commands/generation/{referral,letter,synopsis,peer_discussion}.rs`), each triggered individually.
- The pipeline-step vocabulary used for progress labels lives in `crates/processing/src/pipeline.rs:64` — see §3 below.
- The DB layer has queue/batch **types** (`queue_tasks`, `QueueTaskStatus`, `ProcessingEvent` in `crates/core/src/types/processing.rs`) but no HTTP job-status API exposes them; a recording→job model over HTTP is greenfield.

## 3. Pipeline-step enum — resolved

Two enumerations were in circulation during planning:

1. **Ada's claim** — `core/src/types/pipeline.rs` holds `Transcription → IcdCoding → DemographicsExtraction → PatientMatching → ClinicalValidation → RagIndexing → Complete`. **FALSE.** `crates/core/src/types/` contains no `pipeline.rs`; grep for `IcdCoding|DemographicsExtraction|PatientMatching|ClinicalValidation|RagIndexing` across the whole repo returns **zero matches**. This enum does not exist.
2. **Actual code** — `crates/processing/src/pipeline.rs:63-72`:
   `PipelineStep::{Transcribing, GeneratingSoap, GeneratingReferral, GeneratingLetter, ExtractingData, IndexingRag, Complete}` (with `PipelineConfig` gating the generation/indexing steps; default: SOAP on, referral/letter off, RAG auto-index on).

**Resolution: the `crates/processing/src/pipeline.rs` enum is authoritative.** It is the only pipeline-step type in the codebase; it is used as the progress-label vocabulary (`PipelineStep::label()` at pipeline.rs:78-85). The frontend mirror is `src/lib/stores/pipeline.svelte.ts` (`'idle' | 'transcribing' | 'generating_soap' | 'completed' | 'failed'`). No IcdCoding/Demographics/PatientMatching/ClinicalValidation stages exist anywhere.

Docs now match reality.

## 4. API contract (HTTP/JSON over Tailscale)

Auth: bearer token from pairing (`POST /pair/enroll` on :11436), presented on every :11437 request. No TTL/refresh exists today — treat tokens as long-lived until the server adds expiry (a candidate server-side hardening task, not a mobile blocker).

### Existing endpoints (verified in source)

| Service | Method | Path | Purpose |
|---|---|---|---|
| :11436 pairing router | POST | `/pair/enroll` | QR/token pairing → bearer token |
| :11436 pairing router | GET | `/info` | unauthenticated discovery probe |
| :11436 pairing router | GET | `/pair/clients` | device list (loopback-gated) |
| :11436 pairing router | POST | `/pair/revoke/:id` | revoke a device (loopback-gated) |
| :11437 data API | GET/POST | `/v1/content/sync` | recording-content delta pull / push (per-field LWW; includes transcript, soap_note, referral, letter, peer_discussion, chat) |
| :11437 data API | GET | `/v1/content/sync/meta` | sync cursor diagnostics |
| :11437 data API | GET | `/v1/content/events` | SSE change notifications |
| :11437 data API | GET/PUT | `/v1/content/audio/{recording_id}` | audio download / **plaintext upload** (server encrypts at rest; first-upload-wins 409; 1 GiB cap) |
| :11437 data API | (family) | `/v1/vocabulary*`, `/v1/context-templates*`, `/v1/user-dictionary*`, `/v1/condition-chips*` | vocab/template/dictionary/chip sync (not needed by mobile v1) |

### Net-new endpoints (must be built — the critical-path server track)

| Method | Path | Purpose |
|---|---|---|
| POST | `/v1/recordings` | create recording row + ingest audio (multipart, or metadata push + existing `PUT /v1/content/audio/{id}`) — exact shape TBD by the server track |
| GET | `/v1/jobs/{recording_id}` | job status + SSE progress (transcribing → generating_soap → per-doc-type generation) |
| POST | `/v1/recordings/{id}/generate/{doc_type}` | trigger the separate generation commands (referral/letter/synopsis/peer-discussion; SOAP via process_recording) |
| PUT | `/v1/recordings/{id}/documents/{type}` | save an edited document back (or extend `/v1/content/sync` push) |
| GET | `/v1/recordings/{id}/export?format=pdf|docx&doc_type=…` | invoke `medical-export` and stream the file (net-new exporter paths for synopsis + peer_discussion) |
| POST | `/v1/devices/self` (self-revocation) | the existing `POST /pair/revoke/:id` is loopback-gated; mobile "unpair/lost phone" needs a self-revocation endpoint or desktop-side revocation (decision for the server track) |

Doc types: `soap | referral | letter | synopsis | peer_discussion`.

SSE constraint: event payloads carry **IDs only**, never patient names or transcript content. Content is fetched via separate GET calls.

## 5. Export coverage (verified)

`medical-export` (`crates/export/`) today exports **soap, referral, letter** in both PDF and DOCX (`pdf.rs`/`docx.rs`: `export_soap`, `export_referral`, `export_letter`) plus FHIR. **Synopsis + peer_discussion exporters do not exist** — they are net-new server work (the generic `render_document(title, body, date)` helper can carry them).

## 6. Mobile data model

- `Recording { id, title, started_at, duration_s, audio_path, status }` — `audio_path` points at pending-upload audio in app-private storage (plaintext on-device pre-upload; the server encrypts at rest on receipt).
- `Document { recording_id, doc_type, body, edited, synced_at }`
- `PatientContext { recording_id, meds, allergies, conditions, notes }` — background context, mirrors desktop.
- `ServerConfig { tailscale_host, pairing_port(11436), data_port(11437), token, paired_at }`

Local storage: SQLCipher (AES-256) via `sqlcipher_flutter_libs` (pin `^2.1.0`) + `drift`. Bearer token in `flutter_secure_storage`.

## 7. Security / PHI invariants

1. **No hosted AI** — all inference is the physician's local FerriScribe server. The mobile app makes zero calls to any cloud AI provider.
2. **No telemetry / phone-home** — only the paired server is contacted, over Tailscale. No Sentry/Crashlytics/Firebase — crash stack traces can carry transcript fragments.
3. **Transport & audio:** plain HTTP over Tailscale (WireGuard on the wire; no app-level TLS). Audio leaves the phone **as plaintext bytes** — this matches the existing desktop↔desktop sync protocol (`PUT /v1/content/audio`); the server encrypts at rest (FE1) on receipt. **Do not add client-side AES-GCM or streaming encryption** — cut from the plan because the server already owns at-rest encryption and the existing endpoint expects plaintext bodies.
4. **PHI at rest on-device:** document cache in SQLCipher; pending-upload audio in app-private storage only (excluded from backups, wiped after confirmed upload). No plaintext temp files outside app-private storage.
5. **No PHI in logs** — IDs/counts/lengths only, on both client and server. No PHI in SSE event payloads or push notifications.
6. **Screen protection** — Android `FLAG_SECURE`; iOS screen-capture block; **app-switcher snapshot masking** (blur overlay on `AppLifecycleState.inactive` — iOS snapshots the last frame to disk unencrypted).
7. **Backup exclusion** — SQLCipher DB, document cache, and pending audio excluded from iCloud backup (`NSURLIsExcludedFromBackupKey`) and Android Auto Backup (`android:allowBackup="false"` + extraction rules). Encrypted DB + keychain entry restored to a new device defeats the at-rest model.
8. **Clipboard** — never auto-copy PHI to the OS clipboard (iOS clipboard is readable by any foreground app and syncs via Universal Clipboard). Explicit user-initiated copies only.
9. **Token hygiene** — long-lived bearer token in `flutter_secure_storage` (no TTL/refresh in the server today); revocation via `POST /pair/revoke/:id` (loopback-gated, desktop-side) or the net-new self-revocation endpoint. Failed auth → 429 rate-limit budget. Server tokens never logged.

## 8. Decisions & open questions

- **Transport v1:** HTTP + JSON REST over Tailscale, matching the existing sharing HTTP patterns. gRPC is a v2 candidate but does not gate v1.
- **Server mode:** v1 uses the desktop app in office-server mode. A dedicated headless `ferriscribe-server` daemon (no GUI) is a v2 candidate.
- **Offline:** v1 cache is read-only review of already-fetched documents. Offline *generation* is out of scope — the server is required for AI.
- **Critical path:** the server-side track is the critical-path dependency for mobile Phase 1 (recording ingestion + job status + doc read/write + export endpoints). See implementation-plan.md §Parallel track.
- **Open:** unpair-from-phone UX (existing revoke is loopback-gated).
- **Open:** synopsis is not in the `/v1/content/sync` field set and has no dedicated DB column (stored in recording metadata) — decide whether to add it server-side or treat it as on-demand fetch only.
- **Open:** token TTL/refresh does not exist in the server — if desired, it is a server-track task; the mobile app treats tokens as long-lived.
