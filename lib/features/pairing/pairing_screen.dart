import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_bootstrap.dart';
import '../../core/constants.dart';
import '../../pairing/pairing_client.dart';
import '../../pairing/pairing_payload.dart';
import '../../ui/components/status.dart';

/// Connect-to-office onboarding (§5K).
///
/// Short title, three preparatory steps, primary Scan pairing QR (camera
/// permission requested on action), secondary Enter pairing link. On
/// capture: stop scanning, confirm host + device label (ports collapsed
/// under Details; the pairing code is not prominently repeated). Invalid
/// input gives a visible reason; wrong scheme never silently no-ops.
/// Camera-denied explains and offers the manual route. Success returns to
/// Consultations.
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

enum _PairStage { choose, scanning, confirm }

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _labelController = TextEditingController(
    text: kDefaultDeviceLabel,
  );
  final TextEditingController _manualController = TextEditingController();

  _PairStage _stage = _PairStage.choose;
  PairingPayload? _payload;
  String? _rawInput;
  bool _manual = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // ── Capture ───────────────────────────────────────────────────────────

  void _startScan() {
    // Camera permission is requested by the scanner on action (§5K), not
    // before the user has chosen to scan.
    setState(() {
      _stage = _PairStage.scanning;
      _manual = false;
      _error = null;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_stage != _PairStage.scanning || _busy) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _accept(raw);
  }

  /// Accepts a scanned or manually entered value. A wrong scheme gives a
  /// visible reason — never a silent no-op (§5K).
  void _accept(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.toLowerCase().startsWith('$kPairingScheme://')) {
      setState(
        () => _error =
            'That does not look like a FerriScribe pairing link '
            '(it should start with ferriscribe://). Get a fresh QR from the '
            'desktop app and try again.',
      );
      return;
    }
    try {
      final payload = PairingPayload.parse(trimmed);
      // Stop scanning on capture (§5K).
      setState(() {
        _payload = payload;
        _rawInput = trimmed;
        _stage = _PairStage.confirm;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(
        () => _error =
            'The pairing link is invalid or expired (${e.message}). '
            'Display a fresh QR in the desktop app and scan again.',
      );
    }
  }

  void _applyManual() {
    final raw = _manualController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste the pairing link first.');
      return;
    }
    _accept(raw);
  }

  // ── Enroll ────────────────────────────────────────────────────────────

  Future<void> _pair() async {
    final raw = _rawInput;
    if (raw == null) return;
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Enter a name for this phone.');
      return;
    }
    setState(() {
      _busy = true; // busy state disables repeated enroll (§5K)
      _error = null;
    });
    try {
      await widget.services.pairingService.pair(qrText: raw, label: label);
      widget.onPaired(); // returns to Consultations on success (§5K)
    } on PairingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FormatException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'The pairing link is invalid or expired '
              '(${e.message}). Get a fresh QR from the desktop app.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to your office')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_stage == _PairStage.choose) ..._chooseBody(),
            if (_stage == _PairStage.scanning) ..._scanBody(),
            if (_stage == _PairStage.confirm) ..._confirmBody(),
          ],
        ),
      ),
    );
  }

  List<Widget> _chooseBody() {
    return [
      Text(
        'To connect this phone to your office server:',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _step('1', 'Open FerriScribe on the desktop computer'),
      _step('2', 'Display its pairing QR code'),
      _step('3', 'Make sure Tailscale is running on this phone'),
      if (_error != null) ...[
        const SizedBox(height: 16),
        NoticeBanner(tone: AppStatusTone.error, text: _error!),
      ],
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: _startScan,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan pairing QR'),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => setState(() {
          _manual = true;
          _stage = _PairStage.choose;
        }),
        icon: const Icon(Icons.edit_note),
        label: const Text('Enter pairing link'),
      ),
      if (_manual) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _manualController,
          decoration: const InputDecoration(
            labelText: 'Pairing link (ferriscribe://…)',
            helperText: 'Paste the link shown in the desktop app.',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          // Manual text stays local; never read/write the clipboard.
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _applyManual,
          child: const Text('Use this link'),
        ),
      ],
    ];
  }

  Widget _step(String n, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Text(
              n,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  List<Widget> _scanBody() {
    return [
      SizedBox(
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MobileScanner(onDetect: _onDetect),
        ),
      ),
      const SizedBox(height: 12),
      // Contrast-safe guidance OUTSIDE the image (§5K).
      const Text(
        'Hold the phone so the desktop\'s pairing QR fills the frame. '
        'Scanning stops automatically once it is read.',
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        NoticeBanner(tone: AppStatusTone.error, text: _error!),
      ],
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() => _stage = _PairStage.choose),
        child: const Text('Cancel'),
      ),
    ];
  }

  List<Widget> _confirmBody() {
    final payload = _payload!;
    return [
      const Text(
        'Confirm this is your office server:',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(Icons.dns_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              payload.host,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _labelController,
        decoration: const InputDecoration(
          labelText: 'Name this phone',
          helperText: 'Shown in the desktop app\'s device list.',
          border: OutlineInputBorder(),
        ),
      ),
      // Ports collapsed under Details (§5K); the pairing code is NOT
      // prominently repeated here.
      Theme(
        data: Theme.of(context).copyWith(
          dividerTheme: const DividerThemeData(color: Colors.transparent),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('Details'),
          children: [
            ListTile(
              dense: true,
              title: const Text('Pairing port'),
              subtitle: Text('${payload.pairingPort}'),
            ),
            ListTile(
              dense: true,
              title: const Text('Data port'),
              subtitle: Text('${payload.dataPort ?? kDefaultDataPort}'),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        NoticeBanner(tone: AppStatusTone.error, text: _error!),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _pair,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.link),
        label: const Text('Pair this phone'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _payload = null;
                _rawInput = null;
                _stage = _PairStage.scanning;
              }),
        child: const Text('Scan again'),
      ),
    ];
  }
}
