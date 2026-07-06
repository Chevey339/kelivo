import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/utils/png_alpha_detector.dart';

/// Build a minimal valid PNG with the given [colorType].
/// colorType values: 0=Grayscale, 2=RGB, 3=Indexed, 4=Grayscale+Alpha, 6=RGBA
Uint8List _makePng(int colorType) {
  // Minimal PNG: 1×1 pixel, bitDepth=8, no interlace.
  final buf = BytesBuilder();
  // PNG signature (8 bytes)
  buf.add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  // Width  (4 bytes, 1 pixel)
  ihdr.add(<int>[0, 0, 0, 1]);
  // Height (4 bytes, 1 pixel)
  ihdr.add(<int>[0, 0, 0, 1]);
  // Bit depth (1 byte)
  ihdr.add(<int>[8]);
  // ColorType (1 byte)
  ihdr.add(<int>[colorType]);
  // Compression, filter, interlace (3 bytes)
  ihdr.add(<int>[0, 0, 0]);

  final ihdrData = ihdr.toBytes();
  final ihdrCrc = _crc(ihdrData);

  final ihdrChunk = BytesBuilder();
  // Chunk length
  ihdrChunk.add(_u32(13));
  // Chunk type "IHDR"
  ihdrChunk.add(<int>[0x49, 0x48, 0x44, 0x52]);
  ihdrChunk.add(ihdrData);
  ihdrChunk.add(_u32(ihdrCrc));
  buf.add(ihdrChunk.toBytes());

  // IDAT chunk — minimal compressed pixel data
  final raw = BytesBuilder();
  // filter byte + pixel data (RGB or RGBA depending on colorType)
  raw.addByte(0); // filter = None
  if (colorType == 0 || colorType == 4) {
    // Grayscale: 1 byte per pixel; Gray+Alpha: 2 bytes
    raw.add(<int>[128]); // gray
    if (colorType == 4) raw.add(<int>[255]); // fully opaque
  } else if (colorType == 2 || colorType == 6) {
    raw.add(<int>[255, 0, 0]); // RGB
    if (colorType == 6) raw.add(<int>[255]); // fully opaque
  } else if (colorType == 3) {
    raw.addByte(0); // indexed, palette index 0
  }
  final rawBytes = raw.toBytes();
  final zlib = _zlibCompress(rawBytes);

  final idatCrc = _crc(zlib);
  final idatChunk = BytesBuilder();
  idatChunk.add(_u32(zlib.length));
  idatChunk.add(<int>[0x49, 0x44, 0x41, 0x54]); // "IDAT"
  idatChunk.add(zlib);
  idatChunk.add(_u32(idatCrc));
  buf.add(idatChunk.toBytes());

  // IEND chunk
  buf.add(_u32(0));
  buf.add(<int>[0x49, 0x45, 0x4E, 0x44]); // "IEND"
  buf.add(_u32(_crc(<int>[0x49, 0x45, 0x4E, 0x44])));

  return buf.toBytes();
}

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

int _crc(List<int> data) {
  // Simplified CRC-32 for PNG. Uses the standard polynomial.
  int crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (int i = 0; i < 8; i++) {
      if (crc & 1 == 1) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}

Uint8List _zlibCompress(Uint8List data) {
  // Minimal zlib wrapper: raw deflate with no compression (store method).
  // For 1×1 images this is sufficient.
  final deflate = BytesBuilder();
  // Zlib header: CMF=0x78 (deflate, window=32K), FLG=0x01 (no dict/check)
  deflate.add(<int>[0x78, 0x01]);
  // Raw deflate: final block (BFINAL=1), stored (BTYPE=00)
  final len = data.length;
  deflate.addByte(0x01); // BFINAL=1, BTYPE=00
  deflate.add(_u16(len));
  deflate.add(_u16(len ^ 0xFFFF));
  deflate.add(data);
  // Adler-32 checksum of the original data
  deflate.add(_u32(_adler32(data)));
  return deflate.toBytes();
}

Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v);

int _adler32(Uint8List data) {
  int a = 1, b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('png_alpha_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('pngHasAlphaChannel', () {
    test('returns false for non-existent file', () {
      expect(pngHasAlphaChannel('/nonexistent/file.png'), isFalse);
    });

    test('returns false for non-PNG file', () {
      final f = File('${tmpDir.path}/test.txt')..writeAsStringSync('hello');
      expect(pngHasAlphaChannel(f.path), isFalse);
    });

    test('returns false for PNG with colorType=0 (Grayscale)', () {
      final f = File('${tmpDir.path}/gray.png')..writeAsBytesSync(_makePng(0));
      expect(pngHasAlphaChannel(f.path), isFalse);
    });

    test('returns false for PNG with colorType=2 (RGB)', () {
      final f = File('${tmpDir.path}/rgb.png')..writeAsBytesSync(_makePng(2));
      expect(pngHasAlphaChannel(f.path), isFalse);
    });

    test('returns false for PNG with colorType=3 (Indexed)', () {
      final f = File('${tmpDir.path}/indexed.png')
        ..writeAsBytesSync(_makePng(3));
      expect(pngHasAlphaChannel(f.path), isFalse);
    });

    test('returns true for PNG with colorType=4 (Grayscale+Alpha)', () {
      final f = File('${tmpDir.path}/gray_alpha.png')
        ..writeAsBytesSync(_makePng(4));
      expect(pngHasAlphaChannel(f.path), isTrue);
    });

    test('returns true for PNG with colorType=6 (RGBA)', () {
      final f = File('${tmpDir.path}/rgba.png')..writeAsBytesSync(_makePng(6));
      expect(pngHasAlphaChannel(f.path), isTrue);
    });
  });
}
