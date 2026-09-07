import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/models.dart';
import 'document_service.dart';
import 'recording_detail_screen.dart';

/// Phase 2 recordings list: pulls all recordings via content sync and opens
/// the per-recording document view. Falls back to the offline cache when the
/// server is unreachable.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  bool _loading = true;
  bool _offline = false;
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
      _offline = false;
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
    final service = DocumentService(cache: widget.services.offlineCache);
    try {
      final list = await service.listRecordings(config, token);
      if (mounted) {
        setState(() {
          _recordings = list;
          _loading = false;
        });
      }
    } catch (_) {
      // Offline fallback: serve the last-synced cache.
      final cached = await service.listRecordingsCached();
      if (mounted) {
        setState(() {
          _recordings = cached;
          _offline = true;
          _loading = false;
          _error = cached.isEmpty
              ? 'Server unreachable — nothing cached yet.'
              : null;
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_offline)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Offline — showing cached recordings.')),
                ],
              ),
            ),
          ),
        if (_error != null && _recordings.isEmpty) ...[
          const SizedBox(height: 24),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ] else if (_recordings.isEmpty) ...[
          const SizedBox(height: 80),
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No recordings yet. Record a consultation from the home screen.',
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const SizedBox(height: 4),
          for (final rec in _recordings)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(rec.patientName ?? rec.filename),
              subtitle: Text(_subtitle(rec)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(rec),
            ),
        ],
      ],
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
