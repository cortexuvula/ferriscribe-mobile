import 'package:flutter/foundation.dart';
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
class LifecycleMaskController with WidgetsBindingObserver {
  LifecycleMaskController({WidgetsBinding? binding})
    : _binding = binding ?? WidgetsBinding.instance {
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;

  /// Whether the privacy mask is currently active.
  final ValueNotifier<bool> masked = ValueNotifier<bool>(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    masked.value = shouldMask(state);
  }

  void dispose() {
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
