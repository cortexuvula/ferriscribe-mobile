import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';

void main() {
  group('DataApiClient', () {
    late HttpServer server;
    late List<String> log;

    const token = 'test-bearer-token';

    setUp(() async {
      log = <String>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final auth = req.headers.value('authorization');
        log.add('${req.method} ${req.uri.path} auth=$auth');
        if (auth != 'Bearer $token') {
          req.response.statusCode = 401;
          await req.response.close();
          return;
        }
        if (req.method == 'POST' && req.uri.path == '/v1/recordings') {
          final body = jsonDecode(await utf8.decodeStream(req)) as Map;
          req.response
            ..statusCode = 201
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'id': body['id'], 'created_at': '2026-09-06'}));
          await req.response.close();
        } else if (req.method == 'PUT' &&
            req.uri.path.startsWith('/v1/content/audio/')) {
          final bytes = <int>[];
          await for (final chunk in req) {
            bytes.addAll(chunk);
          }
          req.response.statusCode = 201;
          await req.response.close();
          log.add('audio-bytes=${bytes.length}');
        } else if (req.method == 'POST' &&
            req.uri.path.endsWith('/generate/soap')) {
          req.response.statusCode = 202;
          await req.response.close();
        } else if (req.method == 'GET' && req.uri.path == '/v1/jobs/known') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'recording_id': 'known',
                'stage': 'transcribing',
                'updated_at': 't',
              }),
            );
          await req.response.close();
        } else if (req.method == 'GET' && req.uri.path == '/v1/jobs/missing') {
          req.response.statusCode = 404;
          await req.response.close();
        } else if (req.method == 'GET' && req.uri.path.endsWith('/events')) {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType('text', 'event-stream')
            ..write(
              'data: {"recording_id":"r","stage":"queued","updated_at":"t"}\n\n'
              'data: {"recording_id":"r","stage":"completed","updated_at":"t"}\n\n',
            );
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    });

    tearDown(() => server.close(force: true));

    test('createRecording sends client id and parses 201', () async {
      final client = DataApiClient(
        host: '127.0.0.1',
        port: server.port,
        token: token,
      );
      addTearDown(client.close);
      final created = await client.createRecording(id: 'abc', filename: 'f');
      expect(created.id, 'abc');
      expect(log.any((l) => l.startsWith('POST /v1/recordings')), isTrue);
    });

    test('uploadAudio PUTs raw bytes with bearer auth', () async {
      final client = DataApiClient(
        host: '127.0.0.1',
        port: server.port,
        token: token,
      );
      addTearDown(client.close);
      final n = await client.uploadAudio(
        'rid',
        Uint8List.fromList(List.filled(100, 1)),
      );
      expect(n, 100);
      expect(log, contains('audio-bytes=100'));
    });

    test('generateSoap POSTs and expects 202', () async {
      final client = DataApiClient(
        host: '127.0.0.1',
        port: server.port,
        token: token,
      );
      addTearDown(client.close);
      await client.generateSoap('rid');
      expect(
        log.any((l) => l.endsWith('/generate/soap auth=Bearer $token')),
        isTrue,
      );
    });

    test('jobStatus returns snapshot or null on 404', () async {
      final client = DataApiClient(
        host: '127.0.0.1',
        port: server.port,
        token: token,
      );
      addTearDown(client.close);
      final snap = await client.jobStatus('known');
      expect(snap, isNotNull);
      expect(snap!.stage, 'transcribing');
      expect(await client.jobStatus('missing'), isNull);
    });

    test('jobEvents streams parsed SSE frames', () async {
      final client = DataApiClient(
        host: '127.0.0.1',
        port: server.port,
        token: token,
      );
      addTearDown(client.close);
      final stages = <String>[];
      await for (final snap in client.jobEvents('rid')) {
        stages.add(snap.stage);
      }
      expect(stages, ['queued', 'completed']);
    });

    test('rejects missing bearer with 401 → DataApiException', () async {
      final client = DataApiClient(
        host: '127.0.0.1',
        port: server.port,
        token: 'wrong',
      );
      addTearDown(client.close);
      await expectLater(
        client.generateSoap('rid'),
        throwsA(isA<DataApiException>()),
      );
    });
  });
}
