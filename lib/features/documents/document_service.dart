import '../../core/api/data_api_client.dart';
import '../../core/app_logger.dart';
import '../../core/api/models.dart';
import '../../pairing/server_config_repository.dart';
import '../../storage/offline_cache_repository.dart';

/// Orchestrates Phase 2 document operations against the paired :11437 data
/// API: list recordings (content sync), fetch/save documents, and trigger
/// generation with progress.
///
/// Write-through offline cache: every successful pull and document fetch is
/// persisted to the SQLCipher cache so the data stays viewable offline.
class DocumentService {
  DocumentService({this.clientFactory = DataApiClient.forConfig, this.cache});

  final DataApiClient Function(ServerConfig, String) clientFactory;
  final OfflineCacheRepository? cache;

  DataApiClient _client(ServerConfig config, String token) =>
      clientFactory(config, token);

  /// Fetches all recordings (paginated full pull). Deduplicates by id and
  /// drops soft-deleted rows. Writes through to the offline cache on success.
  Future<List<SyncRecording>> listRecordings(
    ServerConfig config,
    String token,
  ) async {
    final client = _client(config, token);
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
        // Page by the last item's updated_at (server orders ascending).
        cursor = page.recordings.isNotEmpty
            ? page.recordings.last.updatedAt
            : page.serverTime;
      }
      final list = byId.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await cache?.replaceRecordings(list);
      return list;
    } finally {
      client.close();
    }
  }

  /// Reads the cached recordings list (offline fallback).
  Future<List<SyncRecording>> listRecordingsCached() async {
    if (cache == null) return const [];
    return cache!.readRecordings();
  }

  /// Fetches a single document's authoritative content, writing it through to
  /// the cache.
  Future<RecordingDocument> fetchDocument(
    ServerConfig config,
    String token,
    String recordingId,
    DocType doc,
  ) async {
    final client = _client(config, token);
    try {
      final d = await client.getDocument(recordingId, doc);
      final content = d.content;
      if (content != null && content.isNotEmpty) {
        await cache?.upsertDocument(recordingId, doc, content);
      }
      return d;
    } finally {
      client.close();
    }
  }

  /// Reads the last-cached document content (offline fallback).
  Future<String?> fetchDocumentCached(String recordingId, DocType doc) async {
    return cache?.readDocument(recordingId, doc);
  }

  /// Saves an edited document back to the server, then updates the cache.
  Future<void> saveDocument(
    ServerConfig config,
    String token,
    String recordingId,
    DocType doc,
    String content,
  ) async {
    final client = _client(config, token);
    try {
      await client.saveDocument(recordingId, doc, content);
    } finally {
      client.close();
    }
    // Cache write is deliberately OUTSIDE the server call and best-effort:
    // a successful server PUT (204) is the authoritative save — a local
    // cache failure must NOT surface as a failed save. The §6.5 adapter
    // tracks this separately via DocumentSaveResult.cacheWritten.
    try {
      await cache?.upsertDocument(recordingId, doc, content);
    } catch (e) {
      AppLog.event('document.save.cache-write-failed');
      // Intentionally swallowed: server state is the truth.
    }
  }

  /// Triggers generation and streams stage labels until terminal.
  ///
  /// Emits the raw server stage string (`generating_referral`, `completed`,
  /// `failed`, …). Callers refetch the document on `completed`.
  Stream<String> generate(
    ServerConfig config,
    String token,
    String recordingId,
    DocType doc,
    GenerateRequest request,
  ) async* {
    final client = _client(config, token);
    try {
      await client.generateDoc(recordingId, doc, request);
      await for (final snap in client.jobEvents(recordingId)) {
        yield snap.stage;
        if (snap.stage == 'completed' || snap.stage == 'failed') return;
      }
    } finally {
      client.close();
    }
  }
}
