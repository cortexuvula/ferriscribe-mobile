import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/documents/document_editor_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

void main() {
  // Drives the REAL DocumentEditorScreen through production seams: a real
  // in-memory SQLCipher DB, a real paired config row, and an injected
  // MockClient (the binding blocks real sockets). No copied reducers.
  const recordingId = '11111111-1111-4111-8111-111111111111';
  const soapBody =
      'S: Patient reports chest pain.\nO: BP 138/86.\nA: Stable angina.';
  final soapJson =
      '{"doc_type":"soap","content":"${soapBody.replaceAll('\n', r'\n')}","updated_at":"2026-09-07T10:00:00Z"}';

  Future<(_Harness, Widget Function(), Widget Function())> spawn({
    required bool online,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    final cache = OfflineCacheRepository(db);
    await repo.savePaired(
      label: 'phone',
      host: '127.0.0.1',
      pairingPort: 11436,
      dataPort: 11437,
      token: 'test-token',
    );

    late http.Client httpClient;
    if (online) {
      httpClient = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer test-token');
        if (req.method == 'GET' && req.url.path.contains('/documents/soap')) {
          return http.Response(soapJson, 200);
        }
        if (req.method == 'PUT' && req.url.path.contains('/documents/soap')) {
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
    } else {
      // Offline: every request fails at the transport level, exactly as a
      // dead Tailscale connection would (SocketException from dart:io).
      httpClient = MockClient(
        (req) async => throw const SocketException('network unreachable'),
      );
      await cache.upsertDocument(recordingId, DocType.soap, soapBody);
    }

    DataApiClient factory(config, token) => DataApiClient(
      host: config.host,
      port: config.dataPort,
      token: token,
      client: httpClient,
    );

    final services = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: cache,
    );

    Widget screen() => DocumentEditorScreen(
      services: services,
      recordingId: recordingId,
      doc: DocType.soap,
      clientFactory: factory,
    );
    Widget app() => MaterialApp(home: screen());
    return (_Harness(db), app, screen);
  }

  testWidgets('reader shows From office server; editing tracks dirty', (
    tester,
  ) async {
    final (h, app, _) = await spawn(online: true);
    addTearDown(h.dispose);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('From office server'), findsOneWidget);
    expect(find.text('Edit'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'edited SOAP');
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);
  });

  testWidgets('save success shows Saved to office server', (tester) async {
    final (h, app, _) = await spawn(online: true);
    addTearDown(h.dispose);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'edited SOAP');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Saved to office server'), findsOneWidget);
  });

  testWidgets('offline entry is read-only with the cached banner', (
    tester,
  ) async {
    final (h, app, _) = await spawn(online: false);
    addTearDown(h.dispose);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Cached copy · offline'), findsOneWidget);
    expect(
      find.text('Cached copy · reconnect to edit or export'),
      findsOneWidget,
    );
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('dirty exit offers the three-way decision', (tester) async {
    final (h, _, screen) = await spawn(online: true);
    addTearDown(h.dispose);

    // Push the editor over a base route so it has a back button.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit').first);
    await tester.pump();
    await tester.tap(find.text('Edit').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'unsaved edit');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard changes'), findsOneWidget);
    expect(find.text('Save & leave'), findsOneWidget);
  });
}

class _Harness {
  _Harness(this._db);
  final AppDatabase _db;
  Future<void> dispose() => _db.close();
}
