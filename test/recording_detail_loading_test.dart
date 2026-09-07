import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/documents/recording_detail_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

void main() {
  // Regression: the id-keyed detail entry (Open SOAP note / post-generation
  // navigation) previously rendered a near-empty body over the dark canvas
  // while its metadata fetch ran — the user saw a silent black screen. It
  // must show a labelled loading state for as long as the fetch is pending.
  testWidgets('id-keyed entry shows a labelled loading state while the '
      'fetch is pending', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    await repo.savePaired(
      label: 'phone',
      host: '127.0.0.1',
      pairingPort: 11436,
      dataPort: 11437,
      token: 't',
    );
    final services = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
    );

    // A client whose content-sync pull NEVER completes — a slow Tailscale
    // fetch in miniature.
    final hanging = _HangingClient();

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingDetailScreen.byId(
          services: services,
          recordingId: '11111111-1111-4111-8111-111111111111',
          clientFactory: (_, _) => hanging,
        ),
      ),
    );
    // Let initState kick the fetch off; it stays pending forever.
    await tester.pump(const Duration(milliseconds: 100));

    // The labelled loading state is visible — not a silent dark screen.
    expect(find.text('Opening consultation…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // No document rows rendered as if data existed.
    expect(find.text('SOAP Note'), findsNothing);
  });
}

/// Test double: the paged pull never settles.
class _HangingClient extends DataApiClient {
  _HangingClient() : super(host: 'localhost', port: 1, token: 'x');

  final _completer = Completer<ContentPullPage>();

  @override
  Future<ContentPullPage> pullContent({String? since, int? limit}) =>
      _completer.future;

  @override
  Future<RecordingDocument> getDocument(String recordingId, DocType doc) =>
      throw UnimplementedError();

  @override
  Future<void> saveDocument(String recordingId, DocType doc, String content) =>
      throw UnimplementedError();

  @override
  void close() {
    if (!_completer.isCompleted) _completer.completeError('closed');
  }
}
