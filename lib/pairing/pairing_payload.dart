import '../core/constants.dart';

/// Parsed contents of the `ferriscribe://pair?...` URL the desktop QR encodes.
///
/// Verified against `crates/sharing/src/qr.rs`. Required params: `code`,
/// `host`, `op` (ollama), `wp` (whisper), `pp` (pairing). Optional: `lan`,
/// `ts` (tailscale), `lp` (lmstudio), `mp` (omlx), `vp` (vocab/data). Keys are
/// emitted in sorted order and percent-encoded; this parser decodes and
/// normalises so ordering and encoding differences don't matter.
class PairingPayload {
  const PairingPayload({
    required this.code,
    required this.host,
    required this.pairingPort,
    required this.ollamaPort,
    required this.whisperPort,
    this.lan,
    this.tailscale,
    this.lmstudioPort,
    this.omlxPort,
    this.dataPort,
  });

  final String code;
  final String host;
  final int pairingPort;
  final int ollamaPort;
  final int whisperPort;
  final String? lan;
  final String? tailscale;
  final int? lmstudioPort;
  final int? omlxPort;
  final int? dataPort;

  /// Parses a raw QR text into a [PairingPayload].
  ///
  /// Throws [FormatException] on an invalid URL or missing/out-of-range
  /// required field. Messages carry no PHI (a pairing code and ports are not
  /// PHI, but we avoid echoing the code back verbatim regardless).
  static PairingPayload parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) {
      throw const FormatException('not a valid pairing URL');
    }
    if (uri.scheme != kPairingScheme || uri.host != 'pair') {
      throw const FormatException('not a ferriscribe://pair URL');
    }

    final code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) {
      throw const FormatException('pairing URL missing code');
    }
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('pairing code must be 6 digits');
    }

    final host = uri.queryParameters['host']?.trim();
    if (host == null || host.isEmpty) {
      throw const FormatException('pairing URL missing host');
    }

    int requiredPort(String key) {
      final rawPort = uri.queryParameters[key];
      final port = rawPort == null ? null : int.tryParse(rawPort);
      if (port == null || port < 1 || port > 65535) {
        throw FormatException('pairing URL missing or invalid $key port');
      }
      return port;
    }

    int? optionalPort(String key) {
      final rawPort = uri.queryParameters[key];
      if (rawPort == null) return null;
      final port = int.tryParse(rawPort);
      if (port == null || port < 1 || port > 65535) {
        throw FormatException('pairing URL has invalid $key port');
      }
      return port;
    }

    return PairingPayload(
      code: code,
      host: host,
      pairingPort: requiredPort('pp'),
      ollamaPort: requiredPort('op'),
      whisperPort: requiredPort('wp'),
      lan: _nonEmpty(uri.queryParameters['lan']),
      tailscale: _nonEmpty(uri.queryParameters['ts']),
      lmstudioPort: optionalPort('lp'),
      omlxPort: optionalPort('mp'),
      dataPort: optionalPort('vp'),
    );
  }

  /// The host to connect over, preferring Tailscale (the PHI-safe transport).
  ///
  /// Content sync is Tailscale-only on the server; pairing and `/info` work on
  /// either. Prefer the Tailscale name when the QR carries one.
  String? get preferredHost => tailscale ?? lan;

  static String? _nonEmpty(String? s) {
    final v = s?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
