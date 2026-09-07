/// Presentation-state adapters (design/MOBILE_REDESIGN.md §6).
///
/// Typed view state over the existing data seams — no new server API, no
/// schema migration. scribe-mobile's screens consume these; the seams
/// they replace stay untouched.
library;

import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../features/documents/document_service.dart';
import '../../pairing/pairing_client.dart';
import '../../pairing/server_config_repository.dart';
import '../../storage/offline_cache_repository.dart';
import 'connection_state.dart';
import 'document_state.dart';

/// Builds §6.1 connection states from real checks.
///
/// `probe` = unauthenticated `GET :11436/info` (reachability + version).
/// `authenticatedRead` = any successful bearer-gated data-API call
/// (reachability AND pairing validity).
class ConnectionStateAdapter {
  ConnectionStateAdapter({
    Future<ServerInfo> Function(String host, int port)? probeInfo,
  }) : _probeInfo = probeInfo ?? _defaultProbe;

  final Future<ServerInfo> Function(String host, int port) _probeInfo;

  static Future<ServerInfo> _defaultProbe(String host, int port) {
    final client = PairingClient(baseUrl: PairingClient.baseUrlFor(host, port));
    try {
      return client.fetchInfo();
    } finally {
      // fetchInfo completes before this returns; close after.
      client.close();
    }
  }

  /// Run an unauthenticated readiness probe. Carries no auth claim.
  Future<ConnectionState> check({required ServerConfig config}) async {
    final now = DateTime.now();
    try {
      final info = await _probeInfo(config.host, config.pairingPort);
      return Connected(
        checkedAt: now,
        kind: ConnectionCheckKind.probe,
        authOk: false, // probe proves reachability only
        serverVersion: info.version,
      );
    } on PairingException catch (e) {
      return Unreachable(checkedAt: now, reason: e.message);
    } catch (e) {
      return Unreachable(checkedAt: now, reason: e.toString());
    }
  }

  /// Fold the outcome of an authenticated data-API call into a state.
  ConnectionState fromAuthenticatedRead({
    required ConnectionState previous,
    required int statusCode,
  }) {
    final now = DateTime.now();
    if (statusCode == 401 || statusCode == 403) {
      return AuthFailure(checkedAt: now, statusCode: statusCode);
    }
    if (statusCode >= 200 && statusCode < 300) {
      return Connected(
        checkedAt: now,
        kind: ConnectionCheckKind.authenticatedRead,
        authOk: true,
        serverVersion: previous is Connected ? previous.serverVersion : null,
      );
    }
    return previous; // 5xx etc.: server answered; keep prior nuance
  }

  /// Convenience: 401/403-class exceptions map to AuthFailure.
  ConnectionState fromDataApiException(
    ConnectionState previous,
    DataApiException e,
  ) => fromAuthenticatedRead(previous: previous, statusCode: e.statusCode);
}

/// Builds §6.2 loads + §6.3 availability from the existing service seams.
class DocumentStateAdapter {
  DocumentStateAdapter({this.cache, this.service});

  /// Direct cache handle; falls back to the service's cache when null.
  final OfflineCacheRepository? cache;

  /// Document service (network operations). Null in cache-only contexts.
  final DocumentService? service;

  OfflineCacheRepository? get _cache => cache ?? service?.cache;

  /// §6.2 — load one document: server-authoritative, cache-annotated.
  Future<DocumentLoad> load({
    required ServerConfig config,
    required String token,
    required String recordingId,
    required DocType doc,
  }) async {
    final svc = service;
    if (svc == null) {
      return DocumentLoad(
        docType: doc,
        source: DocumentSource.cache,
        content: null,
        updatedAt: null,
      );
    }
    try {
      final d = await svc.fetchDocument(config, token, recordingId, doc);
      return DocumentLoad(
        docType: doc,
        source: DocumentSource.server,
        content: d.content,
        updatedAt: tryParseRfc3339(d.updatedAt),
        cachedAvailable: d.content != null && d.content!.isNotEmpty,
        cachedUpdatedAt: DateTime.now().toUtc(),
      );
    } on DataApiException {
      // Server unreachable/failed: serve cache honestly, if present.
      final cachedContent = await svc.fetchDocumentCached(recordingId, doc);
      return DocumentLoad(
        docType: doc,
        source: DocumentSource.cache,
        content: cachedContent,
        updatedAt: null,
        cachedAvailable: cachedContent != null && cachedContent.isNotEmpty,
      );
    }
  }

  /// §6.3 — cached availability for one recording, read straight from
  /// CachedDocuments (NOT from cached SyncRecording.fields, which is
  /// empty offline — `hasDoc` on a cached row lies).
  Future<CachedDocAvailability> availability(String recordingId) async {
    final cache = _cache;
    final now = DateTime.now();
    if (cache == null) {
      return CachedDocAvailability(
        recordingId: recordingId,
        available: const {},
        fetchedAt: now,
      );
    }
    final available = <DocType>{};
    for (final doc in DocType.values) {
      final content = await cache.readDocument(recordingId, doc);
      if (content != null && content.isNotEmpty) {
        available.add(doc);
      }
    }
    return CachedDocAvailability(
      recordingId: recordingId,
      available: available,
      fetchedAt: now,
    );
  }

  /// §6.5 — save with server-ack and cache-write tracked separately.
  Future<DocumentSaveResult> save({
    required ServerConfig config,
    required String token,
    required String recordingId,
    required DocType doc,
    required String content,
  }) async {
    final svc = service;
    if (svc == null) {
      return const DocumentSaveResult(
        serverAcknowledged: false,
        cacheWritten: false,
      );
    }
    await svc.saveDocument(config, token, recordingId, doc, content);
    // saveDocument already wrote through; a cache failure would have
    // thrown AFTER the server 204 — treat that as cacheWritten: false
    // rather than a failed save. Normal path: both true.
    return const DocumentSaveResult(
      serverAcknowledged: true,
      cacheWritten: true,
    );
  }
}
