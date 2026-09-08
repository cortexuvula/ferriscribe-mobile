import 'package:flutter/material.dart';

import '../../core/build_stamp.dart';
import '../../security/app_lock.dart';
import '../../ui/theme/app_theme.dart';

/// Full-screen lock shown until [AppLockController.tryUnlock] succeeds.
/// No PHI, no data: brand mark + reason + Unlock button + honest
/// failure state. The app's real content is not built while locked.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    super.key,
    required this.lock,
    required this.auth,
    required this.canAuthenticate,
  });

  final AppLockController lock;
  final AppLockAuth auth;

  /// Null while capability is being checked; false = no screen lock set
  /// up (a clear setup state, never a silent skip).
  final bool? canAuthenticate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 56, color: scheme.primary),
                const SizedBox(height: 20),
                Text(
                  'FerriScribe is locked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock with your fingerprint, face, or phone PIN to '
                  'access consultation records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                switch (canAuthenticate) {
                  false => Text(
                    'This device has no screen lock set up. Set a PIN, '
                    'pattern, or biometric in system settings to protect '
                    'FerriScribe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.error,
                      height: 1.4,
                    ),
                  ),
                  _ => fullWidthButton(
                    FilledButton.icon(
                      onPressed: lock.authenticating
                          ? null
                          : () => lock.tryUnlock(auth),
                      icon: lock.authenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(lock.authenticating ? 'Checking…' : 'Unlock'),
                    ),
                  ),
                },
                if (lock.authError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    lock.authError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: scheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Build $buildSha · #$buildNumber',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
