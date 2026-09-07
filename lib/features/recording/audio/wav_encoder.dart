import 'dart:typed_data';

/// Assembles a canonical RIFF/WAVE container for 16-bit PCM mono audio.
///
/// The server decodes uploads as WAV via the `hound` crate
/// (`load_wav_to_audio_data` in `commands/transcription/helpers.rs`), so the
/// header must carry exact sizes — a "streaming" placeholder size
/// (`0xFFFFFFFF`) only survives `hound::WavReader::new`'s strict parse when
/// it is frame-misaligned, which is format-dependent and fragile (24-bit
/// breaks it). We therefore finalize the header once the byte count is known
/// and keep the audio in RAM throughout — never a plaintext file.
class WavEncoder {
  WavEncoder._();

  /// 16 kHz mono — whisper.cpp's preferred input, and what the desktop
  /// recorder produces.
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;
  static const int bytesPerSample = bitsPerSample ~/ 8; // 2
  static const int blockAlign = channels * bytesPerSample; // 2
  static const int byteRate = sampleRate * blockAlign; // 32000

  static const int headerLength = 44;

  /// Builds the 44-byte header for [pcmDataLength] bytes of PCM payload.
  static Uint8List header(int pcmDataLength) {
    final b = ByteData(headerLength);
    var o = 0;

    void ascii(String s) {
      for (final c in s.codeUnits) {
        b.setUint8(o++, c);
      }
    }

    ascii('RIFF');
    b.setUint32(o, 36 + pcmDataLength, Endian.little);
    o += 4;
    ascii('WAVE');
    ascii('fmt ');
    b.setUint32(o, 16, Endian.little); // PCM fmt chunk size
    o += 4;
    b.setUint16(o, 1, Endian.little); // audio format: PCM
    o += 2;
    b.setUint16(o, channels, Endian.little);
    o += 2;
    b.setUint32(o, sampleRate, Endian.little);
    o += 4;
    b.setUint32(o, byteRate, Endian.little);
    o += 4;
    b.setUint16(o, blockAlign, Endian.little);
    o += 2;
    b.setUint16(o, bitsPerSample, Endian.little);
    o += 2;
    ascii('data');
    b.setUint32(o, pcmDataLength, Endian.little);
    o += 4;

    assert(o == headerLength);
    return b.buffer.asUint8List();
  }

  /// Combines the header and [pcm] payload into a complete WAV, in memory.
  static Uint8List wrap(Uint8List pcm) {
    final h = header(pcm.length);
    final out = Uint8List(h.length + pcm.length);
    out.setRange(0, h.length, h);
    out.setRange(h.length, out.length, pcm);
    return out;
  }
}
