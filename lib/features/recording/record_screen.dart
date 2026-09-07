import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/patient_context.dart';
import 'patient_context_form.dart';
import 'recording_controller.dart';
import 'recording_ingest_service.dart';

/// Phase 1 recording screen: capture → ingest → SOAP, with live stage
/// progress. No audio is written to disk at any point.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final RecordingController _controller = RecordingController();
  final RecordingIngestService _ingest = RecordingIngestService();

  bool _recording = false;
  bool _ingesting = false;
  IngestStage _stage = IngestStage.queued;
  String? _recordingId;
  String? _error;
  String? _warning;
  PatientContext? _patientContext;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<IngestEvent>? _ingestSub;

  @override
  void dispose() {
    _ticker?.cancel();
    _ingestSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await _controller.start(
        onWarning: () {
          if (!mounted) return;
          setState(
            () => _warning =
                'Recording is long (30+ min). Consider stopping soon.',
          );
        },
        onLimitReached: () {
          if (!mounted) return;
          setState(
            () => _warning = 'Auto-stopped at 60 min to prevent memory issues.',
          );
          _stopAndIngest();
        },
      );
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
        _error = null;
        _warning = null;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } on RecordingPermissionException {
      _showMessage('Microphone permission denied. Enable it in Settings.');
    } catch (e) {
      _showMessage('Could not start recording.');
    }
  }

  Future<void> _stopAndIngest() async {
    _ticker?.cancel();
    final wav = await _controller.stop();
    setState(() {
      _recording = false;
      _ingesting = true;
      _stage = IngestStage.creating;
      _error = null;
    });

    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      setState(() {
        _ingesting = false;
        _error = 'Not paired — pair with a server first.';
      });
      return;
    }

    final filename = 'Consultation ${_nowLabel()}';
    final patientContext = _patientContext;
    _ingestSub = _ingest
        .run(
          config: config,
          token: token,
          wav: wav,
          duration: _elapsed,
          filename: filename,
          patientContext: patientContext,
        )
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              _stage = event.stage;
              _recordingId = event.recordingId;
              _error = event.error;
              if (event.isTerminal) _ingesting = false;
            });
            // Persist patient context once the recording id is known.
            if (event.recordingId != null && patientContext != null) {
              widget.services.offlineCache.upsertPatientContext(
                event.recordingId!,
                patientContext,
              );
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _ingesting = false;
              _error = 'Ingest failed.';
            });
          },
        );
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    await _controller.cancel();
    setState(() {
      _recording = false;
      _elapsed = Duration.zero;
      _warning = null;
    });
  }

  Future<void> _editContext() async {
    final result = await showPatientContextForm(
      context,
      initial: _patientContext,
    );
    if (result != null && mounted) {
      setState(() => _patientContext = result);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  String _nowLabel() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record consultation')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            if (_recording) ...[
              const Icon(Icons.mic, size: 96, color: Colors.red),
              const SizedBox(height: 16),
              Text(_elapsedLabel(), style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              const Text('Recording…'),
              if (_warning != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _warning!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ] else if (_ingesting) ...[
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              Text(_stageLabel(), style: const TextStyle(fontSize: 20)),
            ] else if (_stage == IngestStage.completed) ...[
              const Icon(Icons.check_circle, size: 96, color: Colors.green),
              const SizedBox(height: 16),
              const Text('SOAP generated', style: TextStyle(fontSize: 22)),
              if (_recordingId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Recording ${_shortId(_recordingId!)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
            ] else if (_stage == IngestStage.failed && _error != null) ...[
              const Icon(Icons.error_outline, size: 96, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed', style: const TextStyle(fontSize: 22)),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ] else ...[
              const Icon(Icons.mic_none, size: 96, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Tap record to begin', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _editContext,
                icon: const Icon(Icons.medication_outlined),
                label: Text(
                  _patientContext == null
                      ? 'Add patient context'
                      : 'Patient context (${_patientContext!.medications.length + _patientContext!.conditions.length + _patientContext!.allergies.length} items)',
                ),
              ),
            ],
            if (_error != null &&
                !_ingesting &&
                _stage != IngestStage.completed &&
                _stage != IngestStage.failed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Spacer(),
            if (_recording)
              FilledButton.icon(
                onPressed: _stopAndIngest,
                icon: const Icon(Icons.stop),
                label: const Text('Stop & generate'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              )
            else if (!_ingesting && _stage != IngestStage.completed)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic),
                label: const Text('Record'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            if (_recording)
              TextButton(onPressed: _cancel, child: const Text('Cancel')),
            if (_stage == IngestStage.completed || _stage == IngestStage.failed)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
          ],
        ),
      ),
    );
  }

  String _elapsedLabel() {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _stageLabel() {
    switch (_stage) {
      case IngestStage.creating:
        return 'Creating recording…';
      case IngestStage.uploading:
        return 'Uploading audio…';
      case IngestStage.queued:
        return 'Queued…';
      case IngestStage.transcribing:
        return 'Transcribing…';
      case IngestStage.generatingSoap:
        return 'Generating SOAP…';
      case IngestStage.completed:
        return 'Done';
      case IngestStage.failed:
        return 'Failed';
    }
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}
