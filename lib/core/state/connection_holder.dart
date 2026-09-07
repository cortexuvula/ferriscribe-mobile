import 'package:flutter/foundation.dart';

import 'connection_state.dart';

/// §5J app-scoped connection state: one shared, navigation-surviving truth
/// for "can we reach the paired office server".
///
/// Before this existed, Settings' check stored its result in screen-local
/// state that died on navigation, and the Consultations landing page
/// hardcoded 'connection not checked' — the user-visible bug where
/// checking in Settings never updated the main screen.
///
/// The holder is a [ChangeNotifier] owned by [AppServices]; every writer
/// (Settings check, Consultations content-sync result, record preflight)
/// pushes typed [ConnectionState]s through it, and every reader renders
/// from it. States carry host/port/version facts only — never content,
/// never PHI.
///
/// Auth failure stays distinct from unreachable: the UI must render
/// 'Pairing needs attention', never 'offline' (see ConnectionState).
class ConnectionHolder extends ChangeNotifier {
  ConnectionState? _last;

  /// The most recent completed check, if any. Null means never checked —
  /// rendered as 'connection not checked'.
  ConnectionState? get last => _last;

  /// True while a check is in flight (for progressive 'Checking…' UI).
  bool _checking = false;
  bool get checking => _checking;

  /// Publish a completed check. `ConnectionChecking` should not be pushed
  /// here — use [beginCheck] instead.
  void publish(ConnectionState state) {
    if (state is ConnectionChecking) {
      beginCheck();
      return;
    }
    _last = state;
    _checking = false;
    notifyListeners();
  }

  /// Mark a check as in flight. The previous completed fact is kept for
  /// progressive UI ('Checking…' + last-known state).
  void beginCheck() {
    _checking = true;
    notifyListeners();
  }

  /// Fold a content-sync outcome into the shared state (§5J): a
  /// successful authenticated read is the strongest connection fact
  /// available — it proves reachability AND pairing.
  void reportAuthenticatedRead({required bool ok}) {
    if (ok) {
      _last = Connected(
        checkedAt: DateTime.now(),
        kind: ConnectionCheckKind.authenticatedRead,
        authOk: true,
      );
      _checking = false;
      notifyListeners();
    } else {
      // Failure details belong to the caller (offline vs auth) — it will
      // publish the typed failure itself. Nothing to do here.
    }
  }

  /// Render label per §5J. Kept here so every surface uses the same
  /// vocabulary.
  String get label => switch (_last) {
    null => 'connection not checked',
    ConnectionChecking() => 'checking connection…',
    Connected(:final authOk, :final serverVersion) =>
      authOk
          ? 'office server connected'
          : (serverVersion != null
                ? 'office server reachable · $serverVersion'
                : 'office server reachable'),
    Unreachable() => 'office server unreachable',
    AuthFailure() => 'pairing needs attention',
    ConnectionUnknown() => 'connection not checked',
  };
}
