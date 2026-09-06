# zcode prompt — FerriScribe Mobile (Flutter thin client)

You are building **FerriScribe Mobile** — a Flutter (Dart) client for iOS + Android that pairs with the existing FerriScribe desktop application (Rust + Tauri) running in office-server mode on the physician's own machine. The desktop app runs all AI locally (whisper.cpp STT + Ollama/LM Studio/oMLX for SOAP/referral/letter/synopsis/peer-discussion); the mobile app is a **thin client** that records on-device, ships encrypted audio over Tailscale, and receives documents back for review/edit/export.

Read and follow these files before writing code — they are the authoritative spec:
- `README.md` — goals, non-goals, stack.
- `docs/architecture.md` — components, API contract, data model, security.
- `docs/implementation-plan.md` — phases, milestones, acceptance criteria.

## Hard facts (do not rediscover or guess)

- The server is the existing FerriScribe desktop repo at `~/Development/rustMedicalAssistant` (GitHub `cortexuvula/ferriscribe`). The `medical-sharing` crate already implements office-server mode: mDNS + Tailscale discovery, QR pairing, whisper binary supervisor, and a vocab/template sharing HTTP API.
- **Actual pipeline stages** (from `core/src/types/pipeline.rs`): `Transcription → IcdCoding → DemographicsExtraction → PatientMatching → ClinicalValidation → RagIndexing → Complete`, each emitting Queued→Started→Completed progress events. **Document generation** (the 5 doc types) is a **separate pipeline** that runs after ingestion — it is NOT part of the ingestion stages.
- The 5 document types are `soap | referral | letter | synopsis | peer_discussion`.
- `medical-export` produces PDF and DOCX — reuse it for export.
- **Existing server endpoints only:** `/pair`, `/vocab`, `/templates`. The rest of the API (`/recordings`, `/jobs/{id}`, document CRUD, `/export`, unpair) must be built as net-new.
- **Transport is HTTP over Tailscale** (plain TCP, no TLS). Tailscale WireGuard encrypts the wire. Do not add app-level TLS.

## Critical path

The **server-side API delta is the critical path**. The mobile app cannot function until the server has recording ingest, job status, document read/write, export, and unpair endpoints. Implement the server delta first (or in lockstep), then verify the mobile phases against it.

## What to build

Implement the phases in `docs/implementation-plan.md` in order (0 → 4), plus the parallel server-side delta. Deliver each phase with its acceptance criteria met and verified.

## Non-negotiable constraints

1. **No cloud AI, no telemetry, no phone-home.** The only remote peer is the paired FerriScribe server over Tailscale. Never call a hosted AI/STT/TTS/OCR provider.
2. **No crash reporting SDK** — no Sentry/Crashlytics/Firebase. Crash stack traces can carry transcript fragments. Logging inherits the desktop's counts/lengths-only rule.
3. **PHI at rest encrypted:** audio AES-256-GCM; local DB SQLCipher via `sqlcipher_flutter_libs` (pin `^2.1.0`); keys/tokens in `flutter_secure_storage`. No plaintext temp files, ever.
4. **Streaming audio encryption:** the `record` package's default writes PCM/WAV to a temp path *before* you encrypt — that's plaintext PHI on disk. Capture must **stream chunks directly into the encryptor**. For large files (30-min WAV ~300MB), use streaming AES-256-GCM via `cryptography` package or a platform channel to native crypto (`CommonCrypto` on iOS, `javax.crypto.Cipher` on Android).
5. **No PHI in logs** on either side — log IDs/counts/lengths only. No PHI in SSE event payloads (IDs only) or push notifications.
6. **Never copy PHI to the OS clipboard** automatically. Explicit user-initiated copies only (iOS clipboard is readable by any foreground app and syncs via Universal Clipboard).
7. **Screen protection:** Android `FLAG_SECURE`; iOS screen-capture block; **app-switcher snapshot masking** (blur overlay on `AppLifecycleState.inactive` — iOS snapshots the last frame to disk unencrypted).
8. **Backup exclusion:** SQLCipher DB and cached documents excluded from iCloud backup (`NSURLIsExcludedFromBackupKey`) and Android Auto Backup (`android:allowBackup="false"` + extraction rules).
9. **Token hygiene:** short-lived session tokens with refresh; server-side unpair endpoint (`DELETE /devices/{device_id}`) for lost-phone revocation; server tokens never logged.
10. **Pairing/token flow:** QR → bearer-token exchange; token persisted in the secure store.

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
- **App-switcher mask:** screenshot of app in switcher shows blur, not content.
- **Backup exclusion:** `adb backup` (Android) / iTunes backup (iOS) inspection confirms DB and audio not included.
- **Temp-dir scan:** after a recording session, assert zero plaintext audio files in the app's temp directory.
- **Clipboard audit:** verify no auto-copy of PHI after recording/generation.
- **Log scan:** grep app logs for transcript fragments — must find none.
- **No crash reporting:** confirm no Sentry/Crashlytics/Firebase SDK present in dependencies.
- **No cloud endpoints:** network trace confirms only the paired server is contacted.

## Report

List the Dart packages/features added per phase, the server-side API additions (with the exact `medical-sharing` files touched), the pairing flow, the streaming encryption implementation, and a per-gate verification result. Do not claim success for any gate you did not actually run — say so explicitly.
