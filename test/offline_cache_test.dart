import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/core/api/patient_context.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart'
    hide PatientContext;
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

void main() {
  late AppDatabase db;
  late OfflineCacheRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = OfflineCacheRepository(db);
  });

  tearDown(() => db.close());

  group('offline recordings cache', () {
    test('replace + read round-trips', () async {
      final recs = [
        SyncRecording(
          id: 'a',
          filename: 'a.wav',
          createdAt: '2026-09-06T00:00:00Z',
          updatedAt: '2026-09-06T01:00:00Z',
          patientName: 'Jane',
          durationSeconds: 42.0,
        ),
        SyncRecording(
          id: 'b',
          filename: 'b.wav',
          createdAt: '2026-09-06T00:00:00Z',
          updatedAt: '2026-09-06T02:00:00Z',
          patientName: null,
        ),
      ];
      await repo.replaceRecordings(recs);
      final out = await repo.readRecordings();
      expect(out, hasLength(2));
      // Newest first.
      expect(out.first.id, 'b');
      expect(out.last.patientName, 'Jane');
      expect(out.last.durationSeconds, 42.0);
    });

    test('replace clears previous rows', () async {
      await repo.replaceRecordings([
        SyncRecording(
          id: 'a',
          filename: 'a.wav',
          createdAt: 't',
          updatedAt: 't',
        ),
        SyncRecording(
          id: 'b',
          filename: 'b.wav',
          createdAt: 't',
          updatedAt: 't',
        ),
      ]);
      await repo.replaceRecordings([
        SyncRecording(
          id: 'c',
          filename: 'c.wav',
          createdAt: 't',
          updatedAt: 't',
        ),
      ]);
      final out = await repo.readRecordings();
      expect(out, hasLength(1));
      expect(out.single.id, 'c');
    });
  });

  group('document cache', () {
    test('upsert + read round-trips', () async {
      await repo.upsertDocument('a', DocType.soap, 'SOAP body');
      expect(await repo.readDocument('a', DocType.soap), 'SOAP body');
      expect(await repo.readDocument('a', DocType.referral), isNull);
      // Upsert overwrites.
      await repo.upsertDocument('a', DocType.soap, 'edited');
      expect(await repo.readDocument('a', DocType.soap), 'edited');
    });
  });

  group('patient context', () {
    test('upsert + read round-trips all fields', () async {
      const ctx = PatientContext(
        patientName: 'Jane Doe',
        medications: ['Lisinopril', 'Metformin'],
        conditions: ['T2DM'],
        allergies: ['Penicillin'],
        priorSoapNotes: ['prior note'],
      );
      await repo.upsertPatientContext('a', ctx);
      final out = await repo.readPatientContext('a');
      expect(out, isNotNull);
      expect(out!.patientName, 'Jane Doe');
      expect(out.medications, ['Lisinopril', 'Metformin']);
      expect(out.conditions, ['T2DM']);
      expect(out.allergies, ['Penicillin']);
      expect(out.priorSoapNotes, ['prior note']);
    });

    test('returns null when no context captured', () async {
      expect(await repo.readPatientContext('missing'), isNull);
    });
  });

  group('PatientContext wire shape', () {
    test('toJson matches the server PatientContext', () {
      const ctx = PatientContext(
        patientName: 'Jane',
        medications: ['a'],
        conditions: ['b'],
        allergies: ['c'],
        priorSoapNotes: ['d'],
      );
      expect(ctx.toJson(), {
        'patient_name': 'Jane',
        'medications': ['a'],
        'conditions': ['b'],
        'allergies': ['c'],
        'prior_soap_notes': ['d'],
      });
    });

    test('isEmpty is true only when nothing captured', () {
      expect(const PatientContext().isEmpty, isTrue);
      expect(const PatientContext(patientName: 'x').isEmpty, isFalse);
    });
  });
}
