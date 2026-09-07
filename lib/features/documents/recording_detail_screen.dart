import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/models.dart';
import '../export/export_service.dart';
import 'document_editor_screen.dart';
import 'document_service.dart';

/// Per-recording view: five document types, each with generate / view-edit.
class RecordingDetailScreen extends StatefulWidget {
  const RecordingDetailScreen({
    super.key,
    required this.services,
    required this.recording,
  });

  final AppServices services;
  final SyncRecording recording;

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  final DocumentService _service = DocumentService();
  final ExportService _exportService = ExportService();

  /// Which doc type is currently generating (drives the spinner).
  DocType? _generating;
  DocType? _exporting;
  String? _generateError;
  final Map<DocType, bool> _hasContent = {};

  @override
  void initState() {
    super.initState();
    for (final d in DocType.values) {
      _hasContent[d] = widget.recording.hasDoc(d);
    }
  }

  Future<void> _generate(DocType doc) async {
    final request = await _requestFor(doc);
    if (request == null) return;

    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      _showError('Not paired.');
      return;
    }

    setState(() {
      _generating = doc;
      _generateError = null;
    });

    StreamSubscription<String>? sub;
    try {
      sub = _service
          .generate(config, token, widget.recording.id, doc, request)
          .listen(
            (stage) {
              if (stage == 'completed' && mounted) {
                setState(() {
                  _hasContent[doc] = true;
                  _generating = null;
                });
              }
            },
            onError: (Object _) {
              if (mounted) {
                setState(() {
                  _generating = null;
                  _generateError = 'Generation failed.';
                });
              }
            },
            onDone: () {
              if (mounted && _generating == doc) {
                setState(() => _generating = null);
              }
            },
          );
    } catch (_) {
      if (mounted) setState(() => _generateError = 'Generation failed.');
    } finally {
      // Stream completes on its own; the listener manages state.
      sub;
    }
  }

  /// Builds the generate request for a doc type, prompting for required
  /// fields (peer_discussion) via a dialog. Returns null if cancelled.
  Future<GenerateRequest?> _requestFor(DocType doc) async {
    if (doc == DocType.peerDiscussion) {
      final result = await showPeerDiscussionForm(context);
      if (result == null) return null;
      return GenerateRequest(
        physicianName: result[0],
        specialty: result[1],
        reason: result[2],
      );
    }
    return const GenerateRequest();
  }

  void _openEditor(DocType doc) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => DocumentEditorScreen(
              services: widget.services,
              recordingId: widget.recording.id,
              doc: doc,
            ),
          ),
        )
        .then((_) {
          // Refresh existence after a possible edit.
          if (mounted) setState(() => _hasContent[doc] = true);
        });
  }

  void _showError(String message) {
    if (mounted) setState(() => _generateError = message);
  }

  /// Prompts for a format then exports + shares the rendered document.
  Future<void> _export(DocType doc) async {
    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Export as')),
            for (final f in ExportFormat.values)
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(f.label),
                onTap: () => Navigator.pop(context, f),
              ),
          ],
        ),
      ),
    );
    if (format == null) return;

    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      _showError('Not paired.');
      return;
    }

    setState(() => _exporting = doc);
    final outcome = await _exportService.exportAndShare(
      config: config,
      token: token,
      recordingId: widget.recording.id,
      doc: doc,
      format: format,
    );
    if (!mounted) return;
    setState(() => _exporting = null);
    if (!outcome.ok) _showError(outcome.error ?? 'Export failed.');
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recording;
    return Scaffold(
      appBar: AppBar(title: Text(rec.patientName ?? rec.filename)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(rec.filename, style: const TextStyle(color: Colors.grey)),
          if (rec.durationSeconds != null)
            Text(
              '${rec.durationSeconds!.round()}s · updated ${_short(rec.updatedAt)}',
              style: const TextStyle(color: Colors.grey),
            ),
          if (_generateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Text(
                    _generateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _generateError = null),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (final doc in DocType.values) _docTile(doc),
        ],
      ),
    );
  }

  Widget _docTile(DocType doc) {
    final has = _hasContent[doc] ?? false;
    final generating = _generating == doc;
    return Card(
      child: ListTile(
        leading: Icon(
          has ? Icons.check_circle_outline : Icons.circle_outlined,
          color: has ? Colors.green : null,
        ),
        title: Text(doc.label),
        trailing: generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (has) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: () => _openEditor(doc),
                    ),
                    IconButton(
                      icon: _exporting == doc
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_outlined),
                      tooltip: 'Export',
                      onPressed: _exporting == null ? () => _export(doc) : null,
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.auto_awesome_outlined),
                      tooltip: 'Generate',
                      onPressed: () => _generate(doc),
                    ),
                ],
              ),
      ),
    );
  }

  String _short(String rfc3339) {
    if (rfc3339.length < 16) return rfc3339;
    return rfc3339.substring(0, 16).replaceFirst('T', ' ');
  }
}

/// Prompts for the three required peer-discussion fields. Returns
/// `[physician, specialty, reason]` or null on cancel.
Future<List<String>?> showPeerDiscussionForm(BuildContext context) {
  final physician = TextEditingController();
  final specialty = TextEditingController();
  final reason = TextEditingController();
  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Peer discussion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: physician,
            decoration: const InputDecoration(labelText: 'Consultant name'),
          ),
          TextField(
            controller: specialty,
            decoration: const InputDecoration(labelText: 'Specialty'),
          ),
          TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final p = physician.text.trim();
            final s = specialty.text.trim();
            final r = reason.text.trim();
            if (p.isEmpty || s.isEmpty || r.isEmpty) return; // required
            Navigator.pop(context, [p, s, r]);
          },
          child: const Text('Generate'),
        ),
      ],
    ),
  );
}
