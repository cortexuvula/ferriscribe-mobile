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
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold launch: prompt as soon as the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.lock.locked) widget.lock.tryUnlock(widget.auth);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mask.dispose();
    super.dispose();
  }

  /// When the auth prompt's own `resumed` was last seen; re-lock
  /// suppression is bounded to this window so a GENUINE backgrounding
  /// that outlasts it still re-locks (ui-consultant's f805d3e catch:
  /// the old code computed suppression BEFORE clearing the expired
  /// deadline, so a post-window resume stayed suppressed forever).
  DateTime? _promptSettlingUntil;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _mask.didChangeAppLifecycleState(state);
    final now = DateTime.now();

    // 1) Expiry FIRST — an expired settle window must not suppress
    //    anything on this event.
    final settling = _promptSettlingUntil;
    final settlingStill = settling != null && now.isBefore(settling);
    if (!settlingStill) _promptSettlingUntil = null;

    // 2) Genuine-backgrounding evidence: ONLY paused/hidden/detached
    //    count — `inactive` alone fires for dialogs, the notification
    //    shade, and split-screen drags, none of which hand the phone to
    //    someone else. Leaving the app ALWAYS reaches paused/hidden on
    //    both platforms, so real handoffs are never missed. And while a
    //    prompt is up, even paused is the prompt's own noise.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!widget.lock.authenticating) {
        _pausedAt ??= now;
      }
      return;
    }
    if (state == AppLifecycleState.inactive) return;

    if (state != AppLifecycleState.resumed) return;

    // 3) A resume while the prompt is up is the prompt's own — extend
    //    the settle window, clear stale evidence, and never re-lock
    //    here (the lock is already engaged in every path that shows a
    //    prompt).
    if (widget.lock.authenticating) {
      _promptSettlingUntil = now.add(_settleWindow);
      _pausedAt = null;
      return;
    }

    // 4) A resume within the settle window after a prompt completed:
    //    still treat as prompt noise (no double re-lock right after a
    //    successful unlock).
    if (settlingStill) {
      _pausedAt = null;
      return;
    }

    // 5) Otherwise: a genuine resume. Re-lock iff we have real
    //    backgrounding evidence.
    final away = _pausedAt;
    _pausedAt = null;
    if (widget.lock.relockOnResume && away != null) {
      widget.lock.lock();
      widget.lock.tryUnlock(widget.auth);
    }
  }

  /// Heuristic window (codie: documented trade) covering the OS's
  /// post-prompt event stragglers. If a slow device eats a real
  /// backgrounding inside it, the cost is one missed re-lock; cold
  /// launch and every later resume re-lock normally.
  static const _settleWindow = Duration(seconds: 2);

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
