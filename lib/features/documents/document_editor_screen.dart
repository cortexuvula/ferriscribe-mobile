import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_bootstrap.dart';
import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../pairing/server_config_repository.dart';
import '../../core/state/document_state.dart';
import '../../core/state/presentation_adapters.dart';
import '../../ui/components/status.dart';
import 'document_service.dart';

/// Reader + editor for one document (§5G) — the central clinical surface.
///
/// Reader: state line `From office server` / `Cached copy · offline`,
/// explicit Edit / Export & share / Copy text. Edit mode: visible
/// Unsaved changes / Saving… / Saved status, no autosave, save failure is
/// an inline error over the STILL-VISIBLE buffer with Retry save (never a
/// reload), dirty-exit offers Save & leave / Discard changes / Keep editing.
/// Offline entry is read-only with a banner; native text selection Copy
/// stays available everywhere, programmatic copy is explicit only.
class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({
    super.key,
    required this.services,
    required this.recordingId,
    required this.doc,
    this.clientFactory,
  });

  final AppServices services;
  final String recordingId;
  final DocType doc;

  /// Optional injectable client factory (tests). Production builds clients
  /// against the paired server config.
  final DataApiClient Function(ServerConfig, String)? clientFactory;

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

/// Save flow status for the edit mode state line.
enum _SaveStatus { clean, dirty, saving, saved, failedServer, failedNetwork }

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _editing = false;
  bool _offlineEntry = false;
  bool _authNeedsAttention = false;
  _SaveStatus _saveStatus = _SaveStatus.clean;
  String? _loadError;

  DocumentLoad? _load;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Loads via the §6.2 adapter: server-authoritative, cache-annotated,
  /// auth failures typed.
  Future<void> _loadDocument() async {
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Not paired.';
        });
      }
      return;
    }
    final adapter = DocumentStateAdapter(
      cache: widget.services.offlineCache,
      service: DocumentService(
        clientFactory: widget.clientFactory ?? DataApiClient.forConfig,
        cache: widget.services.offlineCache,
      ),
    );
    try {
      final load = await adapter.load(
        config: config,
        token: token,
        recordingId: widget.recordingId,
        doc: widget.doc,
      );
      if (!mounted) return;
      setState(() {
        _load = load;
        _loading = false;
        _offlineEntry = load.source == DocumentSource.cache;
        _controller.text = load.content ?? '';
        _saveStatus = _SaveStatus.clean;
        _loadError = null;
      });
    } on DocumentAuthException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _authNeedsAttention = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load document.';
      });
    }
  }

  bool get _dirty =>
      _editing && _saveStatus == _SaveStatus.dirty ||
      _saveStatus == _SaveStatus.failedServer ||
      _saveStatus == _SaveStatus.failedNetwork;

  void _startEditing() {
    if (_offlineEntry) return; // read-only cached entry (§5G)
    setState(() {
      _editing = true;
      _saveStatus = _SaveStatus.clean;
    });
  }

  Future<void> _save() async {
    if (_saveStatus == _SaveStatus.saving) return; // single-flight
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      if (mounted) {
        setState(() => _saveStatus = _SaveStatus.failedNetwork);
      }
      return;
    }
    setState(() => _saveStatus = _SaveStatus.saving);
    final adapter = DocumentStateAdapter(
      cache: widget.services.offlineCache,
      service: DocumentService(
        clientFactory: widget.clientFactory ?? DataApiClient.forConfig,
        cache: widget.services.offlineCache,
      ),
    );
    try {
      final result = await adapter.save(
        config: config,
        token: token,
        recordingId: widget.recordingId,
        doc: widget.doc,
        content: _controller.text,
      );
      if (!mounted) return;
      if (result.saved) {
        // Server has the edit. A stale offline copy is a notice, not a
        // save failure (§6.5).
        setState(() => _saveStatus = _SaveStatus.saved);
        if (!result.cacheWritten) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved. Offline copy could not be updated.'),
            ),
          );
        }
      } else {
        setState(() => _saveStatus = _SaveStatus.failedNetwork);
      }
    } on DocumentAuthException {
      if (mounted) {
        setState(() => _saveStatus = _SaveStatus.failedServer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pairing needs attention.')),
        );
      }
    } catch (_) {
      // Buffer stays visible and dirty; Retry save re-sends the PUT (§5G).
      if (mounted) setState(() => _saveStatus = _SaveStatus.failedNetwork);
    }
  }

  /// §5G: dirty-exit three-way decision — Save & leave / Discard changes /
  /// Keep editing. Leave-after-save only on confirmed success.
  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'Your edits have not been saved to the office server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard changes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save & leave'),
          ),
        ],
      ),
    );
    switch (action) {
      case 'discard':
        return true;
      case 'save':
        await _save();
        return _saveStatus == _SaveStatus.saved;
      default:
        return false;
    }
  }

  /// Explicit copy only (§5G) — never auto-copy.
  void _copy() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _confirmExit();
        if (allow && mounted) {
          // ignore: use_build_context_synchronously — guarded by State.mounted
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.doc.label),
          actions: [
            if (_loading == false && _loadError == null && !_authNeedsAttention)
              if (!_editing) ...[
                // Reader actions (§5G): Edit primary, explicit Copy.
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy text',
                  onPressed: _copy,
                ),
                if (!_offlineEntry)
                  TextButton(
                    onPressed: _startEditing,
                    child: const Text('Edit'),
                  ),
              ] else ...[
                // Edit mode: explicit Copy stays available for one's edits.
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy text',
                  onPressed: _copy,
                ),
              ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _authNeedsAttention
            ? _buildAuthIssue(scheme)
            : _loadError != null
            ? _buildLoadError(scheme)
            : _buildBody(scheme),
        // Footer (§5G): Edit primary in reader; Save changes in edit mode.
        bottomNavigationBar: _loading || _loadError != null
            ? null
            : Builder(
                builder: (context) {
                  final footer = _buildFooter(scheme);
                  if (footer == null) return const SizedBox.shrink();
                  return SafeArea(
                    minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: footer,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildAuthIssue(ColorScheme scheme) {
    return EmptyState(
      icon: Icons.link_off,
      message: 'Pairing needs attention',
      supporting:
          'Your device may have been unpaired on the server. Re-pair from '
          'the start screen.',
    );
  }

  Widget _buildLoadError(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EmptyState(
          icon: Icons.cloud_off,
          message: 'Could not load document',
          supporting: _loadError!,
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            // Retry reloads the document (a load failure, not a save).
            onPressed: () {
              setState(() => _loading = true);
              _loadDocument();
            },
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    return Column(
      children: [
        // State line (§5G): honest source + time.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [Expanded(child: _sourceLine(scheme))]),
        ),
        if (_offlineEntry && !_editing) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: NoticeBanner(
              tone: AppStatusTone.warning,
              text: 'Cached copy · reconnect to edit or export',
            ),
          ),
        ],
        if (_editing) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _saveStatusLine(scheme),
          ),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _editing ? _buildEditor(scheme) : _buildReader(scheme),
          ),
        ),
      ],
    );
  }

  /// §5G state line: source + honest timestamp.
  Widget _sourceLine(ColorScheme scheme) {
    final load = _load;
    if (load == null) return const SizedBox.shrink();
    if (load.source == DocumentSource.server) {
      final stamp = load.updatedAt?.toLocal();
      return StatusLine(
        tone: AppStatusTone.success,
        text: stamp == null
            ? 'From office server'
            : 'From office server · updated ${_fmt(stamp)}',
        dense: true,
      );
    }
    final stamp = load.cachedUpdatedAt?.toLocal();
    return StatusLine(
      tone: AppStatusTone.warning,
      text: stamp == null
          ? 'Cached copy · offline'
          : 'Cached copy · saved ${_fmt(stamp)}',
      dense: true,
    );
  }

  /// §5G edit-mode status: Unsaved changes / Saving… / Saved / errors.
  Widget _saveStatusLine(ColorScheme scheme) {
    final (text, tone) = switch (_saveStatus) {
      _SaveStatus.clean => ('No changes yet', AppStatusTone.neutral),
      _SaveStatus.dirty => ('Unsaved changes', AppStatusTone.warning),
      _SaveStatus.saving => ('Saving…', AppStatusTone.neutral),
      _SaveStatus.saved => ('Saved to office server', AppStatusTone.success),
      _SaveStatus.failedServer => (
        'Not saved · pairing needs attention',
        AppStatusTone.error,
      ),
      _SaveStatus.failedNetwork => (
        'Not saved · reconnect to save',
        AppStatusTone.error,
      ),
    };
    return StatusLine(tone: tone, text: text);
  }

  Widget _buildReader(ColorScheme scheme) {
    final content = _controller.text;
    if (content.isEmpty) {
      return Center(
        child: Text(
          'Not generated yet',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    // Constant unobtrusive helper (§5G).
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review generated content before clinical use.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEditor(ColorScheme scheme) {
    return TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      // Explicit contrast (core clinical surface).
      style: TextStyle(color: scheme.onSurface, fontSize: 16, height: 24 / 16),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: 'Not generated yet',
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      onChanged: (_) {
        if (_saveStatus != _SaveStatus.dirty &&
            _saveStatus != _SaveStatus.saving) {
          setState(() => _saveStatus = _SaveStatus.dirty);
        }
      },
    );
  }

  Widget? _buildFooter(ColorScheme scheme) {
    if (_authNeedsAttention || _loadError != null) return null;
    if (_editing) {
      return FilledButton.icon(
        onPressed: _saveStatus == _SaveStatus.saving ? null : _save,
        icon: _saveStatus == _SaveStatus.saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _saveStatus == _SaveStatus.failedServer ||
                  _saveStatus == _SaveStatus.failedNetwork
              ? 'Retry save'
              : 'Save changes',
        ),
      );
    }
    if (_offlineEntry) return null; // read-only cached (§5G)
    return FilledButton.tonalIcon(
      onPressed: _startEditing,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit'),
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }
}
