import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/pairing/pairing_client.dart';

void main() {
  group('PairingClient', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';
      server.listen((req) async {
        if (req.uri.path == '/info') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'host': 'Clinic Server',
                'version': '9.9.9',
                'ports': {
                  'ollama': 11435,
                  'whisper': 8081,
                  'lmstudio': null,
                  'omlx': null,
                  'pairing': 11436,
                  'vocab': 11437,
                },
                'tailscale': 'clinic.tail-abc.ts.net',
              }),
            );
          await req.response.close();
        } else if (req.uri.path == '/pair/enroll') {
          final body = jsonDecode(await utf8.decodeStream(req)) as Map;
          if (body['code'] == '123456') {
            req.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'token': 'secret-token'}));
          } else {
            req.response.statusCode = 401;
          }
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    });

    tearDown(() => server.close(force: true));

    test('fetchInfo parses the /info snapshot', () async {
      final client = PairingClient(baseUrl: baseUrl);
      addTearDown(client.close);
      final info = await client.fetchInfo();
      expect(info.host, 'Clinic Server');
      expect(info.version, '9.9.9');
      expect(info.ports.pairing, 11436);
      expect(info.ports.lmstudio, isNull);
      expect(info.tailscale, 'clinic.tail-abc.ts.net');
    });

    test('enroll returns the token on 200', () async {
      final client = PairingClient(baseUrl: baseUrl);
      addTearDown(client.close);
      final token = await client.enroll(code: '123456', label: 'phone');
      expect(token, 'secret-token');
    });

    test('enroll throws PairingException on 401', () async {
      final client = PairingClient(baseUrl: baseUrl);
      addTearDown(client.close);
      await expectLater(
        client.enroll(code: '000000', label: 'phone'),
        throwsA(isA<PairingException>()),
      );
    });

    test('baseUrlFor brackets IPv6 literals', () {
      expect(
        PairingClient.baseUrlFor('fe80::1', 11436),
        'http://[fe80::1]:11436',
      );
      expect(
        PairingClient.baseUrlFor('clinic.local', 11436),
        'http://clinic.local:11436',
      );
    });
  });
}
