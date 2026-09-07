import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_bootstrap.dart';
import '../../core/api/models.dart';
import 'document_service.dart';

/// Editor for a single document. Fetches authoritative content on open, edits
/// in place, and saves via `PUT …/documents/{doc_type}`.
///
/// Clipboard: only the explicit "Copy" action copies content — never
/// auto-copy on load, save, or generate.
class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({
    super.key,
    required this.services,
    required this.recordingId,
    required this.doc,
  });

  final AppServices services;
  final String recordingId;
  final DocType doc;

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final DocumentService _service = DocumentService();
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Not paired.';
        });
      }
      return;
    }
    try {
      final doc = await _service.fetchDocument(
        config,
        token,
        widget.recordingId,
        widget.doc,
      );
      if (mounted) {
        _controller.text = doc.content ?? '';
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load document.';
        });
      }
    }
  }

  Future<void> _save() async {
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      if (mounted) setState(() => _error = 'Not paired.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveDocument(
        config,
        token,
        widget.recordingId,
        widget.doc,
        _controller.text,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _dirty = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Save failed.';
        });
      }
    }
  }

  void _copy() {
    // Explicit user-initiated copy only.
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy',
            onPressed: _loading ? null : _copy,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: (_loading || _saving || !_dirty) ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Not generated yet',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ),
    );
  }
}
