# FerriScribe Mobile — Architecture

## 1. Components

```
┌─────────────────────────────┐            ┌──────────────────────────────────┐
│  Flutter app (iOS/Android)  │   HTTPS    │  FerriScribe desktop (server)    │
│  · recorder                 │  ─────────▶│  · medical-sharing office mode   │
│  · encrypted audio cache    │  Tailscale │  · whisper.cpp STT               │
│  · document review/editor   │  ◀─────────│  · SOAP / referral / letter /    │
│  · SQLCipher offline cache  │    JSON    │    synopsis / peer-discussion    │
│  · PDF/DOCX export + share  │            │  · medical-export (PDF/DOCX/FHIR)│
└─────────────────────────────┘            └──────────────────────────────────┘
```

## 2. Server side (delta — mostly exists)

`medical-sharing` already implements office-server mode: mDNS + Tailscale discovery, QR pairing, a whisper binary supervisor, and a vocab/template sharing HTTP API. The v1 delta is extending that same paired HTTP API with:

- **audio ingestion** — receive encrypted audio, enqueue the existing processing pipeline.
- **job status** — SSE stream of the existing pipeline progress events (per stage: Queued → Started → Completed), reusing the desktop event channels (`app_handle.emit`).
- **document read/write** — the 5 doc types, so mobile can fetch results and save edits.
- **export** — invoke `medical-export` to PDF/DOCX and stream the file back.

No new inference code — reuse the existing pipeline and providers unchanged. The pipeline stages are `Transcribing → SOAP → Referral → Letter → ExtractingData → RAG indexing → Complete`.

## 3. API contract (HTTP/JSON over Tailscale)

Auth: pairing yields a bearer token (QR → token exchange, same flow as the existing office-server pairing). Every request carries `Authorization: Bearer <token>`. The wire is already encrypted by Tailscale; token auth is the app-level gate. **The token authenticates the client only** — the client must also authenticate the server (cert pinning or a pairing-time server-fingerprint check), and the API authorizes each request against the recording's owner (unguessable UUIDs), never an all-or-nothing token across a shared practice server.

| Method | Path | Purpose |
|---|---|---|
| POST | `/pair` | QR/token pairing → session token |
| POST | `/recordings` | upload encrypted audio (AES-GCM blob) → `{ recording_id, job_id }` |
| GET | `/jobs/{job_id}` | SSE progress events (Queued→Started→Completed per stage); **replayable from `?last_event_id=`** so a backgrounded client can reconnect and recover missed events (iOS drops the TCP connection on background) |
| GET | `/recordings/{id}/documents` | fetch all 5 doc types + metadata |
| PUT | `/recordings/{id}/documents/{type}` | save an edited document back |
| POST | `/recordings/{id}/export` | `{ format: pdf\|docx, doc_type }` → streamed file |
| GET | `/vocab`, `/templates` | existing sharing API (reuse as-is) |

Doc types: `soap | referral | letter | synopsis | peer_discussion`.

## 4. Mobile data model

- `Recording { id, title, started_at, duration_s, audio_path, status }` — `audio_path` points at an AES-256-GCM-encrypted blob.
- `Document { recording_id, doc_type, body, edited, synced_at }`
- `PatientContext { recording_id, meds, allergies, conditions, notes }` — background context, mirrors desktop.
- `ServerConfig { tailscale_host, port, token, paired_at }`

Local storage: SQLCipher (AES-256) via `sqlcipher_flutter_libs` + `drift`. Audio blobs encrypted with a key held in `flutter_secure_storage`.

Audio encryption: **chunked** AES-GCM (64 KB chunks, nonce + tag per chunk, streamed from the recorder) — never whole-blob, which OOMs on a 50–150 MB consultation. Prefer `pointycastle` for streaming control over `cryptography`.

Audio format (decide in Phase 1): whisper.cpp ingests 16 kHz mono WAV natively. If recording AAC/Opus (smaller files), the server needs ffmpeg to transcode before transcription. WAV = simple + large; AAC/Opus = small + server-side conversion.

Retention: local audio is deleted after confirmed server acknowledgment; a storage-usage indicator surfaces what remains (a full day of consultations is ~1 GB — unbounded accumulation will fill the device).

## 5. Security / PHI invariants (carry over from desktop, unchanged — plus mobile-specific hardening)

1. **No hosted AI** — all inference is the physician's local FerriScribe server. The mobile app makes zero calls to any cloud AI provider.
2. **No telemetry / phone-home, and no third-party crash/analytics SDK** (Sentry/Firebase/Crashlytics) — only the paired server is contacted, over Tailscale. Ban the dependency, not just the network call.
3. **PHI at rest** — audio chunked AES-256-GCM with a **random 96-bit nonce per blob** (stored alongside the ciphertext); local DB SQLCipher. Recording is encrypted **in-memory/streaming** — never buffer plaintext audio to a file, and disallow recorder plugins that write their own plaintext cache files. No plaintext temp files, ever.
4. **No PHI in logs** — IDs/counts/lengths only, on both client and server.
5. **Screen protection** — Android `FLAG_SECURE` via a platform channel in `MainActivity.onCreate` (set before first frame; blocks screenshots/recording but NOT HDMI/Miracast), plus `importantForAccessibility=no`/data-masking on PHI views (Android 14+ partial screen-share and accessibility services can read the view hierarchy). iOS: `UIScreen.isCaptured` overlay while recording + `applicationWillResignActive` blur for the app-switcher snapshot (iOS takes that snapshot regardless of capture protection).
6. **Clipboard & text entry** — never auto-copy PHI to the OS clipboard. On PHI text fields: disable autocorrect/spell-check/predictive-text (`autocorrectionType = .no`, `spellCheckingType = .no`) and block third-party keyboards (force system keyboard) — full-access keyboards and iOS text-prediction learn from typed PHI.
7. **Server authentication** — the bearer token authenticates the client only. The client must authenticate the **server** too: cert pinning or a pairing-time server-fingerprint check, so a rogue tailnet host can't harvest tokens/audio. Tokens have lifetime/expiry/refresh/revocation; QR pairing tokens are high-entropy, one-time, and short-expiry.
8. **Per-recording authorization** — the API authorizes each request against the recording's owner, not a single all-or-nothing token; job/recording IDs are unguessable (UUID, not sequential), so one paired device can't enumerate another patient's recordings on a shared practice server.
9. **Export/share path** — a streamed PDF/DOCX is plaintext PHI the moment it's written for sharing. Write exports to an app-private location, no PHI in the filename, present via the share sheet, and delete the plaintext copy after the share completes. AirDrop/print are the physician's own action.
10. **iOS backup exclusion** — exclude the SQLCipher DB and encrypted blobs from iCloud/iTunes backup (`NSURLIsExcludedFromBackupKey`), Keychain accessibility `...ThisDeviceOnly`; Android `android:allowBackup="false"`. A device restore must not migrate PHI.
11. **Key management** — AES key wipe-on-unpair (unpairing deletes local keys + cached PHI). `flutter_secure_storage` requires a declared min-API floor (Android <23 falls back to weaker storage — enforce it).
12. **App lock** — auto-lock after background/inactivity with re-auth (biometric/PIN) on resume. A phone with PHI open and no lock is a downgrade from the desktop posture.
13. **Offline cache lifecycle** — cached documents are deleted on unpair, purged when the server deletes the recording, and subject to a retention policy. PHI on a lost/stolen/traded-in phone is the weakest link — acknowledge and bound it.
14. **Notifications & widgets** — no PHI in local notifications, lock-screen previews, or widgets (patient names, doc snippets). Completion notifications use IDs/titles only.

## 6. Decisions & open questions

- **Transport v1:** HTTPS + JSON REST, matching the existing `medical-sharing` HTTP patterns. gRPC is a v2 candidate (lower-latency streaming) but does not gate v1.
- **Server mode:** v1 uses the desktop app in office-server mode. A dedicated headless `ferriscribe-server` daemon (no GUI) is a v2 candidate.
- **Offline:** v1 cache is read-only review of already-fetched documents. Offline *generation* is out of scope — the server is required for AI.
- **`sqlcipher_flutter_libs` on iOS Simulator:** published binaries may ship x86_64-only simulator slices; verify the pinned version has an arm64-simulator slice or the M-series sim build fails at link. Dev-only fallback: `sqlite3_flutter_libs` (unencrypted) behind a compile flag.
- **`flutter_secure_storage` Android corruption:** some Samsung/Xiaomi devices lose the Keystore master key after OS updates; wrap reads to detect `BadPaddingException` and re-prompt pairing instead of crashing.
- **`drift` codegen:** every model change needs `dart run build_runner build --delete-conflicting-outputs`; generated `.g.dart` files are not hand-editable. Provide a script/Make target.
