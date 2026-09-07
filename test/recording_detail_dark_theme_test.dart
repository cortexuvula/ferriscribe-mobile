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

void main() {
  // Coverage hole this chase exposed: every RecordingDetailScreen widget
  // test rendered under the default (light) theme, while the user runs
  // dark. Pins the screen's visible content under BOTH themes, including
  // the dark canvas (#101A23) where a rendering problem reads as a blank
  // screen.
  for (final brightness in Brightness.values) {
    testWidgets(
      'RecordingDetailScreen renders title + rows + empty state under '
      '${brightness.name} theme',
      (tester) async {
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

        final shell = SyncRecording(
          id: '11111111-1111-4111-8111-111111111111',
          filename: '',
          createdAt: '2026-09-07T09:00:00Z',
          updatedAt: '2026-09-07T09:05:00Z',
        );

        // Phone-like narrow surface (Pixel ~412dp wide): the wide default
        // test surface (800x600) hides row-level layout overflow that
        // breaks painting on the real device.
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            home: RecordingDetailScreen(services: services, recording: shell),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Consultation'), findsOneWidget);
        expect(
          find.text('No documents yet for this consultation'),
          findsOneWidget,
        );
        for (final row in [
          'SOAP Note',
          'Referral',
          'Letter',
          'Synopsis',
          'Peer Discussion',
        ]) {
          expect(find.text(row), findsOneWidget, reason: 'missing row: $row');
        }

        // Dark-theme-specific regression: content must paint with colors
        // that contrast the dark canvas — onSurface differs from the
        // scaffold background in both directions.
        final context = tester.element(find.text('Consultation'));
        final scheme = Theme.of(context).colorScheme;
        final bg = Theme.of(context).scaffoldBackgroundColor;
        expect(scheme.onSurface, isNot(bg));
      },
    );
  }
}
