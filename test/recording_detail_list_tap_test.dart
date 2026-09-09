import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/documents/recording_detail_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

void main() {
  // Regression (user report): tapping a list row for a shell recording
  // (empty filename, no patient name, no documents) opened a screen that
  // read as blank. Pins: the title falls back to 'Consultation' (null OR
  // empty on both fields), the explicit empty state renders, and the five
  // document rows are still present with Generate actions.
  testWidgets('list-tap path: empty-shell recording renders title, empty '
      'state, and doc rows — never a blank screen', (tester) async {
    // Tall viewport so the transcript row + all five doc rows build without
    // lazy-list scrolling (the added Transcript row pushed the last doc row
    // below the default 600px fold).
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    final services = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
    );

    // The shell recording exactly as the content-sync list produces for a
    // generated-but-undocumented consultation: empty filename, null
    // patient, no fields.
    final shell = SyncRecording(
      id: '11111111-1111-4111-8111-111111111111',
      filename: '',
      createdAt: '2026-09-07T09:00:00Z',
      updatedAt: '2026-09-07T09:05:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingDetailScreen(services: services, recording: shell),
      ),
    );
    await tester.pumpAndSettle();

    // Title falls back through empty strings to 'Consultation'.
    expect(find.text('Consultation'), findsOneWidget);
    // Explicit empty state — visible in both themes.
    expect(find.text('No documents yet for this consultation'), findsOneWidget);
    // The view-only transcript row is present (no transcript for a shell).
    expect(find.text('Transcript'), findsOneWidget);
    expect(find.text('No transcript yet'), findsOneWidget);
    // All five document rows still render with their Generate actions.
    expect(find.text('SOAP Note'), findsOneWidget);
    expect(find.text('Referral'), findsOneWidget);
    expect(find.text('Letter'), findsOneWidget);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Peer Discussion'), findsOneWidget);
    expect(find.text('Not generated'), findsNWidgets(5));
    expect(find.text('Generate'), findsAtLeastNWidgets(5));
  });

  testWidgets('list-tap path: real recording shows title and rows', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    final services = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
    );

    final real = SyncRecording(
      id: '22222222-2222-4222-8222-222222222222',
      filename: 'Consultation 2026-09-07 09:10',
      createdAt: '2026-09-07T09:10:00Z',
      updatedAt: '2026-09-07T09:15:00Z',
      patientName: 'Test Patient',
      durationSeconds: 42,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingDetailScreen(services: services, recording: real),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Patient'), findsOneWidget);
    // No documents on this recording either — the empty state IS correct
    // here per §5F; what matters is the title and rows render.
    expect(find.text('No documents yet for this consultation'), findsOneWidget);
    expect(find.text('SOAP Note'), findsOneWidget);
  });
}
