import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Read-only transcript viewer.
///
/// The transcript is produced by the physician's own on-premise whisper.cpp
/// transcription during `process_recording` and synced to this device as a
/// plain field — it is NOT a generated document. So this view deliberately
/// has no Edit, no Generate, and no Export: it is view-only, with an
/// explicit Copy button (PHI invariant: never auto-copy to the OS clipboard).
class TranscriptViewerScreen extends StatelessWidget {
  const TranscriptViewerScreen({
    super.key,
    required this.transcript,
    this.recordingTitle,
  });

  final String transcript;

  /// Optional consultation context shown as the app-bar subtitle.
  final String? recordingTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript'),
        actions: [
          if (transcript.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy text',
              onPressed: () {
                // Explicit user-initiated copy only — never automatic.
                Clipboard.setData(ClipboardData(text: transcript));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: transcript.isEmpty
          ? Center(
              child: Text(
                'No transcript yet',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: SelectableText(
                  transcript,
                  style: TextStyle(
                    fontSize: 16,
                    height: 24 / 16,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
    );
  }
}
