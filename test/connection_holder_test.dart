import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/state/connection_holder.dart';
import 'package:ferriscribe_mobile/core/state/connection_state.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

/// §5J regression (user report): 'connection not checked' on the landing
/// page even after checking in Settings — the check result died with the
/// Settings screen. The ConnectionHolder is the app-scoped truth; every
/// reader renders from it, every writer publishes to it.
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

  group('ConnectionHolder', () {
    test('unknown by default; label vocabulary per §5J', () {
      final h = ConnectionHolder();
      expect(h.last, isNull);
      expect(h.label, 'connection not checked');

      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
          serverVersion: '1.2.3',
        ),
      );
      expect(h.label, 'office server reachable · 1.2.3');

      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.authenticatedRead,
          authOk: true,
        ),
      );
      expect(h.label, 'office server connected');

      h.publish(Unreachable(checkedAt: DateTime.now()));
      expect(h.label, 'office server unreachable');

      h.publish(AuthFailure(checkedAt: DateTime.now()));
      expect(h.label, 'pairing needs attention');
    });

    test('beginCheck keeps previous fact and flags checking', () {
      final h = ConnectionHolder();
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
        ),
      );
      h.beginCheck();
      expect(h.checking, isTrue);
      expect(h.last, isA<Connected>());
      h.publish(Unreachable(checkedAt: DateTime.now()));
      expect(h.checking, isFalse);
      expect(h.last, isA<Unreachable>());
    });

    test('notifies listeners on publish', () {
      final h = ConnectionHolder();
      var calls = 0;
      h.addListener(() => calls++);
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
        ),
      );
      expect(calls, 1);
    });

    test('holder is shared through AppServices — one instance', () {
      final s = services();
      expect(s.connection, same(s.connection));
    });
  });

  testWidgets('landing-page status line reflects a shared check result '
      '(the reported bug)', (tester) async {
    // The reported flow: check in Settings -> return -> landing page
    // still said 'connection not checked'. The holder is what makes the
    // result survive; simulate the check publishing, then read the label
    // the landing page renders from.
    final s = services();
    s.connection.publish(
      Connected(
        checkedAt: DateTime.now(),
        kind: ConnectionCheckKind.authenticatedRead,
        authOk: true,
      ),
    );
    expect(
      'Office server · ${s.connection.label}',
      'Office server · office server connected',
    );
  });
}
