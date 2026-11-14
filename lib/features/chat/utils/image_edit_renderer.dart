import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../../core/models/image_edit_document.dart';
import '../../../utils/image_compressor.dart';
import '../../../utils/upload_dedupe.dart';

/// Shared by the live stage, filmstrip and full-resolution export.
class ImageEditGeometry {
  ImageEditGeometry(Size source, ImageEditDocument doc, {bool full = false}) {
    sourceSize = Size(1000, 1000 * source.height / source.width);
    final r = full ? null : doc.crop;
    crop = r == null
        ? Offset.zero & sourceSize
        : Rect.fromLTRB(
            r.left * 1000,
            r.top * sourceSize.height,
            r.right * 1000,
            r.bottom * sourceSize.height,
          );
    size = doc.quarterTurns.isOdd ? Size(crop.height, crop.width) : crop.size;
    transform = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..rotateZ(doc.quarterTurns * math.pi / 2)
      ..translateByDouble(-crop.center.dx, -crop.center.dy, 0, 1);
  }
  late final Size sourceSize;
  late final Rect crop;
  late final Size size;
  late final Matrix4 transform;
  Offset toSource(Offset point) =>
      MatrixUtils.transformPoint(Matrix4.inverted(transform), point);
}

class ImageEditRenderer {
  /// Imports the original once and builds the sendable image from the edits.
  static Future<({UploadWrite source, UploadWrite? image})?> prepareDraft(
    String sourcePath,
    Directory directory,
    ImageCompressConfig config,
    ImageEditDocument edits, {
    bool ownsSource = false,
    bool reuseSourceInPlace = false,
  }) => ImageCompressor.prepareForEditing(
    sourcePath,
    directory,
    config,
    ownsSource: ownsSource,
    reuseSourceInPlace: reuseSourceInPlace,
    renderEdits: edits.isEmpty
        ? null
        : (original) => export(
            sourcePath: original,
            document: edits,
            directory: directory,
            config: config,
          ),
  );

  static Future<ui.Image> decode(String path, {int? maxEdge}) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final factor = maxEdge == null
          ? 1.0
          : math.min(
              1.0,
              maxEdge / math.max(descriptor.width, descriptor.height),
            );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * factor).round()),
        targetHeight: math.max(1, (descriptor.height * factor).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<ui.Image> pixelate(ui.Image source) async {
    final h = math.max(1, (64 * source.height / source.width).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const contrast = 1.9;
    const bias = 128 * (1 - contrast);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, 64, h.toDouble()),
      Paint()
        ..filterQuality = FilterQuality.low
        ..colorFilter = const ColorFilter.matrix([
          contrast,
          0,
          0,
          0,
          bias,
          0,
          contrast,
          0,
          0,
          bias,
          0,
          0,
          contrast,
          0,
          bias,
          0,
          0,
          0,
          1,
          0,
        ]),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(64, h);
    } finally {
      picture.dispose();
    }
  }

  static Future<UploadWrite> export({
    required String sourcePath,
    required ImageEditDocument document,
    required Directory directory,
    required ImageCompressConfig config,
  }) async {
    if (document.isEmpty) {
      final result = await ImageCompressor.compressToUploadDir(
        sourcePath,
        directory,
        config,
        reuseSourceInPlace: true,
      );
      if (result == null) {
        throw const FileSystemException('Image export failed');
      }
      return result;
    }
    final source = await decode(sourcePath);
    ui.Image? pixels;
    ui.Image? rendered;
    ui.Picture? picture;
    try {
      if (document.mosaic.isNotEmpty) pixels = await pixelate(source);
      final geometry = ImageEditGeometry(
        Size(source.width.toDouble(), source.height.toDouble()),
        document,
      );
      final factor = source.width / 1000;
      final width = math.max(1, (geometry.size.width * factor).round());
      final height = math.max(1, (geometry.size.height * factor).round());
      final recorder = ui.PictureRecorder();
      ImageEditPainter(
        source: source,
        pixels: pixels,
        document: document,
      ).paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
      picture = recorder.endRecording();
      rendered = await picture.toImage(width, height);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const FileSystemException('Image encoding failed');
      }
      var bytes = data.buffer.asUint8List();
      final jpeg = [
        '.jpg',
        '.jpeg',
        '.heic',
        '.heif',
      ].contains(p.extension(sourcePath).toLowerCase());
      bytes = await compute(jpeg ? _encodeJpeg : _encodePng, bytes);
      return await ImageCompressor.storeEncodedImage(
        'edit_${DateTime.now().microsecondsSinceEpoch}.${jpeg ? 'jpg' : 'png'}',
        directory,
        bytes,
        config,
      );
    } finally {
      source.dispose();
      pixels?.dispose();
      rendered?.dispose();
      picture?.dispose();
    }
  }
}

Uint8List _encodeJpeg(Uint8List png) =>
    img.encodeJpg(img.decodePng(png)!, quality: 95);

// Flutter renders RGBA even for opaque screenshots. Store those as RGB so
// the shared compressor does not mistake them for transparency that needs opt-in.
Uint8List _encodePng(Uint8List png) {
  final decoded = img.decodePng(png)!;
  final opaque =
      !decoded.hasAlpha ||
      decoded.every((pixel) => pixel.a == pixel.maxChannelValue);
  return img.encodePng(opaque ? decoded.convert(numChannels: 3) : decoded);
}

TextStyle imageEditTextStyle(ImageEditText text, {Paint? foreground}) {
  final fill = Color(text.color);
  final darkText =
      text.color == 0xffffffff ||
      text.color == 0xffffd60a ||
      text.color == 0xff32d74b;
  return TextStyle(
    color: foreground == null
        ? (text.style == ImageTextStyle.fill
              ? (darkText ? const Color(0xff111111) : Colors.white)
              : fill)
        : null,
    foreground: foreground,
    fontSize: text.size,
    fontFamily: switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => '.SF Pro Text',
      TargetPlatform.windows => 'Segoe UI',
      TargetPlatform.linux => 'Noto Sans',
      _ => 'Roboto',
    },
    fontWeight: FontWeight.w600,
    height: text.style == ImageTextStyle.fill ? 1.56 : 1.24,
    fontFeatures: const [ui.FontFeature('palt')],
    fontVariations: const [ui.FontVariation('wght', 650)],
    shadows: text.style == ImageTextStyle.plain
        ? [
            Shadow(
              color: Colors.black.withValues(alpha: .42),
              offset: Offset(0, text.size * .03),
              blurRadius: text.size * .12,
            ),
          ]
        : null,
  );
}

TextPainter imageEditTextPainter(ImageEditText text, {Paint? foreground}) =>
    TextPainter(
      text: TextSpan(
        text: text.text,
        style: imageEditTextStyle(text, foreground: foreground),
      ),
      textAlign: text.align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 940);

class ImageEditPainter extends CustomPainter {
  ImageEditPainter({
    required this.source,
    required this.document,
    this.pixels,
    this.full = false,
    this.selectedText,
    this.editingText,
    this.textOnly,
  });
  final ui.Image source;
  final ui.Image? pixels;
  final ImageEditDocument document;
  final bool full;
  final int? selectedText;
  final int? editingText;
  final int? textOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = ImageEditGeometry(
      Size(source.width.toDouble(), source.height.toDouble()),
      document,
      full: full,
    );
    canvas.save();
    canvas.scale(
      size.width / geometry.size.width,
      size.height / geometry.size.height,
    );
    canvas.transform(geometry.transform.storage);
    canvas.clipRect(geometry.crop);
    final sourceRect = Offset.zero & geometry.sourceSize;
    void drawPixels(ui.Image image, Paint paint) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        sourceRect,
        paint,
      );
    }

    if (textOnly == null) {
      // Redactions stay attached to the original pixels through every flip.
      canvas.save();
      if (document.flipX) {
        canvas.translate(sourceRect.width, 0);
        canvas.scale(-1, 1);
      }
      drawPixels(source, Paint()..filterQuality = FilterQuality.medium);
      if (pixels != null && document.mosaic.isNotEmpty) {
        canvas.saveLayer(sourceRect, Paint());
        for (final op in document.mosaic) {
          final paint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = op.width;
          if (op.rect != null) {
            canvas.drawRect(op.rect!, paint..style = PaintingStyle.fill);
          } else {
            _paintLine(canvas, op.points, paint);
          }
        }
        drawPixels(
          pixels!,
          Paint()
            ..filterQuality = FilterQuality.none
            ..blendMode = BlendMode.srcIn,
        );
        canvas.restore();
      }
      canvas.restore();
      for (final stroke in document.strokes) {
        final paint = Paint()
          ..color = Color(stroke.color)
          ..strokeWidth = stroke.width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        if (stroke.kind == ImageStrokeKind.arrow && stroke.points.length > 1) {
          final start = stroke.points.first, end = stroke.points.last;
          canvas.drawLine(start, end, paint);
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final length = math.max(stroke.width * 3.4, 20.0);
          for (final delta in [-.5, .5]) {
            canvas.drawLine(
              end,
              end -
                  Offset(math.cos(angle + delta), math.sin(angle + delta)) *
                      length,
              paint,
            );
          }
        } else {
          _paintLine(canvas, stroke.points, paint);
        }
      }
    }
    for (var i = 0; i < document.texts.length; i++) {
      if (i == editingText || (textOnly != null && i != textOnly)) continue;
      final text = document.texts[i];
      final painter = imageEditTextPainter(text);
      final origin =
          text.center - Offset(painter.width / 2, painter.height / 2);
      if (text.style == ImageTextStyle.fill) {
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.text.length),
        );
        for (final box in boxes) {
          final r = box.toRect().shift(origin);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                r.left - text.size * .42,
                r.top - text.size * .12,
                r.right + text.size * .42,
                r.bottom + text.size * .12,
              ),
              Radius.circular(text.size * .34),
            ),
            Paint()..color = Color(text.color),
          );
        }
      } else if (text.style == ImageTextStyle.outline) {
        final outline = imageEditTextPainter(
          text,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = text.size * .16
            ..strokeJoin = StrokeJoin.round
            ..color = Color(text.color).computeLuminance() > .4
                ? Colors.black
                : Colors.white,
        );
        outline.paint(canvas, origin);
        outline.dispose();
      }
      painter.paint(canvas, origin);
      if (i == selectedText) {
        final rect = (origin & painter.size).inflate(text.size * .22);
        final border = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        for (double x = rect.left; x < rect.right; x += 12) {
          canvas.drawLine(
            Offset(x, rect.top),
            Offset(math.min(x + 6, rect.right), rect.top),
            border,
          );
          canvas.drawLine(
            Offset(x, rect.bottom),
            Offset(math.min(x + 6, rect.right), rect.bottom),
            border,
          );
        }
        for (double y = rect.top; y < rect.bottom; y += 12) {
          canvas.drawLine(
            Offset(rect.left, y),
            Offset(rect.left, math.min(y + 6, rect.bottom)),
            border,
          );
          canvas.drawLine(
            Offset(rect.right, y),
            Offset(rect.right, math.min(y + 6, rect.bottom)),
            border,
          );
        }
        canvas.drawCircle(rect.centerLeft, 5, Paint()..color = Colors.white);
        canvas.drawCircle(rect.centerRight, 5, Paint()..color = Colors.white);
      }
      painter.dispose();
    }
    canvas.restore();
  }

  void _paintLine(Canvas c, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      c.drawCircle(
        points.first,
        paint.strokeWidth / 2,
        Paint()..color = paint.color,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ImageEditPainter old) =>
      source != old.source ||
      pixels != old.pixels ||
      document != old.document ||
      full != old.full ||
      selectedText != old.selectedText ||
      editingText != old.editingText ||
      textOnly != old.textOnly;
}
