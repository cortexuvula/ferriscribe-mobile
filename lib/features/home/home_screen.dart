import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_bootstrap.dart';
import '../../core/api/data_api_client.dart';
import '../../pairing/pairing_client.dart';
import '../../pairing/server_config_repository.dart';
import '../documents/recordings_screen.dart';
import '../recording/record_screen.dart';

/// Post-pairing home: recording actions first, then a collapsible Connection
/// section with server diagnostics + Appearance menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.services,
    required this.onUnpaired,
    required this.themeOption,
    required this.onSetTheme,
  });

  final AppServices services;
  final VoidCallback onUnpaired;
  final ThemeModeOption themeOption;
  final ValueChanged<ThemeModeOption> onSetTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasToken = false;
  ServerConfig? _config;
  bool _probing = false;
  String? _probeResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (mounted) {
      setState(() {
        _hasToken = token != null && token.isNotEmpty;
        _config = config;
      });
    }
  }

  Future<void> _probe() async {
    final config = _config;
    if (config == null) return;
    setState(() {
      _probing = true;
      _probeResult = null;
    });
    final client = PairingClient(
      baseUrl: PairingClient.baseUrlFor(config.host, config.pairingPort),
    );
    try {
      final info = await client.fetchInfo();
      if (mounted) {
        setState(() {
          _probeResult =
              'Reachable — v${info.version}${info.tailscale != null ? ' (Tailscale: ${info.tailscale})' : ''}';
        });
      }
    } on PairingException catch (e) {
      if (mounted) setState(() => _probeResult = 'Unreachable: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _probeResult = 'Unreachable');
    } finally {
      client.close();
      if (mounted) setState(() => _probing = false);
    }
  }

  void _record() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordScreen(services: widget.services),
      ),
    );
  }

  void _openRecordings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingsScreen(services: widget.services),
      ),
    );
  }

  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair this device?'),
        content: const Text(
          'This removes the stored token and revokes this phone\'s access on '
          'the server. If the server is unreachable, the token is cleared '
          'locally but may remain active on the server until revoked from '
          'the desktop app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token != null && token.isNotEmpty && config != null) {
      final client = DataApiClient.forConfig(config, token);
      try {
        await client.revokeSelf();
      } finally {
        client.close();
      }
    }

    await widget.services.serverConfigRepository.clear();
    widget.onUnpaired();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('FerriScribe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Recording actions — primary ────────────────────────────
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _record,
            icon: const Icon(Icons.mic),
            label: const Text('Record consultation'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _openRecordings,
            icon: const Icon(Icons.folder_outlined),
            label: const Text('View recordings'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          // ── Appearance ─────────────────────────────────────────────
          const SizedBox(height: 28),
          _SectionHeader(title: 'Appearance', scheme: scheme),
          const SizedBox(height: 8),
          RadioGroup<ThemeModeOption>(
            groupValue: widget.themeOption,
            onChanged: (v) {
              if (v != null) widget.onSetTheme(v);
            },
            child: Column(
              children: [
                for (final o in ThemeModeOption.values)
                  RadioListTile<ThemeModeOption>(
                    value: o,
                    title: Text(o.label),
                    secondary: Icon(o.icon, size: 20, color: scheme.primary),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // ── Connection — collapsible (ExpansionTile: ≥48dp target,
          // accessible expanded/collapsed semantics) ───────────────
          Theme(
            // Remove ExpansionTile's default divider — we render our own.
            data: Theme.of(
              context,
            ).copyWith(dividerTheme: const DividerThemeData(color: null)),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: false,
              title: Text(
                'Connection',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              iconColor: scheme.primary,
              collapsedIconColor: scheme.primary,
              children: [
                if (_config != null) ...[
                  _Row(label: 'Server', value: _config!.host, scheme: scheme),
                  _Row(label: 'Label', value: _config!.label, scheme: scheme),
                ],
                _Row(
                  label: 'Bearer token',
                  value: _hasToken ? 'stored' : 'missing',
                  scheme: scheme,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _probing ? null : _probe,
                        icon: _probing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering, size: 18),
                        label: const Text('Probe server'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _unpair,
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Unpair'),
                    ),
                  ],
                ),
                if (_probeResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _probeResult!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _probeResult!.startsWith('Unreachable')
                          ? scheme.error
                          : scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Simple section header with a tinted rule.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.scheme});

  final String label;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
