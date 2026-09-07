import 'package:local_auth/local_auth.dart';

import 'app_lock.dart';

/// Real `local_auth` implementation of [AppLockAuth]. Kept in its own file
/// so the test suite (which only uses fakes) stays platform-free.
///
/// Device-credential fallback is REQUIRED ("biometric or phone pin"):
/// - `authMessages` include the device-credential option (Android),
/// - iOS falls back to passcode via localizedReason + the system's own
///   passcode button (LocalAuthentication with biometricOnly: false).
class LocalAuthGateImpl implements AppLockAuth {
  LocalAuthGateImpl() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    final can = await _auth.canCheckBiometrics;
    final deviceSupported = await _auth.isDeviceSupported();
    return can || deviceSupported;
  }

  @override
  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: 'Unlock FerriScribe to access your consultation records',
    biometricOnly: false, // device PIN/pattern fallback REQUIRED
    persistAcrossBackgrounding: true, // survive app-switch mid-prompt
  );
}
