import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/src/engine/liquid_glass_layer.dart';

// Real Impeller probe; no app settings, browser storage, or native WebViews.
// flutter drive -d <simulator> --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_glass_transform_probe.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets('first translated glass frame matches a repainted frame', (
    tester,
  ) async {
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
    await LiquidGlassWidgets.preloadPremiumGlass();
    final directory = await Directory.systemTemp.createTemp('glass-transform-');
    final captureKey = GlobalKey();
    final movement = ValueNotifier<Matrix4>(Matrix4.identity());
    final results = <Map<String, Object>>[];
    try {
      for (final dark in [false, true]) {
        movement.value = Matrix4.identity();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: RepaintBoundary(
              key: captureKey,
              child: _Scene(movement: movement, dark: dark),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        var index = 0;
        for (final transform in [
          Matrix4.translationValues(36.25, 0, 0),
          Matrix4.translationValues(-12.5, 24, 0),
          Matrix4.diagonal3Values(1.16, .92, 1)..setTranslationRaw(8, -4, 0),
        ]) {
          movement.value = transform;
          await tester.pump(); // Capture this first scene, with no settling.
          final first = await boundary.toImage(pixelRatio: 1);
          final firstBytes = (await first.toByteData())!;
          for (final renderer
              in tester.allRenderObjects.whereType<RenderLiquidGlassLayer>()) {
            renderer.markNeedsPaint();
          }
          await tester.pump();
          final reference = await boundary.toImage(pixelRatio: 1);
          final referenceBytes = (await reference.toByteData())!;
          final region = MatrixUtils.transformRect(
            transform,
            const Rect.fromLTWH(24, 150, 260, 220),
          );
          final difference = _difference(
            firstBytes,
            referenceBytes,
            first.width,
            first.height,
            region,
          );
          final name = '${dark ? 'dark' : 'light'}-${index++}';
          for (final entry in {
            'first': first,
            'reference': reference,
          }.entries) {
            final png = (await entry.value.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('${directory.path}/$name-${entry.key}.png').writeAsBytes(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
          }
          first.dispose();
          reference.dispose();
          results.add({'case': name, ...difference});
          expect(
            difference['meanRgbError'],
            lessThanOrEqualTo(.35),
            reason: '$name first scene differs from forced repaint',
          );
          expect(
            difference['severePixelFraction'],
            lessThanOrEqualTo(.002),
            reason: '$name contains a translated edge artifact',
          );
        }
      }
    } finally {
      binding.reportData = {
        'glassTransform': results,
        'glassTransformArtifacts': directory.path,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      movement.dispose();
    }
  });
}

Map<String, double> _difference(
  ByteData actual,
  ByteData expected,
  int width,
  int height,
  Rect region,
) {
  var total = 0;
  var severe = 0;
  var pixels = 0;
  for (
    var y = region.top.floor().clamp(0, height);
    y < region.bottom.ceil().clamp(0, height);
    y++
  ) {
    for (
      var x = region.left.floor().clamp(0, width);
      x < region.right.ceil().clamp(0, width);
      x++
    ) {
      var maximum = 0;
      for (var channel = 0; channel < 3; channel++) {
        final index = (y * width + x) * 4 + channel;
        final delta = (actual.getUint8(index) - expected.getUint8(index)).abs();
        total += delta;
        if (delta > maximum) maximum = delta;
      }
      if (maximum > 12) severe++;
      pixels++;
    }
  }
  return {
    'meanRgbError': total / (pixels * 3),
    'severePixelFraction': severe / pixels,
  };
}

class _Scene extends StatelessWidget {
  const _Scene({required this.movement, required this.dark});
  final ValueNotifier<Matrix4> movement;
  final bool dark;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(painter: _Backdrop(dark)),
      ValueListenableBuilder<Matrix4>(
        valueListenable: movement,
        child: Stack(
          children: [
            Positioned(left: 44, top: 170, child: _glass(48, '‹')),
            Positioned(left: 64, top: 290, child: _glass(200, 'Glass')),
          ],
        ),
        builder: (_, transform, child) => Transform(
          transform: transform,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    ],
  );

  Widget _glass(double width, String label) => RepaintBoundary(
    child: SizedBox(
      width: width,
      height: 48,
      child: GlassTheme(
        data: GlassThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        child: AdaptiveGlass(
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          quality: GlassQuality.premium,
          platformViewBackdrop: false,
          useOwnLayer: true,
          clipExpansion: const EdgeInsets.all(18),
          settings: LiquidGlassSettings(
            glassColor: (dark ? const Color(0xFF121212) : Colors.white)
                .withValues(alpha: .62),
            bodyMode: GlassBodyMode.clear,
            lensModel: GlassLensModel.edgeWarp,
            thickness: 30,
            blur: 2,
            refractiveIndex: 1.2,
            chromaticAberration: 0,
            lightIntensity: .42,
            ambientRim: .07,
            shadow: const [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: dark ? Colors.white : Colors.black,
                decoration: TextDecoration.none,
                fontSize: 22,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Backdrop extends CustomPainter {
  const _Backdrop(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(
      dark ? const Color(0xFF24282D) : const Color(0xFFF6F7F9),
      BlendMode.src,
    );
    final paint = Paint()
      ..color = dark ? const Color(0xFF657886) : const Color(0xFFAABBC8)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => dark != oldDelegate.dark;
}
