import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// The UI brightness mode selected by the user.
///
/// Backwards-compatible with the previous `themeMode` shared_preferences key
/// (values `system` / `light` / `dark`).
enum ThemeModeOption {
  system('System', 'Match device appearance', null),
  light('Light', 'Always light', ThemeMode.light),
  dark('Dark', 'Always dark', ThemeMode.dark);

  const ThemeModeOption(this.label, this.helper, this.mode);

  final String label;
  final String helper;
  final ThemeMode? mode;

  static const _key = 'themeMode';

  static Future<ThemeModeOption> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_key)) {
        'light' => light,
        'dark' => dark,
        _ => system,
      };
    } catch (_) {
      // Failed preference read must not crash startup or override a choice.
      return system;
    }
  }

  Future<bool> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key, name);
    } catch (_) {
      // Non-fatal: theme stays applied in-memory even if persistence fails.
      return false;
    }
  }
}

/// Owns the current [ThemeModeOption] and notifies listeners.
///
/// Startup race guard: a slow initial [load] result is applied only when no
/// user choice has been made meanwhile, so a delayed load can never override
/// a just-tapped selection.
class ThemeController extends ChangeNotifier {
  ThemeController([this._option = ThemeModeOption.system]);

  ThemeModeOption _option;

  ThemeModeOption get option => _option;

  /// Material theme mode for [MaterialApp.themeMode].
  ThemeMode get themeMode => _option.mode ?? ThemeMode.system;

  /// Async load for app startup. Guards against the startup race: if the
  /// user picks a mode before the stored preference arrives, the stored
  /// value is discarded.
  Future<void> load() async {
    final stored = await ThemeModeOption.load();
    if (_userSelected) return; // user beat the load — keep their choice
    _option = stored;
    notifyListeners();
  }

  bool _userSelected = false;

  /// Applies [option] immediately, persists it best-effort, and marks that a
  /// user choice is now authoritative over any pending startup load.
  void setOption(ThemeModeOption option) {
    if (option == _option) {
      _userSelected = true;
      return;
    }
    _option = option;
    _userSelected = true;
    notifyListeners();
    option.save(); // fire-and-forget; failure is non-fatal
  }

  @visibleForTesting
  void debugResetUserSelection() => _userSelected = false;
}
