/// The five document types the mobile app reads, writes, generates, and
/// exports. Mirrors the server's `DocType` in
/// `sharing_vocab_api/mobile.rs`.
enum DocType {
  soap('soap', 'SOAP Note', 'soap_note'),
  referral('referral', 'Referral', 'referral'),
  letter('letter', 'Letter', 'letter'),
  synopsis('synopsis', 'Synopsis', 'metadata'),
  peerDiscussion('peer_discussion', 'Peer Discussion', 'peer_discussion');

  const DocType(this.wire, this.label, this.fieldName);

  /// URL path segment / wire name.
  final String wire;

  /// Human-readable label.
  final String label;

  /// The recordings-table column (or `metadata` for synopsis) this type
  /// persists to.
  final String fieldName;

  static DocType? fromWire(String s) {
    for (final d in DocType.values) {
      if (d.wire == s) return d;
    }
    return null;
  }
}

/// Sparse field value carried over the wire for one field
/// (`medical_db::content_sync::SyncFieldValue`).
class SyncFieldValue {
  const SyncFieldValue({required this.value, required this.updatedAt});

  /// The field value as JSON (text fields are strings; `metadata` is an
  /// object).
  final dynamic value;
  final String updatedAt;

  factory SyncFieldValue.fromJson(Map<String, dynamic> json) => SyncFieldValue(
    value: json['value'],
    updatedAt: json['updated_at'] as String? ?? '',
  );

  /// The value as plain text, if it is a string.
  String? get asString => value is String ? value as String : null;
}

/// A recording as exchanged by content sync
/// (`medical_db::content_sync::SyncRecording`).
class SyncRecording {
  const SyncRecording({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.patientName,
    this.durationSeconds,
    this.fileSizeBytes,
    this.fields = const {},
  });

  final String id;
  final String filename;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final String? patientName;
  final double? durationSeconds;
  final int? fileSizeBytes;
  final Map<String, SyncFieldValue> fields;

  bool get isDeleted => deletedAt != null;

  factory SyncRecording.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as Map<String, dynamic>? ?? const {};
    return SyncRecording(
      id: json['id'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      deletedAt: json['deleted_at'] as String?,
      patientName: json['patient_name'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      fields: rawFields.map(
        (k, v) =>
            MapEntry(k, SyncFieldValue.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  /// Reads a text field (e.g. `soap_note`) if present and non-null.
  String? textField(String name) => fields[name]?.asString;

  /// The synopsis, which rides inside `metadata.synopsis` (not a sync field).
  String? get synopsis {
    final meta = fields['metadata']?.value;
    if (meta is Map<String, dynamic>) {
      final s = meta['synopsis'];
      return s is String && s.isNotEmpty ? s : null;
    }
    return null;
  }

  /// Whether content exists for a doc type, using the sync field map.
  bool hasDoc(DocType doc) {
    switch (doc) {
      case DocType.soap:
      case DocType.referral:
      case DocType.letter:
      case DocType.peerDiscussion:
        return (textField(doc.fieldName) ?? '').isNotEmpty;
      case DocType.synopsis:
        return synopsis != null;
    }
  }
}

/// A document's content as served by `GET …/documents/{doc_type}`.
class RecordingDocument {
  const RecordingDocument({
    required this.docType,
    required this.content,
    required this.updatedAt,
  });

  final DocType docType;
  final String? content;
  final String? updatedAt;

  factory RecordingDocument.fromJson(
    DocType docType,
    Map<String, dynamic> json,
  ) {
    return RecordingDocument(
      docType: docType,
      content: json['content'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  bool get hasContent => content != null && content!.isNotEmpty;
}

/// Payload for `POST …/generate/{doc_type}`. Mirrors the server's
/// `GenerateRequest` (all fields optional except peer_discussion's required
/// physician_name/specialty/reason).
class GenerateRequest {
  const GenerateRequest({
    this.context,
    this.template,
    this.patientContext,
    this.recipientType,
    this.urgency,
    this.letterType,
    this.audienceId,
    this.physicianName,
    this.specialty,
    this.reason,
  });

  final String? context;
  final String? template;
  final Map<String, dynamic>? patientContext;
  final String? recipientType;
  final String? urgency;
  final String? letterType;
  final String? audienceId;
  final String? physicianName;
  final String? specialty;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'context': ?context,
    'template': ?template,
    'patient_context': ?patientContext,
    'recipient_type': ?recipientType,
    'urgency': ?urgency,
    'letter_type': ?letterType,
    'audience_id': ?audienceId,
    'physician_name': ?physicianName,
    'specialty': ?specialty,
    'reason': ?reason,
  };
}
