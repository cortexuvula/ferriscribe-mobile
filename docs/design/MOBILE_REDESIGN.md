# FerriScribe Mobile — clinical workspace redesign

**Status: proposed design, awaiting user approval. Not implemented.**
**Design owner:** @ui-consultant. **App implementation:** @scribe-mobile, @turing, @codie. **Integration/release coordination:** @ferriscribe.
**Source baseline inspected:** `7a5f2ffb178c7658375067f22d3ddbcace81b77f`.
**Scope:** the Flutter mobile application, not the FerriScribe desktop UI. No production source, server configuration, PHI database or deployed application was changed to produce this design.

## 1. Direction

This is an **Operate** surface: a clinician records a consultation, reviews its documents, and exports a chosen document. Actions and readable clinical text come first; diagnostics and appearance belong in Settings.

**Recommended: a consultation workspace.** Merge the existing home action launcher and recordings list into one useful landing screen: a compact server-status line, searchable consultations, and one bottom `New consultation` action. A consultation opens its five document types. Recording and editing are focused routes, without persistent navigation competing with their primary action.

Alternatives considered:
- **Conservative launcher:** retain Home + separate Recordings and restyle everything. Lowest integration risk, but still adds a navigation step and gives settings disproportionate weight.
- **Consultation workspace (recommended):** combine launcher/list and put Settings in the app bar. Most direct daily workflow, no new server resources, and familiar back navigation.
- **Three-tab dashboard:** Record / Consultations / Settings. Easy destination switching but recording is an action, not a durable destination; tabs complicate accidental exit during capture and duplicate the main CTA. Not recommended for this small application.

Visual character: restrained clinical blue, warm pale surfaces by day, ink-blue surfaces by night, clear typography and generous touch targets. No marketing hero, decorative statistics, animated fake waveform, gradients, glass panels, patient avatars, or inferred clinical advice. Local platform typography is deliberate: it follows Android/iOS accessibility and requires no external font service.

## 2. Evidence from the existing app

Source review, not a claim to have seen the installed Pixel UI:

| Existing source | Finding | Required design response |
|---|---|---|
| `features/home/home_screen.dart` | Appearance occupies three permanent rows on the daily landing surface; recordings require another route. | Move preferences/diagnostics to Settings; make consultations the useful landing content. Keep the repaired accessible Connection disclosure and orphaned-token warning. |
| `features/recording/record_screen.dart:208–218,280–284` | Success shows an id and Back, not the generated SOAP. | Explicit `Open SOAP note` on success, using the real returned recording id. Do not fabricate a SyncRecording to navigate. |
| `features/recording/record_screen.dart:138–145,278–279` | Cancel discards audio; normal route back can dispose capture. | Label `Discard recording` and intercept all exit gestures with a confirmation. No pause control: it is not supported. |
| `features/documents/document_editor_screen.dart:74–87` | Cached content opens without an offline label and is editable although no offline write queue exists. | Clearly label cached content; offline entry is read-only. |
| `features/documents/document_editor_screen.dart:126–132,162–174` | A save error replaces the editor with an error screen; retry reloads content. | Keep the edited buffer visible and dirty; Retry save retries PUT, never GET. Warn on leaving unsaved edits. |
| `storage/offline_cache_repository.dart:45–58` + `recording_detail_screen.dart:40–42,213–254` | Cached list rows omit document fields, so hasDoc is false; details then offer Generate instead of opening cached content. | Explicitly query cached document availability by recording id/type. Cache presence and server document existence are different facts. This is a required adapter seam, not merely styling. |
| `features/documents/recording_detail_screen.dart` | Five cards expose icon-only actions; peer-discussion blank submission silently returns. | Readable document rows with text status/action; inline required-field errors, keyboard-safe form. |
| `features/recording/record_screen.dart`, `recording_detail_screen.dart`, `recordings_screen.dart` | Hard-coded red/orange/green/grey bypass the theme. | Semantic light/dark tokens, with icon + text for every status. |
| `features/export/export_service.dart` | Share API result is discarded; returning without an exception cannot establish receipt by another app. | Do not show `Sent` or `Delivered`; cancellation returns quietly. |

Preserve: server-authoritative document fetch, explicit Copy only, private temporary exports and cleanup, encrypted cache, microphone-to-memory capture, duration limits, pairing confirmation, and the root privacy shield.

## 3. Information architecture

```
Unpaired → Connect to office → Scan / Enter pairing link → Confirm office → Pair
Paired   → Consultations ── Settings → Appearance / Connection / Unpair
               │
               ├─ New consultation → Patient context (optional)
               │                      → Record → Stop & generate
               │                      → Progress → Open SOAP note
               │
               └─ Consultation → SOAP / Referral / Letter / Synopsis / Peer discussion
                                  ├─ Open → Read → Edit → Save changes
                                  ├─ Generate → Progress → Open
                                  └─ Export & share → PDF / Word → System share sheet
```

`Consultations` is presentation terminology for existing recordings; do not rename database entities or wire identifiers. No patient directory, appointments, prescribing, billing, playback, pause, background-upload guarantee, autosave, draft queue, signed-off flag, or new export destination is introduced.

## 4. Global layout and design system

Exact paired token values are in `DESIGN.md`; the prototype uses those tokens, not independently invented colors. Brand anchor remains `#1B6B93`. Initialize complete Material 3 ColorSchemes from the seed, then explicitly map documented semantic roles so our tokens remain normative; do not replace `fromSeed` with an incomplete hand-built scheme.

- Phone horizontal inset: 20dp at >=360dp, 16dp below; section gap 24dp; related-item gap 8–12dp.
- Top app bar: native safe-area aware, minimum 56dp; action hit areas >=48dp. Large app-bar title is not forced into a narrow row with multiple text actions.
- Footer: one filled primary action, minimum 56dp tall, 12dp top/bottom padding plus system inset. Secondary destructive action, where needed, has its own >=48dp row.
- Main list rows: minimum 80dp, natural growth for long labels/text scale. Touch the whole row; no nested competing row targets. Separate menu actions go outside the main tap semantics.
- Buttons/fields: 12dp radius. Grouped surfaces: 16dp. Sheets: 24dp upper corners. Status pills are descriptive, not tiny buttons.
- Typography: title 28sp/34, page title 22sp/28, section 18sp/24, body/document 16sp/24, supporting 14sp/20, labels 14sp/20 medium; timer 48sp/56, tabular figures. No essential text below 14sp.
- Clinical document area: maximum reading width 720dp on wide screens. Plain-text fidelity is authoritative; preserve line breaks and exact text. Do not parse SOAP into new editable fields or discard unfamiliar headings.
- Wide devices: center an expanded working column up to 840dp; no new tablet two-pane navigation in this pass. At 200% text scale, controls grow/wrap and secondary actions stack; never clamp accessibility text scaling.
- Motion: short 150–200ms fades/size transitions; respect reduced motion. No indefinite waveform or percentage unless backed by actual measurement. Screen-reader live announcements on stage changes, not every timer tick.
- Visible focus, semantic names, selected/expanded state, and focus return after dialogs are mandatory. Toolbar icons require tooltips and semantic labels.

## 5. Screen specifications

### A. Consultations — replaces the action-only Home

```
FerriScribe                                  [Settings]
Office server · connection not checked         [Check]

Consultations
[ Search name or consultation                         ]
Recently updated
DEMO PATIENT A                                       >
Mon 7 Sep · 09:40 · 08:12
SOAP available
──────────────────────────────────────────────────────
Consultation · Mon 7 Sep                             >
09:10 · 05:42
Documents available

                               [ New consultation ]
```

- Search only the loaded recording metadata, locally in memory: name/filename; do not transmit, persist or log search terms. No full-text clinical search in this pass. Clear-query action is labelled.
- Sort by existing `updatedAt` descending. Label the group `Recently updated`, not `Today` using a potentially different created date. Row time is `createdAt` local time and duration in mm:ss/h:mm:ss; omit missing/invalid values, never show epoch fallback as a real event.
- Use known patientName; fall back to filename or `Consultation · <created date>`. Do not invent patient names from transcript or context when the model does not expose them.
- One concise status (`SOAP available`, `Documents available`, `No documents yet`) derived only from actual fields. Availability is not clinician review. Offline use `Cached documents` only if the cache query establishes it.
- Initial load: labelled progress/skeleton list. Refresh with existing data: retain rows and small progress, no full-screen wipe. Empty: `No consultations yet` and `Record a consultation to get started`; retain primary CTA. Filter empty: `No matches` + Clear search.
- Error/no cache: `Could not reach your office server` + `Check that the desktop app and Tailscale are running` + Retry / Settings. Auth denial is `Pairing needs attention`, not offline; retain the security policy for cache access rather than silently bypassing revocation.
- Offline cached list: persistent `Offline · showing cached consultations` + Retry. `New consultation` may open preparation, but final Start is disabled after a failed connection check; no promise of queued offline upload.

### B. New consultation — preparation

- Title `New consultation`; one short instruction: `Record the conversation, then generate a SOAP note.`
- Optional row `Patient context` with `Not added` or `Added for this consultation`; editing reveals the actual form, no meaningless aggregate count.
- Pre-record explanation: `Keep FerriScribe open while recording. Audio is not saved as a recording file on this phone.` Avoid claiming that this verifies server retention, all background capture, or all inference-provider privacy.
- Connection checked before final Start; show checking state, then truthful result. Failure offers Check again / Connection settings; no new network endpoint is required (existing authenticated data request can establish availability).
- Primary `Start recording`; status changes only after the mic operation succeeds. Permission denial stays here with a persistent explanation and `Try again`; add `Open app settings` only if the platform adapter exists and is tested.
- Start/check requests serialized to prevent double capture. Back with changed context warns about discarding context; context remains local to this consultation, not carried into the next patient.

### C. Patient context

Full-screen, scrollable, keyboard-safe form. Title + explanatory line `Optional information to help generate this consultation's documents.`

Fields: Patient name (optional); Medications (one per line); Conditions (one per line); Allergies (one per line); Prior SOAP notes / history (multiline). Preserve the existing five wire keys verbatim. Label above the field and helper text below, never hints alone. Blank allergies means **not provided**, never `No known allergies`. No examples based on a real patient.

Primary `Use context` returns to preparation; not `Saved to server`. Back/cancel preserves prior committed context and confirms discard if the new form is dirty. Completely clearing fields returns an empty context deliberately; the preparation row uses `isEmpty`.

### D. Active recording

Focused view with contextual patient label only if provided, status `Recording`, clear elapsed time, small mic icon, and no irrelevant settings. Timer comes from measured buffered duration where possible, not an independent display clock; freeze appropriately after stop. No pretend waveform.

Primary `Stop & generate SOAP` (normal brand action). Secondary text `Discard recording` (danger foreground). Stop/cancel are single-flight. Hardware back, predictive back, app-bar back and route exit use the same confirmation: `Discard this recording? Audio recorded on this phone will be lost.` Actions `Keep recording` / `Discard recording`.

Keep the 30-minute warning and 60-minute auto-stop policy. Suggested copy: `30 minutes recorded. Recording stops automatically at 60 minutes.` On limit reached: `Recording stopped at the 60-minute limit`; carry that notice through processing, rather than hiding it when `_recording` becomes false. Auto-stop uses the same one-shot Stop path. Privacy shielding on background remains unchanged; background capture reliability is not promised by this design.

### E. Processing, completion and failure

Step list driven by real events: `Preparing consultation` → `Uploading audio` → `Waiting for office server` → `Transcribing` → `Generating SOAP`. Mark only completed stages as complete; don't invent percentages, ETA, or a successful upload before its acknowledgement. Expose one active stage and readable helper copy.

During upload: no route exit that destroys the only client audio silently. For this release keep the focused route and explain why; do not add a background job promise. After acknowledged generation submission, server work may continue if the screen closes; say so only once the adapter records that acknowledgement. Closing the UI is not cancelling a server job.

Completion: `SOAP note ready` + `Review the note before sharing or using it clinically.` Primary `Open SOAP note`, secondary `View consultation`. Open via real id with authoritative fetch; details navigation may refresh/pull that id, but must not create a fake record model.

Failure is stage-aware: `Could not upload audio`, `Generation failed`, or `Lost connection to generation progress`. Do not reduce all to `Failed` and hide context. For known job/id, `Check status` uses existing jobStatus; reattach to live jobs instead of starting duplicate generation. Retry upload only if the adapter proves audio is retained and retry is safe; otherwise omit that action and explicitly state recovery is unavailable. Primary may be `View consultation` when the record exists or `Back to consultations`; never imply capture is recoverable simply because an id was allocated.

### F. Consultation detail

Header: patient/fallback title, created date/time, duration. Body: `Documents` group, SOAP first followed by Referral, Letter, Synopsis, Peer discussion (wire order can remain existing enum order).

Each row shows name + state (`Available`, `Not generated`, `Generating…`, `Cached copy`, `Not cached`). Whole row opens available content; absent content exposes a labelled `Generate` action. No five giant cards or three tiny icons packed into each row. Footer/no main button when there is no primary action. Export lives with the document, not on every overview row.

Per-type async operation state; prevent double requests and do not let a single `_generating` variable make another job appear idle. If only one generation job per recording is supported, disable other Generate actions with a short reason while it runs. On completion refetch existence/content. Returning from a failed or empty editor is not proof that a document exists.

Offline: query cached documents independent of `SyncRecording.hasDoc`. Cached rows open read-only; uncached rows explain `Open this document while connected to make a cached copy available`. No network Generate/Export buttons presented as usable while offline.

### G. Document reader and editor — the central clinical surface

Reader header: Back, document title. Subheader: patient/fallback consultation context. State line: `From office server` or `Cached copy · offline`; show server updated time if actually supplied, cache saved time if that is what is known. Do not relabel cache insertion time as server updated time.

Body: selectable, readable document text, 16sp/24. Treat unusual Markdown/plain text as text unless a safe fidelity-preserving renderer is separately chosen. No auto-copy or HTML injection. Constant unobtrusive helper `Review generated content before clinical use.` This is not a persisted review status.

Reader actions: `Edit` (primary), `Export & share` (secondary), explicit `Copy text` in overflow. All actions have text/semantics. Native text-selection Copy remains intentional, not automatic.

Edit mode: focus on text, visible `Unsaved changes` / `Saving…` / `Saved to office server`. Main action `Save changes`; no autosave. Save failure is an inline error over the *still-visible editable buffer*, with `Retry save`; it must not call reload. A late fetch must never overwrite a dirty buffer. Back when dirty: `Save & leave`, `Discard changes`, `Keep editing`; leave after Save only on confirmed success. Do not call a cache write success a server save success.

Offline entry: read-only, banner `Cached copy · reconnect to edit or export`. If connection drops *during an existing edit*, preserve the in-memory dirty buffer and show `Not saved · reconnect to save`; don't lock out copying one's edits, silently discard, or assert queued persistence. Dirty-exit confirmation remains mandatory. Copy is still explicit and supported for cached text.

Export from dirty edit mode requires `Save & export` or `Keep editing`; do not export the server's older text while implying it contains local edits.

### H. Generate Peer discussion

Keyboard-safe full-screen form or scrollable sheet with Consultant name, Specialty, Reason for discussion. Mark all required; validate inline on Generate and move focus to first invalid field. Return focus after cancel. Prefer 3–5 visible lines for reason; no silent no-op. Other document types retain their current generation defaults—no invented templates/urgency menus in this redesign.

### I. Export & share

Safe-area bottom sheet: document title/context, `PDF` / `Word (.docx)` single selection, one `Continue to share` action. Helper: `Choose a trusted destination. Shared files may be stored outside FerriScribe.` Download progress uses `Preparing PDF…` or `Preparing Word document…`; no claimed share completion until a platform result supports it, and never `Delivered`.

Cancel before download returns unchanged. Share-sheet dismiss returns to document, preserves content/scroll, and retains current private-temp cleanup behavior. Local cleanup does not revoke copies in receiving applications, and is not guaranteed physical erasure on flash. No analytics and no new storage location.

### J. Settings

Header `Settings`; sections `Appearance`, `Office connection`, `Privacy`.

Appearance uses full-height (>=48dp) System / Light / Dark radio rows, System helper `Match device appearance`. Current selected option exposed semantically; immediate change with the preference in shared_preferences only. Preserve during navigation and restart; System reacts live to OS brightness. Handle failed preference writes non-fatally and don't let delayed initial load override a just-made user choice.

Connection displays paired host and phone/device label as separate concepts (config.label is the **phone label**, not server name). `Check connection` replaces developer wording `Probe server`. States: Not checked / Checking / Reachable / Unreachable / Pairing needs attention. A public `/info` response establishes reachability, not authenticated data readiness; do not show a permanent `Ready to record` based on it. Tailscale idle alone is not a reachability failure. Host/ports/timestamps under accessible Connection details disclosure.

Unpair is separate at the bottom, not visually equal to routine Check. Confirmation preserves existing warning: `If the office server cannot be reached, access may remain active there until revoked from the desktop app.` Distinguish successful revocation from local-only removal in outcome text. Do not claim cached PHI was deleted unless separately implemented and verified; no cache-wipe behavior is introduced by this design.

Privacy copy is factual and limited: app-switcher content hidden; documents cached in encrypted app storage; clipboard only through explicit Copy; exports can leave the app. Do not label a lock icon as a blanket HIPAA/privacy certification.

### K. Connect to office (onboarding)

Short title `Connect to your office`; steps: Open FerriScribe on the desktop, display its pairing QR, enable Tailscale on this phone. Primary `Scan pairing QR`; request camera permission on action, not before explaining why. Secondary `Enter pairing link` for manual route.

Scanner is a real camera viewport with contrast-safe guidance outside the image; the design prototype deliberately contains no functional QR or real secret. On capture, stop scanning; confirm host and device label, collapse ports under Details. Don't prominently repeat the secret pairing code/URL in summaries or logs. Primary `Pair this phone`; busy state disables repeated enroll. Secondary `Scan again`.

Invalid QR/link gives a visible reason; wrong scheme must not silently do nothing. Expired/used code prompts obtaining a new desktop QR. Camera denied has explanation + manual link alternative. Manual text remains local; never automatically read/write clipboard. On success return to Consultations; pairing is the only prerequisite route, not a promotional onboarding carousel.

## 6. Required presentation/data adapters (no new server API)

@turing owns these contracts; @scribe-mobile consumes them. Prefer typed view state over inferring from formatted strings.

1. **Connection state** with checking, reachability, authenticated-read readiness, auth failure, error, and last-check time; preserve how each fact was obtained.
2. **Document load result** includes content, source (server/cache), known timestamps and cached availability. CachedDocuments.updatedAt is local cache time. Keep PHI in the existing encrypted store; do not introduce shared_preferences for content.
3. **Per-recording cached availability**, queried from CachedDocuments even when cached SyncRecording has empty fields. No schema migration needed to expose existing rows.
4. **Ingest presentation state** includes last acknowledged stage, real recording id, whether upload was acknowledged, whether generation was accepted and whether audio is still recoverable. Existing events alone do not prove every fact; implement adapters without inventing success. Use existing job status endpoint for reconciliation.
5. **Unsaved edits** stay in the current editor's memory, separate from fetched/cache content; no unrequested offline-write queue. Track server-write acknowledgement separately from cache write so cache failure doesn't say the server save failed.
6. **Navigation targets** take real recording id for immediate SOAP open; list/detail fetch may resolve recording metadata. Preserve successful share cleanup and map share outcome honestly.

If any proposed adapter unexpectedly requires server contract changes, stop and flag it to @ferriscribe; do not invent endpoints or silently broaden backend scope. Performance/capture hardening beyond these seams remains separately owned.

## 7. File ownership and execution sequence

**No app-code changes by @ui-consultant.** This directory contains design artifacts only.

| Owner | Files / slice | Deliverable |
|---|---|---|
| @scribe-mobile | new `lib/ui/theme/app_theme.dart`, `lib/ui/theme/theme_controller.dart`, reusable status/empty/loading components; `lib/app.dart` composition; `features/home/home_screen.dart`; new `features/settings/settings_screen.dart` | Tokens, settings, consultation workspace, theme controls, responsive shell. Move theme definitions out of app.dart so Home no longer imports the app root. |
| @scribe-mobile | `features/pairing/pairing_screen.dart`, `features/recording/record_screen.dart`, `patient_context_form.dart` | Onboarding, preparation, active recording, processing/result screens and exit guards. |
| @scribe-mobile | `features/documents/recordings_screen.dart`, `recording_detail_screen.dart`, `document_editor_screen.dart`; export format sheet UI | Reuse list presenter from Home, document rows, reader/edit split, safe export flow. |
| @turing | `features/documents/document_service.dart`, `storage/offline_cache_repository.dart`, `features/recording/recording_ingest_service.dart`, necessary models in `core/api/*`, `features/export/export_service.dart` outcome mapping | Typed adapters above and tests; no endpoint renames. Coordinate any RecordScreen controller seam with scribe before editing that screen. |
| @codie | new `test/ui/*`, `test/theme_test.dart`, `test/offline_cache_test.dart`, service tests; focused remediation agreed with owners | Real widget interaction tests, cache-route regression, dirty-save/exit tests, state/contrast/semantics checks, independent review. No parallel edits to scribe's screen files without explicit handoff. |
| @ui-consultant | `docs/design/*` | Design, state/copy spec, mockups and visual review against implemented screenshots. |
| @ferriscribe | integration/build/deployment coordination | Baseline commit, reviewed integration SHA, verified APK artifact and on-device gates. |

Sequence: approve design direction → turing publishes adapter contracts + scribe lands theme/components → home/settings + pairing/recording → documents/editor/export → codie integration review + ui-consultant visual review → fresh APK tied to exact reviewed commit → real-device tests. Use isolated branches/worktrees per slice; no simultaneous shared-tree source rewrites. Codie writes tests in parallel once the contracts are agreed, not after an APK is declared done.

**No changes needed:** server export/generation wire vocabulary, pairing protocol, encryption/key-store implementation, `security/snapshot_mask.dart`, backup exclusions, audio-at-rest policy. Privacy shield remains at the app root and independent of theme. Theme refactoring must not remount/dispose an active recording/editor route or recreate security controllers unnecessarily.

## 8. Acceptance matrix

- All screens in light and dark; System switch responds live; explicit override survives restart. Test actual FerriScribeApp + UI selection, not just a duplicated MaterialApp harness. Check controller startup race/failure.
- >=48dp touch targets, TalkBack/VoiceOver labelled controls, selection/expanded semantics, keyboard traversal, focus restoration, 200% text and narrow/landscape layout. No bottom action hidden by system navigation/keyboard.
- Contrast: normal text >=4.5:1, large text >=3:1, essential UI/focus >=3:1 against adjacent surface. Use luminance **ratio**, not absolute luminance difference. Disabled controls remain identifiable and communicate why.
- New consultation → optional context → record → stop → observed server stages → open actual SOAP. No copy on any automatic transition. Double taps and exit gestures safe; 30/60-minute notices survive transitions. Real mic/background behavior remains a device test.
- Load doc online → cache → lose server → enter via consultation list → open the correct cached type, labelled read-only. Missing cached doc shows explanation rather than a fake Generate path. Distinguish auth failure from offline fallback.
- Edit → fail save → buffer visible/intact → Retry save sends edited text → correct saved status. Back/gesture with dirty text offers three-way decision. Export from dirty state never exports stale server text without resolving edits.
- All five doc types retain exact wire identifiers: `soap`, `referral`, `letter`, `synopsis`, `peer_discussion`. Peer form invalid submission yields inline errors; job failures clear busy state and remain visible.
- Explicit Copy only; export PDF/DOCX to actual system share sheet with private temp cleanup; cancel is not reported as delivered. Existing app-switcher shield tested across settings/sheets/reader/edit in both themes on device.
- `flutter analyze`, complete `flutter test`, and formatting gate clean; fresh APK built from reviewed SHA. Source approval, artifact creation, transfer, install, and real-device behavior are separate evidence claims.

## 9. Review artifacts and limits

`prototype.html` is a self-contained clickable **design simulation**, not Flutter and not connected to a server, mic, camera, clipboard or share service. All displayed names/clinical text are explicitly synthetic. Only theme preference persists in the mock; clinical edit text stays in memory. Browser renders illustrate layout, not proof that Flutter matches it.

Open `prototype.html?board=1&theme=light` or `?board=1&theme=dark` for the three-screen overview. Use the screen/state picker for onboarding, forms, processing, errors, empty/cache states and settings. The written state contracts above are normative when a simulation shortcut differs.

User approval requested: the **consultation-workspace direction** and proposed screen organization. App implementation belongs to the named teammates after approval; this is not authorization to ship unverified UX or relax PHI gates.
