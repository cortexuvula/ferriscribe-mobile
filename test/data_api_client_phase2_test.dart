import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';

void main() {
  group('DataApiClient (Phase 2)', () {
    late HttpServer server;
    late List<String> log;

    const token = 'test-bearer-token';

    setUp(() async {
      log = <String>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final auth = req.headers.value('authorization');
        if (auth != 'Bearer $token') {
          req.response.statusCode = 401;
          await req.response.close();
          return;
        }
        log.add('${req.method} ${req.uri.path}');
        if (req.uri.path == '/v1/content/sync') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'recordings': [
                  {
                    'id': 'rec-1',
                    'filename': 'a.wav',
                    'created_at': 't',
                    'updated_at': 't2',
                    'fields': {
                      'soap_note': {'value': 'S', 'updated_at': 't2'},
                    },
                  },
                ],
                'server_time': 'now',
                'has_more': false,
              }),
            );
          await req.response.close();
        } else if (req.method == 'GET' &&
            req.uri.path == '/v1/recordings/rec-1/documents/soap') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'doc_type': 'soap',
                'content': 'SOAP body',
                'updated_at': 't',
              }),
            );
          await req.response.close();
        } else if (req.method == 'PUT' &&
            req.uri.path == '/v1/recordings/rec-1/documents/soap') {
          final body = jsonDecode(await utf8.decodeStream(req)) as Map;
          log.add('put-content=${body['content']}');
          req.response.statusCode = 204;
          await req.response.close();
        } else if (req.method == 'POST' &&
            req.uri.path == '/v1/recordings/rec-1/generate/referral') {
          req.response.statusCode = 202;
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    });

    tearDown(() => server.close(force: true));

    DataApiClient client() =>
        DataApiClient(host: '127.0.0.1', port: server.port, token: token);

    test('pullContent parses recordings + has_more', () async {
      final c = client();
      addTearDown(c.close);
      final page = await c.pullContent();
      expect(page.hasMore, isFalse);
      expect(page.recordings, hasLength(1));
      expect(page.recordings[0].id, 'rec-1');
      expect(page.recordings[0].hasDoc(DocType.soap), isTrue);
    });

    test('getDocument parses content', () async {
      final c = client();
      addTearDown(c.close);
      final doc = await c.getDocument('rec-1', DocType.soap);
      expect(doc.hasContent, isTrue);
      expect(doc.content, 'SOAP body');
    });

    test('saveDocument PUTs the content', () async {
      final c = client();
      addTearDown(c.close);
      await c.saveDocument('rec-1', DocType.soap, 'edited');
      expect(log, contains('put-content=edited'));
    });

    test('generateDoc POSTs with the request body', () async {
      final c = client();
      addTearDown(c.close);
      await c.generateDoc('rec-1', DocType.referral, const GenerateRequest());
      expect(log, contains('POST /v1/recordings/rec-1/generate/referral'));
    });
  });
}
