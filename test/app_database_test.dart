import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ferriscribe_mobile/storage/database/app_database.dart';

/// 64 hex chars = a 256-bit SQLCipher passphrase.
const _key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  test('SQLCipher DB round-trips and encrypts at rest', () async {
    final dir = Directory.systemTemp.createTempSync('ferriscribe_db_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.db');

    // Write a row through the encrypted connection.
    final db = AppDatabase.open(path: path, key: _key);
    await db
        .into(db.serverConfigs)
        .insert(
          ServerConfigsCompanion.insert(
            label: const Value('patient-confidential-label'),
            tailscaleHost: const Value('clinic.tail-abc.ts.net'),
            pairingPort: const Value(11436),
            dataPort: const Value(11437),
            pairedAt: DateTime.now(),
          ),
        );
    await db.close();

    // The plaintext label must not appear in the on-disk bytes — this is the
    // at-rest encryption invariant (SQLCipher/sqlite3mc AES-256).
    final bytes = File(path).readAsBytesSync();
    final asText = String.fromCharCodes(bytes);
    expect(
      asText.contains('patient-confidential-label'),
      isFalse,
      reason: 'database must be encrypted at rest',
    );

    // Reopening with the same key returns the data.
    final db2 = AppDatabase.open(path: path, key: _key);
    addTearDown(db2.close);
    final rows = await db2.select(db2.serverConfigs).get();
    expect(rows, hasLength(1));
    expect(rows.single.label, 'patient-confidential-label');
    expect(rows.single.tailscaleHost, 'clinic.tail-abc.ts.net');
  });
}
