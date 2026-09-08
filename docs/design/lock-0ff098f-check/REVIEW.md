# App-lock regression verification — 0ff098f

## Verdict

PASS for the previously blocked lifecycle regressions. This is software regression clearance, not a claim of native biometric/device-PIN behavior, complete security certification, or deployment.

Reviewed commit: `0ff098f8bc38f2650efbc44a9301d88fbdb651fd`.
Isolated git-archive checkout and SHA recorded in `baseline.json`; no production files or refs changed. Shared `lib`/`test` were also unchanged against this commit at final check.

## Independently executed

- `flutter analyze`: clean.
- Full committed suite: 159 tests passed.
- `dart format --output=none --set-exit-if-changed lib test`: 76 files, zero changed.
- Two review-only test files: six tests passed using the actual FerriScribeApp, synthetic in-memory services and real binding lifecycle dispatch.
- Source check: no DateTime, _settleWindow or _promptSettlingUntil in app.dart.

## Review-only test coverage

1. Original regression: real background followed by resume after the former settle deadline now re-locks.
2. Pushed draft: same pre-lock State and exact unsaved text retained through lock/unlock.
3. Resume before auth completion, immediately followed by genuine background/resume: re-locks. Deliberately no extra straggler after completion.
4. Completion before prompt resume, then immediate genuine background/resume: re-locks.
5. Genuine background/resume before any expected prompt resume is consumed: evidence wins and re-locks.
6. Prompt cancelled across background/resume: remains locked with one prompt.

The new order tests hold the second authentication Future unresolved and pump frames: the app stays locked, the neutral lock screen is visible and the pairing action is hidden. They also exercise cancellation, manual Unlock retry and successful restoration. This proves more than a synchronous locked assertion before an immediately successful fake prompt.

## Harness correction

Initial cancellation test timed out in pumpAndSettle because the never-unlocked root retains an offstage loading spinner. Replaced that wait with bounded frames; no production change. Initial failure and subsequent passing output retained separately.

## Evidence

- repository-gates.log
- independent-regressions-final.log (six passed)
- review_lock_regression_test.dart (original reproduction and retained-draft check)
- review_prompt_order_test.dart (four additional cases)

To reproduce: copy the two review-only tests into test/ in an isolated checkout at this SHA, run flutter pub get, then flutter test test/review_lock_regression_test.dart test/review_prompt_order_test.dart --reporter expanded.

## Limits and follow-up

Native biometric and device-PIN fallback, actual OS lifecycle ordering, privacy-mask behavior on hardware, and native recording continuity remain device checks. Use synthetic speech only. No APK build, installation, transfer or merge performed by this review. Auth exceptions, disposal with an auth Future pending, and all accessibility interaction channels were not re-tested in this bounded regression pass.

The duplicated _promptResumeExpected assignment is harmless. Source comments asserting that every auth-time pause cancels the prompt should be corrected or substantiated: LocalAuthGateImpl explicitly sets persistAcrossBackgrounding: true. The executed tests do not establish such a native cancellation guarantee.
