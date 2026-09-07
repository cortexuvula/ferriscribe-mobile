import 'package:flutter/material.dart';

/// Semantic status colors beyond Material's baseline scheme — success and
/// warning — mapped per theme from the design tokens (docs/design/DESIGN.md).
///
/// Access via `Theme.of(context).extension<AppStatusColors>()!`.
///
/// Per the design: green never means "clinically reviewed" — it only marks
/// presence/success of an operation. Status is always icon + words + color,
/// never color alone.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.onWarningContainer,
    required this.warningContainer,
  });

  /// Foreground success (icon/text on canvas).
  final Color success;

  /// Container fill for success notices.
  final Color successContainer;

  /// Text on successContainer.
  final Color onSuccessContainer;

  /// Foreground warning (offline/degraded).
  final Color warning;

  /// Container fill for warning notices (e.g. offline banner).
  final Color warningContainer;

  /// Text on warningContainer.
  final Color onWarningContainer;

  static const light = AppStatusColors(
    success: Color(0xFF216C50),
    successContainer: Color(0xFFE2F2E9),
    onSuccessContainer: Color(0xFF20553F),
    warning: Color(0xFF865600),
    warningContainer: Color(0xFFFFF1D4),
    onWarningContainer: Color(0xFF684700),
  );

  static const dark = AppStatusColors(
    success: Color(0xFF94D7B5),
    successContainer: Color(0xFF203F34),
    onSuccessContainer: Color(0xFFB8E7CE),
    warning: Color(0xFFEDC773),
    warningContainer: Color(0xFF433722),
    onWarningContainer: Color(0xFFF7DCA5),
  );

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccessContainer,
    Color? successContainer,
    Color? warning,
    Color? onWarningContainer,
    Color? warningContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}

/// Builds the FerriScribe clinical theme for a brightness.
///
/// The scheme is initialized from the brand seed (#1B6B93) via
/// `ColorScheme.fromSeed`, then the documented semantic roles are mapped
/// explicitly from the design tokens — canvas, surfaces, outlines — so the
/// tokens stay normative. Success/warning ride in [AppStatusColors].
///
/// Design constants: 12dp control radius, 16dp grouped panels, 24dp sheets;
/// native platform fonts only (no downloads); never clamp text scaling.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final seedScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B6B93),
    brightness: brightness,
  );

  // Semantic tokens from DESIGN.md (paired per theme).
  final canvas = isDark ? const Color(0xFF101A23) : const Color(0xFFF4F7F9);
  final surface = isDark ? const Color(0xFF192731) : const Color(0xFFFFFFFF);
  final surfaceVariant = isDark
      ? const Color(0xFF233641)
      : const Color(0xFFE8EFF3);
  final onSurface = isDark ? const Color(0xFFE6EEF3) : const Color(0xFF162D3B);
  final onSurfaceVariant = isDark
      ? const Color(0xFFB1C2CD)
      : const Color(0xFF4E6573);
  final primary = isDark ? const Color(0xFF91CEF0) : const Color(0xFF1B6B93);
  final onPrimary = isDark ? const Color(0xFF10384F) : const Color(0xFFFFFFFF);
  final primaryContainer = isDark
      ? const Color(0xFF21495F)
      : const Color(0xFFDAEBF4);
  final onPrimaryContainer = isDark
      ? const Color(0xFFD7EDF9)
      : const Color(0xFF174660);
  final outline = isDark ? const Color(0xFF718B9B) : const Color(0xFF768B98);
  final outlineVariant = isDark
      ? const Color(0xFF3A505F)
      : const Color(0xFFCEDAE1);

  final scheme = seedScheme.copyWith(
    surface: surface,
    onSurface: onSurface,
    surfaceContainer: surfaceVariant,
    surfaceContainerLowest: canvas,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: canvas,
    extensions: [isDark ? AppStatusColors.dark : AppStatusColors.light],
    // Native platform fonts — no downloads; never clamp text scaling.
    fontFamily: null,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: outline),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      hintStyle: TextStyle(color: onSurfaceVariant),
      labelStyle: TextStyle(color: onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minVerticalPadding: 14,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primary : onSurfaceVariant,
      ),
    ),
    dividerTheme: DividerThemeData(color: outlineVariant, thickness: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
