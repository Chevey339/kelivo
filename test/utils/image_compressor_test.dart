import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:Cuplivo/utils/image_compressor.dart';

/// Project-root test fixture: a 512×512 RGBA PNG with transparent areas.
final _kelivoPng = File(p.join('assets', 'icons', 'kelivo.png'));

/// Create a test JPEG with photographic-style content.
File _createTestJpeg(Directory dir, String name, int w, int h) {
  final image = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 7) % 256,
        (y * 13) % 256,
        (x + y) % 256,
        255,
      );
    }
  }
  final f = File('${dir.path}/$name')
    ..writeAsBytesSync(img.encodeJpg(image, quality: 100));
  return f;
}

/// Create a fake GIF file (just header bytes).
File _createFakeGif(Directory dir) {
  return File('${dir.path}/test.gif')
    ..writeAsBytesSync(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('img_compressor_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('ImageCompressor.compressIfNeeded', () {
    test('skips GIF files', () async {
      final f = _createFakeGif(tmpDir);
      final result = await ImageCompressor.compressIfNeeded(
        f.path,
        enabled: true,
        quality: 50,
      );
      expect(result, f.path);
    });

    test('skips files smaller than minBytes', () async {
      final f = _createTestJpeg(tmpDir, 'tiny.jpg', 1, 1);
      expect(f.lengthSync(), lessThan(60 * 1024));
      final result = await ImageCompressor.compressIfNeeded(
        f.path,
        enabled: true,
        quality: 10,
      );
      expect(result, f.path);
    });

    test(
      'compresses a large JPEG with quality 30 and returns smaller file',
      () async {
        final f = _createTestJpeg(tmpDir, 'large.jpg', 800, 600);
        final origLen = f.lengthSync();
        final result = await ImageCompressor.compressIfNeeded(
          f.path,
          enabled: true,
          quality: 30,
          minBytes: 0,
        );
        expect(p.basename(result), 'large.jpg');
        expect(File(result).lengthSync(), lessThan(origLen));
      },
    );

    test('maxDimension resizes the image', () async {
      final f = _createTestJpeg(tmpDir, 'big.jpg', 400, 300);
      await ImageCompressor.compressIfNeeded(
        f.path,
        enabled: true,
        quality: 80,
        maxDimension: 100,
        minBytes: 0,
      );
      final decoded = img.decodeImage(await File(f.path).readAsBytes());
      expect(decoded, isNotNull);
      // longest edge (400) resized to 100; aspect ratio kept: 300→75
      expect(decoded!.width, 100);
      expect(decoded.height, 75);
    });

    test(
      'keepPng keeps PNG format for a real RGBA image with transparency',
      () async {
        expect(
          await _kelivoPng.exists(),
          isTrue,
          reason: 'test fixture missing',
        );
        final f = File('${tmpDir.path}/kelivo.png')
          ..writeAsBytesSync(await _kelivoPng.readAsBytes());
        final origLen = f.lengthSync();
        final result = await ImageCompressor.compressIfNeeded(
          f.path,
          enabled: true,
          quality: 80,
          keepPng: true,
          minBytes: 0,
        );
        expect(p.extension(result).toLowerCase(), '.png');
        expect(
          File(result).lengthSync(),
          lessThan(origLen * 2),
        ); // PNG re-compression at level 6
      },
    );

    test('returns original path when disabled', () async {
      final f = _createTestJpeg(tmpDir, 'disabled.jpg', 100, 100);
      final result = await ImageCompressor.compressIfNeeded(
        f.path,
        enabled: false,
        quality: 50,
      );
      expect(result, f.path);
    });

    test('returns original path for non-existent file', () async {
      final path = '${tmpDir.path}/nonexistent.png';
      final result = await ImageCompressor.compressIfNeeded(
        path,
        enabled: true,
        quality: 50,
      );
      expect(result, path);
    });

    test(
      'compresses real kelivo.png (has transparency), keeps PNG, output valid',
      () async {
        expect(
          await _kelivoPng.exists(),
          isTrue,
          reason: 'test fixture missing',
        );
        final f = File('${tmpDir.path}/kelivo.png')
          ..writeAsBytesSync(await _kelivoPng.readAsBytes());
        // kelivo.png has real transparency → keep PNG via explicit option.
        final result = await ImageCompressor.compressIfNeeded(
          f.path,
          enabled: true,
          quality: 50,
          keepPng: true,
          minBytes: 0,
        );
        expect(p.extension(result).toLowerCase(), '.png');
        final decoded = img.decodeImage(await File(result).readAsBytes());
        expect(decoded, isNotNull);
      },
    );

    test('compresses opaque PNG (varied content), output valid', () async {
      final image = img.Image(width: 800, height: 600);
      for (int y = 0; y < 600; y++) {
        for (int x = 0; x < 800; x++) {
          image.setPixelRgba(
            x,
            y,
            (x * 7) % 256,
            (y * 13) % 256,
            (x + y) % 256,
            255,
          );
        }
      }
      final bytes = img.encodePng(image);
      final f = File('${tmpDir.path}/opaque.png')..writeAsBytesSync(bytes);

      final result = await ImageCompressor.compressIfNeeded(
        f.path,
        enabled: true,
        quality: 50,
        minBytes: 0,
      );
      expect(File(result).existsSync(), isTrue);
      final decoded = img.decodeImage(await File(result).readAsBytes());
      expect(decoded, isNotNull);
    });

    test('skips enabled: false even with all parameters set', () async {
      final f = _createTestJpeg(tmpDir, 'noop.jpg', 200, 200);
      final result = await ImageCompressor.compressIfNeeded(
        f.path,
        enabled: false,
        quality: 10,
        maxDimension: 10,
        keepPng: true,
      );
      expect(result, f.path);
    });
  });
}
