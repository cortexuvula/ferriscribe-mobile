import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';

void main() {
  group('DataApiClient.revokeSelf', () {
    test('returns true on 204', () async {
      final client = DataApiClient(
        host: 'localhost',
        port: 11437,
        token: 'test-token',
        client: MockClient((req) async {
          expect(req.method, 'POST');
          expect(req.url.path, '/v1/devices/self');
          expect(req.headers['Authorization'], 'Bearer test-token');
          return http.Response('', 204);
        }),
      );
      expect(await client.revokeSelf(), isTrue);
      client.close();
    });

    test('returns true on 200', () async {
      final client = DataApiClient(
        host: 'localhost',
        port: 11437,
        token: 'test-token',
        client: MockClient((req) async => http.Response('{}', 200)),
      );
      expect(await client.revokeSelf(), isTrue);
      client.close();
    });

    test('returns false on 401 (revoked/invalid token)', () async {
      final client = DataApiClient(
        host: 'localhost',
        port: 11437,
        token: 'stale-token',
        client: MockClient((req) async => http.Response('unauthorized', 401)),
      );
      expect(await client.revokeSelf(), isFalse);
      client.close();
    });

    test('returns false on network error', () async {
      final client = DataApiClient(
        host: 'localhost',
        port: 11437,
        token: 'test-token',
        client: MockClient(
          (req) async => throw const SocketException('offline'),
        ),
      );
      expect(await client.revokeSelf(), isFalse);
      client.close();
    });

    test('returns false on timeout', () async {
      final client = DataApiClient(
        host: 'localhost',
        port: 11437,
        token: 'test-token',
        client: MockClient(
          (req) => Future.delayed(
            const Duration(minutes: 1),
            () => http.Response('', 200),
          ),
        ),
      );
      // The 10-second timeout should fire before the mock responds
      expect(await client.revokeSelf(), isFalse);
      client.close();
    });
  });
}

/// Dart doesn't export SocketException from dart:io in tests by default;
/// define a local stand-in so the test compiles without importing dart:io.
class SocketException implements Exception {
  const SocketException(this.message);
  final String message;
}
