import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../pairing/server_config_repository.dart';

/// Orchestrates Phase 2 document operations against the paired :11437 data
/// API: list recordings (content sync), fetch/save documents, and trigger
/// generation with progress.
class DocumentService {
  DocumentService({this.clientFactory = DataApiClient.forConfig});

  final DataApiClient Function(ServerConfig, String) clientFactory;

  DataApiClient _client(ServerConfig config, String token) =>
      clientFactory(config, token);

  /// Fetches all recordings (paginated full pull). Deduplicates by id and
  /// drops soft-deleted rows.
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
      return list;
    } finally {
      client.close();
    }
  }

  /// Fetches a single document's authoritative content.
  Future<RecordingDocument> fetchDocument(
    ServerConfig config,
    String token,
    String recordingId,
    DocType doc,
  ) async {
    final client = _client(config, token);
    try {
      return await client.getDocument(recordingId, doc);
    } finally {
      client.close();
    }
  }

  /// Saves an edited document back to the server.
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
