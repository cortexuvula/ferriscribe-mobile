import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/constants.dart';
import 'pairing/pairing_service.dart';
import 'pairing/server_config_repository.dart';
import 'security/platform_security.dart';
import 'storage/database/app_database.dart';
import 'core/state/connection_holder.dart';
import 'security/app_lock.dart';
import 'storage/key_store.dart';
import 'storage/offline_cache_repository.dart';

/// App-wide service container, built once at startup.
class AppServices {
  AppServices({
    required this.db,
    required this.keyStore,
    required this.serverConfigRepository,
    required this.pairingService,
    required this.offlineCache,
    AppLockAuth? appLockAuth,
  }) : connection = ConnectionHolder(),
       appLockAuth = appLockAuth ?? const NoAuthGate();

  /// §5J app-scoped connection state — shared across screens so a check
  /// in Settings is visible on the Consultations landing page.
  final ConnectionHolder connection;

  /// Launch gate (biometric/PIN). Defaults to a pass-through gate so
  /// existing tests construct services unchanged; main() installs the
  /// real local_auth-backed gate.
  final AppLockAuth appLockAuth;

  /// The app-lock controller owned by the root widget, exposed so
  /// _RootScreen can defer its (secure-store-reading) load until unlock.
  AppLockController? appLock;

  final AppDatabase db;
  final KeyStore keyStore;
  final ServerConfigRepository serverConfigRepository;
  final PairingService pairingService;
  final OfflineCacheRepository offlineCache;
}

/// Builds the service graph, generating/persisting the SQLCipher key and
/// opening the encrypted database.
class AppBootstrap {
  static Future<AppServices> create({AppLockAuth? appLockAuth}) async {
    final keyStore = SecureKeyStore();

    // Generate-or-load the SQLCipher key. The key never leaves the secure
    // store and never touches disk in plaintext.
    var dbKey = await keyStore.read(kDbKeyKey);
    if (dbKey == null || dbKey.isEmpty) {
      dbKey = generateDbKeyHex();
      await keyStore.write(kDbKeyKey, dbKey);
    }

    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'ferriscribe.db');

    final db = AppDatabase.open(path: dbPath, key: dbKey);

    // Exclude the SQLCipher DB from OS backup / cloud sync. Best-effort; the
    // Android manifest already disables backup app-wide.
    await PlatformSecurity.excludeFromBackup(dbPath);

    final repository = ServerConfigRepository(db, keyStore);
    final pairingService = PairingService(repository: repository);
    final offlineCache = OfflineCacheRepository(db);

    return AppServices(
      db: db,
      keyStore: keyStore,
      serverConfigRepository: repository,
      pairingService: pairingService,
      offlineCache: offlineCache,
      appLockAuth: appLockAuth,
    );
  }
}
