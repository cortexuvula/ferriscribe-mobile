#!/usr/bin/env python3
"""V1 part 2: remaining full-width primary sites."""

edits = [
    # record_screen done-phase: Open SOAP note primary
    ('lib/features/recording/record_screen.dart',
     """          FilledButton.icon(
            onPressed: _presentation.recordingId.isEmpty ? null : _openSoapNote,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open SOAP note'),
          ),""",
     """          fullWidthButton(
            FilledButton.icon(
              onPressed:
                  _presentation.recordingId.isEmpty ? null : _openSoapNote,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Open SOAP note'),
            ),
          ),"""),
    # document_editor footer: Save changes / Edit full-width in bottom bar
    ('lib/features/documents/document_editor_screen.dart',
     """    if (_editing) {
      return FilledButton.icon(
        onPressed: _saveStatus == _SaveStatus.saving ? null : _save,
        icon: _saveStatus == _SaveStatus.saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _saveStatus == _SaveStatus.failedServer ||
                  _saveStatus == _SaveStatus.failedNetwork
              ? 'Retry save'
              : 'Save changes',
        ),
      );
    }
    if (_offlineEntry) return null; // read-only cached (§5G)
    return FilledButton.tonalIcon(
      onPressed: _startEditing,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit'),
    );""",
     """    if (_editing) {
      return fullWidthButton(
        FilledButton.icon(
          onPressed: _saveStatus == _SaveStatus.saving ? null : _save,
          icon: _saveStatus == _SaveStatus.saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _saveStatus == _SaveStatus.failedServer ||
                    _saveStatus == _SaveStatus.failedNetwork
                ? 'Retry save'
                : 'Save changes',
          ),
        ),
      );
    }
    if (_offlineEntry) return null; // read-only cached (§5G)
    return fullWidthButton(
      FilledButton.tonalIcon(
        onPressed: _startEditing,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
    );"""),
    # pairing_screen: scan/enroll primaries
    ('lib/features/pairing/pairing_screen.dart',
     None),  # inspected separately below
]

for path, old, new in edits:
    if old is None:
        continue
    s = open(path).read()
    assert old in s, f'anchor missing in {path}'
    s = s.replace(old, new)
    open(path, 'w').write(s)
    print('ok', path)
