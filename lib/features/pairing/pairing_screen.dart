import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_bootstrap.dart';
import '../../core/constants.dart';
import '../../pairing/pairing_client.dart';
import '../../pairing/pairing_payload.dart';

/// QR → `/pair/enroll` pairing screen.
///
/// Scans the desktop's `ferriscribe://pair?...` QR (or accepts the URL pasted
/// manually), probes `GET /info`, exchanges the 6-digit code for a bearer
/// token, and persists it. The token is never displayed.
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.services,
    required this.onPaired,
  });

  final AppServices services;
  final VoidCallback onPaired;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _labelController = TextEditingController(
    text: kDefaultDeviceLabel,
  );
  final TextEditingController _manualController = TextEditingController();

  PairingPayload? _payload;
  String? _rawQr;
  bool _scanning = true;
  bool _showManual = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning || _busy) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _accept(raw);
  }

  void _accept(String raw) {
    if (!raw.trim().toLowerCase().startsWith('$kPairingScheme://')) return;
    try {
      final payload = PairingPayload.parse(raw);
      setState(() {
        _payload = payload;
        _rawQr = raw;
        _scanning = false;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() => _error = 'Unrecognised QR: ${e.message}');
    }
  }

  void _applyManual() {
    final raw = _manualController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste the pairing URL first.');
      return;
    }
    _accept(raw);
  }

  Future<void> _pair() async {
    final raw = _rawQr;
    if (raw == null) return;
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Enter a device label.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.services.pairingService.pair(qrText: raw, label: label);
      widget.onPaired();
    } on PairingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair FerriScribe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Scan the pairing QR shown in the desktop FerriScribe app, or '
            'paste the pairing URL below.',
          ),
          const SizedBox(height: 16),
          if (_scanning && !_showManual)
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(onDetect: _onDetect),
              ),
            ),
          if (_payload != null) _confirmCard(),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _showManual = !_showManual),
            icon: Icon(_showManual ? Icons.qr_code_scanner : Icons.edit_note),
            label: Text(_showManual ? 'Use camera' : 'Enter URL manually'),
          ),
          if (_showManual) ...[
            TextField(
              controller: _manualController,
              decoration: const InputDecoration(
                labelText: 'Pairing URL (ferriscribe://pair?…)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _applyManual,
              child: const Text('Use this URL'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _confirmCard() {
    final payload = _payload!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server: ${payload.host}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Pairing port: ${payload.pairingPort}'),
            Text('Data port: ${payload.dataPort ?? kDefaultDataPort}'),
            Text('Code: ${payload.code}'),
            const SizedBox(height: 12),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Device label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _pair,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: const Text('Pair'),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _payload = null;
                      _rawQr = null;
                      _scanning = true;
                    }),
              child: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}
