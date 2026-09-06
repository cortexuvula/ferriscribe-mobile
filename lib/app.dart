import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
import 'features/home/home_screen.dart';
import 'features/pairing/pairing_screen.dart';
import 'security/snapshot_mask.dart';

/// Root widget. Wraps the whole navigator in the privacy shield so the
/// app-switcher mask covers every route.
class FerriScribeApp extends StatelessWidget {
  const FerriScribeApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FerriScribe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B93)),
        useMaterial3: true,
      ),
      builder: (context, child) => _AppShell(child: child!),
      home: _RootScreen(services: services),
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
        ? HomeScreen(services: widget.services, onUnpaired: _load)
        : PairingScreen(services: widget.services, onPaired: _load);
  }
}
