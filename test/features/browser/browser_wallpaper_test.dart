import 'dart:ui' as ui;

import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('wallpaper stays inside a translated page in $brightness', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                height: 500,
                child: ColoredBox(
                  color: const Color(0xffff00ff),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 120,
                        top: 20,
                        width: 160,
                        height: 400,
                        child: BrowserWallpaper(child: const SizedBox.expand()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final image = await tester.runAsync(
        () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(),
      );
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final bytes = data!.buffer.asUint8List();
      var leaked = 0;
      for (var y = 0; y < 500; y++) {
        for (var x = 0; x < 360; x++) {
          if (x >= 120 && x < 280 && y >= 20 && y < 420) continue;
          final offset = (y * 360 + x) * 4;
          if (bytes[offset] != 255 ||
              bytes[offset + 1] != 0 ||
              bytes[offset + 2] != 255) {
            leaked++;
          }
        }
      }
      image!.dispose();
      expect(
        leaked,
        0,
        reason: 'Side-swipe must not reveal ribbons outside the page.',
      );
    });
  }
}
