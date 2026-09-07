# FerriScribe Mobile — Phase Tracker

> Owned by @ferriscribe. Status legend: `not-started` / `in-progress` / `verifying` / `done`.
> Last updated: 2026-09-06

## Dependency order (the sequence)

1. **Server track** (turing) — CRITICAL PATH. Gates Flutter Phase 1.
2. **Flutter Phase 0** (scribe-mobile) — parallel; depends only on the *existing* `/pair/enroll` + `GET /info`.
3. **Flutter Phase 1** — BLOCKED on server track (recording ingest + job status/SSE).
4. **Flutter Phase 2** — BLOCKED on Phase 1 + server doc read/write.
5. **Flutter Phase 3** — BLOCKED on server export endpoints.
6. **Flutter Phase 4** — after Phase 2 (offline read cache).
7. **Review** (codie) — both tracks, before anything ships.

## Phases

| # | Phase | Owner | Status | Acceptance gates | Blocked by |
|---|---|---|---|---|---|
| S | Server delta (recording ingest, jobs+SSE, generation triggers, doc read/write, export, self-revocation) | turing | done | `cargo test`/`fmt`/`clippy -D warnings` green, re-run independently by ferriscribe + codie; tombstone leak fixed (`df6bd8f`); codie APPROVE | — |
| 0 | Scaffold & pairing | scribe-mobile | done | flutter gates clean; APK builds + installs; pairs via QR→`/pair/enroll`; token persists; PHI controls compiled in. **Device pending @user:** app-switcher blur (PHI-gate #1) | — |
| 1 | Record + ingest | scribe-mobile | done | `f698743`; flutter gates clean (40/40); RAM-only mic→WAV→upload, no temp file; codie APPROVE. **Device pending @user:** e2e record→SOAP + temp-file scan | S |
| 2 | Five doc types + review/edit | scribe-mobile | done | `5d21d2d`; flutter gates clean (50/50); codie APPROVE. **Device pending @user:** clipboard no-auto-copy audit | S |
| 3 | Export + share | scribe-mobile | done | `c2987c2`; flutter gates clean (63/63); PDF/DOCX→share sheet→shred; codie APPROVE | — (proceed) |
| 4 | Offline + polish | scribe-mobile + ada | done | scribe `a70597b` + ada `3dd6333`; codie APPROVE both. **Device pending @user:** offline-read smoke check folds into gate list | 2 |

## PHI leak checklist (release gate — codie verifies each, no "should work")

1. App-switcher mask shows blur, not content.
2. Backup exclusion: `adb backup` / iTunes backup inspection confirms doc cache + any temp audio NOT included.
3. Temp-file hygiene: after a recording session, zero plaintext audio files; any platform-forced temp file shredded (overwritten, not deleted).
4. Clipboard audit: no auto-copy of PHI.
5. Log scan: grep app logs for transcript fragments — none.
6. No crash reporting: no Sentry/Crashlytics/Firebase SDK.
7. No cloud endpoints: network trace shows only :11436/:11437 over Tailscale.

## Blockers / risks

- **CODE: NONE. Every track QA-signed** (codie APPROVE on S `df6bd8f`, P0–P4, polish slice; gates re-run independently by codie + ferriscribe). MVP is code-complete.
- **✅ Deploy gap CLOSED (verified live):** mobile API is now in the running server — `POST /v1/recordings` → 422 (validation, route exists), `POST /v1/devices/self` → 401, `GET /v1/jobs/*` → 401, `GET …/export` → 401 (auth-gated, not 404). Recording ingest should now work end-to-end.
- **Post-MVP backlog (codie-vetted, all non-blocking):** (1) `record_screen.dart:121-126` — dedupe the per-SSE-event `upsertPatientContext` with a `_contextPersisted` guard + `.catchError`; (2) pagination `(updated_at, id)` tiebreak — accept re-pull dedupe for now, fix server-side later; (3) stale-export-file sweep on app start.
- **Device PHI-gates (@user):** ✅ app-switcher blur (P0) PASSED on device; ❌ e2e record→SOAP (P1) FAILED — server predates mobile API (deployment blocker above); ⏳ clipboard no-auto-copy (P2) + offline-read (P4) not yet tested.

- **Server repo is mid-flight:** `~/Development/rustMedicalAssistant` is on `feat/specialty-prompt-packs` with uncommitted changes; `master` is the base branch (origin/HEAD → origin/master). Server track MUST branch off clean `master` in a new git worktree — do not disturb the in-progress branch.
- Synposis is not in `/v1/content/sync` field set and has no DB column (stored in recording metadata) — server-track decision.
- Unpair-from-phone is loopback-gated today (`POST /pair/revoke/:id`) — server-track decision (self-revocation endpoint vs desktop-side).
