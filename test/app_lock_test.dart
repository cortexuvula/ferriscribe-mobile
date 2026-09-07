import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app.dart';
import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/security/app_lock.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';

/// Fake auth: N failures then success, so tests drive locked→unlocked.
class _FakeAuth implements AppLockAuth {
  _FakeAuth(this.failures);
  int failures;
  int authCalls = 0;

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate() async {
    authCalls++;
    return failures-- > 0 ? false : true;
  }
}

void main() {
  AppServices services(AppLockAuth auth) {
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
      appLockAuth: auth,
    );
  }

  testWidgets('locked: lock screen renders, no data loads until unlock', (
    tester,
  ) async {
    final auth = _FakeAuth(1); // first attempt fails
    final s = services(auth);

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(Brightness.dark), home: SizedBox()),
    );
    // Drive the app shell itself via FerriScribeApp.
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    await tester.pump();

    // The cold-launch auto-prompt ran (attempt 1 failed).
    expect(auth.authCalls, greaterThanOrEqualTo(1));
    // Still locked: the lock screen shows, and the app's real content
    // (pairing screen) never loaded — the root deferred its read.
    expect(find.text('FerriScribe is locked'), findsOneWidget);

    // User taps Unlock -> succeeds now.
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Unlocked: the lock screen is gone.
    expect(find.text('FerriScribe is locked'), findsNothing);
    // And the root's deferred load ran (pairing screen shows — unpaired).
    expect(find.text('Scan pairing QR'), findsOneWidget);
  });

  testWidgets('locked stays locked on cancel; controller semantics', (
    tester,
  ) async {
    final auth = _FakeAuth(99); // always fails
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('FerriScribe is locked'), findsOneWidget);
    expect(
      find.text('Scan pairing QR'),
      findsNothing,
      reason: 'no data/screen may appear before unlock',
    );
  });

  test(
    'controller: lock/unlock notify; tryUnlock unlocks on success',
    () async {
      final c = AppLockController();
      expect(c.locked, isTrue);
      var notified = 0;
      c.addListener(() => notified++);
      c.unlock();
      expect(c.locked, isFalse);
      expect(notified, 1);
      c.lock();
      expect(c.locked, isTrue);
      expect(notified, 2);
      final ok = await c.tryUnlock(_FakeAuth(0));
      expect(ok, isTrue);
      expect(c.locked, isFalse);
    },
  );
}
