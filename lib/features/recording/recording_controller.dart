import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'audio/wav_encoder.dart';

/// PCM bytes-per-second for 16 kHz mono 16-bit: 16000 × 2 = 32000.
const int _pcmBytesPerSecond = WavEncoder.sampleRate * 2;

/// Soft-cap: warn the user at 30 minutes of buffered audio.
const Duration kDurationWarning = Duration(minutes: 30);

/// Hard cap: auto-stop at 60 minutes to prevent OOM on low-memory devices.
/// At 16 kHz mono 16-bit, 60 min ≈ 115 MB of RAM — well within safe bounds
/// for any modern phone, but the OS may kill backgrounded apps with less.
const Duration kDurationLimit = Duration(minutes: 60);

/// Alias for the duration-monitor callback signature.
typedef VoidCallback = void Function();

/// Captures mic audio into RAM only — never a temp file.
///
/// Uses the `record` package's streaming API (`startStream`), which routes
/// PCM chunks through an EventChannel straight to Dart. This is the PHI
/// linchpin: the file-based `start(path:)` path writes a plaintext WAV to
/// disk (recoverable from unallocated blocks), so it is never used here.
/// Plaintext audio exists only in this process's memory and is discarded on
/// [dispose]/[cancel].
///
/// Duration monitoring: [start] accepts optional [onWarning] and [onLimitReached]
/// callbacks. The warning fires once when buffered audio crosses
/// [kDurationWarning]; the limit fires once at [kDurationLimit] and the caller
/// should treat it as an auto-stop signal (capture is halted automatically).
class RecordingController {
  RecordingController({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final BytesBuilder _buffer = BytesBuilder();
  StreamSubscription<Uint8List>? _subscription;
  bool _recording = false;
  Timer? _durationTimer;
  bool _warningFired = false;
  bool _limitFired = false;

  bool get isRecording => _recording;

  /// Current buffered duration, computed from the PCM byte count.
  Duration get bufferedDuration {
    final bytes = _buffer.length;
    if (bytes == 0) return Duration.zero;
    return Duration(seconds: bytes ~/ _pcmBytesPerSecond);
  }

  /// Begins capture. Throws [RecordingPermissionException] when mic access is
  /// denied.
  ///
  /// [onWarning] fires once when the buffered duration crosses
  /// [kDurationWarning]. [onLimitReached] fires once at [kDurationLimit] —
  /// capture is automatically stopped when this fires, and the caller should
  /// treat it as a normal stop (call [stop] to retrieve the WAV).
  Future<void> start({
    VoidCallback? onWarning,
    VoidCallback? onLimitReached,
  }) async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw const RecordingPermissionException();
    }
    _warningFired = false;
    _limitFired = false;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: WavEncoder.sampleRate,
        numChannels: WavEncoder.channels,
      ),
    );
    _subscription = stream.listen(_buffer.add);
    _recording = true;

    // Duration monitor: check every second, fire callbacks at thresholds.
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final d = bufferedDuration;
      if (!_limitFired && d >= kDurationLimit) {
        _limitFired = true;
        // Auto-stop capture — the caller retrieves audio via stop().
        _subscription?.cancel();
        _subscription = null;
        try {
          _recorder.stop();
        } catch (_) {}
        onLimitReached?.call();
      } else if (!_warningFired && d >= kDurationWarning) {
        _warningFired = true;
        onWarning?.call();
      }
    });
  }

  /// Stops capture and returns the complete WAV bytes, in memory. Never
  /// touches disk.
  Future<Uint8List> stop() async {
    _durationTimer?.cancel();
    _durationTimer = null;
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
    _durationTimer?.cancel();
    _durationTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _buffer.clear();
    _recording = false;
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  void dispose() {
    _durationTimer?.cancel();
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
