import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/export/export_service.dart';

void main() {
  group('parseExportFilename', () {
    test('parses quoted filename', () {
      expect(
        parseExportFilename('attachment; filename="soap-abc12345.pdf"'),
        'soap-abc12345.pdf',
      );
    });

    test('parses unquoted filename', () {
      expect(
        parseExportFilename('attachment; filename=soap-abc.pdf'),
        'soap-abc.pdf',
      );
    });

    test('returns null for missing filename', () {
      expect(parseExportFilename('attachment'), isNull);
      expect(parseExportFilename(null), isNull);
    });
  });

  group('ExportFormat', () {
    test('wire + mime round-trip', () {
      expect(ExportFormat.pdf.wire, 'pdf');
      expect(ExportFormat.pdf.mimeType, 'application/pdf');
      expect(ExportFormat.docx.mimeType, contains('wordprocessingml'));
      expect(ExportFormat.fromWire('pdf'), ExportFormat.pdf);
      expect(ExportFormat.fromWire('docx'), ExportFormat.docx);
      expect(ExportFormat.fromWire('xlsx'), isNull);
    });
  });

  group('shredFile', () {
    test('overwrites then deletes', () async {
      final dir = Directory.systemTemp.createTempSync('shred_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/doc.pdf';
      final f = File(path);
      await f.writeAsBytes(List<int>.filled(100, 0x41), flush: true); // 'A'
      expect(f.existsSync(), isTrue);

      await shredFile(path);
      expect(f.existsSync(), isFalse);
    });

    test('is a no-op for a missing file', () async {
      final dir = Directory.systemTemp.createTempSync('shred_missing');
      addTearDown(() => dir.deleteSync(recursive: true));
      await shredFile('${dir.path}/nope.pdf'); // must not throw
    });
  });
}
