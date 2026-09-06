# zcode prompt — FerriScribe Mobile (Flutter thin client)

You are building **FerriScribe Mobile** — a Flutter (Dart) client for iOS + Android that pairs with the existing FerriScribe desktop application (Rust + Tauri) running in office-server mode on the physician's own machine. The desktop app runs all AI locally (whisper.cpp STT + Ollama/LM Studio/oMLX for SOAP/referral/letter/synopsis/peer-discussion); the mobile app is a **thin client** that records on-device, ships audio over Tailscale, and receives documents back for review/edit/export.

Read and follow these files before writing code — they are the authoritative spec:
- `README.md` — goals, non-goals, stack.
- `docs/architecture.md` — components, server reality, API contract, security.
- `docs/implementation-plan.md` — phases, milestones, acceptance criteria.

## Hard facts (do not rediscover or guess — verified against the repo)

- The server is the existing FerriScribe desktop repo at `~/Development/rustMedicalAssistant` (GitHub `cortexuvula/ferriscribe`). It runs **two** relevant HTTP services in office-server mode:
  - `medical-sharing` crate on **:11436** — the pairing router: `POST /pair/enroll`, `GET /info`, and loopback-gated `GET /pair/clients` / `POST /pair/revoke/:id`. Also mDNS/Tailscale discovery, whisper supervision, LLM proxying.
  - `src-tauri/src/sharing_vocab_api/` (a Tauri app module, **not** the medical-sharing crate) on **:11437** — the data API: `/v1/vocabulary*`, `/v1/context-templates*`, `/v1/user-dictionary*`, `/v1/condition-chips*`, `/v1/content/sync{,/meta}`, `/v1/content/events` (SSE), `/v1/content/audio/{recording_id}` GET/PUT.
- **Audio is uploaded as plaintext bytes** (`PUT /v1/content/audio/{id}`); the server encrypts at rest itself (FE1 envelope, `medical_security::file_crypto`) the moment it lands. **Do not build client-side AES-GCM or streaming encryption** — it was explicitly cut from the plan. The app's job is: stream capture from the mic into the upload request (plaintext audio lives only in RAM); where a platform forces a temp file, keep it app-private and **shred it immediately after upload** — never merely delete it.
- **Transport is plain HTTP over Tailscale** (WireGuard encrypts the wire; no app-level TLS). Do not add TLS.
- **Auth** is a long-lived bearer token from `POST /pair/enroll` (validated by `TokenStore`; failed attempts hit a 429 rate-limit budget). There is **no TTL/refresh** — do not invent a refresh flow.
- **Pipeline reality:** `process_recording` is **transcribe → SOAP only** (stages: `transcribing → generating_soap → completed | failed`, reported via Tauri events, not HTTP). Referral/letter/synopsis/peer-discussion are **separate commands** triggered individually. The authoritative pipeline-step enum is `crates/processing/src/pipeline.rs:63-72`: `PipelineStep::{Transcribing, GeneratingSoap, GeneratingReferral, GeneratingLetter, ExtractingData, IndexingRag, Complete}`. (A claim that `core/src/types/pipeline.rs` holds `Transcription → IcdCoding → …` was checked and is false — that file does not exist.)
- **Document types:** `soap | referral | letter | synopsis | peer_discussion`. Content sync (`/v1/content/sync`, per-field LWW) covers transcript/soap/referral/letter/peer_discussion — **synopsis is not synced** and has no dedicated DB column (stored in recording metadata).
- **Export:** `medical-export` produces PDF + DOCX for **soap/referral/letter only** (plus FHIR). Synopsis + peer_discussion exporters are net-new server work.
- **Job queue/status over HTTP is greenfield** — `queue_tasks`/`ProcessingEvent` types exist in `medical-core` but nothing exposes them over HTTP; `process_recording` progress never leaves the Tauri event bus.
- **Server delta is mostly net-new** (recording ingestion, job status, generation triggers, export endpoints, self-revocation) — built beside the existing :11437 data API, not as an extension of `medical-sharing`'s pairing router. **The server track is the critical path for mobile Phase 1.**

## Critical path

The **server-side track is the critical path**. The mobile app cannot function until the server has recording ingest, job status, generation triggers, document read/write, export, and self-revocation endpoints. Implement the server delta first (or in lockstep), then verify the mobile phases against it.

## What to build

Implement the phases in `docs/implementation-plan.md` in order (0 → 4), plus the parallel server-side track. Deliver each phase with its acceptance criteria met and verified.

## Non-negotiable constraints

1. **No cloud AI, no telemetry, no phone-home.** The only remote peer is the paired FerriScribe server over Tailscale (:11436 and :11437). Never call a hosted AI/STT/TTS/OCR provider.
2. **No crash reporting SDK** — no Sentry/Crashlytics/Firebase. Crash stack traces can carry transcript fragments. Logging inherits the desktop's counts/lengths-only rule.
3. **No client-side audio encryption.** Audio goes up as plaintext bytes; the server owns at-rest encryption (FE1). Capture must **stream from the mic into the upload request** so plaintext audio lives only in RAM. Where a platform technically forces a temp file: app-private storage, excluded from backups, **shredded (overwritten, not merely deleted) immediately after confirmed upload**.
4. **PHI at rest on-device:** local DB SQLCipher via `sqlcipher_flutter_libs` (pin `^2.1.0`); tokens in `flutter_secure_storage`. **No plaintext audio file at rest, ever** — stream capture into the upload request (RAM only); where a platform forces a temp file: app-private, backup-excluded, shredded immediately after confirmed upload.
5. **No PHI in logs** on either side — log IDs/counts/lengths only. No PHI in SSE event payloads (IDs only) or push notifications.
6. **Never copy PHI to the OS clipboard** automatically. Explicit user-initiated copies only (iOS clipboard is readable by any foreground app and syncs via Universal Clipboard).
7. **Screen protection:** Android `FLAG_SECURE`; iOS screen-capture block; **app-switcher snapshot masking** (blur overlay on `AppLifecycleState.inactive` — iOS snapshots the last frame to disk unencrypted).
8. **Backup exclusion:** SQLCipher DB, document cache, and pending audio excluded from iCloud backup (`NSURLIsExcludedFromBackupKey`) and Android Auto Backup (`android:allowBackup="false"` + extraction rules).
9. **Token hygiene:** long-lived bearer token (no refresh exists server-side); stored in `flutter_secure_storage`; never logged. Revocation is desktop-side (`POST /pair/revoke/:id`, loopback-gated) or via the net-new self-revocation endpoint from the server track.
10. **Pairing/token flow:** QR (carries `pp=11436`, `vp=11437`, Tailnet host) → `POST /pair/enroll` → token persisted in the secure store.

## Verification (run and report each individually — no chaining into one opaque failure)

### Flutter gates:
- `flutter analyze` — clean (zero issues).
- `flutter test` — all green.
- `dart format --output=none --set-exit-if-changed .` — clean.

### Server gates (Rust, run in `~/Development/rustMedicalAssistant`):
- `cargo test --workspace --lib`
- `cargo fmt --all -- --check`
- `cargo clippy --workspace --all-targets -- -D warnings`

### PHI leak checklist (explicit acceptance gate — verify and report each):
- **App-switcher mask:** screenshot of app in app-switcher shows blur, not content.
- **Backup exclusion:** `adb backup` (Android) / iTunes backup (iOS) inspection confirms document cache — and any platform-forced pending-audio temp file — not included.
- **Temp-file hygiene:** after a recording session, assert zero plaintext audio files in the app's temp/storage directories; where a platform forced a temp file, verify it was shredded (overwritten, not merely deleted) immediately after upload. (At-rest gate, independent of transport — unaffected by the cut of client-side encryption.)
- **Clipboard audit:** verify no auto-copy of PHI after recording/generation.
- **Log scan:** grep app logs for transcript fragments — must find none.
- **No crash reporting:** confirm no Sentry/Crashlytics/Firebase SDK present in dependencies.
- **No cloud endpoints:** network trace confirms only the paired server (:11436/:11437 over Tailscale) is contacted.

## Report

List the Dart packages/features added per phase, the server-side API additions (with exact source files touched — expect `src-tauri/src/sharing_vocab_api/` for the data API and `crates/sharing/` only if pairing changes), the pairing flow, the stream-to-upload capture implementation (no plaintext temp file, or verified shredding), and a per-gate verification result. Do not claim success for any gate you did not actually run — say so explicitly.
