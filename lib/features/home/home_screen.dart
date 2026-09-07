import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../pairing/pairing_client.dart';
import '../../pairing/server_config_repository.dart';
import '../recording/record_screen.dart';

/// Post-pairing home: shows the paired server, probes reachability, and lets
/// the user unpair.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.services,
    required this.onUnpaired,
  });

  final AppServices services;
  final VoidCallback onUnpaired;

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

  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair this device?'),
        content: const Text(
          'This removes the stored token and server connection from this '
          'phone. Revoking access on the server itself is done from the '
          'desktop app.',
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
    await widget.services.serverConfigRepository.clear();
    widget.onUnpaired();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('FerriScribe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.health_and_safety_outlined, size: 64),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Paired to office server',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          if (config != null) ...[
            _Row(label: 'Device label', value: config.label),
            _Row(label: 'Host', value: config.host),
            _Row(label: 'Pairing port', value: '${config.pairingPort}'),
            _Row(label: 'Data port', value: '${config.dataPort}'),
            _Row(
              label: 'Paired at',
              value: config.pairedAt.toLocal().toString(),
            ),
          ],
          _Row(label: 'Bearer token', value: _hasToken ? 'stored' : 'missing'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _probing ? null : _probe,
            icon: _probing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('Probe server'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _record,
            icon: const Icon(Icons.mic),
            label: const Text('Record consultation'),
          ),
          if (_probeResult != null) ...[
            const SizedBox(height: 12),
            Text(_probeResult!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _unpair,
            icon: const Icon(Icons.link_off),
            label: const Text('Unpair this device'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
