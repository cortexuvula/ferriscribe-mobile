import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';

void main() {
  group('SseParser.parseJson', () {
    Future<List<Map<String, dynamic>>> parse(String raw) async {
      // Reify as List<int> (not Uint8List) so the utf8 transform's type check
      // passes — utf8.encode returns a Uint8List at runtime.
      final stream = Stream<List<int>>.value(utf8.encode(raw));
      final out = <Map<String, dynamic>>[];
      await for (final event in SseParser.parseJson(stream)) {
        out.add(event);
      }
      return out;
    }

    test('parses a single data frame', () async {
      final events = await parse(
        'data: {"recording_id":"a","stage":"transcribing","updated_at":"t"}\n\n',
      );
      expect(events, hasLength(1));
      expect(events[0]['recording_id'], 'a');
      expect(events[0]['stage'], 'transcribing');
    });

    test('parses multiple frames split across chunks', () async {
      final events = await parse(
        'data: {"stage":"queued"}\n\n'
        'data: {"stage":"transcribing"}\n\n'
        'data: {"stage":"completed"}\n\n',
      );
      expect(events, hasLength(3));
      expect(events.map((e) => e['stage']).toList(), [
        'queued',
        'transcribing',
        'completed',
      ]);
    });

    test('ignores event/id/comment lines and joins multi-line data', () async {
      final events = await parse(
        'event: job\n'
        'id: 1\n'
        ': comment\n'
        'data: {"a":1,\n'
        'data: "b":2}\n\n',
      );
      expect(events, hasLength(1));
      expect(events[0], {'a': 1, 'b': 2});
    });

    test('emits nothing for empty input', () async {
      expect(await parse(''), isEmpty);
    });
  });
}
