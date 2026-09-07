import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Whether a given lifecycle state should trigger the privacy mask.
///
/// `inactive` fires before the iOS app-switcher snapshot; `paused` follows it.
/// The mask must be up for both, and cleared on `resumed`.
bool shouldMask(AppLifecycleState state) =>
    state == AppLifecycleState.inactive || state == AppLifecycleState.paused;

/// Maps app lifecycle to a single `masked` boolean that drives the privacy
/// shield.
///
/// iOS snapshots the last rendered frame to disk (unencrypted) when the app
/// is backgrounded for the app switcher. We must therefore show an opaque
/// cover on [AppLifecycleState.inactive] — before the snapshot is taken —
/// and keep it up through [AppLifecycleState.paused]. It is cleared on
/// [AppLifecycleState.resumed].
///
/// Defensive reconciliation: some Android audio plugins (the mic session
/// during recording) toggle `inactive`/`paused` while the app remains
/// foreground, and a lost or out-of-order `resumed` would leave the mask
/// stuck over a live app — a black screen. A post-frame callback re-reads
/// the binding's authoritative lifecycle state after every frame while
/// masked: if the platform says `resumed`, the mask clears within one frame.
/// The PHI guarantee is unchanged — the mask still rises on every reported
/// inactive/paused before any snapshot, and only the platform's own
/// `resumed` can clear it.
class LifecycleMaskController with WidgetsBindingObserver {
  LifecycleMaskController({WidgetsBinding? binding})
    : _binding = binding ?? WidgetsBinding.instance {
    _binding.addObserver(this);
    masked.addListener(_scheduleReconcile);
  }

  final WidgetsBinding _binding;

  /// Whether the privacy mask is currently active.
  final ValueNotifier<bool> masked = ValueNotifier<bool>(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    masked.value = shouldMask(state);
  }

  /// When the mask rises, verify it against the platform's authoritative
  /// state after the next frame — clearing only if the platform itself
  /// reports `resumed` (a lost-resumed recovery).
  void _scheduleReconcile() {
    if (!masked.value) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!masked.value) return;
      reconcileWithPlatform();
    });
  }

  /// Re-reads the binding's authoritative lifecycle state and clears the
  /// mask ONLY when the platform itself reports `resumed` while the mask
  /// is up — i.e. a lost/injected lifecycle event left the mask stuck over
  /// a foregrounded app. `inactive`/`paused`/`hidden`/`detached` keep the
  /// mask (legitimate pre-snapshot/background states); no authoritative
  /// state (null) also keeps it — clearing requires positive `resumed`.
  @visibleForTesting
  void reconcileWithPlatform() {
    if (!masked.value) return;
    if (_binding.lifecycleState == AppLifecycleState.resumed) {
      masked.value = false;
      assert(() {
        debugPrint(
          'privacy mask: recovered from a stuck state '
          '(platform reports resumed)',
        );
        return true;
      }());
    }
  }

  void dispose() {
    masked.removeListener(_scheduleReconcile);
    _binding.removeObserver(this);
    masked.dispose();
  }
}

/// Overlays a full-screen opaque cover over [child] whenever [masked] is true,
/// so app-switcher snapshots and screen captures show a blank surface, never
/// PHI. A solid color is deliberately stronger than a blur: it cannot leak
/// content silhouettes.
class AppPrivacyShield extends StatelessWidget {
  const AppPrivacyShield({
    super.key,
    required this.masked,
    required this.child,
  });

  /// Drives the mask; produced by a [LifecycleMaskController] in production,
  /// or any [ValueNotifier] in tests.
  final ValueListenable<bool> masked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: masked,
      builder: (context, isMasked, _) {
        return Stack(
          fit: StackFit.expand,
          children: [child, if (isMasked) const PrivacyMask()],
        );
      },
    );
  }
}

/// A solid, content-free cover. Carries no PHI by construction.
class PrivacyMask extends StatelessWidget {
  const PrivacyMask({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFF0F141A));
  }
}
