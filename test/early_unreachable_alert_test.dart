import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/state/connection_state.dart';
import 'package:ferriscribe_mobile/features/home/consultations_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';

/// Visual review 8dd93c0 finding: with the probe FAILED and the list
/// still loading, the label said 'Unreachable' but the Tailscale alert
/// never appeared (it was gated on list-completion `_offline`).
void main() {
  testWidgets('failed probe shows the Tailscale alert immediately, even '
      'while the list is still loading', (tester) async {
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

    // Seed a paired config + token so the screen takes the paired path,
    // then simulate the fast-failed probe: the holder already holds an
    // Unreachable fact while the list pull hangs (no repository data
    // reachable in the test env -> loading persists).
    await repo.savePaired(
      label: 'Office',
      host: '100.0.0.1',
      pairingPort: 11436,
      dataPort: 11437,
      token: 'test-token',
    );
    services.connection.publish(Unreachable(checkedAt: DateTime.now()));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: ConsultationsScreen(services: services, onUnpaired: () {}),
      ),
    );
    await tester.pump();

    // The core assertion: the alert is up, driven by the connection
    // RESULT (the holder's Unreachable fact), regardless of the list
    // pull's own state.
    expect(
      find.textContaining('Check that the desktop app and Tailscale'),
      findsOneWidget,
      reason:
          'the Tailscale alert must be driven by the connection '
          'result, not list completion',
    );
  });
}
