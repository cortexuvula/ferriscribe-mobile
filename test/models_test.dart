import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/models.dart';

void main() {
  group('DocType', () {
    test('round-trips wire names and labels', () {
      expect(DocType.values.map((d) => d.wire).toList(), [
        'soap',
        'referral',
        'letter',
        'synopsis',
        'peer_discussion',
      ]);
      expect(DocType.soap.label, 'SOAP Note');
      expect(DocType.synopsis.fieldName, 'metadata');
      expect(DocType.fromWire('soap'), DocType.soap);
      expect(DocType.fromWire('peer_discussion'), DocType.peerDiscussion);
      expect(DocType.fromWire('nope'), isNull);
    });
  });

  group('SyncRecording.fromJson', () {
    test('parses sparse fields and synopsis from metadata', () {
      final rec = SyncRecording.fromJson({
        'id': 'abc',
        'filename': 'f.wav',
        'created_at': '2026-09-06T00:00:00Z',
        'updated_at': '2026-09-06T01:00:00Z',
        'patient_name': 'Jane Doe',
        'duration_seconds': 42.0,
        'file_size_bytes': 1234,
        'fields': {
          'soap_note': {'value': 'S: ...', 'updated_at': 't'},
          'metadata': {
            'value': {
              'synopsis': 'Synopsis text',
              'generation_stats': {'x': 1},
            },
            'updated_at': 't',
          },
        },
      });
      expect(rec.id, 'abc');
      expect(rec.patientName, 'Jane Doe');
      expect(rec.durationSeconds, 42.0);
      expect(rec.textField('soap_note'), 'S: ...');
      expect(rec.synopsis, 'Synopsis text');
      expect(rec.hasDoc(DocType.soap), isTrue);
      expect(rec.hasDoc(DocType.synopsis), isTrue);
      expect(rec.hasDoc(DocType.referral), isFalse);
    });

    test('missing synopsis key → null, not content', () {
      final rec = SyncRecording.fromJson({
        'id': 'abc',
        'filename': 'f.wav',
        'created_at': 't',
        'updated_at': 't',
        'fields': {
          'metadata': {
            'value': {'other': 1},
            'updated_at': 't',
          },
        },
      });
      expect(rec.synopsis, isNull);
      expect(rec.hasDoc(DocType.synopsis), isFalse);
    });

    test('deleted recordings are flagged', () {
      final rec = SyncRecording.fromJson({
        'id': 'abc',
        'filename': 'f.wav',
        'created_at': 't',
        'updated_at': 't',
        'deleted_at': '2026-09-06T02:00:00Z',
        'fields': <String, dynamic>{},
      });
      expect(rec.isDeleted, isTrue);
    });
  });

  group('GenerateRequest', () {
    test('omits null fields', () {
      const req = GenerateRequest();
      expect(req.toJson(), isEmpty);
    });

    test('includes peer-discussion fields', () {
      const req = GenerateRequest(
        physicianName: 'Dr. X',
        specialty: 'Cardiology',
        reason: 'Consult',
      );
      expect(req.toJson(), {
        'physician_name': 'Dr. X',
        'specialty': 'Cardiology',
        'reason': 'Consult',
      });
    });
  });
}
