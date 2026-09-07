import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/features/recording/audio/wav_encoder.dart';

void main() {
  group('WavEncoder', () {
    test('header is 44 bytes with correct RIFF/WAVE/fmt/data structure', () {
      final h = WavEncoder.header(1000);
      expect(h.length, 44);

      String ascii(int start, int len) =>
          String.fromCharCodes(h.sublist(start, start + len));
      int u32le(int off) =>
          ByteData.sublistView(h).getUint32(off, Endian.little);
      int u16le(int off) =>
          ByteData.sublistView(h).getUint16(off, Endian.little);

      expect(ascii(0, 4), 'RIFF');
      expect(ascii(8, 4), 'WAVE');
      expect(ascii(12, 4), 'fmt ');
      expect(ascii(36, 4), 'data');

      expect(u32le(4), 36 + 1000, reason: 'RIFF size');
      expect(u32le(16), 16, reason: 'fmt chunk size');
      expect(u16le(20), 1, reason: 'PCM format');
      expect(u16le(22), 1, reason: 'mono');
      expect(u32le(24), 16000, reason: 'sample rate');
      expect(u32le(28), 32000, reason: 'byte rate');
      expect(u16le(32), 2, reason: 'block align');
      expect(u16le(34), 16, reason: 'bits per sample');
      expect(u32le(40), 1000, reason: 'data size');
    });

    test('wrap produces header + payload with matching sizes', () {
      final pcm = Uint8List(64);
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] = i;
      }
      final wav = WavEncoder.wrap(pcm);
      expect(wav.length, 44 + 64);
      // RIFF size field reflects total minus 8.
      final riff = ByteData.sublistView(wav).getUint32(4, Endian.little);
      expect(riff, 36 + 64);
      // Payload is byte-for-byte preserved after the header.
      expect(wav.sublist(44), equals(pcm));
    });

    test('wrap handles empty payload (0 bytes)', () {
      final wav = WavEncoder.wrap(Uint8List(0));
      expect(wav.length, 44);
      expect(ByteData.sublistView(wav).getUint32(40, Endian.little), 0);
    });
  });
}
