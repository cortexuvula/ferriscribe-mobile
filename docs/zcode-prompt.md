# zcode prompt — FerriScribe Mobile (Flutter thin client)

You are building **FerriScribe Mobile** — a Flutter (Dart) client for iOS + Android that pairs with the existing FerriScribe desktop application (Rust + Tauri) running in office-server mode on the physician's own machine. The desktop app runs all AI locally (whisper.cpp STT + Ollama/LM Studio/oMLX for SOAP/referral/letter/synopsis/peer-discussion); the mobile app is a **thin client** that records on-device, ships encrypted audio over Tailscale, and receives documents back for review/edit/export.

Read and follow these files before writing code — they are the authoritative spec:
- `README.md` — goals, non-goals, stack.
- `docs/architecture.md` — components, API contract, data model, security.
- `docs/implementation-plan.md` — phases, milestones, acceptance criteria.

## Hard facts (do not rediscover or guess)

- The server is the existing FerriScribe desktop repo at `~/Development/rustMedicalAssistant` (GitHub `cortexuvula/ferriscribe`). The `medical-sharing` crate already implements office-server mode: mDNS + Tailscale discovery, QR pairing, whisper binary supervisor, and a vocab/template sharing HTTP API.
- The processing pipeline stages are `Transcribing → SOAP → Referral → Letter → ExtractingData → RAG indexing → Complete`, each emitting Queued→Started→Completed progress events. Reuse them; add no new inference code.
- The 5 document types are `soap | referral | letter | synopsis | peer_discussion`.
- `medical-export` produces PDF and DOCX (and FHIR) — reuse it for export.

## What to build

Implement the phases in `docs/implementation-plan.md` in order (0 → 4), plus the parallel server-side delta. Deliver each phase with its acceptance criteria met and verified.

## Non-negotiable constraints

1. **No cloud AI, no telemetry, no phone-home.** The only remote peer is the paired FerriScribe server over Tailscale. Never call a hosted AI/STT/TTS/OCR provider.
2. **PHI at rest encrypted:** audio AES-256-GCM; local DB SQLCipher via `sqlcipher_flutter_libs`; keys/tokens in `flutter_secure_storage`. No plaintext temp files, ever.
3. **No PHI in logs** on either side — log IDs/counts/lengths only.
4. **Never copy PHI to the OS clipboard** (cloud clipboard sync).
5. **Screen protection:** Android `FLAG_SECURE`; iOS screen-capture block.
6. **Pairing/token flow:** QR → bearer-token exchange; token persisted in the secure store; server tokens never logged.

## Verification (run and report each individually — no chaining into one opaque failure)

- `flutter analyze` — clean (zero issues).
- `flutter test` — all green.
- `dart format --output=none --set-exit-if-changed .` — clean.
- If the Rust server delta is implemented: `cargo test --workspace --lib`, `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings` (run in `~/Development/rustMedicalAssistant`).

## Report

List the Dart packages/features added per phase, the server-side API additions (with the exact `medical-sharing` files touched), the pairing flow, and a per-gate verification result. Do not claim success for any gate you did not actually run — say so explicitly.
