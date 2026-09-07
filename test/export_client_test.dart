import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';

void main() {
  group('DataApiClient.exportDocument', () {
    late HttpServer server;
    late List<String> log;

    const token = 'test-bearer-token';
    final pdfMagic = <int>[0x25, 0x50, 0x44, 0x46, 0x2D]; // "%PDF-"

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
        log.add('${req.method} ${req.uri}');
        if (req.uri.path == '/v1/recordings/rec-1/export') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType('application', 'pdf')
            ..headers.set(
              'content-disposition',
              'attachment; filename="soap-abc12345.pdf"',
            )
            ..add(pdfMagic);
          await req.response.close();
        } else if (req.uri.path == '/v1/recordings/missing/export') {
          req.response.statusCode = 404;
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

    test('downloads bytes and parses the suggested filename', () async {
      final c = client();
      addTearDown(c.close);
      final file = await c.exportDocument(
        'rec-1',
        DocType.soap,
        ExportFormat.pdf,
      );
      expect(file.bytes.sublist(0, 5), pdfMagic);
      expect(file.filename, 'soap-abc12345.pdf');
      expect(file.contentType, 'application/pdf');
      expect(
        log.any((l) => l.contains('/export?') && l.contains('format=pdf')),
        isTrue,
      );
    });

    test('throws DataApiException on 404', () async {
      final c = client();
      addTearDown(c.close);
      await expectLater(
        c.exportDocument('missing', DocType.soap, ExportFormat.pdf),
        throwsA(isA<DataApiException>()),
      );
    });
  });
}
