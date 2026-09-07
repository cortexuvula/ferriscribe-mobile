import 'package:flutter/material.dart';

import '../../ui/theme/app_theme.dart';

import '../../core/api/patient_context.dart';

/// Patient-context form (§5C): full-screen, scrollable, keyboard-safe.
///
/// Label above the field and helper text below (never hints alone); blank
/// allergies means *not provided*, never `No known allergies`; no real-
/// patient examples. Primary `Use context` returns to preparation (not
/// "Saved to server" — the context is local to this consultation).
/// Back/cancel preserves prior committed context and confirms discard if
/// the form is dirty. Completely clearing fields returns an empty context
/// deliberately.
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

  /// Dirty = the form's serialized context differs from the initial one.
  /// A null initial is an empty context — an untouched form is NOT dirty.
  bool get _dirty => _current() != (widget.initial ?? const PatientContext());

  @override
  void initState() {
    super.initState();
    // _dirty is derived from controller text; PopScope.canPop must react to
    // programmatic text changes too, so rebuild on every controller change.
    for (final c in [_name, _medications, _conditions, _allergies, _notes]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

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

  PatientContext _current() => PatientContext(
    patientName: _name.text.trim().isEmpty ? null : _name.text.trim(),
    medications: _split(_medications.text),
    conditions: _split(_conditions.text),
    allergies: _split(_allergies.text),
    priorSoapNotes: _split(_notes.text),
  );

  /// §5C: back with a dirty form confirms discard; keeps prior committed
  /// context otherwise.
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your edits to this patient context have not been applied.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _confirmDiscard();
        if (allow && mounted) {
          // ignore: use_build_context_synchronously — guarded by State.mounted
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Patient context')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Text(
                'Optional information to help generate this consultation\'s '
                'documents.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _field(
                controller: _name,
                label: 'Patient name',
                helper: 'Optional.',
                isRequired: false,
              ),
              _field(
                controller: _medications,
                label: 'Medications',
                helper: 'One per line.',
                maxLines: 3,
                isRequired: false,
              ),
              _field(
                controller: _conditions,
                label: 'Conditions',
                helper: 'One per line.',
                maxLines: 3,
                isRequired: false,
              ),
              _field(
                controller: _allergies,
                label: 'Allergies',
                helper: 'One per line. Leave blank if not provided.',
                maxLines: 3,
                isRequired: false,
              ),
              _field(
                controller: _notes,
                label: 'Prior SOAP notes / history',
                helper: 'Optional background for this consultation.',
                maxLines: 5,
                isRequired: false,
              ),
              const SizedBox(height: 20),
              fullWidthButton(
                FilledButton(
                  onPressed: () => Navigator.pop(context, _current()),
                  child: const Text('Use context'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String helper,
    required bool isRequired,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          helperText: helper,
          // Label above the field, helper below — never hints alone (§5C).
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }
}

/// Shows the patient-context form and returns the result (or null on
/// cancel, which preserves the prior committed context).
Future<PatientContext?> showPatientContextForm(
  BuildContext context, {
  PatientContext? initial,
}) {
  return Navigator.of(context).push<PatientContext>(
    MaterialPageRoute(builder: (_) => PatientContextForm(initial: initial)),
  );
}
