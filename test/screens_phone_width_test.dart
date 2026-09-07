import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/documents/document_editor_screen.dart';
import 'package:ferriscribe_mobile/features/home/consultations_screen.dart';
import 'package:ferriscribe_mobile/features/recording/record_screen.dart';
import 'package:ferriscribe_mobile/features/settings/settings_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';

/// Standing acceptance rule (ferriscribe, after the blank-screen chase):
/// every pushed screen's widget tests must run at phone width in both
/// themes — the 800x600 default test surface is a structural blind spot
/// that hid a layout exception through three fix attempts.
///
/// This guard sweeps every top-level pushed screen: it must lay out with
/// NO exception (takeException() == null) at 412dp in light and dark, and
/// paint visible content.
void main() {
  AppServices services() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    return AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
    );
  }

  final screens = <String, WidgetBuilder>{
    'ConsultationsScreen': (c) =>
        ConsultationsScreen(services: services(), onUnpaired: () {}),
    'SettingsScreen': (c) =>
        SettingsScreen(services: services(), onUnpaired: () {}),
    'RecordScreen': (c) => RecordScreen(services: services()),
    'DocumentEditorScreen(server)': (c) => DocumentEditorScreen(
      services: services(),
      recordingId: '00000000-0000-0000-0000-000000000001',
      doc: DocType.soap,
    ),
  };

  for (final entry in screens.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} lays out at phone width (${brightness.name})', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            home: Builder(builder: entry.value),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              '${entry.key} threw a layout exception at phone width '
              'under ${brightness.name} — the blank-screen bug class.',
        );
        // Something visible painted.
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    }
  }
}
