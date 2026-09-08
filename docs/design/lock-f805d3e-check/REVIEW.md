# Targeted lock interaction check — f805d3e

**Result: one production-app regression passes; one fails. Revisit lifecycle sign-off before merging.**

Used a separate git-archive copy of `f805d3e`, path in baseline.json. No production code or teammate branch edited. `review_lock_regression_test.dart` is a synthetic test using the actual FerriScribeApp, fake injectable auth, in-memory DB/keys and actual binding lifecycle callbacks. It does not require biometric hardware or record clinical audio.

Run (copy the review test into the isolated checkout's test/):
```
flutter test test/review_lock_regression_test.dart --reporter expanded
```
Actual output: **1 passed, 1 failed; exit 1**. Full output: run.log.

## Pass: real Navigator route state survives explicit re-lock

Unlocked actual FerriScribeApp, pushed a synthetic stateful text editor through its actual Navigator, captured its State reference before lock, changed its TextEditingController, called the shared lock controller, then unlocked. The same captured State/controller/text survived and hidden content was skipped by default finders while locked. The production Navigator's retained placement succeeds here even though the overlay's conditional structure is concerning in isolation.

This test checks controller retention, not physical audio continuation or all accessibility interactions. Do not claim a live mic stream remains healthy merely from Offstage. Also: Offstage still lays out its child; the code/review comments claiming no layout are inaccurate.

## Fail: real background/resume can skip the required re-lock after expiry

Sequence driven through the actual app-shell lifecycle handler:
1. Cold-launch authentication remains pending (fake future).
2. Dispatch inactive then resumed while authenticating, establishing `_promptSettlingUntil`.
3. Complete authentication successfully: unlocked with exactly one prompt.
4. Dispatch a genuine inactive + paused immediately after success.
5. Wait 2.2 real seconds without lifecycle events (past the two-second settle deadline).
6. Dispatch resumed.
7. Expected locked=true and a new auth attempt; actual locked=false.

The code computes `promptActive = authenticating || _promptSettlingUntil != null` **before** clearing an expired `_promptSettlingUntil`. On the first resume after expiry, the cached local promptActive remains true and blocks re-lock. `_pausedAt` is then cleared, losing the real background evidence. This is not merely an intentional grace period for a rapid round trip inside two seconds; the reproduced resume occurs after expiry, and the same ordering can affect a longer absence if no intermediate lifecycle event clears the deadline.

@scribe-mobile: evaluate expiration before computing suppression, and preserve real background evidence separately from auth-prompt lifecycle noise. Don't suppress a real required re-lock merely because a deadline once existed. Add cancellation/exception/real-background test sequences, not just cold-start unlock.

@codie: the existing test named prompt inactive→resumed does not dispatch lifecycle events at all; it calls AppLockController.tryUnlock then pumps time. The overlay test's `same(draftKey.currentState)` compares the current value to itself, not a saved pre-transition reference. The new regression test avoids both pitfalls. Please rerun it and re-review the lifecycle fix.

For the device capture gate, timer progress alone is insufficient: use an approved synthetic spoken sample across background/unlock and verify post-resume audio/transcription is present. Keep clinical data and unfiltered device logs out of hosted review tools.
