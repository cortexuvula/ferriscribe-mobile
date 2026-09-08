import 'dart:async';

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

/// ui-consultant's f805d3e regression, with REAL lifecycle dispatch —
/// the class of test codie's original pin lacked (no lifecycle events).
/// Scenarios:
///  A. prompt up -> its own inactive/resumed -> success -> straggler
///     resume within window -> genuine backgrounding AFTER the window:
///     must re-lock (the shipped bug kept it unlocked).
///  B. straggler resume right after unlock: no double prompt.
///  C. cancelled/failed prompt over a real backgrounding: stays locked.
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

  void dispatch(AppLifecycleState state) {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
  }

  testWidgets('A: genuine backgrounding after the settle window re-locks', (
    tester,
  ) async {
    final auth = _AuthFake()..holdOpen = true;
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();

    // Cold-launch prompt is UP (held open like a real system dialog).
    expect(auth.prompts, 1);

    // The prompt's own inactive->resumed pair while authenticating:
    // must not be treated as backgrounding.
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.resumed);
    await tester.pump();
    expect(s.appLock!.locked, isTrue, reason: 'still locked while prompt up');

    // Prompt completes successfully.
    auth.resolve(true);
    await tester.pump();
    expect(s.appLock!.locked, isFalse);
    expect(auth.prompts, 1);

    // Straggler resume within the settle window: no re-prompt.
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(auth.prompts, 1, reason: 'no double prompt');
    expect(s.appLock!.locked, isFalse, reason: 'no spurious re-lock');

    // Time passes beyond the 2s settle window. The settle deadline is
    // WALL-CLOCK based (DateTime.now), so the synthetic frame clock
    // can't age it — run real async time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );

    // ...then a GENUINE backgrounding.
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.paused);
    dispatch(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));

    // THE REGRESSION: this must be locked (and re-prompting).
    expect(
      s.appLock!.locked,
      isTrue,
      reason: 'genuine backgrounding after the settle window must re-lock',
    );
    expect(auth.prompts, 2, reason: 're-lock prompts again');
  });

  testWidgets('B: straggler resume right after unlock does not double-prompt', (
    tester,
  ) async {
    final auth = _AuthFake();
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.prompts, 1);
    expect(s.appLock!.locked, isFalse);

    // The OS's post-prompt straggler events land within the window.
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200));
    expect(auth.prompts, 1, reason: 'no double prompt');
    expect(s.appLock!.locked, isFalse, reason: 'no spurious re-lock');
  });

  testWidgets('C: cancelled prompt over real backgrounding stays locked', (
    tester,
  ) async {
    final auth = _AuthFake(alwaysFail: true);
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(s.appLock!.locked, isTrue);

    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.paused);
    dispatch(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));

    expect(
      s.appLock!.locked,
      isTrue,
      reason: 'a failed/cancelled auth leaves the app locked',
    );
  });
}

class _AuthFake implements AppLockAuth {
  int prompts = 0;
  final bool alwaysFail;
  _AuthFake({this.alwaysFail = false});

  /// When true, the prompt stays up until the test resolves it
  /// manually (simulating the system dialog being on screen).
  bool holdOpen = false;

  Completer<bool>? _current;

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate() {
    prompts++;
    _current = Completer<bool>();
    if (!holdOpen) {
      scheduleMicrotask(() => _current!.complete(!alwaysFail));
    }
    return _current!.future;
  }

  void resolve(bool ok) {
    _current!.complete(ok);
  }
}
