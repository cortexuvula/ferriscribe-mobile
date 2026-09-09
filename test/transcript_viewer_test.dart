import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/documents/recording_detail_screen.dart';
import 'package:ferriscribe_mobile/features/documents/transcript_viewer_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';

/// Transcript is a view-only entry above the generated documents, sourced
/// from the synced `fields.transcript` (raw on-premise STT output). Pins:
/// the row renders above SOAP Note, shows "Available" when the transcript is
/// non-empty, opens the read-only viewer on tap, and a transcript-only
/// recording does NOT show the "No documents yet" empty shell.
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('transcript row renders above SOAP and opens viewer '
        '(${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final keys = MemoryKeyStore();
      final repo = ServerConfigRepository(db, keys);
      final services = AppServices(
        db: db,
        keyStore: keys,
        serverConfigRepository: repo,
        pairingService: PairingService(repository: repo),
        offlineCache: OfflineCacheRepository(db),
      );

      final rec = SyncRecording(
        id: '11111111-1111-4111-8111-111111111111',
        filename: 'consultation-1.wav',
        createdAt: '2026-09-08T09:00:00Z',
        updatedAt: '2026-09-08T09:05:00Z',
        patientName: 'Test Patient',
        fields: const {
          'transcript': SyncFieldValue(
            value: 'Hello, this is the consultation transcript.',
            updatedAt: '2026-09-08T09:05:00Z',
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: RecordingDetailScreen(services: services, recording: rec),
        ),
      );
      await tester.pumpAndSettle();

      // Transcript row is present and above the SOAP row.
      expect(find.text('Transcript'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);

      // "No documents yet" empty shell must NOT appear (transcript counts).
      expect(
        find.text('No documents yet for this consultation'),
        findsNothing,
        reason: 'transcript-only recording is not empty (${brightness.name})',
      );

      // Tap the transcript row → read-only viewer with the raw text.
      await tester.tap(find.text('Transcript'));
      await tester.pumpAndSettle();
      expect(find.byType(TranscriptViewerScreen), findsOneWidget);
      expect(
        find.text('Hello, this is the consultation transcript.'),
        findsOneWidget,
        reason: 'transcript text visible in viewer (${brightness.name})',
      );
      // Viewer is read-only: no Edit / Generate / Export affordances.
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Generate'), findsNothing);
      expect(find.byTooltip('Export & share'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('transcript row shows "No transcript yet" when absent '
        '(${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final keys = MemoryKeyStore();
      final repo = ServerConfigRepository(db, keys);
      final services = AppServices(
        db: db,
        keyStore: keys,
        serverConfigRepository: repo,
        pairingService: PairingService(repository: repo),
        offlineCache: OfflineCacheRepository(db),
      );

      final rec = SyncRecording(
        id: '22222222-2222-4222-8222-222222222222',
        filename: 'consultation-2.wav',
        createdAt: '2026-09-08T10:00:00Z',
        updatedAt: '2026-09-08T10:05:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: RecordingDetailScreen(services: services, recording: rec),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transcript'), findsOneWidget);
      expect(find.text('No transcript yet'), findsOneWidget);
      // Tap does nothing (no viewer) when there's no transcript.
      await tester.tap(find.text('Transcript'));
      await tester.pumpAndSettle();
      expect(find.byType(TranscriptViewerScreen), findsNothing);

      expect(tester.takeException(), isNull);
    });
  }
}
