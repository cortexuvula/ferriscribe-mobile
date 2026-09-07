import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
import 'features/home/consultations_screen.dart';
import 'features/pairing/pairing_screen.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _mask.didChangeAppLifecycleState(state);
    // Re-lock on resume: a physician can hand the phone off while the
    // app is foregrounded — that's the gap the lock exists to close.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt;
      _pausedAt = null;
      if (widget.lock.relockOnResume && away != null) {
        widget.lock.lock();
        widget.lock.tryUnlock(widget.auth);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPrivacyShield(
      masked: _mask.masked,
      child: widget.lock.locked
          ? AppLockScreen(
              lock: widget.lock,
              auth: widget.auth,
              canAuthenticate: widget.canAuthenticate,
            )
          : widget.child,
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
      lock.addListener(_onLockUnlocked);
    }
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
