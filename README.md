# FerriScribe Mobile

Flutter (Dart) mobile client for [FerriScribe](https://github.com/cortexuvula/ferriscribe) — the local-first AI medical scribe. Targets iOS + Android.

## Architecture at a glance

FerriScribe desktop runs all AI **locally** (whisper.cpp STT + Ollama/LM Studio/oMLX for SOAP, referral, letter, synopsis, and peer-discussion) on the physician's own machine. A phone can't run that stack, so this app is a **thin client**: it records the consultation on-device, ships the audio to the physician's local FerriScribe server over **Tailscale**, and receives back the generated documents for review, edit, and export.

```
[Flutter app]  --audio + docs (HTTP)-->  [FerriScribe desktop, office-server mode]
 (iOS/Android)      over Tailscale        (Mac Studio — all inference local;
                                        audio FE1-encrypted at rest on receipt)
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
- Client-side audio encryption — dropped by design (Sep 2026 consolidation): audio is uploaded as plaintext over Tailscale and the server applies its existing FE1 at-rest encryption on receipt. The phone never persists audio at rest (see security section).

## Privacy & security (non-negotiable — inherited from desktop)

- No hosted AI, no telemetry, no phone-home.
- No Sentry/Crashlytics/Firebase — crash stack traces can carry transcript fragments. If logging exists, it inherits the desktop's counts/lengths-only rule.
- **No plaintext audio temp file on the phone.** The `record` package's default writes a plaintext WAV temp file before upload — that is a LOCAL at-rest PHI leak (recoverable from unallocated blocks even after deletion), independent of transport security. Audio capture must **stream directly into the upload request** so plaintext audio exists only in RAM; if a temp file is technically unavoidable on some platform, **shred it immediately after upload** succeeds.
- **Audio at rest is the server's job.** The phone does not encrypt audio and does not keep it: audio is uploaded as plaintext over Tailscale, and the server applies its existing FE1 at-rest file encryption (AES-256-GCM under an OS-keychain key) on receipt. After a successful upload the phone retains no audio.
- Local document cache (offline review) stays encrypted: SQLCipher (AES-256) via `sqlcipher_flutter_libs`.
- Tokens in the platform secure store (Keychain / Keystore via `flutter_secure_storage`). Long-lived bearer token (no server-side TTL/refresh today); the existing `/pair/revoke/:id` is loopback-gated, so remote lost-phone revocation needs the net-new self-revocation endpoint from the server track.
- Transport: plain HTTP over Tailscale (Tailscale WireGuard encrypts the wire; no app-level TLS). Server pairing via QR + token.
- No PHI in logs — IDs/counts/lengths only. No PHI in SSE event payloads or push notifications.
- Android `FLAG_SECURE` + iOS screen-capture protection + app-switcher snapshot masking.
- SQLCipher DB and cached documents excluded from iCloud backup (`NSURLIsExcludedFromBackupKey`) and Android Auto Backup (`android:allowBackup="false"` + extraction rules).
- Clipboard: explicit user-initiated copies only, never auto-copy PHI.

## Stack

- Flutter / Dart (iOS + Android)
- `flutter_secure_storage` — tokens
- `sqlcipher_flutter_libs` (pin `^2.1.0`) + `drift` — encrypted local document cache
- `record` — microphone capture (**streaming API**; chunks multiplexed straight into the upload request)
- HTTP over Tailscale — JSON REST + SSE progress
- `pdf` / `docx` export + system share sheet

No client-side crypto package — audio encryption was dropped by design; at-rest protection is the server's FE1 on receipt, plus the no-temp-file rule above.

## Bundle ID

`ai.ferriscribe.mobile` — iOS `PRODUCT_BUNDLE_IDENTIFIER` and Android `applicationId`/`namespace`.

## Building & releasing

Signing and release are CI-driven via GitHub Actions (`.github/workflows/`). No signing material is
committed — certificates, profiles, keystore, and the App Store Connect API key live in GitHub repo
Secrets (backed up in Bitwarden). See `flutter-mobile-release-ci` and `apple-appstoreconnect-api`
skills for the full procedure.

| Workflow | Runner | Output |
| --- | --- | --- |
| `ios-build.yml` | macOS | signed **ad-hoc** IPA (artifact) |
| `ios-testflight.yml` | macOS | uploads the App Store IPA to **TestFlight** |
| `android-build.yml` | ubuntu | signed **release APK** → **GitHub Release** |

All three trigger on `workflow_dispatch` and `v*` tag pushes.

**Release the Android APK** — push a version tag, and CI builds + signs + attaches the APK to an
auto-created GitHub Release:

```bash
git tag v1.0.31 && git push --tags
```

**iOS distribution routes:**
- **Ad-hoc** — gated by device UDIDs embedded in the profile (own devices only).
- **TestFlight** — the non-UDID path; the build uploads to App Store Connect for beta review.

**Signing setup:**
- iOS — `iPhone Distribution: Andre Hugo (RB4QV9W52C)` cert + `IOS_APP_ADHOC` / `IOS_APP_STORE`
  profiles; Manual signing (`DEVELOPMENT_TEAM RB4QV9W52C`) driven by the committed
  `ios/ExportOptions-{adhoc,appstore}.plist`.
- Android — release keystore (alias `ferriscribe`) wired via gitignored `android/key.properties`;
  falls back to debug signing when absent (local dev).

Local signed builds (dev machine with cert/profile installed and `android/key.properties` present):

```bash
flutter build apk --release
flutter build ipa --release --export-options-plist ios/ExportOptions-adhoc.plist   # or -appstore.plist
```

## Repo layout

```
docs/architecture.md          — components, data model, API contract, security
docs/implementation-plan.md   — phased plan, milestones, acceptance criteria
docs/zcode-prompt.md          — the build prompt fed to Zcode
.github/workflows/            — ios-build, ios-testflight, android-build
ios/ExportOptions-*.plist     — ad-hoc + app-store export options
```
