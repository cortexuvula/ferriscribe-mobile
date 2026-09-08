// Review-only test; outside test/ to preserve application source ownership.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ferriscribe_mobile/app.dart';
import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/security/app_lock.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';

class Auth implements AppLockAuth {
  int calls = 0;
  final prompt = Completer<bool>();
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<bool> authenticate() {
    calls++;
    return calls == 1 ? prompt.future : Future.value(false);
  }
}

class Draft extends StatefulWidget {
  const Draft({super.key});
  @override
  State<Draft> createState() => DraftState();
}

class DraftState extends State<Draft> {
  final controller = TextEditingController(text: 'SYNTHETIC UNSAVED DRAFT');
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: TextField(controller: controller));
}

void main() {
  testWidgets('production app retains pushed draft across relock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    final auth = Auth();
    final s = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
      appLockAuth: auth,
    );
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    auth.prompt.complete(true);
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const Draft()));
    await tester.pumpAndSettle();
    final before = tester.state<DraftState>(find.byType(Draft));
    before.controller.text = 'SYNTHETIC EDIT RETAIN ME';
    s.appLock!.lock();
    await tester.pump();
    await tester.pump();
    expect(before.disposed, isFalse);
    expect(find.byType(Draft), findsNothing);
    s.appLock!.unlock();
    await tester.pumpAndSettle();
    expect(tester.state<DraftState>(find.byType(Draft)), same(before));
    expect(before.controller.text, 'SYNTHETIC EDIT RETAIN ME');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  testWidgets('real resume after prompt settle expiry must relock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    final auth = Auth();
    final s = AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
      appLockAuth: auth,
    );
    await tester.pumpWidget(FerriScribeApp(services: s));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    auth.prompt.complete(true);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(s.appLock!.locked, isFalse);
    // Real pause inside settle window, real resume after it expires.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2200)),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      s.appLock!.locked,
      isTrue,
      reason: 'real pause/resume beyond settle window must relock',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
}
