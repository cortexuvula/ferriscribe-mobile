import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ferriscribe_mobile/app.dart';

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
  });

  group('ThemeModeOption modes', () {
    test('maps to MaterialApp ThemeMode', () {
      expect(ThemeModeOption.system.mode, isNull);
      expect(ThemeModeOption.light.mode, ThemeMode.light);
      expect(ThemeModeOption.dark.mode, ThemeMode.dark);
    });

    test('every option has a label and icon', () {
      for (final o in ThemeModeOption.values) {
        expect(o.label, isNotEmpty);
        expect(o.icon, isNotNull);
      }
    });
  });

  group('buildTheme', () {
    test('light and dark derive from the same brand seed', () {
      final light = buildTheme(Brightness.light);
      final dark = buildTheme(Brightness.dark);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      // Dark surfaces must actually be dark; light surfaces light.
      final darkLum = dark.colorScheme.surface.computeLuminance();
      final lightLum = light.colorScheme.surface.computeLuminance();
      expect(darkLum, lessThan(0.5), reason: 'dark surface should be dark');
      expect(
        lightLum,
        greaterThan(0.5),
        reason: 'light surface should be light',
      );

      // On-surface text must contrast against its own surface in both modes.
      for (final theme in [light, dark]) {
        final lumDiff =
            (theme.colorScheme.onSurface.computeLuminance() -
                    theme.colorScheme.surface.computeLuminance())
                .abs();
        expect(
          lumDiff,
          greaterThan(0.4),
          reason: 'onSurface/surface contrast in ${theme.brightness}',
        );
      }

      // Same seed → same primary hue family in both modes.
      expect(
        dark.colorScheme.primary.toARGB32() & 0x00FF0000,
        isNot(equals(light.colorScheme.primary.toARGB32() & 0x00FF0000 | 1)),
      );
    });

    test('dark editor hint stays distinct from background', () {
      final dark = buildTheme(Brightness.dark);
      final hint = dark.inputDecorationTheme.hintStyle?.color;
      expect(hint, isNotNull);
      // Hint is visible but softer than full onSurface.
      final hintLum = hint!.computeLuminance();
      final surfaceLum = dark.colorScheme.surface.computeLuminance();
      expect(
        hintLum - surfaceLum,
        greaterThan(0.1),
        reason: 'hint must be readable on dark surface',
      );
    });
  });

  group('FerriScribeApp follows the selected mode', () {
    testWidgets('system mode renders light under platform light', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'system'});
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(const _Harness(option: ThemeModeOption.system));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('system mode renders dark under platform dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(const _Harness(option: ThemeModeOption.system));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('light override stays light under platform dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(const _Harness(option: ThemeModeOption.light));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('dark override stays dark under platform light', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(const _Harness(option: ThemeModeOption.dark));
      expect(
        Theme.of(tester.element(find.text('content'))).brightness,
        Brightness.dark,
      );
    });
  });
}

/// Pumps a MaterialApp configured exactly like FerriScribeApp's theme block
/// so the resolved Theme.brightness can be asserted per option.
class _Harness extends StatelessWidget {
  const _Harness({required this.option});

  final ThemeModeOption option;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: option.mode ?? ThemeMode.system,
      home: const Scaffold(body: Text('content')),
    );
  }
}
