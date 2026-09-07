import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
import 'features/home/consultations_screen.dart';
import 'features/pairing/pairing_screen.dart';
import 'features/settings/settings_screen.dart' show ThemeControllerScope;
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

  @override
  void initState() {
    super.initState();
    _themeController.load(); // race-guarded: user choice wins over late load
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      notifier: _themeController,
      child: ListenableBuilder(
        listenable: _themeController,
        builder: (context, _) => MaterialApp(
          title: 'FerriScribe',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: _themeController.themeMode,
          builder: (context, child) => _AppShell(child: child!),
          home: _RootScreen(services: widget.services),
        ),
      ),
    );
  }
}

/// Hosts the [LifecycleMaskController] and wraps every route in the shield.
/// Independent of theme: the mask is opaque and token-free by design.
class _AppShell extends StatefulWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final LifecycleMaskController _mask = LifecycleMaskController();

  @override
  void dispose() {
    _mask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPrivacyShield(masked: _mask.masked, child: widget.child);
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
    _load();
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
