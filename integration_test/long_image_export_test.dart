import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:Kelivo/features/chat/widgets/export_image_capture.dart';

// Run in profile mode on an iOS device. The fixture contains fractional colors
// and antialiased text, which exercise Metal's high-precision PNG readback.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native long export preserves every source pixel and requested size',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const Center(
                  child: Text('Kelivo image export validation'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final watch = Stopwatch()..start();
      final progress = <Map<String, Object>>[];
      final result = await tester.runAsync(
        () => captureExportWidget(
          context,
          const SizedBox(
            width: 480,
            height: 9780,
            child: CustomPaint(painter: _ExportFixturePainter()),
          ),
          theme: ThemeData.dark(),
          onProgress: (p) => progress.add({
            'stage': p.stage.name,
            'completed': p.completed,
            'total': p.total,
            'elapsedMs': watch.elapsedMilliseconds,
          }),
        ),
      );
      watch.stop();
      expect(result, isNotNull);
      final image = img.decodePng(result!.pngBytes)!;
      expect((image.width, image.height), (1440, 29340));
      final preview = result.preview!;
      expect(preview.tiles.length, 8);
      final output = image.toUint8List();
      var offset = 0;
      for (final tile in preview.tiles) {
        final decoded = img.decodePng(tile.bytes)!;
        expect(decoded.format, image.format);
        final bytes = decoded.toUint8List();
        for (var i = 0; i < bytes.length; i++) {
          if (bytes[i] != output[offset + i]) {
            fail(
              'Pixel changed in slice at byte ${offset + i}: ${bytes[i]} != ${output[offset + i]}',
            );
          }
        }
        offset += bytes.length;
      }
      expect(offset, output.length);
      final pixel = image.getPixel(1200, 300);
      expect(pixel.rNormalized, closeTo(.1, .003));
      expect(pixel.gNormalized, closeTo(.1, .003));
      expect(pixel.bNormalized, closeTo(.1, .003));
      // Reproduce the former direct 16-to-8 assignment using the same real slice.
      final first = img.decodePng(preview.tiles.first.bytes)!;
      final old = img.Image(width: 1, height: 1, numChannels: 4);
      old.setPixel(0, 0, first.getPixel(1200, 300));
      final oldPixel = old.getPixel(0, 0);
      // The preview decodes the retained PNG with Flutter's native codec.
      // Check that readback too, rather than validating only Dart PNG buffers.
      final codec = await ui.instantiateImageCodec(preview.tiles.first.bytes);
      final frame = await codec.getNextFrame();
      final raw = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      final previewGray =
          raw!.getUint8((300 * frame.image.width + 1200) * 4) / 255;
      expect(previewGray, closeTo(.1, .005));
      frame.image.dispose();
      codec.dispose();
      final report = <String, Object>{
        'platform': Platform.operatingSystem,
        'elapsedMs': watch.elapsedMilliseconds,
        'width': image.width,
        'height': image.height,
        'pngBytes': result.pngBytes.length,
        'inputBitDepth': preview.tiles.first.bytes[24],
        'outputBitDepth': result.pngBytes[24],
        'allSourceBytesPreserved': true,
        'correctGray': pixel.rNormalized,
        'formerCopyGray': oldPixel.rNormalized,
        'nativePreviewGray': previewGray,
        'progress': progress,
      };
      final dir = Directory(
        '${Directory.systemTemp.path}/kelivo-export-validation',
      )..createSync(recursive: true);
      File('${dir.path}/after.png').writeAsBytesSync(result.pngBytes);
      File(
        '${dir.path}/first-slice.png',
      ).writeAsBytesSync(preview.tiles.first.bytes);
      File('${dir.path}/report.json').writeAsStringSync(jsonEncode(report));
      binding.reportData = report;
      debugPrint('EXPORT_VALIDATION ${jsonEncode(report)}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _ExportFixturePainter extends CustomPainter {
  const _ExportFixturePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color.from(alpha: 1, red: .1, green: .1, blue: .1),
    );
    // Boundary markers make cropping mistakes and lost last rows detectable.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = Colors.white,
    );
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: 'Long export 0123456789 · 清晰文字与颜色',
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    )..layout(maxWidth: 340);
    for (var y = 24.0; y < size.height - 24; y += 48) {
      canvas.drawRect(
        Rect.fromLTWH(16, y, 360, 34),
        Paint()
          ..color = const Color.from(
            alpha: .35,
            red: .63,
            green: .27,
            blue: .81,
          ),
      );
      text.paint(canvas, Offset(24, y + 5));
    }
    text.dispose();
  }

  @override
  bool shouldRepaint(_ExportFixturePainter oldDelegate) => false;
}
