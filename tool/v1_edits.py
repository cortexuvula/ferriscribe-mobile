#!/usr/bin/env python3
"""One-shot V1 edits: wrap full-width primary buttons in fullWidthButton."""
edits = [
    ('lib/features/recording/patient_context_form.dart',
     """              FilledButton(
                onPressed: () => Navigator.pop(context, _current()),
                child: const Text('Use context'),
              ),""",
     """              fullWidthButton(
                FilledButton(
                  onPressed: () => Navigator.pop(context, _current()),
                  child: const Text('Use context'),
                ),
              ),"""),
    ('lib/features/recording/record_screen.dart',
     """        FilledButton.icon(
          onPressed: _startEnabled ? _startRecording : null,
          icon: const Icon(Icons.mic),
          label: const Text('Start recording'),
        ),""",
     """        fullWidthButton(
          FilledButton.icon(
            onPressed: _startEnabled ? _startRecording : null,
            icon: const Icon(Icons.mic),
            label: const Text('Start recording'),
          ),
        ),"""),
    ('lib/features/recording/record_screen.dart',
     """          FilledButton.icon(
            onPressed: _stopAndGenerate,
            icon: const Icon(Icons.stop),
            label: const Text('Stop & generate SOAP'),
          ),""",
     """          fullWidthButton(
            FilledButton.icon(
              onPressed: _stopAndGenerate,
              icon: const Icon(Icons.stop),
              label: const Text('Stop & generate SOAP'),
            ),
          ),"""),
]
for path, old, new in edits:
    s = open(path).read()
    assert old in s, f'anchor missing in {path}'
    s = s.replace(old, new)
    open(path, 'w').write(s)
    print('ok', path)
