import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/api/models.dart';
import '../../core/api/patient_context.dart';
import 'database/app_database.dart' hide PatientContext;

/// Offline read cache over the SQLCipher DB.
///
/// Write-through: every successful content-sync pull and document fetch
/// updates the cache. Reads serve the recordings list and document editor
/// when the server is unreachable (Phase 4 acceptance).
class OfflineCacheRepository {
  OfflineCacheRepository(this._db);

  final AppDatabase _db;

  // ── Recordings ────────────────────────────────────────────────────────

  /// Replaces the cached recording metadata with the given list.
  Future<void> replaceRecordings(List<SyncRecording> recordings) async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedRecordings).go();
      for (final r in recordings) {
        await _db
            .into(_db.cachedRecordings)
            .insert(
              CachedRecordingsCompanion.insert(
                id: r.id,
                filename: r.filename,
                patientName: Value(r.patientName),
                createdAt: _parse(r.createdAt),
                updatedAt: _parse(r.updatedAt),
                durationSeconds: Value(r.durationSeconds),
                sttProvider: Value(null),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// Reads cached recordings, newest first.
  Future<List<SyncRecording>> readRecordings() async {
    final rows = await (_db.select(
      _db.cachedRecordings,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    return rows
        .map(
          (r) => SyncRecording(
            id: r.id,
            filename: r.filename,
            createdAt: r.createdAt.toIso8601String(),
            updatedAt: r.updatedAt.toIso8601String(),
            patientName: r.patientName,
            durationSeconds: r.durationSeconds,
          ),
        )
        .toList();
  }

  // ── Documents ─────────────────────────────────────────────────────────

  /// Caches the authoritative content for one document.
  Future<void> upsertDocument(
    String recordingId,
    DocType doc,
    String content,
  ) async {
    await _db
        .into(_db.cachedDocuments)
        .insert(
          CachedDocumentsCompanion.insert(
            recordingId: recordingId,
            docType: doc.wire,
            content: content,
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Reads a cached document's content, or null if never cached.
  Future<String?> readDocument(String recordingId, DocType doc) async {
    final row =
        await (_db.select(_db.cachedDocuments)
              ..where(
                (t) =>
                    t.recordingId.equals(recordingId) &
                    t.docType.equals(doc.wire),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.content;
  }

  // ── Patient context ───────────────────────────────────────────────────

  /// Persists patient context for a recording.
  Future<void> upsertPatientContext(
    String recordingId,
    PatientContext context,
  ) async {
    final storage = context.toStorageJson();
    await _db
        .into(_db.patientContexts)
        .insert(
          PatientContextsCompanion.insert(
            recordingId: recordingId,
            patientName: Value(context.patientName),
            medicationsJson: Value(storage['medicationsJson']!),
            conditionsJson: Value(storage['conditionsJson']!),
            allergiesJson: Value(storage['allergiesJson']!),
            priorSoapNotesJson: Value(storage['priorSoapNotesJson']!),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Reads patient context for a recording, or null if none captured.
  Future<PatientContext?> readPatientContext(String recordingId) async {
    final row =
        await (_db.select(_db.patientContexts)
              ..where((t) => t.recordingId.equals(recordingId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return PatientContext.fromJson({
      'patient_name': row.patientName,
      'medications': _decodeList(row.medicationsJson),
      'conditions': _decodeList(row.conditionsJson),
      'allergies': _decodeList(row.allergiesJson),
      'prior_soap_notes': _decodeList(row.priorSoapNotesJson),
    });
  }

  static DateTime _parse(String rfc3339) {
    final parsed = DateTime.tryParse(rfc3339);
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
  }

  static List<String> _decodeList(String json) {
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
