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

Auth: pairing yields a bearer token (QR → token exchange, same flow as the existing office-server pairing). Every request carries `Authorization: Bearer <token>`. The wire is already encrypted by Tailscale; token auth is the app-level gate.

| Method | Path | Purpose |
|---|---|---|
| POST | `/pair` | QR/token pairing → session token |
| POST | `/recordings` | upload encrypted audio (AES-GCM blob) → `{ recording_id, job_id }` |
| GET | `/jobs/{job_id}` | SSE progress events (Queued→Started→Completed per stage) |
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

## 5. Security / PHI invariants (carry over from desktop, unchanged)

1. **No hosted AI** — all inference is the physician's local FerriScribe server. The mobile app makes zero calls to any cloud AI provider.
2. **No telemetry / phone-home** — only the paired server is contacted, over Tailscale.
3. **PHI at rest** — audio AES-256-GCM; local DB SQLCipher. No plaintext temp files.
4. **No PHI in logs** — IDs/counts/lengths only, on both client and server.
5. **Screen protection** — Android `FLAG_SECURE`; iOS screen-capture block in the app switcher.
6. **Clipboard** — never auto-copy PHI to the OS clipboard (cloud clipboard sync).
7. **Token hygiene** — bearer token in `flutter_secure_storage`; server tokens never logged.

## 6. Decisions & open questions

- **Transport v1:** HTTPS + JSON REST, matching the existing `medical-sharing` HTTP patterns. gRPC is a v2 candidate (lower-latency streaming) but does not gate v1.
- **Server mode:** v1 uses the desktop app in office-server mode. A dedicated headless `ferriscribe-server` daemon (no GUI) is a v2 candidate.
- **Offline:** v1 cache is read-only review of already-fetched documents. Offline *generation* is out of scope — the server is required for AI.
