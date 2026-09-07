import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/security/snapshot_mask.dart';

void main() {
  group('shouldMask', () {
    test('masks on inactive and paused, clears on resumed/detached', () {
      expect(shouldMask(AppLifecycleState.inactive), isTrue);
      expect(shouldMask(AppLifecycleState.paused), isTrue);
      expect(shouldMask(AppLifecycleState.resumed), isFalse);
      expect(shouldMask(AppLifecycleState.detached), isFalse);
    });
  });

  group('LifecycleMaskController', () {
    testWidgets('drives masked from lifecycle state', (tester) async {
      final controller = LifecycleMaskController();
      addTearDown(controller.dispose);

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(controller.masked.value, isTrue);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.masked.value, isFalse);
    });
  });

  group('stuck-mask recovery', () {
    testWidgets('reconcile is a no-op when the mask is already down, and '
        'does not raise it', (tester) async {
      final controller = LifecycleMaskController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // In the test binding the platform lifecycle state is null; the
      // reconcile must be conservative — never raise the mask, and with no
      // authoritative resumed state it cannot clear a legitimately-set one.
      controller.reconcileWithPlatform();
      expect(controller.masked.value, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(controller.masked.value, isTrue);
      // Null platform state (test env): the paused mask stays — clearing
      // requires the platform itself to report resumed.
      controller.reconcileWithPlatform();
      expect(controller.masked.value, isTrue);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.masked.value, isFalse);
    });
  });

  group('AppPrivacyShield', () {
    testWidgets('shows the mask only while masked is true', (tester) async {
      final masked = ValueNotifier<bool>(false);
      addTearDown(masked.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppPrivacyShield(
            masked: masked,
            child: const Text('PHI content'),
          ),
        ),
      );

      expect(find.byType(PrivacyMask), findsNothing);
      expect(find.text('PHI content'), findsOneWidget);

      masked.value = true;
      await tester.pump();
      expect(find.byType(PrivacyMask), findsOneWidget);

      masked.value = false;
      await tester.pump();
      expect(find.byType(PrivacyMask), findsNothing);
    });
  });
}
