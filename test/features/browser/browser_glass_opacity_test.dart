import 'dart:ui' as ui;

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fading glass preserves its live backdrop and foreground state', (
    tester,
  ) async {
    final sceneKey = GlobalKey();
    final foregroundKey = GlobalKey();

    Future<void> mount(double opacity) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: sceneKey,
              child: SizedBox(
                width: 160,
                height: 64,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ColoredBox(color: Colors.black)),
                          Expanded(child: ColoredBox(color: Colors.white)),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: BrowserGlassScope(
                        style: BrowserSurfaceStyle.frosted,
                        child: BrowserGlass(
                          opacity: opacity,
                          elevated: false,
                          child: SizedBox.expand(key: foregroundKey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<int> redAt(int x, int y) async {
      final boundary =
          sceneKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return data!.getUint8((y * image.width + x) * 4);
        } finally {
          image.dispose();
        }
      }))!;
    }

    await mount(1);
    final foreground = foregroundKey.currentContext;
    final full = await redAt(32, 32);
    await mount(.5);
    expect(foregroundKey.currentContext, same(foreground));
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
    );
    final faded = await redAt(32, 32);
    expect(faded, greaterThan(0));
    expect(faded, lessThan(full));
    await mount(0);
    expect(foregroundKey.currentContext, same(foreground));
    expect(await redAt(32, 32), 0);
    expect(await redAt(128, 32), 255);
    expect(tester.takeException(), isNull);
  });
}
