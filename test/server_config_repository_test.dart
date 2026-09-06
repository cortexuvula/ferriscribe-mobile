import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';

void main() {
  late AppDatabase db;
  late MemoryKeyStore keys;
  late ServerConfigRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    keys = MemoryKeyStore();
    repo = ServerConfigRepository(db, keys);
  });

  tearDown(() => db.close());

  test('savePaired persists token and server config', () async {
    await repo.savePaired(
      label: 'phone',
      host: 'clinic.tail-abc.ts.net',
      pairingPort: 11436,
      dataPort: 11437,
      token: 'tok-123',
    );

    expect(await repo.readToken(), 'tok-123');

    final config = await repo.readCurrent();
    expect(config, isNotNull);
    expect(config!.label, 'phone');
    expect(config.host, 'clinic.tail-abc.ts.net');
    expect(config.pairingPort, 11436);
    expect(config.dataPort, 11437);
  });

  test('readCurrent and readToken return null when unpaired', () async {
    expect(await repo.readCurrent(), isNull);
    expect(await repo.readToken(), isNull);
  });

  test('clear removes both token and config', () async {
    await repo.savePaired(
      label: 'phone',
      host: 'clinic.tail-abc.ts.net',
      pairingPort: 11436,
      dataPort: 11437,
      token: 'tok-123',
    );
    await repo.clear();
    expect(await repo.readToken(), isNull);
    expect(await repo.readCurrent(), isNull);
  });

  test('savePaired replaces the previous pairing', () async {
    await repo.savePaired(
      label: 'phone',
      host: 'old.ts.net',
      pairingPort: 11436,
      dataPort: 11437,
      token: 'old-token',
    );
    await repo.savePaired(
      label: 'tablet',
      host: 'new.ts.net',
      pairingPort: 11436,
      dataPort: 11437,
      token: 'new-token',
    );
    expect(await repo.readToken(), 'new-token');
    final config = await repo.readCurrent();
    expect(config!.label, 'tablet');
    expect(config.host, 'new.ts.net');
  });
}
