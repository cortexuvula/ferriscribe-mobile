import 'package:flutter/services.dart';

import '../core/constants.dart';

/// Native security hooks that Flutter cannot express on its own.
///
/// The channel name and method names must match the native side
/// (Android `MainActivity.kt`, iOS `AppDelegate.swift`).
class PlatformSecurity {
  PlatformSecurity._();

  static const MethodChannel _channel = MethodChannel(kNativeChannel);

  /// Marks a file or directory as excluded from OS backup / cloud sync.
  ///
  /// iOS: sets `NSURLIsExcludedFromBackupKey` on the given path.
  /// Android: backup is disabled app-wide via `android:allowBackup="false"`
  /// and data-extraction rules, so this is a no-op that returns `true`.
  ///
  /// Returns `false` only on a genuine native failure; [MissingPluginException]
  /// (no native side, e.g. in widget tests) is treated as non-fatal.
  static Future<bool> excludeFromBackup(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('excludeFromBackup', {
        'path': path,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
