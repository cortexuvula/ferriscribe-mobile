import 'dart:convert';

/// On-device patient context, mirroring the server's `PatientContext`
/// (`crates/core/src/types/agent.rs`). Captured for a recording and attached
/// to generation requests.
class PatientContext {
  const PatientContext({
    this.patientName,
    this.medications = const [],
    this.conditions = const [],
    this.allergies = const [],
    this.priorSoapNotes = const [],
  });

  final String? patientName;
  final List<String> medications;
  final List<String> conditions;
  final List<String> allergies;
  final List<String> priorSoapNotes;

  bool get isEmpty =>
      patientName == null &&
      medications.isEmpty &&
      conditions.isEmpty &&
      allergies.isEmpty &&
      priorSoapNotes.isEmpty;

  /// Wire shape for `generate`'s `patient_context` field.
  Map<String, dynamic> toJson() => {
    'patient_name': ?patientName,
    'medications': medications,
    'conditions': conditions,
    'allergies': allergies,
    'prior_soap_notes': priorSoapNotes,
  };

  factory PatientContext.fromJson(Map<String, dynamic> json) => PatientContext(
    patientName: json['patient_name'] as String?,
    medications: _stringList(json['medications']),
    conditions: _stringList(json['conditions']),
    allergies: _stringList(json['allergies']),
    priorSoapNotes: _stringList(json['prior_soap_notes']),
  );

  static List<String> _stringList(dynamic v) =>
      (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

  /// Serializes the list fields as JSON for storage in a single column.
  Map<String, String> toStorageJson() => {
    'medicationsJson': jsonEncode(medications),
    'conditionsJson': jsonEncode(conditions),
    'allergiesJson': jsonEncode(allergies),
    'priorSoapNotesJson': jsonEncode(priorSoapNotes),
  };
}
