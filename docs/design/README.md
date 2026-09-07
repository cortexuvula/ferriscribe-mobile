# FerriScribe Mobile redesign — review package

**Proposed, not implemented. User approval of the direction is pending.**

## Open first

- `prototype.html` — interactive local design simulation. Open directly in a browser. The Overview button shows the landing screen, recording and document reading side by side. Use Theme and Screen controls to inspect other views.
- `overview-light.png` and `overview-dark.png` — screenshots of the proposed design, not the Flutter app.
- `MOBILE_REDESIGN.md` — source-grounded screen/state specification, API constraints, exact file ownership and acceptance gates.
- `DESIGN.md` and `tokens.json` — paired light/dark semantic design tokens.

All names, dates and clinical text are synthetic. No real pairing secrets, patient data, server connections, mic/camera access, clipboard writes, or OS sharing are present. Theme preference is the only locally persisted prototype value.

## What was verified

Using a separate headless Chrome browser and Playwright against the local HTML file:

- 15 screen renderers × 3 widths (320, 390, 1320) × 2 themes = 90 layout cases. No horizontal viewport/content overflow, footer overlap, or app buttons shorter than 48px within measurement tolerance.
- Simulated record → stop → processing → SOAP → edit → save → export flow.
- Discard-recording confirmation; dirty-edit exit confirmation; failed save retains the editor buffer.
- Peer-discussion required-field errors; local search/no matches; offline read-only presentation and disabled Start.
- Theme selection restored after navigation/reload; System responds to changing emulated platform brightness. The test waits for the browser change event rather than checking before it fires.
- Document scroll reaches the final text; footer sits outside the scroll area rather than covering content.
- No JavaScript page errors or external network requests observed.
- Screenshots inspected in light/dark and a larger-text reader view. The larger-text prototype control is a visual stress sample, **not** a complete 200% native text-scaling test.
- 30 explicit foreground/background token-pair checks passed their defined contrast thresholds; values are in `contrast-checks.json`. This tests the chosen pairs, not every possible widget combination.
- `@google/design.md lint DESIGN.md`: zero errors; 22 orphaned-token warnings because several surface/border/status tokens are documented for Flutter but not referenced in the small set of sample component declarations. No WCAG finding was reported. Not described as warning-free.

Reproduction: `verify_prototype.py` requires Python Playwright and the macOS Chrome binary at the documented path. This is a design test helper, not a new application dependency. Detailed results: `prototype-verification.json`.

## Visual self-review

Anti-template audit: 0/10 applicable tells. The composition is an action workspace, not a hero or feature-tile grid. Platform typography is selected deliberately for native accessibility/offline operation. Centered timer is limited to active recording, where focused state matters. No decorative gradient, invented metrics, generic violet accent, blur, or fake audio visualization.

Vision review suggested possible low-contrast secondary text; the explicit sRGB ratio checks establish 5.69:1 light metadata/canvas and 9.60:1 dark metadata/canvas. Suggested document clipping is ordinary below-fold content; DOM geometry and scroll test show no footer overlap. Physical glare/readability remains an on-device check.

## Deliberate simulation shortcuts

- Recording timer and progress are synthetic fixed states. Progress completion is explicitly a simulation button, not a fake server response.
- No real network/revocation/cache/clipboard/share operation occurs.
- Context form demonstrates layout but does not implement the complete dirty-context/data-retention contract; the written spec governs implementation.
- Known-state pickers can jump between views; they are review controls, not app navigation.
- Clinical text is plain text. Production must preserve text and exact document types without automatic reinterpretation.
- Camera viewport contains a generic scanner icon, not a working QR. No production imagery is missing: this app does not require decorative artwork.

## Not yet verified

Flutter implementation, native TalkBack/VoiceOver semantics, 200% native text scaling, real microphone/keyboard/system share-sheet behavior, encrypted-cache routes, app-switcher shielding, APK build/install, and actual server-generated SOAP. Those belong to the implementation and device acceptance matrix in the specification.

## Ownership

- @ui-consultant: design artifacts and visual review only.
- @scribe-mobile: app theme, components, screens and navigation.
- @turing: typed state/data adapters and their tests, preserving server contracts.
- @codie: regression/widget/accessibility tests, agreed remediation and independent review.
- @ferriscribe: coordination and verified build/deploy handoff.

Baseline reviewed: `7a5f2ffb178c7658375067f22d3ddbcace81b77f`. The design work wrote only `docs/design/`; it did not modify application source or the existing tracker. Files are deliberately uncommitted proposals until the user approves the direction.
