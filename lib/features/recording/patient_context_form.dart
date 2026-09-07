import 'package:flutter/material.dart';

import '../../core/api/patient_context.dart';

/// Form for capturing patient context (medications, conditions, allergies,
/// notes). Returns a [PatientContext] on save, or null on cancel.
class PatientContextForm extends StatefulWidget {
  const PatientContextForm({super.key, this.initial});

  final PatientContext? initial;

  @override
  State<PatientContextForm> createState() => _PatientContextFormState();
}

class _PatientContextFormState extends State<PatientContextForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.patientName ?? '',
  );
  late final TextEditingController _medications = TextEditingController(
    text: _join(widget.initial?.medications),
  );
  late final TextEditingController _conditions = TextEditingController(
    text: _join(widget.initial?.conditions),
  );
  late final TextEditingController _allergies = TextEditingController(
    text: _join(widget.initial?.allergies),
  );
  late final TextEditingController _notes = TextEditingController(
    text: _join(widget.initial?.priorSoapNotes),
  );

  @override
  void dispose() {
    _name.dispose();
    _medications.dispose();
    _conditions.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _join(List<String>? items) => (items ?? const []).join('\n');

  static List<String> _split(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient context')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Patient name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medications,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Medications (one per line)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conditions,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Conditions (one per line)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _allergies,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Allergies (one per line)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes / prior history',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final result = PatientContext(
                patientName: _name.text.trim().isEmpty
                    ? null
                    : _name.text.trim(),
                medications: _split(_medications.text),
                conditions: _split(_conditions.text),
                allergies: _split(_allergies.text),
                priorSoapNotes: _split(_notes.text),
              );
              Navigator.pop(context, result);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Shows the patient-context form and returns the result (or null on cancel).
Future<PatientContext?> showPatientContextForm(
  BuildContext context, {
  PatientContext? initial,
}) {
  return Navigator.of(context).push<PatientContext>(
    MaterialPageRoute(builder: (_) => PatientContextForm(initial: initial)),
  );
}
