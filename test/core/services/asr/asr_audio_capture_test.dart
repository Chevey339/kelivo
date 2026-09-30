import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/asr/asr_audio_capture.dart';

void main() {
  test('normalizedPcm16Level maps silence to zero', () {
    expect(normalizedPcm16Level(Uint8List(32)), 0);
    expect(normalizedPcm16Level(Uint8List(1)), 0);
  });

  test('normalizedPcm16Level increases with PCM amplitude', () {
    Uint8List pcm(int value) {
      final result = Uint8List(64);
      final data = ByteData.sublistView(result);
      for (var offset = 0; offset < result.length; offset += 2) {
        data.setInt16(offset, value, Endian.little);
      }
      return result;
    }

    final quiet = normalizedPcm16Level(pcm(800));
    final speech = normalizedPcm16Level(pcm(8000));
    final loud = normalizedPcm16Level(pcm(30000));

    expect(quiet, greaterThan(0));
    expect(speech, greaterThan(quiet));
    expect(loud, greaterThan(speech));
    expect(loud, lessThanOrEqualTo(1));
  });

  test('wraps mono PCM16 in a canonical WAV header', () {
    final pcm = Uint8List.fromList([1, 2, 3, 4]);
    final wav = pcm16MonoToWav(pcm, sampleRate: 24000);
    final header = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), 36 + pcm.length);
    expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 24000);
    expect(header.getUint32(28, Endian.little), 48000);
    expect(header.getUint16(32, Endian.little), 2);
    expect(header.getUint16(34, Endian.little), 16);
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });
}
