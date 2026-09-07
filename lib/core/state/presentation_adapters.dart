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

/// Thrown by [DocumentStateAdapter.load] when the server answered 401/403.
///
/// Deliberately NOT a cache-fallback case: the server is reachable and
/// rejected the pairing — callers render "pairing needs attention", not a
/// stale cached document, and not "offline".
class DocumentAuthException implements Exception {
  const DocumentAuthException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'DocumentAuthException($statusCode)';
}

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

  static Future<ServerInfo> _defaultProbe(String host, int port) async {
    final client = PairingClient(baseUrl: PairingClient.baseUrlFor(host, port));
    try {
      // MUST await inside the try: returning the future un-awaited would
      // run the finally (client.close()) while the request is still in
      // flight, aborting it. Pinned by
      // presentation_state_test's probe-against-live-server test.
      return await client.fetchInfo();
    } finally {
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

  /// §5B mandatory preflight: an AUTHENTICATED check that proves both
  /// reachability and pairing validity before recording starts.
  ///
  /// Uses `GET /v1/jobs/{id}` with a well-formed id that can never exist:
  /// the server's authorize() runs before the handler, so 404 means the
  /// bearer token was ACCEPTED (a bad token would 401 before routing).
  /// 2xx/404 → Connected{authenticatedRead, authOk: true}; 401/403 →
  /// AuthFailure; network error → Unreachable. No new server API.
  Future<ConnectionState> authenticatedCheck({
    required ServerConfig config,
    required String token,
  }) async {
    // Nil UUID v4 variant bits — valid format, cannot collide with real ids.
    const probeId = '00000000-0000-4000-8000-000000000000';
    final client = DataApiClient.forConfig(config, token);
    try {
      // Any answer — 404 (no such job), a snapshot, anything — proves auth
      // passed: the server's authorize() runs before the job handler.
      await client.jobStatus(probeId);
      return Connected(
        checkedAt: DateTime.now(),
        kind: ConnectionCheckKind.authenticatedRead,
        authOk: true,
        serverVersion: null,
      );
    } on DataApiException catch (e) {
      return fromAuthenticatedRead(
        previous: ConnectionUnknown(checkedAt: DateTime.now()),
        statusCode: e.statusCode,
      );
    } catch (e) {
      return Unreachable(checkedAt: DateTime.now(), reason: e.toString());
    } finally {
      client.close();
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
    } on DataApiException catch (e) {
      // Auth rejection is NOT an offline condition: the server is up and
      // answered 401/403. Falling back to cached content here would mask
      // a stale/revoked pairing behind a readable document — the UI must
      // render "pairing needs attention" instead. Surface it as a typed
      // exception; only genuine reachability failures fall back to cache.
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw DocumentAuthException(e.statusCode);
      }
      // Server unreachable/5xx: serve cache honestly, if present.
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
  ///
  /// The server PUT is authoritative. A cache write that fails AFTER the
  /// server returned 204 must NOT propagate — the edit IS saved; only the
  /// offline copy is stale. The result reports both facts.
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

    // Server first — an exception here means NOT saved; propagate.
    var serverOk = false;
    DataApiException? serverError;
    try {
      await svc.saveDocument(config, token, recordingId, doc, content);
      serverOk = true;
    } on DataApiException catch (e) {
      serverError = e; // deferred: auth vs offline distinction below
    }

    if (!serverOk) {
      // The PUT itself failed. Auth failure is a pairing problem, not a
      // connectivity one — rethrow typed so callers don't render "offline".
      final code = serverError!.statusCode;
      if (code == 401 || code == 403) {
        throw DocumentAuthException(code);
      }
      return DocumentSaveResult(serverAcknowledged: false, cacheWritten: false);
    }

    // Server acknowledged. The cache write inside saveDocument is
    // best-effort (failures swallowed there — the server 204 IS the save).
    // Report cacheWritten honestly by verifying the write landed.
    var cacheOk = false;
    try {
      final written = await _cache?.readDocument(recordingId, doc);
      cacheOk = written == content;
    } catch (_) {
      cacheOk = false; // offline copy stale; edit is durable on the server
    }
    return DocumentSaveResult(serverAcknowledged: true, cacheWritten: cacheOk);
  }
}
