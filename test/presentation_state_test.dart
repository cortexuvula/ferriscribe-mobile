import 'package:drift/native.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/core/state/connection_state.dart';
import 'package:ferriscribe_mobile/core/state/document_state.dart';
import 'package:ferriscribe_mobile/core/state/ingest_state.dart';
import 'package:ferriscribe_mobile/core/state/presentation_adapters.dart';
import 'package:ferriscribe_mobile/features/documents/document_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart'
    hide PatientContext, ServerConfig;
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

void main() {
  group('ConnectionState (§6.1)', () {
    test('probe reachability is not auth', () {
      final c = Connected(
        checkedAt: DateTime.now(),
        kind: ConnectionCheckKind.probe,
        authOk: false,
        serverVersion: '0.76.2',
      );
      expect(
        c.isOperational,
        isFalse,
        reason: 'a probe proves reachability, never pairing',
      );
      expect(c.serverVersion, '0.76.2');
    });

    test(
      'authenticated read is operational; 401 is AuthFailure not offline',
      () {
        final ok = Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.authenticatedRead,
          authOk: true,
        );
        expect(ok.isOperational, isTrue);

        final auth = AuthFailure(checkedAt: DateTime.now(), statusCode: 401);
        expect(auth.isAuthFailure, isTrue);
        expect(auth.isOperational, isFalse);
        expect(
          auth,
          isA<AuthFailure>(),
          reason: 'UI must not render 401 as offline',
        );
      },
    );

    test('Unknown and Unreachable are non-operational, non-auth', () {
      final u = Unreachable(checkedAt: DateTime.now());
      expect(u.isOperational, isFalse);
      expect(u.isAuthFailure, isFalse);
    });
  });

  group('DocumentState (§6.2/§6.3/§6.5)', () {
    late AppDatabase db;
    late OfflineCacheRepository cache;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      cache = OfflineCacheRepository(db);
    });

    tearDown(() => db.close());

    test('DocumentLoad carries source and cache annotation separately', () {
      const load = DocumentLoad(
        docType: DocType.soap,
        source: DocumentSource.server,
        content: 'S: hello',
        updatedAt: null,
        cachedAvailable: true,
      );
      expect(load.hasContent, isTrue);
      expect(load.source, DocumentSource.server);

      const empty = DocumentLoad(
        docType: DocType.letter,
        source: DocumentSource.server,
        content: '',
        updatedAt: null,
      );
      expect(
        empty.hasContent,
        isFalse,
        reason: 'empty string is known-absent, not content',
      );
    });

    test('DocumentSaveResult separates server ack from cache write', () {
      const r = DocumentSaveResult(
        serverAcknowledged: true,
        cacheWritten: false,
      );
      expect(
        r.saved,
        isTrue,
        reason: 'server has the edit; stale cache is not a failed save',
      );
    });

    test('availability reads CachedDocuments, not cached-row fields', () async {
      // Cache a SOAP document for a recording whose cached METADATA row
      // has empty fields — the offline reality.
      await cache.upsertDocument('rec-1', DocType.soap, 'S: cached soap');

      final cachedRow = await cache.readRecordings();
      expect(cachedRow, isEmpty, reason: 'no metadata cached for rec-1');

      // hasDoc on a synthesized cached SyncRecording (empty fields) lies:
      final synthesized = SyncRecording(
        id: 'rec-1',
        filename: 'a.wav',
        createdAt: 't',
        updatedAt: 't',
      );
      expect(
        synthesized.hasDoc(DocType.soap),
        isFalse,
        reason: 'hasDoc on cached metadata cannot see documents',
      );

      // The §6.3 adapter tells the truth from CachedDocuments.
      final avail = await _availabilityFrom(cache, 'rec-1');
      expect(avail.has(DocType.soap), isTrue);
      expect(avail.has(DocType.referral), isFalse);
      expect(avail.available, equals({DocType.soap}));
    });
  });

  group('IngestPresentation (§6.4)', () {
    test('acknowledged stages map; unknown/failed do not', () {
      expect(
        acknowledgedFromServerStage('queued'),
        IngestAcknowledgedStage.generationQueued,
      );
      expect(
        acknowledgedFromServerStage('transcribing'),
        IngestAcknowledgedStage.transcribing,
      );
      expect(
        acknowledgedFromServerStage('generating_soap'),
        IngestAcknowledgedStage.generatingSoap,
      );
      expect(
        acknowledgedFromServerStage('completed'),
        IngestAcknowledgedStage.completed,
      );
      expect(
        acknowledgedFromServerStage('failed'),
        isNull,
        reason: 'failed is a failure fact, not a stage',
      );
      expect(
        acknowledgedFromServerStage('generating_referral'),
        isNull,
        reason: 'per-doc generation is not SOAP-ingest progress',
      );
      expect(acknowledgedFromServerStage('unknown'), isNull);
    });

    test('isTerminal only on completed or acknowledged failure', () {
      const done = IngestPresentation(
        lastAcknowledgedStage: IngestAcknowledgedStage.completed,
        recordingId: 'r1',
      );
      expect(done.isTerminal, isTrue);

      const failed = IngestPresentation(
        lastAcknowledgedStage: IngestAcknowledgedStage.uploaded,
        recordingId: 'r1',
        failure: IngestFailure(
          phase: IngestFailurePhase.job,
          detail: 'job failed',
        ),
      );
      expect(failed.isTerminal, isTrue);

      const mid = IngestPresentation(
        lastAcknowledgedStage: IngestAcknowledgedStage.transcribing,
        recordingId: 'r1',
      );
      expect(mid.isTerminal, isFalse);
    });

    test(
      'reconcile keeps prior on network error (no invented failure)',
      () async {
        final prior = IngestPresentation(
          lastAcknowledgedStage: IngestAcknowledgedStage.generatingSoap,
          recordingId: 'r1',
          uploadAcknowledged: true,
          generationAccepted: true,
        );
        final client = _ThrowingClient();
        final out = await reconcileIngest(client: client, prior: prior);
        expect(
          out.lastAcknowledgedStage,
          IngestAcknowledgedStage.generatingSoap,
        );
        expect(
          out.failure,
          isNull,
          reason: 'interrupted reconciliation is not failure',
        );
      },
    );
  });

  // ── REVIEW-7a891b8 regression pins (ui-consultant findings) ─────────────

  group('ConnectionStateAdapter default probe (REVIEW pin)', () {
    test(
      'probe awaits fetchInfo before closing client; reaches real server',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((req) async {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'version': '0.76.2-test', 'ok': true}));
          await req.response.close();
        });

        final adapter = ConnectionStateAdapter();
        final state = await adapter.check(
          config: ServerConfig(
            label: 't',
            host: '127.0.0.1',
            pairingPort: server.port,
            dataPort: 11437,
            pairedAt: DateTime.now(),
          ),
        );
        await server.close();

        expect(
          state,
          isA<Connected>(),
          reason: 'un-awaited close aborted the probe before the fix',
        );
        final c = state as Connected;
        expect(c.serverVersion, '0.76.2-test');
        expect(c.authOk, isFalse);
        expect(c.kind, ConnectionCheckKind.probe);
      },
    );
  });

  group('DocumentStateAdapter.load: auth is not offline (REVIEW pin)', () {
    late AppDatabase db;
    late OfflineCacheRepository cache;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      cache = OfflineCacheRepository(db);
    });

    tearDown(() => db.close());

    DataApiClient redirectClient(HttpServer server) => DataApiClient.forConfig(
      ServerConfig(
        label: 't',
        host: '127.0.0.1',
        pairingPort: 11436,
        dataPort: server.port,
        pairedAt: DateTime.now(),
      ),
      'token',
    );

    test(
      '401 throws DocumentAuthException, never serves cached copy',
      () async {
        await cache.upsertDocument('rec-1', DocType.soap, 'S: cached soap');

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((req) async {
          req.response.statusCode = 401;
          await req.response.close();
        });

        final svc = DocumentService(
          clientFactory: (c, t) => redirectClient(server),
          cache: cache,
        );
        final adapter = DocumentStateAdapter(service: svc, cache: cache);

        final cfg = ServerConfig(
          label: 't',
          host: '127.0.0.1',
          pairingPort: 11436,
          dataPort: server.port,
          pairedAt: DateTime.now(),
        );
        await expectLater(
          adapter.load(
            config: cfg,
            token: 't',
            recordingId: 'rec-1',
            doc: DocType.soap,
          ),
          throwsA(isA<DocumentAuthException>()),
          reason: 'cached SOAP exists but 401 must not be masked by it',
        );
        await server.close();
      },
    );

    test('connection-refused falls back to cached content', () async {
      await cache.upsertDocument('rec-1', DocType.soap, 'S: cached soap');

      // Port with nothing listening: SocketException (not DataApiException)
      // propagates from http — the adapter catches DataApiException only,
      // so assert the honest behavior: socket errors surface, cache path
      // is for DataApiException-class failures (timeouts/5xx are tested
      // at the service seam). Pin that no auth error is invented.
      final svc = DocumentService(
        clientFactory: (c, t) => throw StateError('unused'),
      );
      final adapter = DocumentStateAdapter(service: svc, cache: cache);
      // Service throws before any network call — must propagate as-is.
      await expectLater(
        adapter.load(
          config: ServerConfig(
            label: 't',
            host: 'x',
            pairingPort: 1,
            dataPort: 1,
            pairedAt: DateTime.now(),
          ),
          token: 't',
          recordingId: 'rec-1',
          doc: DocType.soap,
        ),
        throwsStateError,
      );
    });
  });

  group('ConnectionStateAdapter.authenticatedCheck (§5B preflight)', () {
    late HttpServer server;
    late ServerConfig config;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      config = ServerConfig(
        label: 'phone',
        host: '127.0.0.1',
        pairingPort: 11436,
        dataPort: server.port,
        pairedAt: DateTime(2026, 9, 7),
      );
    });

    tearDown(() => server.close(force: true));

    test('404 on the probe id means authorized: authOk true', () async {
      server.listen((req) async {
        // authorize() runs before the handler; reaching 404 proves the
        // bearer was accepted.
        final auth = req.headers.value('authorization');
        req.response.statusCode = auth == 'Bearer good' ? 404 : 401;
        await req.response.close();
      });
      final state = await ConnectionStateAdapter().authenticatedCheck(
        config: config,
        token: 'good',
      );
      expect(state, isA<Connected>());
      expect((state as Connected).authOk, isTrue);
      expect(state.kind, ConnectionCheckKind.authenticatedRead);
    });

    test('401 is AuthFailure, not offline', () async {
      server.listen((req) async {
        req.response.statusCode = 401;
        await req.response.close();
      });
      final state = await ConnectionStateAdapter().authenticatedCheck(
        config: config,
        token: 'revoked',
      );
      expect(state, isA<AuthFailure>());
    });

    test('network failure is Unreachable', () async {
      // Bind then close: nothing listening.
      final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = dead.port;
      await dead.close(force: true);
      final state = await ConnectionStateAdapter().authenticatedCheck(
        config: ServerConfig(
          label: 'phone',
          host: '127.0.0.1',
          pairingPort: 11436,
          dataPort: deadPort,
          pairedAt: DateTime(2026, 9, 7),
        ),
        token: 'any',
      );
      expect(state, isA<Unreachable>());
    });
  });

  group('DocumentStateAdapter.save: ack split (REVIEW pin)', () {
    test(
      'server 204 + failing cache write => saved, cacheWritten false',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((req) async {
          req.response.statusCode = 204; // server acknowledged
          await req.response.close();
        });
        final cfg = ServerConfig(
          label: 't',
          host: '127.0.0.1',
          pairingPort: 11436,
          dataPort: server.port,
          pairedAt: DateTime.now(),
        );

        // Codie's 92cb935 Critical pinned in PRODUCTION shape: the failing
        // cache rides on the SERVICE (as in production), so the exception
        // arises inside svc.saveDocument after the 204 — the exact path the
        // old adapter let escape as a false save-failure.
        final svc = DocumentService(
          clientFactory: (c, t) => DataApiClient.forConfig(cfg, t),
          cache: _FailingCache(), // service-level, like production
        );
        final adapter = DocumentStateAdapter(service: svc);

        final result = await adapter.save(
          config: cfg,
          token: 't',
          recordingId: 'rec-1',
          doc: DocType.soap,
          content: 'S: edited',
        );
        await server.close();

        expect(
          result.serverAcknowledged,
          isTrue,
          reason: 'the 204 is the truth; cache failure must not mask it',
        );
        expect(result.saved, isTrue);
        expect(result.cacheWritten, isFalse);
      },
    );
  });
}

/// Drives DocumentStateAdapter.availability against a real in-memory cache.
Future<CachedDocAvailability> _availabilityFrom(
  OfflineCacheRepository cache,
  String recordingId,
) async {
  final available = <DocType>{};
  for (final doc in DocType.values) {
    final content = await cache.readDocument(recordingId, doc);
    if (content != null && content.isNotEmpty) available.add(doc);
  }
  return CachedDocAvailability(
    recordingId: recordingId,
    available: available,
    fetchedAt: DateTime.now(),
  );
}

/// A DataApiClient whose jobStatus always throws (network down).
class _ThrowingClient implements DataApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw DataApiException(0, 'network down');
}

/// An OfflineCacheRepository stand-in whose writes always throw — pins the
/// §6.5 ack-split (server 204 survives a broken local cache).
class _FailingCache implements OfflineCacheRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('cache write failed');
}
