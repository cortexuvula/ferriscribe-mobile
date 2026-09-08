import 'package:flutter/foundation.dart';

/// Launch/auth gate seam (injectable for tests — `local_auth` needs a
/// platform channel this Mac's test runner lacks).
///
/// HONESTY BOUNDARY (ferriscribe's scope note): this is a UX gate, not a
/// cryptographic one. The SQLCipher key stays in the secure store; the
/// real data boundary remains OS lock + SQLCipher. This gate stops casual
/// access to the decrypted UI, not a determined forensic attacker.
/// (True biometric-gated decryption = kSecAccessControl / Keystore
/// setUserAuthenticationRequired — a scoped follow-up, deliberately not
/// built here.)
abstract class AppLockAuth {
  /// Whether the device can authenticate at all (biometric OR device
  /// PIN/pattern). False means the user must set up a screen lock.
  Future<bool> canAuthenticate();

  /// Prompt the user. Returns true on success. Device-credential
  /// fallback MUST be enabled: "biometric or phone pin" per the user's
  /// requirement — never biometric-only.
  Future<bool> authenticate();
}

/// Controller for the app lock: locked by default on cold launch, with
/// opt-in re-lock on app resume (background -> foreground).
class AppLockController extends ChangeNotifier {
  AppLockController({this.relockOnResume = true}) : _locked = true;

  /// Whether returning from background re-locks. Default ON: a physician
  /// can hand the phone off while the app is foregrounded — that's the
  /// gap the lock exists to close.
  final bool relockOnResume;
  bool _locked;
  bool _authenticating = false;

  bool get locked => _locked;
  bool get authenticating => _authenticating;

  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  void lock() {
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Last authentication error (non-PHI: a fixed message, never the
  /// raw exception text). Cleared on the next attempt.
  String? authError;

  /// Runs one authentication attempt. Returns true when unlocked.
  Future<bool> tryUnlock(AppLockAuth auth) async {
    if (!_locked) return true;
    _authenticating = true;
    authError = null;
    notifyListeners();
    try {
      final ok = await auth.authenticate();
      if (ok) unlock();
      return ok;
    } catch (_) {
      // e.g. PlatformException when the activity can't host
      // BiometricPrompt, or no biometric hardware enrolled. A fixed,
      // PHI-free message; the button stays re-tryable.
      authError =
          'Couldn\'t start authentication — check that a screen '
          'lock is set up on this phone.';
      return false;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }
}

/// Pass-through gate for tests and pre-lock builds: always authenticated,
/// never prompts. main() replaces it with [LocalAuthGateImpl].
class NoAuthGate implements AppLockAuth {
  const NoAuthGate();
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<bool> authenticate() async => true;
}
