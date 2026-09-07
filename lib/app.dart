import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_bootstrap.dart';
import 'features/home/home_screen.dart';
import 'features/pairing/pairing_screen.dart';
import 'security/snapshot_mask.dart';

/// The UI brightness mode selected by the user.
enum ThemeModeOption {
  system(Icons.phone_iphone_outlined, 'System', null),
  light(Icons.light_mode_outlined, 'Light', ThemeMode.light),
  dark(Icons.dark_mode_outlined, 'Dark', ThemeMode.dark);

  const ThemeModeOption(this.icon, this.label, this.mode);

  final IconData icon;
  final String label;
  final ThemeMode? mode;

  static const _key = 'themeMode';

  static Future<ThemeModeOption> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'light' => light,
      'dark' => dark,
      _ => system,
    };
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }
}

/// Builds a Material 3 [ThemeData] from the brand seed for a given brightness.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B6B93),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}

/// Root widget. Wraps the navigator in the privacy shield so the app-switcher
/// mask covers every route.
class FerriScribeApp extends StatefulWidget {
  const FerriScribeApp({super.key, required this.services});

  final AppServices services;

  @override
  State<FerriScribeApp> createState() => _FerriScribeAppState();
}

class _FerriScribeAppState extends State<FerriScribeApp> {
  ThemeModeOption _option = ThemeModeOption.system;

  @override
  void initState() {
    super.initState();
    ThemeModeOption.load().then((o) {
      if (mounted) setState(() => _option = o);
    });
  }

  void setThemeMode(ThemeModeOption option) {
    setState(() => _option = option);
    option.save();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FerriScribe',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _option.mode ?? ThemeMode.system,
      builder: (context, child) => _AppShell(child: child!),
      home: _RootScreen(
        services: widget.services,
        themeOption: _option,
        onSetTheme: setThemeMode,
      ),
    );
  }
}

/// Hosts the [LifecycleMaskController] and wraps every route in the shield.
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

/// Decides pairing vs. home based on whether a server is already paired.
class _RootScreen extends StatefulWidget {
  const _RootScreen({
    required this.services,
    required this.themeOption,
    required this.onSetTheme,
  });

  final AppServices services;
  final ThemeModeOption themeOption;
  final ValueChanged<ThemeModeOption> onSetTheme;

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
        ? HomeScreen(
            services: widget.services,
            onUnpaired: _load,
            themeOption: widget.themeOption,
            onSetTheme: widget.onSetTheme,
          )
        : PairingScreen(services: widget.services, onPaired: _load);
  }
}
