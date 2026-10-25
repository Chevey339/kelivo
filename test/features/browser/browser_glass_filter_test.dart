import 'dart:ui' as ui;

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('uniform settings sample retains pixels without blur: $dark', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 240,
                height: 140,
                child: ColoredBox(
                  color: dark
                      ? const Color(0xff1c1c1e)
                      : const Color(0xfff2f2f7),
                  child: const Center(
                    child: SizedBox(
                      width: 180,
                      height: 66,
                      child: BrowserGlassScope(
                        style: BrowserSurfaceStyle.frosted,
                        child: BrowserGlass(
                          radius: 24,
                          elevated: false,
                          blur: false,
                          child: Center(child: Text('Frosted')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      Future<Uint8List> pixels() async => (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
      final actual = await pixels();
      final filter = tester.renderObject<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(filter.enabled, isFalse);
      filter.enabled = true;
      await tester.pump();
      final reference = await pixels();
      var difference = 0;
      for (var i = 0; i < actual.length; i++) {
        difference += (actual[i] - reference[i]).abs();
      }
      expect(difference / actual.length, lessThan(1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  for (final dark in [false, true]) {
    for (final offset in [0, 4096]) {
      for (final ratio in [1.0, 3.0]) {
        for (final opacity in [.2, .6, 1.0]) {
          testWidgets(
            'frosted pixels preserve blur alignment: $dark/$offset/$ratio/$opacity',
            (tester) async {
              tester.view.devicePixelRatio = ratio;
              tester.view.physicalSize = Size(360 * ratio, 260 * ratio);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final boundaryKey = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                  home: Center(
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: SizedBox(
                        width: 320,
                        height: 220,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(painter: _Backdrop(offset)),
                            ),
                            Positioned(
                              left: 16,
                              top: 24,
                              right: 16,
                              bottom: 24,
                              child: BrowserGlassScope(
                                style: BrowserSurfaceStyle.frosted,
                                child: BrowserGlass(
                                  radius: 24,
                                  opacity: opacity,
                                  child: Center(
                                    child: Text('Sharp foreground'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              Future<Uint8List> pixels() async =>
                  (await tester.runAsync(() async {
                    final image = await boundary.toImage(pixelRatio: ratio);
                    final data = await image.toByteData(
                      format: ui.ImageByteFormat.rawRgba,
                    );
                    image.dispose();
                    return data!.buffer.asUint8List();
                  }))!;
              final actual = await pixels();
              // Compare against the original full-resolution Gaussian on the same
              // scene. This detects scaling/translation errors and gray sampling
              // edges without binding the test to the optimized filter structure.
              final render = tester.renderObject<RenderBackdropFilter>(
                find.byType(BackdropFilter),
              );
              render.filter = ui.ImageFilter.blur(
                sigmaX: 20 * opacity,
                sigmaY: 20 * opacity,
              );
              await tester.pump();
              final reference = await pixels();
              final width = (320 * ratio).round();
              var error = 0;
              var channels = 0;
              for (
                var y = (32 * ratio).round();
                y < (188 * ratio).round();
                y++
              ) {
                for (
                  var x = (24 * ratio).round();
                  x < (296 * ratio).round();
                  x++
                ) {
                  final index = (y * width + x) * 4;
                  for (var channel = 0; channel < 3; channel++) {
                    error +=
                        (actual[index + channel] - reference[index + channel])
                            .abs();
                    channels++;
                  }
                }
              }
              expect(
                error / channels,
                lessThan(3.0),
                reason:
                    'Blur must retain its position, color and effective radius',
              );
              if (opacity == 1) {
                render.filter = ui.ImageFilter.blur();
                await tester.pump();
                final unblurred = await pixels();
                var effect = 0;
                for (var i = 0; i < actual.length; i++) {
                  effect += (actual[i] - unblurred[i]).abs();
                }
                expect(
                  effect / actual.length,
                  greaterThan(5),
                  reason: 'The capture must actually include backdrop blur',
                );
              }
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(TargetPlatform.android),
          );
        }
      }
    }
  }
}

class _Backdrop extends CustomPainter {
  const _Backdrop(this.offset);
  final int offset;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xff192d62),
      Color(0xffed724b),
      Color(0xff39b6a0),
      Color(0xffedce74),
      Colors.white,
    ];
    for (var y = -32; y < size.height + 32; y += 16) {
      for (var x = -32; x < size.width + 32; x += 16) {
        final color = colors[((x + y + offset).abs() ~/ 16) % colors.length];
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 16, 16),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => offset != oldDelegate.offset;
}
