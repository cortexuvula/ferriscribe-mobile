import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_logger.dart';

/// `GET /info` response body (verified against
/// `crates/sharing/src/orchestrator.rs` `InfoSnapshot`).
class ServerInfo {
  const ServerInfo({
    required this.host,
    required this.version,
    required this.ports,
    this.tailscale,
  });

  final String host;
  final String version;
  final ServerPorts ports;
  final String? tailscale;

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      host: json['host'] as String? ?? '',
      version: json['version'] as String? ?? '',
      ports: ServerPorts.fromJson(
        (json['ports'] as Map<String, dynamic>?) ?? const {},
      ),
      tailscale: json['tailscale'] as String?,
    );
  }
}

/// Ports block of `GET /info` (`crates/sharing/src/mdns.rs` `ServerPorts`).
class ServerPorts {
  const ServerPorts({
    this.ollama,
    this.whisper,
    this.lmstudio,
    this.omlx,
    this.pairing,
    this.vocab,
  });

  final int? ollama;
  final int? whisper;
  final int? lmstudio;
  final int? omlx;
  final int? pairing;
  final int? vocab;

  factory ServerPorts.fromJson(Map<String, dynamic> json) {
    int? port(String key) => (json[key] as num?)?.toInt();
    return ServerPorts(
      ollama: port('ollama'),
      whisper: port('whisper'),
      lmstudio: port('lmstudio'),
      omlx: port('omlx'),
      pairing: port('pairing'),
      vocab: port('vocab'),
    );
  }
}

/// Thin HTTP client for the pairing router on `:11436`.
///
/// Only ever talks to the paired office server. Never logs PHI; status codes
/// and byte lengths only.
class PairingClient {
  PairingClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Base URL including scheme/host/port (e.g. `http://clinic.tail-abc.ts.net:11436`).
  final String baseUrl;
  final http.Client _client;

  /// Builds a base URL, bracketing IPv6 literals (mirrors the server's
  /// `medical_core::types::http_url` behaviour).
  static String baseUrlFor(String host, int port) {
    final h = (host.contains(':') && !host.startsWith('[')) ? '[$host]' : host;
    return 'http://$h:$port';
  }

  /// `GET /info` — unauthenticated discovery/readiness probe.
  Future<ServerInfo> fetchInfo() async {
    final uri = Uri.parse('$baseUrl/info');
    final resp = await _client.get(uri).timeout(const Duration(seconds: 5));
    AppLog.status('info', resp.statusCode);
    if (resp.statusCode != 200) {
      throw PairingException('server /info returned ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return ServerInfo.fromJson(body);
  }

  /// `POST /pair/enroll` — exchange a 6-digit code + label for a bearer token.
  ///
  /// Returns the token on success. The token is never logged.
  Future<String> enroll({required String code, required String label}) async {
    final uri = Uri.parse('$baseUrl/pair/enroll');
    AppLog.count('enroll.codeLength', code.length);
    AppLog.count('enroll.labelLength', label.length);
    final resp = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'code': code, 'label': label}),
        )
        .timeout(const Duration(seconds: 10));
    AppLog.status('enroll', resp.statusCode);
    if (resp.statusCode != 200) {
      throw PairingException('server rejected pairing (${resp.statusCode})');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = body['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const PairingException('server returned no token');
    }
    AppLog.count('enroll.tokenLength', token.length);
    return token;
  }

  void close() => _client.close();
}

/// A pairing/network failure surfaced to the UI. Messages carry no PHI and no
/// secrets (no token, no code, no transcript).
class PairingException implements Exception {
  const PairingException(this.message);
  final String message;

  @override
  String toString() => message;
}
