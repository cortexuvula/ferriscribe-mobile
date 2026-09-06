import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/constants.dart';

part 'app_database.g.dart';

/// Non-secret metadata for the paired office server.
///
/// The bearer token is deliberately NOT stored here — it lives in the platform
/// secure store (Keychain / Keystore). This table holds only discovery
/// metadata that is already visible via mDNS / the QR payload (hostnames and
/// ports), so keeping it in the SQLCipher DB is defense-in-depth, not a PHI
/// exposure.
class ServerConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get tailscaleHost => text().nullable()();
  TextColumn get lanHost => text().nullable()();
  IntColumn get pairingPort =>
      integer().withDefault(const Constant(kDefaultPairingPort))();
  IntColumn get dataPort =>
      integer().withDefault(const Constant(kDefaultDataPort))();
  DateTimeColumn get pairedAt => dateTime()();
}

/// The on-device SQLCipher database.
///
/// Opened with a 256-bit key via `PRAGMA key`, which `NativeDatabase.setup`
/// runs before any other statement — required for SQLCipher. The cipher build
/// is selected at compile time through `hooks.user_defines.sqlite3.source`
/// in `pubspec.yaml` (`sqlite3mc` = SQLite3MultipleCiphers, AES-256).
@DriftDatabase(tables: [ServerConfigs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open({required String path, required String key}) {
    return AppDatabase(
      NativeDatabase(
        File(path),
        setup: (db) => db.execute("PRAGMA key = '$key';"),
      ),
    );
  }

  @override
  int get schemaVersion => 1;
}
