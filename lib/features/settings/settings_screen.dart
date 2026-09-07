import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/data_api_client.dart';
import '../../core/state/connection_state.dart';
import '../../core/state/presentation_adapters.dart';
import '../../pairing/server_config_repository.dart';
import '../../core/build_stamp.dart';
import '../../ui/components/status.dart';
import '../../ui/theme/theme_controller.dart';

/// Settings: Appearance, Office connection, Privacy, and Unpair.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    required this.onUnpaired,
  });

  final AppServices services;
  final VoidCallback onUnpaired;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ServerConfig? _config;
  String? _reachDetail;

  // Derived from the app-scoped holder (§5J): the check result outlives
  // this screen and is shared with the Consultations landing page.
  bool get _checking => widget.services.connection.checking;
  bool get _authFailure => widget.services.connection.last is AuthFailure;
  bool get _reachable =>
      widget.services.connection.last is Connected &&
      widget.services.connection.last is! ConnectionChecking;
  bool get _unreachable => widget.services.connection.last is Unreachable;

  @override
  void initState() {
    super.initState();
    // V5: subscribe to the shared holder — checks published elsewhere
    // (launch check, sync fold, preflight) reflect here live.
    widget.services.connection.addListener(_onConnectionChanged);
    _load();
  }

  @override
  void dispose() {
    widget.services.connection.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (mounted) setState(() => _config = config);
  }

  /// `Check connection` — public /info establishes reachability (not
  /// authenticated data readiness). Runs through the shared
  /// ConnectionStateAdapter and publishes into the app-scoped
  /// ConnectionHolder (§5J), so the Consultations landing page reflects
  /// the result and it survives leaving this screen.
  Future<void> _check() async {
    final config = _config;
    if (config == null) return;
    final holder = widget.services.connection;
    final adapter = ConnectionStateAdapter();
    setState(() => _reachDetail = null);
    holder.beginCheck();
    final state = await adapter.check(config: config);
    holder.publish(state);
    if (!mounted) return;
    setState(() {
      _reachDetail = switch (state) {
        Connected(:final serverVersion) when serverVersion != null =>
          'FerriScribe v$serverVersion',
        _ => null,
      };
    });
  }

  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair this device?'),
        content: const Text(
          'This removes the stored token and revokes this phone\'s access on '
          'the server. If the office server cannot be reached, access may '
          'remain active there until revoked from the desktop app.',
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

    var serverRevoked = false;
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token != null && token.isNotEmpty && config != null) {
      final client = DataApiClient.forConfig(config, token);
      try {
        serverRevoked = await client.revokeSelf();
      } finally {
        client.close();
      }
    }

    await widget.services.serverConfigRepository.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          serverRevoked
              ? 'Unpaired. Server access revoked.'
              : 'Unpaired locally. Server access may remain active until '
                    'revoked from the desktop app.',
        ),
      ),
    );
    widget.onUnpaired();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ThemeControllerScope.maybeOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Build identification: answers 'which build is installed' from
          // the phone itself (SHA + build number, matching Android
          // versionCode).
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Build $buildSha · #$buildNumber',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          // ── Appearance ───────────────────────────────────────────
          _sectionLabel('Appearance', scheme),
          if (controller != null)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => RadioGroup<ThemeModeOption>(
                groupValue: controller.option,
                onChanged: (v) {
                  if (v != null) controller.setOption(v);
                },
                child: Column(
                  children: [
                    for (final o in ThemeModeOption.values)
                      RadioListTile<ThemeModeOption>(
                        value: o,
                        title: Text(o.label),
                        subtitle: Text(
                          o.helper,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Appearance unavailable.'),
            ),
          const SizedBox(height: 24),

          // ── Office connection ────────────────────────────────────
          _sectionLabel('Office connection', scheme),
          if (_config != null) ...[
            ListTile(
              title: const Text('Server'),
              subtitle: Text(_config!.host),
              dense: true,
            ),
            ListTile(
              title: const Text('This phone'),
              subtitle: Text(_config!.label),
              dense: true,
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_checking ? 'Checking…' : 'Check connection'),
            ),
          ),
          if (_reachable)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: StatusLine(
                tone: AppStatusTone.success,
                text: _reachDetail ?? 'Reachable',
              ),
            )
          else if (_authFailure)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: StatusLine(
                tone: AppStatusTone.error,
                text:
                    'Pairing needs attention — this phone was rejected by '
                    'the server. Re-pair from the desktop app.',
              ),
            )
          else if (_unreachable)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: StatusLine(
                tone: AppStatusTone.error,
                text: 'Unreachable — check the desktop app and Tailscale',
              ),
            ),
          if (_config != null)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Connection details',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              children: [
                ListTile(
                  dense: true,
                  title: const Text('Pairing port'),
                  subtitle: Text('${_config!.pairingPort}'),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Data port'),
                  subtitle: Text('${_config!.dataPort}'),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Paired at'),
                  subtitle: Text(_config!.pairedAt.toLocal().toString()),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // ── Privacy ──────────────────────────────────────────────
          _sectionLabel('Privacy', scheme),
          _privacyRow(
            context,
            icon: Icons.visibility_off_outlined,
            text:
                'App-switcher content is hidden while FerriScribe is in '
                'the background.',
          ),
          _privacyRow(
            context,
            icon: Icons.lock_outline,
            text: 'Documents are cached in encrypted app storage.',
          ),
          _privacyRow(
            context,
            icon: Icons.content_copy,
            text: 'Clipboard is used only through explicit Copy.',
          ),
          _privacyRow(
            context,
            icon: Icons.ios_share,
            text: 'Exports can leave the app once you share them.',
          ),
          const SizedBox(height: 32),

          // ── Unpair — separate, not visually equal to Check ───────
          TextButton.icon(
            onPressed: _unpair,
            icon: Icon(Icons.link_off, color: scheme.error),
            label: Text(
              'Unpair this device',
              style: TextStyle(color: scheme.error),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _privacyRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provides the [ThemeController] down the tree without importing the app
/// root (per the design: Home no longer imports app.dart).
class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()
      ?.notifier;
}
