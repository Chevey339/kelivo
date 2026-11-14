import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:Kelivo/core/models/image_edit_document.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/models/image_upload_quality.dart';
import 'package:Kelivo/features/chat/utils/image_edit_renderer.dart';
import 'package:Kelivo/utils/image_compressor.dart';
import 'package:Kelivo/utils/upload_dedupe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const original = ImageCompressConfig(
    enabled: false,
    quality: 100,
    maxLongEdge: 1568,
    includeTransparent: false,
  );
  test(
    'draft serialization retains original, edit layers and per-image quality',
    () {
      const doc = ImageEditDocument(
        crop: Rect.fromLTWH(.1, .2, .7, .6),
        quarterTurns: 1,
        flipX: true,
        strokes: [
          ImageEditStroke(
            points: [Offset(10, 20), Offset(200, 30)],
            width: 8,
            color: 0xffff453a,
            kind: ImageStrokeKind.arrow,
          ),
        ],
        mosaic: [ImageMosaicOp(rect: Rect.fromLTWH(20, 30, 50, 60))],
        texts: [
          ImageEditText(
            text: '原位文字',
            center: Offset(300, 200),
            style: ImageTextStyle.outline,
          ),
        ],
      );
      const draft = ComposerDraftInput(
        text: 'draft',
        selectionBase: 2,
        selectionExtent: 4,
        images: [
          DraftImage(
            path: '/edited.png',
            sourcePath: '/original.png',
            edits: doc,
            quality: ImageUploadQuality.custom,
            customQuality: 65,
          ),
        ],
      );
      final restored = ComposerDraftInput.fromJson(draft.toJson());
      expect(restored.sameValue(draft), isTrue);
      expect(restored.paths, containsAll(['/original.png', '/edited.png']));
      expect(restored.toInput().imagePaths, ['/edited.png']);
      expect(restored.images.first.edits.sameValue(doc), isTrue);
      expect(
        restored
            .copyWith(
              images: [
                restored.images.first.copyWith(
                  edits: const ImageEditDocument(),
                ),
              ],
            )
            .sameValue(draft),
        isFalse,
      );
    },
  );
  test(
    'crop and rotated source coordinates round trip without moving annotations',
    () {
      for (final turns in [0, 1, 2, 3]) {
        for (final flip in [false, true]) {
          final g = ImageEditGeometry(
            const Size(1200, 800),
            ImageEditDocument(
              crop: const Rect.fromLTWH(.1, .2, .6, .5),
              quarterTurns: turns,
              flipX: flip,
            ),
          );
          final source = const Offset(350, 250);
          final m = g.transform;
          final v = MatrixUtils.transformPoint(m, source);
          final actual = g.toSource(v);
          expect(actual.dx, closeTo(source.dx, 1e-6));
          expect(actual.dy, closeTo(source.dy, 1e-6));
          expect(
            g.size.width,
            closeTo(turns.isOdd ? 1000 * 800 / 1200 * .5 : 600, 1e-6),
          );
        }
      }
    },
  );
  test(
    'export changes real pixels, applies crop and rotation, leaves source intact',
    () async {
      final dir = await Directory.systemTemp.createTemp('kelivo-edit-render-');
      try {
        final source = image.Image(width: 200, height: 100);
        image.fill(source, color: image.ColorRgb8(255, 255, 255));
        final bytes = image.encodePng(source);
        final file = await File('${dir.path}/source.png').writeAsBytes(bytes);
        final output = await ImageEditRenderer.export(
          sourcePath: file.path,
          directory: dir,
          config: original,
          document: const ImageEditDocument(
            crop: Rect.fromLTWH(.25, 0, .5, 1),
            quarterTurns: 1,
            strokes: [
              ImageEditStroke(
                points: [Offset(250, 250), Offset(750, 250)],
                width: 80,
                color: 0xffff0000,
              ),
            ],
          ),
        );
        final result = image.decodePng(await File(output.path).readAsBytes())!;
        expect(result.width, 100);
        expect(result.height, 100);
        expect(result.getPixel(50, 50).r, greaterThan(240));
        expect(result.getPixel(50, 50).g, lessThan(20));
        expect(await file.readAsBytes(), bytes);
        final reset = await ImageEditRenderer.export(
          sourcePath: file.path,
          directory: dir,
          config: original,
          document: const ImageEditDocument(),
        );
        expect(await File(reset.path).readAsBytes(), bytes);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'mosaic masks screenshot pixels and rendered text is included',
    () async {
      final dir = await Directory.systemTemp.createTemp('kelivo-edit-mosaic-');
      try {
        final source = image.Image(width: 640, height: 200);
        image.fill(source, color: image.ColorRgb8(255, 255, 255));
        for (var x = 200; x < 440; x += 6) {
          image.fillRect(
            source,
            x1: x,
            y1: 65,
            x2: x + 2,
            y2: 85,
            color: image.ColorRgb8(0, 0, 0),
          );
        }
        final file = await File(
          '${dir.path}/secret.png',
        ).writeAsBytes(image.encodePng(source));
        final result = await ImageEditRenderer.export(
          sourcePath: file.path,
          directory: dir,
          config: original,
          document: const ImageEditDocument(
            mosaic: [ImageMosaicOp(rect: Rect.fromLTWH(300, 90, 400, 60))],
            texts: [
              ImageEditText(
                text: 'MASKED',
                center: Offset(500, 220),
                size: 50,
                color: 0xffff453a,
                style: ImageTextStyle.fill,
              ),
            ],
          ),
        );
        final output = image.decodePng(await File(result.path).readAsBytes())!;
        var changes = 0;
        for (var y = 64; y < 86; y++) {
          for (var x = 200; x < 440; x++) {
            if (output.getPixel(x, y).r != source.getPixel(x, y).r) changes++;
          }
        }
        expect(changes, greaterThan(1000));
        var redPixels = 0;
        for (var y = 110; y < 180; y++) {
          for (var x = 180; x < 460; x++) {
            final pixel = output.getPixel(x, y);
            if (pixel.r > 200 && pixel.g < 120) redPixels++;
          }
        }
        expect(redPixels, greaterThan(100));
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'mirrored redactions cover the same photo pixels after crop and flip',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo-mirrored-redaction-',
      );
      try {
        final bitmap = image.Image(width: 400, height: 200);
        for (final pixel in bitmap) {
          final v = pixel.x % 4 < 2 ? 0 : 255;
          pixel.setRgb(v, v, v);
        }
        final source = await File(
          '${dir.path}/pattern.png',
        ).writeAsBytes(image.encodePng(bitmap));
        final result = await ImageEditRenderer.export(
          sourcePath: source.path,
          directory: dir,
          config: original,
          document: const ImageEditDocument(
            flipX: true,
            crop: Rect.fromLTWH(.05, 0, .9, 1),
            mosaic: [ImageMosaicOp(rect: Rect.fromLTWH(100, 25, 200, 225))],
          ),
        );
        final cropped = image.decodePng(await File(result.path).readAsBytes())!;
        var redacted = 0;
        for (var y = 20; y < 90; y++) {
          for (var x = 285; x < 345; x++) {
            final original = bitmap.getPixel(399 - x, y).r;
            if (cropped.getPixel(x - 20, y).r != original) redacted++;
            expect(
              cropped.getPixel(399 - x - 20, y).r,
              bitmap.getPixel(x, y).r,
            );
          }
        }
        expect(redacted, greaterThan(1600));
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'flipping mirrors source pixels and keeps annotation placement and lettering',
    () async {
      final dir = await Directory.systemTemp.createTemp('kelivo-flip-');
      try {
        final bitmap = image.Image(width: 300, height: 100);
        image.fill(bitmap, color: image.ColorRgb8(30, 30, 30));
        image.fillRect(
          bitmap,
          x1: 0,
          y1: 0,
          x2: 149,
          y2: 99,
          color: image.ColorRgb8(220, 220, 220),
        );
        final source = await File(
          '${dir.path}/source.png',
        ).writeAsBytes(image.encodePng(bitmap));
        const doc = ImageEditDocument(
          texts: [
            ImageEditText(
              text: 'Fb',
              center: Offset(220, 150),
              size: 95,
              color: 0xffff453a,
              style: ImageTextStyle.fill,
            ),
          ],
        );
        Future<image.Image> render(bool flip) async {
          final result = await ImageEditRenderer.export(
            sourcePath: source.path,
            document: doc.copyWith(flipX: flip),
            directory: dir,
            config: original,
          );
          expect(result.reused, isFalse);
          expect(UploadDedupe.isShared(result.path), isFalse);
          final img = image.decodePng(await File(result.path).readAsBytes())!;
          await UploadDedupe.deleteIfUnshared(result.path);
          expect(await File(result.path).exists(), isFalse);
          return img;
        }

        final normal = await render(false);
        final flipped = await render(true);
        expect(normal.getPixel(5, 5).r, 220);
        expect(flipped.getPixel(5, 5).r, 30);
        expect(flipped.getPixel(295, 5).r, 220);
        // The solid interior of the text badge, including its glyphs, is
        // independent of the mirrored photograph underneath.
        var labelPixels = 0;
        for (var y = 30; y < 60; y++) {
          for (var x = 45; x < 88; x++) {
            final pixel = normal.getPixel(x, y);
            if (pixel.r == 255 && (pixel.g < 100 || pixel.g == 255)) {
              final reflected = flipped.getPixel(x, y);
              expect(
                [reflected.r, reflected.g, reflected.b],
                [pixel.r, pixel.g, pixel.b],
              );
              labelPixels++;
            }
          }
        }
        expect(labelPixels, greaterThan(200));
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test('edited opaque screenshots still honor per-image compression', () async {
    final dir = await Directory.systemTemp.createTemp('kelivo-edit-quality-');
    try {
      final bitmap = image.Image(width: 512, height: 512);
      final random = math.Random(17);
      for (final pixel in bitmap) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final source = await File(
        '${dir.path}/screen.png',
      ).writeAsBytes(image.encodePng(bitmap));
      const doc = ImageEditDocument(
        strokes: [
          ImageEditStroke(
            points: [Offset(100, 100), Offset(800, 700)],
            width: 20,
            color: 0xffff0000,
          ),
        ],
      );
      final full = await ImageEditRenderer.export(
        sourcePath: source.path,
        document: doc,
        directory: dir,
        config: original,
      );
      final small = await ImageEditRenderer.export(
        sourcePath: source.path,
        document: doc,
        directory: dir,
        config: const ImageCompressConfig(
          enabled: true,
          quality: 70,
          maxLongEdge: 128,
          includeTransparent: false,
        ),
      );
      final bytes = await File(small.path).readAsBytes();
      final decoded = image.decodeImage(bytes)!;
      expect(decoded.width, lessThanOrEqualTo(128));
      expect(bytes.length, lessThan(await File(full.path).length()));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
