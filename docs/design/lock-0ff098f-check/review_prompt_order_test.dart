// Review-only production-app lifecycle tests; no device or clinical data.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ferriscribe_mobile/app.dart';
import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/security/app_lock.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';

class HeldAuth implements AppLockAuth {
  final prompts = <Completer<bool>>[];
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<bool> authenticate() {
    final p = Completer<bool>();
    prompts.add(p);
    return p.future;
  }
}

void main() {
  Future<AppServices> mount(WidgetTester tester, HeldAuth auth) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    final s = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
      appLockAuth: auth,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    expect(auth.prompts.length, 1);
    expect(s.appLock!.locked, isTrue);
    expect(find.text('Scan pairing QR'), findsNothing);
    return s;
  }

  void dispatch(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.handleAppLifecycleStateChanged(state);

  for (final order in [
    'resume-before-completion',
    'completion-before-resume',
  ]) {
    testWidgets('$order followed by immediate real background must relock', (
      tester,
    ) async {
      final auth = HeldAuth();
      final s = await mount(tester, auth);
      dispatch(tester, AppLifecycleState.inactive);
      if (order == 'resume-before-completion') {
        dispatch(tester, AppLifecycleState.resumed);
        await tester.pump();
        expect(s.appLock!.locked, isTrue);
        auth.prompts[0].complete(true);
        await tester.pumpAndSettle();
        // Deliberately NO extra post-completion straggler to consume state.
      } else {
        auth.prompts[0].complete(true);
        await tester.pump();
        dispatch(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      }
      expect(
        auth.prompts.length,
        1,
        reason: 'no duplicate prompt for dismissal',
      );
      expect(s.appLock!.locked, isFalse);
      expect(find.text('Scan pairing QR'), findsOneWidget);

      // No delay or clock advancement. Do not auto-succeed the new prompt.
      dispatch(tester, AppLifecycleState.inactive);
      dispatch(tester, AppLifecycleState.hidden);
      dispatch(tester, AppLifecycleState.paused);
      dispatch(tester, AppLifecycleState.resumed);
      expect(s.appLock!.locked, isTrue);
      expect(auth.prompts.length, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        s.appLock!.locked,
        isTrue,
        reason: 'must stay locked pending fresh auth',
      );
      expect(find.text('FerriScribe is locked'), findsOneWidget);
      expect(find.text('Scan pairing QR'), findsNothing);

      // Cancel must not expose content; manual retry then succeeds once.
      auth.prompts[1].complete(false);
      await tester.pumpAndSettle();
      expect(s.appLock!.locked, isTrue);
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      expect(auth.prompts.length, 3);
      auth.prompts[2].complete(true);
      await tester.pumpAndSettle();
      expect(s.appLock!.locked, isFalse);
      expect(find.text('Scan pairing QR'), findsOneWidget);
    });
  }

  testWidgets('genuine background beats an UNCONSUMED prompt expectation', (
    tester,
  ) async {
    final auth = HeldAuth();
    final s = await mount(tester, auth);
    auth.prompts.single.complete(true);
    await tester.pumpAndSettle();
    expect(s.appLock!.locked, isFalse);
    // No prompt resumed event at all before the new genuine round trip.
    dispatch(tester, AppLifecycleState.inactive);
    dispatch(tester, AppLifecycleState.paused);
    dispatch(tester, AppLifecycleState.resumed);
    expect(s.appLock!.locked, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(auth.prompts.length, 2);
    expect(s.appLock!.locked, isTrue);
    expect(find.text('FerriScribe is locked'), findsOneWidget);
    expect(find.text('Scan pairing QR'), findsNothing);
    auth.prompts[1].complete(false);
    await tester.pump();
  });

  testWidgets('cancel while prompt spans real background stays locked', (
    tester,
  ) async {
    final auth = HeldAuth();
    final s = await mount(tester, auth);
    dispatch(tester, AppLifecycleState.inactive);
    dispatch(tester, AppLifecycleState.hidden);
    dispatch(tester, AppLifecycleState.paused);
    dispatch(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.prompts.length, 1);
    auth.prompts.single.complete(false);
    // Root retains an offstage loading spinner until first unlock.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.appLock!.locked, isTrue);
    expect(find.text('FerriScribe is locked'), findsOneWidget);
    expect(find.text('Scan pairing QR'), findsNothing);
    expect(auth.prompts.length, 1);
  });
}
