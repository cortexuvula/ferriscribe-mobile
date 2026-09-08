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

/// The consultation workspace: searchable consultations (server-paged, 10 at
/// a time), a compact server-status line, and one primary New consultation
/// action.
///
/// Option B: the list is fetched from `GET /v1/recordings` with a composite
/// `(created_at, id)` cursor, ordered by consultation date. Each "Load more"
/// tap fetches the next page and appends with dedupe-by-id. Search is scoped
/// to loaded rows only (the UI says so explicitly).
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
  bool _oldServer = false; // 404/405 on /v1/recordings — pre-0.76.5 server
  String? _error;

  /// Accumulated recordings across pages, deduped by id.
  List<SyncRecording> _recordings = const [];

  /// Cursor for the next page fetch; null when we've reached the end.
  String? _nextCursor;

  /// Whether a "Load more" fetch is in flight (single-flight guard).
  bool _loadingMore = false;

  /// Whether the last "Load more" fetch failed (retry available).
  bool _loadMoreFailed = false;

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

  /// The holder's latest completed fact says unreachable — independent of
  /// this screen's list state (drives the Tailscale alert early).
  bool get _connectionUnreachable =>
      widget.services.connection.last is Unreachable;

  @override
  void dispose() {
    widget.services.connection.removeListener(_onConnectionChanged);
    _search.dispose();
    super.dispose();
  }

  /// Fetch the first page (refresh or initial load). Resets cursor and
  /// accumulated list.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
      _authNeedsAttention = false;
      _oldServer = false;
      _error = null;
      _recordings = const [];
      _nextCursor = null;
      _loadMoreFailed = false;
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
      try {
        final page = await client.listRecordingsPage(limit: 10);
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
        // Dedupe by id (server shouldn't duplicate, but defensive).
        final byId = <String, SyncRecording>{};
        for (final r in page.recordings) {
          byId[r.id] = r;
        }
        if (mounted) {
          setState(() {
            _recordings = byId.values.toList();
            _nextCursor = page.nextCursor;
            _loading = false;
          });
        }
      } finally {
        client.close();
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
    } on DataApiException catch (e) {
      // 404/405 = old server (pre-0.76.5, no /v1/recordings endpoint).
      if (e.statusCode == 404 || e.statusCode == 405) {
        widget.services.connection.publish(
          Unreachable(checkedAt: DateTime.now()),
          epoch: epoch,
        );
        if (mounted) {
          setState(() {
            _loading = false;
            _oldServer = true;
          });
        }
        return;
      }
      // Other HTTP errors fall through to the generic catch.
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

  /// Fetch the next page and append with dedupe-by-id. Single-flight: if a
  /// fetch is already in progress, this is a no-op.
  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    final token = await widget.services.serverConfigRepository.readToken();
    final config = await widget.services.serverConfigRepository.readCurrent();
    if (token == null || token.isEmpty || config == null) {
      setState(() => _loadingMore = false);
      return;
    }
    try {
      final client = DataApiClient.forConfig(config, token);
      try {
        final page = await client.listRecordingsPage(
          limit: 10,
          cursor: _nextCursor,
        );
        if (mounted) {
          setState(() {
            // Append with dedupe-by-id: a row whose created_at shifts between
            // page fetches (new recording landing mid-scroll) must not render
            // twice. An insertion-ordered map seeded old-then-new keeps
            // newest-first order; a collision keeps its first-insertion
            // position while the newer page's content wins (codie's pin —
            // pinned by `dedupe-by-id survives overlapping pages`).
            final byId = <String, SyncRecording>{};
            for (final r in _recordings) {
              byId[r.id] = r;
            }
            for (final r in page.recordings) {
              byId[r.id] = r;
            }
            _recordings = byId.values.toList();
            _nextCursor = page.nextCursor;
            _loadingMore = false;
          });
        }
      } finally {
        client.close();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _loadMoreFailed = true;
          // Rows and scroll position are retained — the user can retry.
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

  /// Search is scoped to loaded rows only (the UI says so explicitly).
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
          // V5 (user request) + visual review 8dd93c0: the Tailscale
          // alert is driven by the CONNECTION RESULT, not by list
          // completion — a fast failed probe shows the notice immediately
          // even while the list pull is still loading (the old
          // `_offline` gate left a bare 'Unreachable' label with no
          // alert during the hang).
          if (_connectionUnreachable)
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
          // Scoped to loaded rows only (Option B consequence: search cannot
          // reach rows not yet fetched). The label and empty copy say so
          // explicitly — ui-consultant's requirement.
          if (!_loading && _recordings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: 'Search loaded consultations',
                  hintText: 'Name or consultation',
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
                : _oldServer
                ? _buildOldServerError()
                : _error != null && _recordings.isEmpty
                ? _buildError()
                // Filtered-empty is distinct from genuinely-empty —
                // underlying data exists but nothing matches the query.
                : recordings.isEmpty && _recordings.isNotEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    message: 'No matches in loaded consultations',
                    supporting:
                        'Try a different search, or load more consultations.',
                    action: TextButton(
                      onPressed: () {
                        // Visual review 33fcdfa: clear BOTH the filter
                        // state and the visible field text.
                        _search.clear();
                        setState(() => _query = '');
                      },
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
                      key: const Key('consultations-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Rows + optional footer (load-more or retry).
                      itemCount: recordings.length + _footerCount,
                      separatorBuilder: (_, index) {
                        // No divider after the last row (before the footer).
                        if (index == recordings.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return Divider(height: 1, color: scheme.outlineVariant);
                      },
                      itemBuilder: (context, index) {
                        if (index >= recordings.length) {
                          return _buildFooter();
                        }
                        return _ConsultationRow(
                          rec: recordings[index],
                          onTap: () => _open(recordings[index]),
                        );
                      },
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

  /// Whether a footer row should be rendered (load-more or retry).
  int get _footerCount {
    if (_nextCursor != null || _loadMoreFailed) return 1;
    return 0;
  }

  Widget _buildFooter() {
    if (_loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: fullWidthButton(
          OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry loading more'),
          ),
        ),
      );
    }
    // Load-more footer: visible whenever a next cursor exists, even when
    // search yields no matches (ui-consultant's requirement: don't let the
    // No-matches branch swallow it).
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: fullWidthButton(
        OutlinedButton.icon(
          onPressed: _loadingMore ? null : _loadMore,
          icon: _loadingMore
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(_loadingMore ? 'Loading…' : 'Load more'),
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

  /// 404/405 on the list endpoint = old server (pre-0.76.5). Actionable:
  /// update the desktop app. Codie's requirement: never a silent empty list.
  Widget _buildOldServerError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 64),
        EmptyState(
          icon: Icons.system_update,
          message: 'Server update required',
          supporting:
              'The office server is running an older version. Update the '
              'desktop app to view consultations.',
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
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
