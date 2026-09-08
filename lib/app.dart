import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
import 'features/home/consultations_screen.dart';
import 'features/pairing/pairing_screen.dart';
import 'features/lock/app_lock_overlay.dart';
import 'features/lock/app_lock_screen.dart';
import 'features/settings/settings_screen.dart' show ThemeControllerScope;
import 'security/app_lock.dart';
import 'security/snapshot_mask.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_controller.dart';

/// Root widget. Wraps the navigator in the privacy shield so the app-switcher
/// mask covers every route, and owns the app-wide [ThemeController].
class FerriScribeApp extends StatefulWidget {
  const FerriScribeApp({super.key, required this.services});

  final AppServices services;

  @override
  State<FerriScribeApp> createState() => _FerriScribeAppState();
}

class _FerriScribeAppState extends State<FerriScribeApp> {
  final ThemeController _themeController = ThemeController();

  /// App lock: gates the WHOLE app above the root — no data loads (no
  /// content-sync, no launch check) until unlocked. The lock screen
  /// replaces the app body, so nothing renders underneath.
  late final AppLockController _lock;
  bool _canAuthResolved = false;
  bool _canAuth = false;

  @override
  void initState() {
    super.initState();
    _themeController.load(); // race-guarded: user choice wins over late load
    _lock = AppLockController(relockOnResume: true);
    // Expose the lock so _RootScreen defers its data load until unlock.
    widget.services.appLock = _lock;
    _checkCapability();
  }

  Future<void> _checkCapability() async {
    final ok = await widget.services.appLockAuth.canAuthenticate();
    if (!mounted) return;
    setState(() {
      _canAuth = ok;
      _canAuthResolved = true;
    });
  }

  @override
  void dispose() {
    _lock.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      notifier: _themeController,
      child: ListenableBuilder(
        listenable: Listenable.merge([_themeController, _lock]),
        builder: (context, _) => MaterialApp(
          title: 'FerriScribe',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: _themeController.themeMode,
          builder: (context, child) => _AppShell(
            lock: _lock,
            auth: widget.services.appLockAuth,
            canAuthenticate: _canAuthResolved ? _canAuth : null,
            child: child!,
          ),
          home: _RootScreen(services: widget.services),
        ),
      ),
    );
  }
}

/// Hosts the [LifecycleMaskController] and wraps every route in the shield.
/// Independent of theme: the mask is opaque and token-free by design.
class _AppShell extends StatefulWidget {
  @override
  State<_AppShell> createState() => _AppShellState();

  const _AppShell({
    required this.child,
    required this.lock,
    required this.auth,
    required this.canAuthenticate,
  });

  final Widget child;
  final AppLockController lock;
  final AppLockAuth auth;

  /// Null while capability is being checked; false = no screen lock set
  /// up (clear setup state, never a silent skip).
  final bool? canAuthenticate;
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  final LifecycleMaskController _mask = LifecycleMaskController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold launch: prompt as soon as the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.lock.locked) _promptAndExpectResume();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mask.dispose();
    super.dispose();
  }

  /// NO-CLOCK prompt-noise suppression (codie design + ui-consultant
  /// refinement). The system auth dialog produces exactly one `resumed`
  /// that is NOT a real background round-trip. Instead of a time window
  /// (which a genuine fast handoff inside the window would defeat — a
  /// PHI exposure), we track events:
  ///
  /// - [_promptResumeExpected] is set when WE show a prompt (every
  ///   tryUnlock call site) and cleared when that resume is observed.
  /// - A `resumed` while `authenticating` is the prompt's own.
  /// - A later-arriving prompt resume (completion-before-resume order)
  ///   is swallowed ONCE — but ONLY when no genuine-background evidence
  ///   was recorded after unlock: EVIDENCE WINS. A real paused->resumed
  ///   round-trip always re-locks, however fast.
  bool _promptResumeExpected = false;
  bool _wasBackgrounded = false;

  /// Shows the auth prompt and marks that exactly ONE future `resumed`
  /// belongs to the prompt itself (the system dialog's own event), so
  /// the resume right after a successful unlock is not treated as a
  /// genuine background round-trip.
  void _promptAndExpectResume() {
    _promptResumeExpected = true;
    widget.lock.tryUnlock(widget.auth);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _mask.didChangeAppLifecycleState(state);

    // Genuine-backgrounding evidence: ONLY paused/hidden/detached count
    // — `inactive` alone fires for dialogs, the notification shade, and
    // split-screen drags, none of which hand the phone to someone else.
    // Leaving the app ALWAYS reaches paused/hidden on both platforms.
    // While a prompt is up, a paused is the prompt's own noise (the
    // dialog covers the app); it also cancels the prompt, so no
    // evidence is needed — the lock is engaged.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!widget.lock.authenticating) {
        _wasBackgrounded = true;
      }
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    // The prompt's own resume, observed while it is still up.
    if (widget.lock.authenticating) {
      _promptResumeExpected = false;
      _wasBackgrounded = false;
      return;
    }

    final wasBackgrounded = _wasBackgrounded;
    _wasBackgrounded = false;

    if (wasBackgrounded) {
      // Genuine background evidence exists: it was recorded after any
      // unlock, so a pending prompt expectation CANNOT erase it
      // (ui-consultant's refinement). Re-lock.
      _promptResumeExpected = false;
      if (widget.lock.relockOnResume) {
        widget.lock.lock();
        _promptAndExpectResume();
      }
      return;
    }

    if (_promptResumeExpected) {
      // Completion-before-resume order: the prompt's straggler resume
      // arrives after unlock with NO background evidence. Swallow it
      // exactly once — no double prompt.
      _promptResumeExpected = false;
      return;
    }

    // Resume with no evidence and no pending expectation (e.g. after an
    // inactive-only banner pull): nothing to do.
  }

  @override
  Widget build(BuildContext context) {
    return AppPrivacyShield(
      masked: _mask.masked,
      // Codie review: OVERLAY the lock — replacing the child would
      // dispose the Navigator and every route's State (unsaved editor
      // drafts, active RecordingController) on re-lock. The app subtree
      // stays mounted under the lock; AppLockOverlay excludes it from
      // touch, focus, semantics, and back-navigation while locked.
      child: AppLockOverlay(
        locked: widget.lock.locked,
        lockScreen: AppLockScreen(
          lock: widget.lock,
          auth: widget.auth,
          canAuthenticate: widget.canAuthenticate,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Decides pairing vs. consultations based on whether a server is paired.
class _RootScreen extends StatefulWidget {
  const _RootScreen({required this.services});

  final AppServices services;

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  bool? _paired;

  AppLockController? _subscribedLock;

  @override
  void initState() {
    super.initState();
    // App-lock gating: while locked, NO data loads — the pairing check
    // reads the secure store and must not run before unlock (the lock
    // would otherwise be theater with the fetch already done).
    final lock = widget.services.appLock;
    if (lock == null || !lock.locked) {
      _load();
    } else {
      _subscribedLock = lock;
      lock.addListener(_onLockUnlocked);
    }
  }

  @override
  void dispose() {
    // Codie review: no listener leak if disposed while still locked.
    _subscribedLock?.removeListener(_onLockUnlocked);
    super.dispose();
  }

  void _onLockUnlocked() {
    final lock = widget.services.appLock;
    if (lock != null && !lock.locked) {
      lock.removeListener(_onLockUnlocked);
      _load();
    }
  }

  Future<void> _load() async {
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    final paired = token != null && token.isNotEmpty && config != null;
    if (mounted) setState(() => _paired = paired);
  }

  @override
  Widget build(BuildContext context) {
    final paired = _paired;
    if (paired == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return paired
        ? ConsultationsScreen(services: widget.services, onUnpaired: _load)
        : PairingScreen(services: widget.services, onPaired: _load);
  }
}
