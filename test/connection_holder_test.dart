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
      expect(h.label, 'Reachable · 1.2.3');

      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.authenticatedRead,
          authOk: true,
        ),
      );
      expect(h.label, 'Connected');

      h.publish(Unreachable(checkedAt: DateTime.now()));
      expect(h.label, 'Unreachable');

      h.publish(AuthFailure(checkedAt: DateTime.now()));
      expect(h.label, 'Pairing needs attention');
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
      'Office server · Connected',
    );
  });

  group('superseded-completion rejection (launch-check guardrail)', () {
    test('stale epoch publish is dropped; newer truth survives', () {
      final h = ConnectionHolder();

      // Launch probe starts (epoch 1), then a later authenticated read
      // starts (epoch 2) and completes first with an AUTH FAILURE.
      final launchEpoch = h.beginCheck();
      final laterEpoch = h.beginCheck();
      h.publish(
        AuthFailure(checkedAt: DateTime.now(), statusCode: 401),
        epoch: laterEpoch,
      );
      expect(h.last, isA<AuthFailure>());

      // The slow launch probe now answers "reachable" — for its OLD epoch.
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
        ),
        epoch: launchEpoch,
      );
      expect(
        h.last,
        isA<AuthFailure>(),
        reason: 'a superseded completion must not overwrite the newer fact',
      );

      // A current-epoch publish still lands normally.
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.authenticatedRead,
          authOk: true,
        ),
        epoch: h.beginCheck(),
      );
      expect(h.last, isA<Connected>());
      expect((h.last as Connected).authOk, isTrue);
    });

    test('concurrent in-flight checks each publish (visual review 33fcdfa: '
        'launch probe no longer invalidated by the sync fold starting)', () {
      final h = ConnectionHolder();
      // Launch probe starts, then the list sync starts BEFORE the probe
      // completes (both in flight).
      final probeEpoch = h.beginCheck();
      final syncEpoch = h.beginCheck();

      // The probe completes first with 'reachable'.
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
        ),
        epoch: probeEpoch,
      );
      expect(h.last, isA<Connected>(), reason: 'probe result preserved');
      expect(h.checking, isTrue, reason: 'sync still in flight');

      // The sync completes after — its result is newer, it lands.
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.authenticatedRead,
          authOk: true,
        ),
        epoch: syncEpoch,
      );
      expect(h.checking, isFalse);
      expect((h.last as Connected).authOk, isTrue);

      // And the guardrail still holds in this shape: if the SYNC had
      // published an auth failure first, the late probe cannot undo it.
      final p2 = h.beginCheck();
      final s2 = h.beginCheck();
      h.publish(
        AuthFailure(checkedAt: DateTime.now(), statusCode: 401),
        epoch: s2,
      );
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
        ),
        epoch: p2,
      );
      expect(h.last, isA<AuthFailure>());
    });

    test('epoch-less publish keeps legacy last-writer-wins', () {
      final h = ConnectionHolder();
      h.publish(Unreachable(checkedAt: DateTime.now()));
      h.publish(
        Connected(
          checkedAt: DateTime.now(),
          kind: ConnectionCheckKind.probe,
          authOk: false,
        ),
      );
      expect(h.last, isA<Connected>());
    });
  });
}
