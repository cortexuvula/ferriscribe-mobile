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
import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';

/// Phone-width sweep: the default 800x600 test surface hides layout
/// exceptions that abort painting on a real ~412dp device (the blank-
/// screen bug class). Every pushed screen must lay out cleanly at phone
/// width in both themes with visible content.
void main() {
  testWidgets('RecordingDetailScreen paints at phone width, both themes, '
      'all row states', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final brightness in Brightness.values) {
      final db = AppDatabase(NativeDatabase.memory());
      final keys = MemoryKeyStore();
      final repo = ServerConfigRepository(db, keys);
      final services = AppServices(
        db: db,
        keyStore: keys,
        serverConfigRepository: repo,
        pairingService: PairingService(repository: repo),
        offlineCache: OfflineCacheRepository(db),
      );

      // Rich recording: patient + filename + duration drives the metadata
      // section too.
      final rec = SyncRecording(
        id: '33333333-3333-4333-8333-333333333333',
        filename: 'Consultation 2026-09-07 09:10',
        createdAt: '2026-09-07T09:10:00Z',
        updatedAt: '2026-09-07T09:15:00Z',
        patientName: 'Test Patient',
        durationSeconds: 42,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: RecordingDetailScreen(services: services, recording: rec),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'layout exception under ${brightness.name}',
      );
      expect(find.text('Test Patient'), findsOneWidget);
      expect(find.text('SOAP Note'), findsOneWidget);
      expect(find.text('Generate'), findsAtLeastNWidgets(5));

      await db.close();
    }
  });
}
