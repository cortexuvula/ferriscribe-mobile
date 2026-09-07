import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/models.dart';
import 'document_service.dart';
import 'recording_detail_screen.dart';

/// Phase 2 recordings list: pulls all recordings via content sync and opens
/// the per-recording document view.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final DocumentService _service = DocumentService();

  bool _loading = true;
  String? _error;
  List<SyncRecording> _recordings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Not paired — pair with a server first.';
        });
      }
      return;
    }
    try {
      final list = await _service.listRecordings(config, token);
      if (mounted) {
        setState(() {
          _recordings = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load recordings.';
        });
      }
    }
  }

  void _open(SyncRecording rec) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RecordingDetailScreen(services: widget.services, recording: rec),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordings')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    if (_recordings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No recordings yet. Record a consultation from the home screen.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _recordings.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final rec = _recordings[index];
        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(rec.patientName ?? rec.filename),
          subtitle: Text(_subtitle(rec)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(rec),
        );
      },
    );
  }

  String _subtitle(SyncRecording rec) {
    final parts = <String>[];
    if (rec.durationSeconds != null) {
      final s = rec.durationSeconds!.round();
      parts.add('${s ~/ 60}m ${s % 60}s');
    }
    final docs = DocType.values.where(rec.hasDoc).map((d) => d.label).toList();
    if (docs.isNotEmpty) parts.add(docs.join(', '));
    return parts.join(' · ');
  }
}
