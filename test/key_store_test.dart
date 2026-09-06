import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/storage/key_store.dart';

void main() {
  group('MemoryKeyStore', () {
    test('round-trips values', () async {
      final store = MemoryKeyStore();
      expect(await store.read('k'), isNull);
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
      await store.delete('k');
      expect(await store.read('k'), isNull);
    });
  });

  group('generateDbKeyHex', () {
    test('returns 64 hex chars (32 bytes) and differs across calls', () {
      final a = generateDbKeyHex();
      final b = generateDbKeyHex();
      expect(a, hasLength(64));
      expect(b, hasLength(64));
      expect(a, isNot(b));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
    });
  });
}
