# Mobile icon visual review — 2af6534

**Verdict: brand recognizable; refinement required before icon design sign-off. No store approval claimed.**

Inspected desktop source, generated mobile square, actual Android drawable/legacy resources, adaptive XML and iOS catalog. Mask comparison is `icon-mask-board.png`: synthetic raster mask simulations, not launcher screenshots. No production asset or app source modified by ui-consultant.

## Verified

- Source and mobile assets contain the same white outlined medical cross, cyan ECG trace and stylized stethoscope/chestpiece. Not the Flutter logo.
- iOS has 21 PNG files, all RGB without alpha. All 25 catalog references resolve to files of the correct size. The shared icon is 1024×1024 RGB. This satisfies the inspected raster sizing/opacity checks; not proof of App Store acceptance.
- Android generated foreground/background assets and v26 adaptive definition exist. Legacy and round PNGs exist. XML adds a 16% inset on top of transparent foreground padding.
- After cleaning my review-only harness lint, full `flutter analyze` reports no issues and the existing 141 tests pass. `checks.log` contains output. No app-code changes were needed for that cleanup.
- Git diff from 043b4ce to 2af6534 has no changes to the theme, consultations screen or editor: the earlier rendering blockers remain open.

## Icon findings and design decision

1. **Remove the surviving white perimeter strokes.** `app_icon.png` is not fully cleaned of its old squircle outline: thin white segments survive near top/bottom/left/right. Pixel detection finds white pixels from coordinate 17 to 1007 while the central white emblem is confined to x317–707, y228–880. Source vision confirms the outer line is white, not a navy ring. The background is cerulean `#1A73A8`; calling it navy is misleading. Keep the emblem itself, remove the old container outline and use one continuous full-bleed blue surface. Painting only pixels outside an approximate superellipse leaves these strokes behind.

2. **Adaptive mark is shrunk twice.** The source foreground is already padded (alpha bbox 162,162–862,862 on 1024). The generated foreground retains that padding, and XML then applies another 16% inset. Measuring the white medical emblem in the actual 432px drawable and applying XML scaling yields ~36.21dp height on the 108dp layer canvas. It appears visibly smaller than the iOS/legacy version at 48/64px and shows an inset-square patch in the background.

   Decision: transparent foreground should contain the medical emblem, not a blue badge; keep blue exclusively in the opaque background. Size the emblem once, after considering all resource/XML transforms. Target the tall emblem's bounding-box height around 54–60dp on the 108dp adaptive canvas, centered optically and contained within the central 66dp safe region. Verify circle, rounded-square and squircle mask previews at actual small sizes. Do not blindly apply a percentage to an already-padded image. iOS can retain roughly its current central-emblem scale once the stray perimeter is removed; the measured result is not simply a proposed 4% bleed.

3. **The adaptive round resource is incomplete.** Manifest roundIcon references `ic_launcher_round`, but only the legacy circular PNG is supplied under that name; no adaptive v26 round XML was found in the inspected resource directory. Prefer making modern icon and roundIcon resolve to the same properly layered adaptive resource (with legacy fallbacks) so launchers don't receive inconsistent scale/masking paths. This is a consistency recommendation, not a claim that roundIcon is mandatory.

4. **Reproduction pipeline is not self-contained.** Current committed pubspec.yaml contains neither flutter_launcher_icons dev dependency nor its generator configuration. `tool/make_icon.py` writes only app_icon.png, refers to an absolute path in another repo, and does not recreate foreground/background or round resources. Preserve a source asset in this repo or explicitly document its required provenance and add a checked-in deterministic config/script for every generated output. Do not regenerate on the shared tree until the implementer owns that change.

5. **Themed appearance:** no monochrome layer is present. Provide a clean single-color emblem if deliberate Android themed-icon support is wanted. This is a polish recommendation; current Android documentation says newer Android can auto-theme absent layers, while earlier supported themed launchers require a supplied monochrome layer. Do not claim no monochrome universally causes rejection.

## Current platform guidance

Checked official documents:
- Android: https://developer.android.com/develop/ui/compose/system/icon_design_adaptive — 108dp layers, central 66dp safe region, no pre-applied outer masks/shadows, foreground/background and optional monochrome; roundIcon is optional.
- Apple: https://developer.apple.com/design/human-interface-guidelines/app-icons — square 1024px assets/layers, OS-applied masks, simple centered content, full-bleed opaque background. Flattened icons are still supported; layered foregrounds may intentionally have transparency. Our RGB/no-alpha check concerns the flattened App Store icon, not a universal prohibition on alpha in layered artwork.

No official source checked here establishes an automatic rejection solely because an icon is the Flutter placeholder. Replacing it is necessary product/brand completeness, but 'store-approved' or guaranteed rejection/acceptance requires an actual store review/validation result.

## Handoff

@scribe-mobile: clean perimeter, remove double padding/inset, make adaptive layer separation and round path consistent, check in reproduction config.
@ui-consultant: re-review actual generated resources with 48/64px mask board once supplied.
@codie: verify deterministic generation/package references and no regression to app gates.

The larger redesign remains **changes required**, per `../flutter-043b4ce/REVIEW.md`; icon replacement does not resolve online reader/offline-home width exceptions or large-text/empty-state findings.
