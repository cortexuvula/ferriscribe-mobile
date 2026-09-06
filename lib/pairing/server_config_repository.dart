import 'package:drift/drift.dart';

import '../core/constants.dart';
import '../storage/database/app_database.dart';
import '../storage/key_store.dart';

/// Non-secret view of the paired server (the token is intentionally absent —
/// it lives only in the secure store).
class ServerConfig {
  const ServerConfig({
    required this.label,
    required this.host,
    required this.pairingPort,
    required this.dataPort,
    required this.pairedAt,
  });

  final String label;
  final String host;
  final int pairingPort;
  final int dataPort;
  final DateTime pairedAt;
}

/// Persists pairing state: the token in the platform secure store, the
/// non-secret server metadata in the SQLCipher DB.
class ServerConfigRepository {
  ServerConfigRepository(this._db, this._keyStore);

  final AppDatabase _db;
  final KeyStore _keyStore;

  Future<String?> readToken() => _keyStore.read(kTokenKey);

  Future<void> writeToken(String token) => _keyStore.write(kTokenKey, token);

  Future<void> deleteToken() => _keyStore.delete(kTokenKey);

  /// Persists a successful pairing. Replaces any previous pairing.
  Future<void> savePaired({
    required String label,
    required String host,
    required int pairingPort,
    required int dataPort,
    required String token,
  }) async {
    await _keyStore.write(kTokenKey, token);
    await _db
        .into(_db.serverConfigs)
        .insertOnConflictUpdate(
          ServerConfigsCompanion.insert(
            id: const Value(1),
            label: Value(label),
            tailscaleHost: Value(host),
            pairingPort: Value(pairingPort),
            dataPort: Value(dataPort),
            pairedAt: DateTime.now(),
          ),
        );
  }

  /// The current paired server, or null if unpaired.
  Future<ServerConfig?> readCurrent() async {
    final row =
        await (_db.select(_db.serverConfigs)
              ..where((t) => t.id.equals(1))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return ServerConfig(
      label: row.label,
      host: row.tailscaleHost ?? row.lanHost ?? '',
      pairingPort: row.pairingPort,
      dataPort: row.dataPort,
      pairedAt: row.pairedAt,
    );
  }

  /// Clears pairing state (unpair).
  Future<void> clear() async {
    await _keyStore.delete(kTokenKey);
    await (_db.delete(_db.serverConfigs)..where((t) => t.id.equals(1))).go();
  }
}
