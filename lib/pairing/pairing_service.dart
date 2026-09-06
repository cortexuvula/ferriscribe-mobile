import '../core/constants.dart';
import 'pairing_client.dart';
import 'pairing_payload.dart';
import 'server_config_repository.dart';

/// Outcome of a successful pairing, for display and for the home screen.
class PairingResult {
  const PairingResult({
    required this.host,
    required this.serverVersion,
    this.tailscale,
  });

  final String host;
  final String serverVersion;
  final String? tailscale;
}

/// Orchestrates the QR → probe → enroll → persist flow.
///
/// `POST /pair/enroll` is one-shot and consumes the 6-digit code on the server,
/// so this runs probe-then-enroll exactly once per code.
class PairingService {
  PairingService({
    required this.repository,
    PairingClient Function(String baseUrl)? clientFactory,
  }) : _clientFactory = clientFactory ?? _defaultClient;

  final ServerConfigRepository repository;
  final PairingClient Function(String baseUrl) _clientFactory;

  static PairingClient _defaultClient(String baseUrl) =>
      PairingClient(baseUrl: baseUrl);

  /// Runs the full pairing flow from a raw QR text.
  Future<PairingResult> pair({
    required String qrText,
    required String label,
  }) async {
    final payload = PairingPayload.parse(qrText);
    final host = payload.preferredHost;
    if (host == null) {
      throw const PairingException('pairing URL carries no reachable host');
    }

    final client = _clientFactory(
      PairingClient.baseUrlFor(host, payload.pairingPort),
    );
    try {
      // Probe first — verifies reachability over Tailscale/LAN and surfaces a
      // clean error before consuming the one-shot code.
      final info = await client.fetchInfo();
      final token = await client.enroll(code: payload.code, label: label);
      await repository.savePaired(
        label: label,
        host: host,
        pairingPort: payload.pairingPort,
        dataPort: payload.dataPort ?? kDefaultDataPort,
        token: token,
      );
      return PairingResult(
        host: host,
        serverVersion: info.version,
        tailscale: info.tailscale,
      );
    } finally {
      client.close();
    }
  }
}
