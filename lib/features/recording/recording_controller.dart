import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'audio/wav_encoder.dart';

/// Captures mic audio into RAM only — never a temp file.
///
/// Uses the `record` package's streaming API (`startStream`), which routes
/// PCM chunks through an EventChannel straight to Dart. This is the PHI
/// linchpin: the file-based `start(path:)` path writes a plaintext WAV to
/// disk (recoverable from unallocated blocks), so it is never used here.
/// Plaintext audio exists only in this process's memory and is discarded on
/// [dispose]/[cancel].
class RecordingController {
  RecordingController({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final BytesBuilder _buffer = BytesBuilder();
  StreamSubscription<Uint8List>? _subscription;
  bool _recording = false;

  bool get isRecording => _recording;

  /// Begins capture. Throws [RecordingPermissionException] when mic access is
  /// denied.
  Future<void> start() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw const RecordingPermissionException();
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: WavEncoder.sampleRate,
        numChannels: WavEncoder.channels,
      ),
    );
    _subscription = stream.listen(_buffer.add);
    _recording = true;
  }

  /// Stops capture and returns the complete WAV bytes, in memory. Never
  /// touches disk.
  Future<Uint8List> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final pcm = _buffer.takeBytes();
    _recording = false;
    try {
      await _recorder.stop();
    } catch (_) {
      // In stream mode stop() only tears down the native recorder; a failure
      // here must not discard already-captured audio.
    }
    return WavEncoder.wrap(pcm);
  }

  /// Aborts capture and discards buffered audio from memory.
  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    _buffer.clear();
    _recording = false;
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
    _buffer.clear();
    _recorder.dispose();
  }
}

class RecordingPermissionException implements Exception {
  const RecordingPermissionException();

  @override
  String toString() => 'Microphone permission denied';
}
