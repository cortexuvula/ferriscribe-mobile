# FerriScribe Mobile

Flutter (Dart) mobile client for [FerriScribe](https://github.com/cortexuvula/ferriscribe) — the local-first AI medical scribe. Targets iOS + Android.

## Architecture at a glance

FerriScribe desktop runs all AI **locally** (whisper.cpp STT + Ollama/LM Studio/oMLX for SOAP, referral, letter, synopsis, and peer-discussion) on the physician's own machine. A phone can't run that stack, so this app is a **thin client**: it records the consultation on-device, ships **encrypted** audio to the physician's local FerriScribe server over **Tailscale**, and receives back the generated documents for review, edit, and export.

```
[Flutter app]  --encrypted audio / docs-->  [FerriScribe desktop, office-server mode]
 (iOS/Android)          over Tailscale          (Mac Studio — all inference local)
```

## Goals

- Record a consultation on the phone; get a complete SOAP note + referral/letter/synopsis/peer-discussion back from the physician's own local AI.
- Review and edit all **5 document types** on-device.
- Export to **PDF/DOCX** and share from the phone.
- Offline review via a local encrypted cache.

## Non-goals (v1)

- On-device inference (whisper/LLM running on the phone) — deferred to v2.
- Cloud/hosted AI — violates the privacy model, never.
- Full desktop feature parity (RAG UI, 8-agent chat, vocabulary editor) — deferred.

## Privacy & security (non-negotiable — inherited from desktop)

- No hosted AI, no telemetry, no phone-home.
- PHI at rest encrypted: audio AES-256-GCM; local DB SQLCipher (AES-256).
- Keys/tokens in the platform secure store (Keychain / Keystore via `flutter_secure_storage`).
- Transport: Tailscale WireGuard; server pairing via QR + token.
- No PHI in logs — IDs/counts/lengths only.
- Android `FLAG_SECURE` + iOS screen-capture protection.

## Stack

- Flutter / Dart (iOS + Android)
- `flutter_secure_storage` — keys/tokens
- `sqlcipher_flutter_libs` + `drift` — encrypted local cache
- `record` — microphone capture
- `cryptography` — AES-256-GCM
- HTTP over Tailscale — JSON REST + SSE progress
- download server-rendered PDF/DOCX (`medical-export`) + system share sheet

## Repo layout

```
docs/architecture.md          — components, data model, API contract, security
docs/implementation-plan.md   — phased plan, milestones, acceptance criteria
docs/zcode-prompt.md          — the build prompt fed to Zcode
```
