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

/// Offline cache of recording metadata, mirroring a content-sync pull.
///
/// Populated on every successful sync so the recordings list stays viewable
/// with the server unreachable. PHI-bearing (`patient_name`), so it lives only
/// in the SQLCipher DB.
class CachedRecordings extends Table {
  TextColumn get id => text()();
  TextColumn get filename => text()();
  TextColumn get patientName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  RealColumn get durationSeconds => real().nullable()();
  TextColumn get sttProvider => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline cache of a fetched document's authoritative content.
///
/// Written through on every successful document fetch so the editor can show
/// the last-known content offline. Content is PHI — SQLCipher only.
class CachedDocuments extends Table {
  TextColumn get recordingId => text()();
  TextColumn get docType => text()();
  TextColumn get content => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {recordingId, docType};
}

/// Per-recording patient context (medications, conditions, allergies, notes),
/// captured on-device and attached to generation requests. Mirrors the
/// server's `PatientContext` (`crates/core/src/types/agent.rs`). PHI — never
/// logged, SQLCipher only.
class PatientContexts extends Table {
  TextColumn get recordingId => text()();
  TextColumn get patientName => text().nullable()();
  TextColumn get medicationsJson => text().withDefault(const Constant('[]'))();
  TextColumn get conditionsJson => text().withDefault(const Constant('[]'))();
  TextColumn get allergiesJson => text().withDefault(const Constant('[]'))();
  TextColumn get priorSoapNotesJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {recordingId};
}

/// The on-device SQLCipher database.
///
/// Opened with a 256-bit key via `PRAGMA key`, which `NativeDatabase.setup`
/// runs before any other statement — required for SQLCipher. The cipher build
/// is selected at compile time through `hooks.user_defines.sqlite3.source`
/// in `pubspec.yaml` (`sqlite3mc` = SQLite3MultipleCiphers, AES-256).
@DriftDatabase(
  tables: [ServerConfigs, CachedRecordings, CachedDocuments, PatientContexts],
)
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Phase 4: offline cache + patient context.
        await m.createTable(cachedRecordings);
        await m.createTable(cachedDocuments);
        await m.createTable(patientContexts);
      }
    },
  );
}
