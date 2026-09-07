import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/patient_context.dart';
import '../../core/state/connection_state.dart' as conn;
import '../../core/state/ingest_state.dart';
import '../../core/state/presentation_adapters.dart';
import '../../ui/components/status.dart';
import '../../ui/theme/app_theme.dart';
import '../documents/document_editor_screen.dart';
import '../documents/recording_detail_screen.dart';
import 'patient_context_form.dart';
import 'recording_controller.dart';
import 'recording_ingest_service.dart';

/// New consultation flow: preparation → recording → processing → result.
///
/// Focused routes per the design (§5B–E): no persistent navigation competes
/// with the primary action; exit during capture confirms discard; success
/// offers Open SOAP note via the real recording id.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

enum _Phase { preparation, recording, processing, done, failed }

class _RecordScreenState extends State<RecordScreen> {
  final RecordingController _controller = RecordingController();
  final RecordingIngestService _ingest = RecordingIngestService();

  _Phase _phase = _Phase.preparation;
  PatientContext? _patientContext;

  // Connection check (preparation).
  conn.ConnectionState _connection = conn.ConnectionUnknown(
    checkedAt: DateTime.now(),
  );
  bool _checking = false;

  // Recording.
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _notice; // 30-min warning / 60-min auto-stop notice

  // Processing state (§6.4).
  IngestPresentation _presentation = const IngestPresentation(
    lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
    recordingId: '',
  );

  StreamSubscription<IngestEvent>? _ingestSub;
  bool _starting = false;
  bool _stopping = false;
  bool _uploadComplete = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _ingestSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Preparation ───────────────────────────────────────────────────────

  /// §5B mandatory preflight: an AUTHENTICATED check runs automatically on
  /// entering preparation — before the user can press Start — and on retry.
  /// Start is enabled only when it proved both reachability and pairing.
  @override
  void initState() {
    super.initState();
    _preflight();
  }

  Future<void> _preflight() async {
    final config = await widget.services.serverConfigRepository.readCurrent();
    final token = await widget.services.serverConfigRepository.readToken();
    if (config == null || token == null || token.isEmpty) {
      if (mounted) {
        setState(
          () => _connection = conn.Unreachable(
            checkedAt: DateTime.now(),
            reason: 'not paired',
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _checking = true);
    final state = await ConnectionStateAdapter().authenticatedCheck(
      config: config,
      token: token,
    );
    if (mounted) {
      setState(() {
        _connection = state;
        _checking = false;
      });
    }
  }

  /// Manual Check button — same authenticated preflight.
  Future<void> _checkConnection() => _preflight();

  Future<void> _editContext() async {
    final result = await showPatientContextForm(
      context,
      initial: _patientContext,
    );
    if (result != null && mounted) {
      setState(() => _patientContext = result);
    }
  }

  Future<void> _startRecording() async {
    if (_starting) return; // single-flight
    _starting = true;
    try {
      await _controller.start(
        onWarning: () {
          if (!mounted) return;
          setState(
            () => _notice =
                '30 minutes recorded. Recording stops '
                'automatically at 60 minutes.',
          );
        },
        onLimitReached: () {
          if (!mounted) return;
          // Same one-shot Stop path as the button.
          setState(() => _notice = 'Recording stopped at the 60-minute limit');
          _stopAndGenerate();
        },
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.recording;
        _elapsed = Duration.zero;
        _notice = null;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } on RecordingPermissionException {
      if (mounted) {
        setState(
          () => _notice =
              'Microphone permission is needed to record. '
              'Allow access in Settings, then try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Could not start recording. Try again.');
      }
    } finally {
      _starting = false;
    }
  }

  // ── Recording → processing ────────────────────────────────────────────

  Future<void> _stopAndGenerate() async {
    if (_stopping) return; // single-flight: no overlapping Stop calls
    _stopping = true;
    try {
      _ticker?.cancel();
      final wav = await _controller.stop();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.processing;
        _uploadComplete = false;
        _presentation = const IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
          recordingId: '',
          audioRecoverable: true, // WAV buffer still in RAM until dropped
        );
      });

      final token = await widget.services.serverConfigRepository.readToken();
      final config = await widget.services.serverConfigRepository.readCurrent();
      if (token == null || token.isEmpty || config == null) {
        setState(() {
          _phase = _Phase.failed;
          _presentation = IngestPresentation(
            lastAcknowledgedStage: _presentation.lastAcknowledgedStage,
            recordingId: '',
            failure: const IngestFailure(
              phase: IngestFailurePhase.create,
              detail: 'not paired',
            ),
            audioRecoverable: true,
          );
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
                if (event.stage == IngestStage.uploading) {
                  _uploadStarted = true; // audio PUT in flight
                }
                if (event.stage == IngestStage.queued) {
                  _uploadComplete = true; // audio safely on the server
                }
                _presentation = _fold(event, _presentation);
              });
              if (event.recordingId != null && patientContext != null) {
                widget.services.offlineCache
                    .upsertPatientContext(event.recordingId!, patientContext)
                    .catchError((_) {});
              }
            },
            onError: (Object _) {
              if (!mounted) return;
              setState(() => _phase = _Phase.failed);
            },
          );
    } finally {
      _stopping = false;
    }
  }

  /// Folds a raw ingest event into the presentation state, tracking each
  /// acknowledgement separately (§6.4) and marking the phase terminal.
  IngestPresentation _fold(IngestEvent event, IngestPresentation prior) {
    var next = prior;
    switch (event.stage) {
      case IngestStage.creating:
        next = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
          recordingId: event.recordingId ?? prior.recordingId,
          audioRecoverable: true,
        );
      case IngestStage.uploading:
        next = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
          recordingId: event.recordingId ?? prior.recordingId,
          audioRecoverable: true,
        );
      case IngestStage.queued:
        next = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.generationQueued,
          recordingId: event.recordingId ?? prior.recordingId,
          uploadAcknowledged: true,
          generationAccepted: true,
          audioRecoverable: false,
        );
      case IngestStage.transcribing:
        next = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.transcribing,
          recordingId: event.recordingId ?? prior.recordingId,
          uploadAcknowledged: true,
          generationAccepted: true,
        );
      case IngestStage.generatingSoap:
        next = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.generatingSoap,
          recordingId: event.recordingId ?? prior.recordingId,
          uploadAcknowledged: true,
          generationAccepted: true,
        );
      case IngestStage.completed:
        next = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.completed,
          recordingId: event.recordingId ?? prior.recordingId,
          uploadAcknowledged: true,
          generationAccepted: true,
        );
        if (mounted) setState(() => _phase = _Phase.done);
      case IngestStage.failed:
        next = IngestPresentation(
          lastAcknowledgedStage: prior.lastAcknowledgedStage,
          recordingId: event.recordingId ?? prior.recordingId,
          uploadAcknowledged: prior.uploadAcknowledged,
          generationAccepted: prior.generationAccepted,
          failure: IngestFailure(
            // Carried on the event from the throw site — never inferred
            // from error text.
            phase: event.failurePhase ?? IngestFailurePhase.job,
            detail: event.error ?? 'failed',
          ),
          audioRecoverable: false,
        );
        if (mounted) setState(() => _phase = _Phase.failed);
      case IngestStage.interrupted:
        // SSE ended without a terminal event — NOT a failure. Reconcile
        // against the job registry; keep prior facts meanwhile.
        _reconcile();
        next = prior;
    }
    return next;
  }

  /// Reconciles an interrupted stream via `GET /v1/jobs/{id}` (§6.4):
  /// completed → done; failed → acknowledged failure; unknown/network
  /// error → keep the last acknowledged stage, never invent either.
  Future<void> _reconcile() async {
    final id = _presentation.recordingId;
    if (id.isEmpty) return;
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) return;
    final client = DataApiClient.forConfig(config, token);
    try {
      final reconciled = await reconcileIngest(
        client: client,
        prior: _presentation,
      );
      if (!mounted) return;
      setState(() {
        _presentation = reconciled;
        if (reconciled.isTerminal && reconciled.failure == null) {
          _phase = _Phase.done;
        } else if (reconciled.failure != null) {
          _phase = _Phase.failed;
        }
      });
    } finally {
      client.close();
    }
  }

  /// Discard confirmation (design: intercept ALL exits from recording).
  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this recording?'),
        content: const Text('Audio recorded on this phone will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard recording'),
          ),
        ],
      ),
    );
    if (result == true) {
      _ticker?.cancel();
      await _controller.cancel();
      if (mounted) {
        setState(() {
          _phase = _Phase.preparation;
          _elapsed = Duration.zero;
          _notice = null;
        });
      }
    }
    return false; // never pop automatically; we reset the phase instead
  }

  void _openSoapNote() {
    final id = _presentation.recordingId;
    if (id.isEmpty) return;
    // Open the SOAP document itself — real id, authoritative fetch inside.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DocumentEditorScreen(
          services: widget.services,
          recordingId: id,
          doc: DocType.soap,
        ),
      ),
    );
  }

  void _viewConsultation() {
    final id = _presentation.recordingId;
    if (id.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RecordingDetailScreen.byId(
          services: widget.services,
          recordingId: id,
        ),
      ),
    );
  }

  String _nowLabel() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Exit protection: during recording always confirm; during processing,
    // block exit while the upload is unacknowledged (leaving would destroy
    // the only copy of the audio). Once the server owns the bytes, exit is
    // safe — the job continues server-side.
    final bool canPop = switch (_phase) {
      _Phase.recording => false,
      _Phase.processing => _uploadComplete,
      _ => true,
    };
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_phase == _Phase.recording) {
          _confirmDiscard();
        } else if (_phase == _Phase.processing) {
          // Upload in flight: explain why leaving is blocked.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Uploading audio — leaving now would lose this recording.',
              ),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (_phase) {
            _Phase.preparation => 'New consultation',
            _Phase.recording => 'Recording',
            _ => 'Processing',
          }),
        ),
        body: switch (_phase) {
          _Phase.preparation => _buildPreparation(),
          _Phase.recording => _buildRecording(),
          _Phase.processing => _buildProcessing(),
          _Phase.done => _buildDone(),
          _Phase.failed => _buildFailed(),
        },
      ),
    );
  }

  Widget _buildPreparation() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Record the conversation, then generate a SOAP note.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
        const SizedBox(height: 20),
        // Optional patient context row.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.medication_outlined, color: scheme.primary),
          title: const Text('Patient context'),
          subtitle: Text(
            _patientContext == null || _patientContext!.isEmpty
                ? 'Not added'
                : 'Added for this consultation',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editContext,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Keep FerriScribe open while recording. Audio is not saved '
                'as a recording file on this phone.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        if (_notice != null) ...[
          const SizedBox(height: 16),
          NoticeBanner(tone: AppStatusTone.error, text: _notice!),
        ],
        const SizedBox(height: 32),
        // Connection check before Start.
        _connectionRow(scheme),
        const SizedBox(height: 24),
        // Start disabled after a failed connection check (per §5B); the
        // user can Check again or proceed once reachable.
        FilledButton.icon(
          onPressed: _startEnabled ? _startRecording : null,
          icon: const Icon(Icons.mic),
          label: const Text('Start recording'),
        ),
        if (!_startEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _checking
                  ? 'Checking your office server before recording…'
                  : 'A successful connection check is required before '
                        'recording. Tap Check to try again.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  /// §5B mandatory preflight: Start requires a state that proves BOTH
  /// reachability AND accepted pairing (`authOk: true` — only an
  /// authenticated read sets it). No-check-yet does NOT allow start.
  bool get _startEnabled => switch (_connection) {
    conn.Connected(:final authOk) => authOk,
    _ => false,
  };

  Widget _connectionRow(ColorScheme scheme) {
    final state = _connection;
    final Widget content;
    if (_checking) {
      content = StatusLine(
        tone: AppStatusTone.neutral,
        text: 'Checking connection…',
      );
    } else if (state is conn.Connected) {
      content = StatusLine(
        tone: AppStatusTone.success,
        text: state.authOk
            ? 'Connected to your office server'
            : 'Office server reachable'
                  '${state.serverVersion != null ? ' · v${state.serverVersion}' : ''}',
      );
    } else if (state is conn.AuthFailure) {
      content = const StatusLine(
        tone: AppStatusTone.error,
        text: 'Pairing needs attention',
      );
    } else if (state is conn.Unreachable) {
      content = const StatusLine(
        tone: AppStatusTone.warning,
        text: 'Office server unreachable',
      );
    } else {
      content = const StatusLine(
        tone: AppStatusTone.neutral,
        text: 'Connection not checked',
      );
    }
    return Row(
      children: [
        Expanded(child: content),
        if (!_checking)
          TextButton(onPressed: _checkConnection, child: const Text('Check')),
      ],
    );
  }

  Widget _buildRecording() {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.mic,
            size: 72,
            color: status?.warning ?? scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            'Recording',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _elapsedLabel(),
            // Tabular figures, 48sp per the design.
            style: TextStyle(
              fontSize: 48,
              height: 56 / 48,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 20),
            NoticeBanner(tone: AppStatusTone.warning, text: _notice!),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: _stopAndGenerate,
            icon: const Icon(Icons.stop),
            label: const Text('Stop & generate SOAP'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _confirmDiscard,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard recording'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    final scheme = Theme.of(context).colorScheme;
    final steps = _processingSteps();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_notice != null) ...[
          NoticeBanner(tone: AppStatusTone.warning, text: _notice!),
          const SizedBox(height: 16),
        ],
        ...steps.map((s) => _stepRow(s, scheme)),
      ],
    );
  }

  /// Ordered step list. The first two steps track LOCAL flow state (create
  /// in flight vs upload in flight vs upload acked); the rest track the
  /// acknowledged stage. No invented progress.
  List<({String label, bool done, bool active})> _processingSteps() {
    final stage = _presentation.lastAcknowledgedStage;
    // Local index: 0 = creating, 1 = uploading (in flight), 2 = acked by
    // server (queued or later).
    final int local;
    if (_uploadComplete ||
        stage.index >= IngestAcknowledgedStage.generationQueued.index) {
      local = 2;
    } else if (stage == IngestAcknowledgedStage.uploaded ||
        _presentation.uploadAcknowledged) {
      local = 2;
    } else {
      local = _uploadInFlight ? 1 : 0;
    }
    final labels = [
      'Preparing consultation',
      'Uploading audio',
      'Waiting for office server',
      'Transcribing',
      'Generating SOAP',
    ];
    // reached = index of the first not-done step.
    final int reached = switch (stage) {
      IngestAcknowledgedStage.creatingAcknowledged => local,
      IngestAcknowledgedStage.uploaded => 2,
      IngestAcknowledgedStage.generationQueued => 2,
      IngestAcknowledgedStage.transcribing => 3,
      IngestAcknowledgedStage.generatingSoap => 4,
      IngestAcknowledgedStage.completed => 5,
    };
    return [
      for (var i = 0; i < labels.length; i++)
        (label: labels[i], done: i < reached, active: i == reached),
    ];
  }

  /// True while the audio PUT is in flight (between the uploading event and
  /// the queued acknowledgement).
  bool get _uploadInFlight =>
      _phase == _Phase.processing && !_uploadComplete && _uploadStarted;

  bool _uploadStarted = false;

  Widget _stepRow(
    ({String label, bool done, bool active}) step,
    ColorScheme scheme,
  ) {
    final status = Theme.of(context).extension<AppStatusColors>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (step.done)
            Icon(
              Icons.check_circle,
              color: status?.success ?? Theme.of(context).colorScheme.primary,
              size: 22,
            )
          else if (step.active)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            )
          else
            Icon(Icons.circle_outlined, size: 22, color: scheme.outlineVariant),
          const SizedBox(width: 14),
          Text(
            step.label,
            style: TextStyle(
              fontSize: 16,
              color: step.done || step.active
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
              fontWeight: step.active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.check_circle,
            size: 72,
            color: status?.success ?? scheme.primary,
          ),
          const SizedBox(height: 20),
          const Text(
            'SOAP note ready',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Review the note before sharing or using it clinically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _presentation.recordingId.isEmpty ? null : _openSoapNote,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open SOAP note'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('View consultation'),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    final failure = _presentation.failure;
    final title = switch (failure?.phase) {
      IngestFailurePhase.upload => 'Could not upload audio',
      IngestFailurePhase.generate ||
      IngestFailurePhase.job => 'Generation failed',
      _ => 'Could not create the consultation',
    };
    final hasRecord = _presentation.recordingId.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.error_outline,
            size: 72,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (failure?.detail case final detail?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Spacer(),
          if (hasRecord)
            FilledButton.icon(
              onPressed: _viewConsultation,
              icon: const Icon(Icons.folder_outlined),
              label: const Text('View consultation'),
            )
          else
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to consultations'),
            ),
          const SizedBox(height: 8),
          if (!_presentation.audioRecoverable)
            Text(
              'Recorded audio is no longer recoverable on this phone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _elapsedLabel() {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
