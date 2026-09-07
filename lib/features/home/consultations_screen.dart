import 'package:flutter/material.dart';

import '../../app_bootstrap.dart';
import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../core/state/connection_state.dart';
import '../../core/state/presentation_adapters.dart';
import '../../ui/components/status.dart';
import '../../ui/theme/app_theme.dart';
import '../documents/recording_detail_screen.dart';
import '../recording/record_screen.dart';
import '../settings/settings_screen.dart';

/// The consultation workspace: searchable consultations, a compact
/// server-status line, and one primary New consultation action.
///
/// Replaces the action-only Home. Settings moves to the app bar.
class ConsultationsScreen extends StatefulWidget {
  const ConsultationsScreen({
    super.key,
    required this.services,
    required this.onUnpaired,
  });

  final AppServices services;
  final VoidCallback onUnpaired;

  @override
  State<ConsultationsScreen> createState() => _ConsultationsScreenState();
}

class _ConsultationsScreenState extends State<ConsultationsScreen> {
  bool _loading = true;
  bool _offline = false;
  bool _authNeedsAttention = false;
  String? _error;
  List<SyncRecording> _recordings = const [];

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.services.connection.addListener(_onConnectionChanged);
    _launchCheck();
    _load();
  }

  /// V5 / user request: launch-time reachability check, DISTINCT from
  /// the list pull — runs even while the list is loading, so the status
  /// line is truthful immediately and doesn't depend on the list
  /// resolving. Epoch-guarded so a slow probe can never overwrite a
  /// newer fact (turing's 57d5d8c guardrail).
  Future<void> _launchCheck() async {
    final config = await widget.services.serverConfigRepository.readCurrent();
    final token = await widget.services.serverConfigRepository.readToken();
    if (config == null || token == null || token.isEmpty) return;
    final holder = widget.services.connection;
    final epoch = holder.beginCheck();
    final state = await ConnectionStateAdapter().authenticatedCheck(
      config: config,
      token: token,
    );
    holder.publish(state, epoch: epoch);
  }

  void _onConnectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.services.connection.removeListener(_onConnectionChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
      _authNeedsAttention = false;
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
    // Epoch the sync fold (codie: without it, half the race surface is
    // unguarded — a slow launch probe could overwrite a stale fold, or
    // vice versa).
    final epoch = widget.services.connection.beginCheck();
    try {
      final client = DataApiClient.forConfig(config, token);
      final list = await _pullAll(client);
      // A successful authenticated read proves reachability AND pairing —
      // the strongest connection fact available.
      widget.services.connection.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.authenticatedRead,
          authOk: true,
        ),
        epoch: epoch,
      );
      if (mounted) {
        setState(() {
          _recordings = list;
          _loading = false;
        });
      }
    } on DataAuthException {
      widget.services.connection.publish(
        AuthFailure(checkedAt: DateTime.now()),
        epoch: epoch,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _authNeedsAttention = true;
        });
      }
    } catch (_) {
      // Offline fallback: serve the last-synced cache.
      widget.services.connection.publish(
        Unreachable(checkedAt: DateTime.now()),
        epoch: epoch,
      );
      final cached = await _loadCached();
      if (mounted) {
        setState(() {
          _recordings = cached;
          _offline = true;
          _loading = false;
        });
      }
    }
  }

  Future<List<SyncRecording>> _loadCached() async {
    try {
      return await widget.services.offlineCache.readRecordings();
    } catch (_) {
      return const [];
    }
  }

  void _newConsultation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordScreen(services: widget.services),
      ),
    );
  }

  void _open(SyncRecording rec) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RecordingDetailScreen(services: widget.services, recording: rec),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          services: widget.services,
          onUnpaired: widget.onUnpaired,
        ),
      ),
    );
  }

  List<SyncRecording> get _filtered {
    if (_query.isEmpty) return _recordings;
    final q = _query.toLowerCase();
    return _recordings
        .where(
          (r) =>
              (r.patientName ?? '').toLowerCase().contains(q) ||
              r.filename.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recordings = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FerriScribe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Compact server-status line ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLineText(),
                    style: TextStyle(
                      fontSize: 13,
                      color: _offline
                          ? Theme.of(
                                  context,
                                ).extension<AppStatusColors>()?.warning ??
                                Theme.of(context).colorScheme.onSurfaceVariant
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!_loading && _offline)
                  TextButton(onPressed: _load, child: const Text('Retry')),
                // V5: a Check affordance on the landing page itself
                // (§5A), not only buried in Settings.
                if (!_loading && !_offline)
                  TextButton(
                    onPressed: _launchCheck,
                    child: const Text('Check'),
                  ),
              ],
            ),
          ),
          // V5 (user request): an unreachable server is never a silent
          // offline label — name the cause and offer recovery, EVEN
          // while cached consultations are shown below.
          if (!_loading && _offline)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: NoticeBanner(
                tone: AppStatusTone.warning,
                text:
                    'Could not reach your office server. Check that the '
                    'desktop app and Tailscale are running.',
              ),
            ),
          // ── Search ─────────────────────────────────────────────────
          if (!_loading && _recordings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search name or consultation',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
          // ── Content ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const ListLoadingState(label: 'Loading consultations…')
                // V4: auth denial renders independent of _error — the
                // 401 catch sets _authNeedsAttention without _error, and
                // previously fell through to the generic empty state.
                : _authNeedsAttention
                ? _buildError()
                : _error != null && _recordings.isEmpty
                ? _buildError()
                // V4: filtered-empty is distinct from genuinely-empty —
                // underlying data exists but nothing matches the query.
                : recordings.isEmpty && _recordings.isNotEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    message: 'No matches',
                    supporting: 'Try a different search.',
                    action: TextButton(
                      onPressed: () => setState(() => _query = ''),
                      child: const Text('Clear search'),
                    ),
                  )
                : recordings.isEmpty && _recordings.isEmpty
                ? EmptyState(
                    icon: Icons.mic_none,
                    message: 'No consultations yet',
                    supporting: 'Record a consultation to get started.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: recordings.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: scheme.outlineVariant),
                      itemBuilder: (context, index) => _ConsultationRow(
                        rec: recordings[index],
                        onTap: () => _open(recordings[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      // ── One primary action ────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: FilledButton.icon(
          onPressed: _newConsultation,
          icon: const Icon(Icons.mic),
          label: const Text('New consultation'),
        ),
      ),
    );
  }

  Widget _buildError() {
    final authIssue = _authNeedsAttention;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 64),
        EmptyState(
          icon: authIssue ? Icons.link_off : Icons.cloud_off,
          message: authIssue
              ? 'Pairing needs attention'
              : 'Could not reach your office server',
          supporting: authIssue
              ? 'Your device may have been unpaired on the server.'
              : 'Check that the desktop app and Tailscale are running.',
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            onPressed: authIssue ? _openSettings : _load,
            child: Text(authIssue ? 'Settings' : 'Retry'),
          ),
        ),
      ],
    );
  }

  String _statusLineText() {
    if (_offline) return 'Offline · showing cached consultations';
    final c = widget.services.connection;
    if (c.checking && c.last == null) return 'Office server · Checking…';
    return 'Office server · ${c.label}';
  }

  /// Paged full pull with 401 surfaced as a distinct auth failure and the
  /// offline cache written through on success.
  Future<List<SyncRecording>> _pullAll(DataApiClient client) async {
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
      final list = byId.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await widget.services.offlineCache.replaceRecordings(list);
      return list;
    } on DataApiException catch (e) {
      if (e.statusCode == 401) throw DataAuthException();
      rethrow;
    }
  }
}

/// Auth rejected — pairing needs attention (distinct from offline).
class DataAuthException implements Exception {}

/// One consultation row: title, time line, one concise status.
class _ConsultationRow extends StatelessWidget {
  const _ConsultationRow({required this.rec, required this.onTap});

  final SyncRecording rec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        rec.patientName ??
        (rec.filename.isNotEmpty
            ? rec.filename
            : 'Consultation · ${_shortDate(rec.createdAt)}');

    final status = _deriveStatus(rec);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      minVerticalPadding: 14,
      onTap: onTap,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _timeLine(rec),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            status,
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
    );
  }

  /// One concise status derived ONLY from actual fields.
  Widget _deriveStatus(SyncRecording rec) {
    if (rec.hasDoc(DocType.soap)) {
      return const StatusLine(
        tone: AppStatusTone.success,
        text: 'SOAP available',
        dense: true,
      );
    }
    final anyDoc = DocType.values.any(rec.hasDoc);
    return StatusLine(
      tone: AppStatusTone.neutral,
      text: anyDoc ? 'Documents available' : 'No documents yet',
      dense: true,
    );
  }

  String _timeLine(SyncRecording rec) {
    final parts = <String>[];
    final created = _formatLocal(rec.createdAt);
    if (created != null) parts.add(created);
    if (rec.durationSeconds != null && rec.durationSeconds! > 0) {
      final s = rec.durationSeconds!.round();
      parts.add('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}');
    }
    return parts.join(' · ');
  }

  String? _formatLocal(String rfc3339) {
    final dt = DateTime.tryParse(rfc3339);
    if (dt == null || dt.year <= 1971) return null;
    final local = dt.toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${days[local.weekday - 1]} ${local.day} ${months[local.month - 1]} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _shortDate(String rfc3339) {
    final dt = DateTime.tryParse(rfc3339);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}';
  }
}
