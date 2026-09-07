import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/core/state/connection_state.dart';
import 'package:ferriscribe_mobile/core/state/document_state.dart';
import 'package:ferriscribe_mobile/core/state/ingest_state.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart'
    hide PatientContext;
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
