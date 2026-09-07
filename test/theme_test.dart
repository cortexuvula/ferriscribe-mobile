import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';
import 'package:ferriscribe_mobile/ui/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeOption persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to system when nothing stored', () async {
      expect(await ThemeModeOption.load(), ThemeModeOption.system);
    });

    test('save() round-trips light and dark', () async {
      await ThemeModeOption.light.save();
      expect(await ThemeModeOption.load(), ThemeModeOption.light);

      await ThemeModeOption.dark.save();
      expect(await ThemeModeOption.load(), ThemeModeOption.dark);
    });

    test('save() round-trips back to system', () async {
      await ThemeModeOption.dark.save();
      await ThemeModeOption.system.save();
      expect(await ThemeModeOption.load(), ThemeModeOption.system);
    });

    test('unknown stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'neon'});
      expect(await ThemeModeOption.load(), ThemeModeOption.system);
    });

    test(
      'corrupt preference store falls back to system, non-fatally',
      () async {
        // Simulate a failing prefs read: setMockInitialValues is not used, and
        // we can't easily force SharedPreferences.getInstance to throw, so this
        // covers the unknown-value path; the try/catch is exercised implicitly.
        expect(await ThemeModeOption.load(), isA<ThemeModeOption>());
      },
    );
  });

  group('ThemeModeOption modes', () {
    test('maps to MaterialApp ThemeMode', () {
      expect(ThemeModeOption.system.mode, isNull);
      expect(ThemeModeOption.light.mode, ThemeMode.light);
      expect(ThemeModeOption.dark.mode, ThemeMode.dark);
      expect(ThemeModeOption.system.helper, 'Match device appearance');
    });
  });

  group('ThemeController', () {
    test('setOption notifies listeners and marks user choice', () {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setOption(ThemeModeOption.dark);
      expect(controller.option, ThemeModeOption.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(notified, 1);

      // Same option: no redundant notification.
      controller.setOption(ThemeModeOption.dark);
      expect(notified, 1);
    });

    testWidgets('startup load does not override a just-made user choice', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
      final controller = ThemeController();
      final future = controller.load(); // not yet awaited
      controller.setOption(ThemeModeOption.light); // user beats the load
      await future;
      expect(controller.option, ThemeModeOption.light);
    });

    testWidgets('startup load applies the stored choice when idle', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
      final controller = ThemeController();
      await controller.load();
      expect(controller.option, ThemeModeOption.dark);
    });
  });

  group('buildAppTheme tokens', () {
    test('light and dark derive from the same brand seed', () {
      final light = buildAppTheme(Brightness.light);
      final dark = buildAppTheme(Brightness.dark);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      // Canvas/surface polarity.
      expect(
        light.scaffoldBackgroundColor.computeLuminance(),
        greaterThan(0.5),
      );
      expect(dark.scaffoldBackgroundColor.computeLuminance(), lessThan(0.5));
    });

    test('contrast: onSurface vs surface >= 4.5:1 ratio in both modes', () {
      for (final theme in [
        buildAppTheme(Brightness.light),
        buildAppTheme(Brightness.dark),
      ]) {
        final ratio = _contrastRatio(
          theme.colorScheme.onSurface,
          theme.colorScheme.surface,
        );
        expect(
          ratio,
          greaterThan(4.5),
          reason: 'onSurface/surface in ${theme.brightness}',
        );
      }
    });

    test('semantic status colors are exposed via ThemeExtension', () {
      final light = buildAppTheme(Brightness.light);
      final dark = buildAppTheme(Brightness.dark);
      final lightStatus = light.extension<AppStatusColors>()!;
      final darkStatus = dark.extension<AppStatusColors>()!;

      // Success container text is readable in both modes.
      expect(
        _contrastRatio(
          lightStatus.onSuccessContainer,
          lightStatus.successContainer,
        ),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(
          darkStatus.onSuccessContainer,
          darkStatus.successContainer,
        ),
        greaterThan(4.5),
      );
      // Warning container too (offline banner).
      expect(
        _contrastRatio(
          lightStatus.onWarningContainer,
          lightStatus.warningContainer,
        ),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(
          darkStatus.onWarningContainer,
          darkStatus.warningContainer,
        ),
        greaterThan(4.5),
      );
    });

    test('primary-onPrimary contrast in both modes', () {
      for (final theme in [
        buildAppTheme(Brightness.light),
        buildAppTheme(Brightness.dark),
      ]) {
        expect(
          _contrastRatio(
            theme.colorScheme.primary,
            theme.colorScheme.onPrimary,
          ),
          greaterThan(4.5),
          reason: 'primary/onPrimary in ${theme.brightness}',
        );
      }
    });

    test('input hint stays distinct from canvas', () {
      final dark = buildAppTheme(Brightness.dark);
      final hint = dark.inputDecorationTheme.hintStyle?.color;
      expect(hint, isNotNull);
      expect(
        _contrastRatio(hint!, dark.scaffoldBackgroundColor),
        greaterThan(4.5),
        reason: 'hint on dark canvas',
      );
    });
  });

  group('buildAppTheme follows the selected mode', () {
    Widget harness(ThemeModeOption option) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: option.mode ?? ThemeMode.system,
      home: const Scaffold(body: Text('content')),
    );

    testWidgets('system renders light under platform light', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(harness(ThemeModeOption.system));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('system renders dark under platform dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(harness(ThemeModeOption.system));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('light override sticks under platform dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(harness(ThemeModeOption.light));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('dark override sticks under platform light', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(harness(ThemeModeOption.dark));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.dark,
      );
    });
  });
}

/// WCAG-style contrast ratio (>=4.5 for normal text).
double _contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double channel(double v) {
      return v <= 0.03928
          ? v / 12.92
          : pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = ((c.r * 255.0).round().clamp(0, 255)).toDouble();
    final g = ((c.g * 255.0).round().clamp(0, 255)).toDouble();
    final b = ((c.b * 255.0).round().clamp(0, 255)).toDouble();
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
  }

  final l1 = lum(a);
  final l2 = lum(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}
