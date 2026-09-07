import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../core/state/document_state.dart';
import '../../core/state/presentation_adapters.dart';
import '../../pairing/server_config_repository.dart';
import '../../ui/components/status.dart';
import '../export/export_service.dart';
import 'document_editor_screen.dart';
import 'document_service.dart';

/// Per-recording view (§5F): readable document rows with real states.
///
/// Rows show name + state (Available / Not generated / Generating… / Cached
/// copy / Not cached). Availability comes from real server fields; cached
/// availability is queried independently via [CachedDocAvailability] — never
/// from `hasDoc` on a cached row (which lies offline).
class RecordingDetailScreen extends StatefulWidget {
  RecordingDetailScreen({
    super.key,
    required this.services,
    required this.recording,
    this.clientFactory,
  }) : recordingId = recording!.id;

  /// Id-keyed entry: fetches authoritative metadata on open.
  const RecordingDetailScreen.byId({
    super.key,
    required this.services,
    required this.recordingId,
    this.clientFactory,
  }) : recording = null;

  final AppServices services;

  /// The recording, when navigated from the list. Null for the id-keyed
  /// entry until [RecordingDetailScreen.byId] resolves it.
  final SyncRecording? recording;

  /// The recording id — always present.
  final String recordingId;

  /// Optional injectable client factory (tests). Production builds clients
  /// against the paired server config.
  final DataApiClient Function(ServerConfig, String)? clientFactory;

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

/// Row-level document state for display.
enum _DocRowState { available, notGenerated, generating, cachedOnly, notCached }

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  final ExportService _exportService = ExportService();

  SyncRecording? _resolved;
  bool _offline = false;
  bool _authNeedsAttention = false;

  /// True while the id-keyed metadata fetch (or a refresh) is in flight.
  /// §5A/§5F: a labelled loading state, never a silent near-black screen.
  bool _metadataLoading = false;

  /// Which doc type is currently generating — per-type, so other rows never
  /// appear idle while one runs (§5F).
  DocType? _generating;
  DocType? _exporting;
  String? _generateError;

  /// Server-field availability (from the resolved recording) and cached
  /// availability (from CachedDocuments) — tracked as separate facts.
  final Map<DocType, bool> _serverHas = {};
  CachedDocAvailability? _cached;

  @override
  void initState() {
    super.initState();
    _resolved = widget.recording;
    if (_resolved != null) {
      _seed(_resolved!);
    } else {
      // Id-keyed entry: show a labelled loading state until the fetch lands.
      _metadataLoading = true;
    }
    _load();
  }

  /// Loads metadata (when id-keyed) + cached availability.
  Future<void> _load() async {
    await _resolveRecording();
    await _loadCached();
    if (mounted) setState(() => _metadataLoading = false);
  }

  /// Fetch real metadata by id — no fabricated SyncRecording.
  Future<void> _resolveRecording() async {
    if (_resolved != null) return; // already have it from the list
    if (mounted) setState(() => _metadataLoading = true);
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) return;
    final client = (widget.clientFactory ?? DataApiClient.forConfig)(
      config,
      token,
    );
    try {
      final byId = <String, SyncRecording>{};
      String? cursor;
      var guard = 0;
      while (guard++ < 50) {
        final page = await client.pullContent(since: cursor);
        for (final r in page.recordings) {
          if (!r.isDeleted) byId[r.id] = r;
        }
        if (!page.hasMore) break;
        cursor = page.recordings.isNotEmpty
            ? page.recordings.last.updatedAt
            : page.serverTime;
      }
      final match = byId[widget.recordingId];
      if (match != null && mounted) {
        setState(() {
          _resolved = match;
          _seed(match);
          _offline = false;
          _authNeedsAttention = false;
        });
      }
    } on DataApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        if (mounted) setState(() => _authNeedsAttention = true);
      } else if (mounted) {
        setState(() => _offline = true);
      }
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    } finally {
      client.close();
    }
  }

  /// Cached availability, queried independently of the recording's fields
  /// (§6.3): a cached row's `fields` are always empty offline, so `hasDoc`
  /// lies — this doesn't.
  Future<void> _loadCached() async {
    final adapter = DocumentStateAdapter(cache: widget.services.offlineCache);
    try {
      final availability = await adapter.availability(widget.recordingId);
      if (mounted) setState(() => _cached = availability);
    } catch (_) {
      // Cache read failure: rows render from server facts only.
    }
  }

  void _seed(SyncRecording rec) {
    for (final d in DocType.values) {
      _serverHas[d] = rec.hasDoc(d);
    }
  }

  Future<void> _generate(DocType doc) async {
    if (_generating != null) return; // one generation at a time (§5F)
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

    final service = DocumentService(cache: widget.services.offlineCache);
    final sub = service
        .generate(config, token, widget.recordingId, doc, request)
        .listen(
          (stage) {
            if (stage == 'completed' && mounted) {
              setState(() {
                _serverHas[doc] = true;
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
    _generateSub = sub;
  }

  StreamSubscription<String>? _generateSub;

  @override
  void dispose() {
    _generateSub?.cancel();
    super.dispose();
  }

  /// Builds the generate request, prompting for peer-discussion's required
  /// fields via a form (§5H). Returns null if cancelled.
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
              recordingId: widget.recordingId,
              doc: doc,
            ),
          ),
        )
        .then((_) {
          // Refresh both facts after a possible edit/generate.
          _load();
        });
  }

  void _showError(String message) {
    if (mounted) setState(() => _generateError = message);
  }

  /// Export & share flow (§5I): format sheet → download → system share.
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
      recordingId: widget.recordingId,
      doc: doc,
      format: format,
    );
    if (!mounted) return;
    setState(() => _exporting = null);
    if (!outcome.ok) _showError(outcome.error ?? 'Export failed.');
  }

  /// Row state for a doc type — real facts only (§5F).
  _DocRowState _rowState(DocType doc) {
    if (_generating == doc) return _DocRowState.generating;
    final serverHas = _serverHas[doc] ?? false;
    if (serverHas) return _DocRowState.available;
    final cachedHas = _cached?.has(doc) ?? false;
    if (cachedHas) return _DocRowState.cachedOnly;
    return _DocRowState.notGenerated;
  }

  @override
  Widget build(BuildContext context) {
    final rec = _resolved;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(rec?.patientName ?? rec?.filename ?? 'Consultation'),
      ),
      body: _metadataLoading && rec == null
          ? _buildMetadataLoading(scheme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (rec?.filename.isNotEmpty == true)
                  Text(
                    rec!.filename,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                if (rec?.durationSeconds != null)
                  Text(
                    '${rec!.durationSeconds!.round()}s · updated ${_short(rec.updatedAt)}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                if (_authNeedsAttention) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(
                    tone: AppStatusTone.error,
                    text:
                        'Pairing needs attention — documents may be unavailable.',
                  ),
                ] else if (_offline) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(
                    tone: AppStatusTone.warning,
                    text: 'Offline · showing what is available on this phone.',
                  ),
                ],
                if (_generateError != null) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(
                    tone: AppStatusTone.error,
                    text: _generateError!,
                    actionLabel: 'Dismiss',
                    onAction: () => setState(() => _generateError = null),
                  ),
                ],
                const SizedBox(height: 12),
                for (final doc in DocType.values) _docRow(doc),
              ],
            ),
    );
  }

  /// Labelled loading state for the id-keyed entry — never a silent dark
  /// screen (the §5A 'labelled progress' requirement).
  Widget _buildMetadataLoading(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Opening consultation…',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            'Fetching from your office server.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// §5F document row: name + state, whole-row opens available content,
  /// absent content exposes a labelled Generate action.
  Widget _docRow(DocType doc) {
    final scheme = Theme.of(context).colorScheme;
    final state = _rowState(doc);
    final busy = _generating != null && _generating != doc;

    final (stateLabel, stateTone) = switch (state) {
      _DocRowState.available => ('Available', AppStatusTone.success),
      _DocRowState.generating => ('Generating…', AppStatusTone.neutral),
      _DocRowState.cachedOnly => ('Cached copy', AppStatusTone.warning),
      _DocRowState.notGenerated => ('Not generated', AppStatusTone.neutral),
      _DocRowState.notCached => ('Not cached', AppStatusTone.neutral),
    };

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          // Whole row opens available/cached content (§5F).
          onTap:
              state == _DocRowState.available ||
                  state == _DocRowState.cachedOnly
              ? () => _openEditor(doc)
              : null,
          title: Text(
            doc.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusLine(tone: stateTone, text: stateLabel, dense: true),
          ),
          trailing: _trailing(doc, state, busy),
        ),
        if (doc != DocType.values.last)
          Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }

  Widget? _trailing(DocType doc, _DocRowState state, bool busy) {
    if (state == _DocRowState.generating) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (state == _DocRowState.notGenerated) {
      if (busy) {
        // One generation at a time: disabled with reason nearby (§5F).
        return const Tooltip(
          message: 'Another document is generating',
          child: Icon(Icons.auto_awesome_outlined, size: 20),
        );
      }
      return TextButton.icon(
        onPressed: _generating == null ? () => _generate(doc) : null,
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Text('Generate'),
      );
    }
    if (state == _DocRowState.cachedOnly && _offline) {
      // Read-only cached copy offline; no fake Generate/Export while
      // offline (§5F).
      return null;
    }
    // Available: export lives with the document (§5F).
    return IconButton(
      icon: _exporting == doc
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share_outlined),
      tooltip: 'Export & share',
      onPressed: _exporting == null ? () => _export(doc) : null,
    );
  }

  String _short(String rfc3339) {
    if (rfc3339.length < 16) return rfc3339;
    return rfc3339.substring(0, 16).replaceFirst('T', ' ');
  }
}

/// Prompts for the three required peer-discussion fields (§5H): inline
/// validation, focus to first invalid field, no silent no-op.
/// Returns `[physician, specialty, reason]` or null on cancel.
Future<List<String>?> showPeerDiscussionForm(BuildContext context) {
  final physician = TextEditingController();
  final specialty = TextEditingController();
  final reason = TextEditingController();
  final physicianFocus = FocusNode();
  final specialtyFocus = FocusNode();
  final reasonFocus = FocusNode();
  final errorText = ValueNotifier<String?>(null);

  return showDialog<List<String>>(
    context: context,
    builder: (context) => ValueListenableBuilder<String?>(
      valueListenable: errorText,
      builder: (context, error, _) => AlertDialog(
        title: const Text('Peer discussion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: physician,
              focusNode: physicianFocus,
              decoration: InputDecoration(
                labelText: 'Consultant name *',
                errorText: error == 'physician' ? 'Required' : null,
              ),
            ),
            TextField(
              controller: specialty,
              focusNode: specialtyFocus,
              decoration: InputDecoration(
                labelText: 'Specialty *',
                errorText: error == 'specialty' ? 'Required' : null,
              ),
            ),
            TextField(
              controller: reason,
              focusNode: reasonFocus,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for discussion *',
                errorText: error == 'reason' ? 'Required' : null,
              ),
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
              // Inline validation with focus to the FIRST invalid field —
              // never a silent no-op (§5H).
              if (p.isEmpty) {
                errorText.value = 'physician';
                physicianFocus.requestFocus();
                return;
              }
              if (s.isEmpty) {
                errorText.value = 'specialty';
                specialtyFocus.requestFocus();
                return;
              }
              if (r.isEmpty) {
                errorText.value = 'reason';
                reasonFocus.requestFocus();
                return;
              }
              Navigator.pop(context, [p, s, r]);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    ),
  );
}
