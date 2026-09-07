/// §6.1 — Connection state adapter (design/MOBILE_REDESIGN.md).
///
/// One typed snapshot of "can we reach the paired server, and how do we
/// know". UI renders from this; it never guesses from HTTP strings.
/// Facts are honest about how they were obtained (probe vs authenticated
/// read), and `authFailure` is distinct from unreachable.
library;

/// How the connection fact was obtained.
enum ConnectionCheckKind {
  /// Unauthenticated readiness probe (`GET :11436/info`).
  probe,

  /// Authenticated data-API read (e.g. content-sync pull succeeded).
  authenticatedRead,
}

/// Typed connection state for the paired office server.
sealed class ConnectionState {
  const ConnectionState({required this.checkedAt});

  /// Local clock time of the observation.
  final DateTime checkedAt;

  /// True when the server answered AND the bearer token was accepted.
  bool get isOperational => switch (this) {
    Connected(:final authOk) => authOk,
    _ => false,
  };

  /// True when the last known fact is an auth failure (token revoked or
  /// rejected). Distinct from offline — the UI must say "pairing needs
  /// attention", not "no connection".
  bool get isAuthFailure => switch (this) {
    AuthFailure() => true,
    _ => false,
  };
}

/// No check has run yet.
class ConnectionUnknown extends ConnectionState {
  const ConnectionUnknown({required super.checkedAt});
}

/// Server reachable. `authOk` is true only when an authenticated read
/// succeeded (a bare `/info` probe proves reachability, not pairing).
class Connected extends ConnectionState {
  const Connected({
    required super.checkedAt,
    required this.kind,
    required this.authOk,
    this.serverVersion,
  });

  final ConnectionCheckKind kind;

  /// Whether an authenticated call has succeeded against this server
  /// during this check (or the most recent one before it).
  final bool authOk;

  /// Server version string from `/info`, when the check was a probe.
  final String? serverVersion;
}

/// Server did not answer (network unreachable, timeout, DNS/Tailnet down).
class Unreachable extends ConnectionState {
  const Unreachable({required super.checkedAt, this.reason});
  final String? reason;
}

/// Server answered but rejected the bearer token (401/403) — pairing is
/// stale or revoked. Never render this as "offline".
class AuthFailure extends ConnectionState {
  const AuthFailure({required super.checkedAt, this.statusCode});
  final int? statusCode;
}

/// Checking right now — previous state carried along for progressive UI.
class ConnectionChecking extends ConnectionState {
  const ConnectionChecking({required super.checkedAt, required this.previous});
  final ConnectionState previous;
}
