import 'dart:developer' as developer;

/// Counts/lengths/IDs-only logger.
///
/// Inherits the FerriScribe desktop rule: **never log PHI.** Every method
/// accepts only non-PHI inputs — counts, byte lengths, opaque IDs, HTTP status
/// codes, and fixed event labels. There is deliberately no method that accepts
/// a free-form dynamic string, so a transcript fragment, patient name, or the
/// bearer token cannot reach the log.
///
/// Do NOT add a `debug(String message)` escape hatch: it defeats the rule.
/// `developer.log` is a no-op in release builds, so this never persists in
/// production either.
final class AppLog {
  AppLog._();

  /// Log a fixed event label (no dynamic content, no PHI).
  static void event(String label) {
    developer.log(label, name: 'ferriscribe', time: DateTime.now());
  }

  /// Log a named count (e.g. number of records synced).
  static void count(String label, int n) {
    developer.log('$label=$n', name: 'ferriscribe', time: DateTime.now());
  }

  /// Log a named byte length (e.g. audio payload size).
  static void byteLength(String label, int bytes) {
    developer.log(
      '$label=$bytes bytes',
      name: 'ferriscribe',
      time: DateTime.now(),
    );
  }

  /// Log an opaque ID (e.g. a recording UUID). IDs carry no PHI.
  static void id(String label, String opaqueId) {
    developer.log(
      '$label=$opaqueId',
      name: 'ferriscribe',
      time: DateTime.now(),
    );
  }

  /// Log an HTTP status code for a named request.
  static void status(String label, int statusCode) {
    developer.log(
      '$label=$statusCode',
      name: 'ferriscribe',
      time: DateTime.now(),
    );
  }
}
