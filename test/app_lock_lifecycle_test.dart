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

/// NO-CLOCK lock lifecycle pins (ferriscribe/codie/ui-consultant agreed
/// design). All scenarios use REAL didChangeAppLifecycleState dispatch.
/// The clock is GONE: no DateTime, no settle window. A genuine
/// paused->resumed round-trip re-locks no matter how fast; the prompt's
/// own resume is suppressed exactly once, and only when no background
/// evidence exists.
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

  testWidgets('1: resume-before-completion order: prompt resume ignored, '
      'then a genuine round-trip re-locks (however fast)', (tester) async {
    final auth = _AuthFake()..holdOpen = true;
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    expect(auth.prompts, 1);

    // The prompt's own resume while it is up: not backgrounding.
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.resumed);
    await tester.pump();
    expect(s.appLock!.locked, isTrue);

    // Success; straggler resume right after unlock (completion-then-
    // resume ordering): suppressed once, no double prompt.
    auth.resolve(true);
    await tester.pump();
    expect(s.appLock!.locked, isFalse);
    dispatch(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.prompts, 1, reason: 'straggler suppressed exactly once');
    expect(s.appLock!.locked, isFalse);

    // THE FAST HANDOFF: genuine paused->resumed with NO delay — must
    // re-lock instantly (the clock would have skipped this). The lock()
    // engages synchronously in the lifecycle handler, so assert BEFORE
    // pumping (the auto re-prompt would otherwise run and, on success,
    // unlock again — which is correct behavior, not a failure).
    dispatch(AppLifecycleState.paused);
    dispatch(AppLifecycleState.resumed);
    expect(
      s.appLock!.locked,
      isTrue,
      reason: 'fast genuine round-trip must re-lock with zero delay',
    );
    await tester.pump();
  });

  testWidgets('2: completion-before-resume order: straggler suppressed, '
      'genuine evidence after it still re-locks', (tester) async {
    final auth = _AuthFake(); // resolves immediately
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    expect(s.appLock!.locked, isFalse);

    // Straggler resume (no paused evidence): suppressed once.
    dispatch(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.prompts, 1);
    expect(s.appLock!.locked, isFalse);

    // Evidence recorded AFTER unlock wins over any stale expectation.
    // lock() engages synchronously — assert before the pump lets the
    // re-prompt run.
    dispatch(AppLifecycleState.paused);
    dispatch(AppLifecycleState.resumed);
    expect(s.appLock!.locked, isTrue, reason: 'evidence beats suppression');
    await tester.pump();
    expect(auth.prompts, 2);
  });

  testWidgets('3: failed prompt over real backgrounding stays locked', (
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
    await tester.pump();
    expect(s.appLock!.locked, isTrue);
  });

  testWidgets('4: inactive-only (banner/dialog) does not re-lock', (
    tester,
  ) async {
    final auth = _AuthFake();
    final s = services(auth);
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    expect(s.appLock!.locked, isFalse);

    // Notification shade / dialog: inactive -> resumed, never paused.
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.prompts, 1, reason: 'no prompt for an inactive-only event');
    expect(s.appLock!.locked, isFalse);
  });
}

class _AuthFake implements AppLockAuth {
  int prompts = 0;
  final bool alwaysFail;
  _AuthFake({this.alwaysFail = false});

  /// When true, the prompt stays up until the test resolves it
  /// (simulating the system dialog being on screen).
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

  void resolve(bool ok) => _current!.complete(ok);
}
