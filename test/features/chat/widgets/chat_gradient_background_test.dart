import 'dart:typed_data';

import 'package:Kelivo/features/chat/widgets/chat_gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = boundary.toImageSync();
  try {
    final bytes = await tester.runAsync(() => image.toByteData());
    return Uint8List.fromList(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

void main() {
  testWidgets(
    'animation repaints without rebuilding content and pauses offscreen',
    (tester) async {
      final key = GlobalKey();
      var builds = 0;
      Widget app({
        bool enabled = true,
        bool ticker = true,
        bool reduced = false,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: ChatGradientBackgroundHost(
              enabled: enabled,
              child: RepaintBoundary(
                key: key,
                child: Stack(
                  children: [
                    const Positioned.fill(child: ChatGradientBackground()),
                    Builder(
                      builder: (_) {
                        builds++;
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      final first = await _pixels(tester, key);
      final originalBuilds = builds;
      await tester.pump(const Duration(seconds: 2));
      expect(await _pixels(tester, key), isNot(orderedEquals(first)));
      expect(builds, originalBuilds);

      for (final config in [
        app(ticker: false),
        app(reduced: true),
        app(enabled: false),
      ]) {
        await tester.pumpWidget(config);
        final frozen = await _pixels(tester, key);
        await tester.pump(const Duration(seconds: 2));
        expect(await _pixels(tester, key), orderedEquals(frozen));
        expect(tester.binding.transientCallbackCount, 0);
      }
      await tester.pumpWidget(app());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = await _pixels(tester, key);
      await tester.pump(const Duration(seconds: 10));
      expect(await _pixels(tester, key), orderedEquals(paused));
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(await _pixels(tester, key), isNot(orderedEquals(paused)));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'static mode exactly matches a selected animated frame after reload',
    (tester) async {
      final root = GlobalKey();
      var currentFrame = 2.0;
      Widget app(bool animated, double phase) => MaterialApp(
        home: RepaintBoundary(
          key: root,
          child: ChatGradientBackgroundHost(
            enabled: animated,
            phase: phase,
            onFrame: (frame) => currentFrame = frame,
            child: const ChatGradientBackground(),
          ),
        ),
      );
      await tester.pumpWidget(app(true, 2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      final selected = currentFrame;
      final animatedPixels = await _pixels(tester, root);
      await tester.pumpWidget(app(false, selected));
      await tester.pump(const Duration(seconds: 2));
      expect(await _pixels(tester, root), orderedEquals(animatedPixels));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(false, selected));
      expect(await _pixels(tester, root), orderedEquals(animatedPixels));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('overlay copies stay aligned through resize and panel movement', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final root = GlobalKey();
    final base = GlobalKey();
    for (final animated in [false, true]) {
      for (final brightness in Brightness.values) {
        for (final size in [const Size(400, 700), const Size(1100, 720)]) {
          tester.view.physicalSize = size;
          for (final left in [40.0, 110.0]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: RepaintBoundary(
                  key: root,
                  child: ChatGradientBackgroundHost(
                    enabled: animated,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: base,
                            child: const ChatGradientBackground(),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: 150,
                          width: 160,
                          height: 200,
                          child: const ColoredBox(
                            color: Colors.pink,
                            child: ChatGradientBackground(pinned: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(seconds: 3));
            final expected = await _pixels(tester, base);
            final actual = await _pixels(tester, root);
            var maxDifference = 0;
            for (var i = 0; i < expected.length; i += 4) {
              for (var c = 0; c < 3; c++) {
                final delta = (expected[i + c] - actual[i + c]).abs();
                if (delta > maxDifference) maxDifference = delta;
              }
              if (brightness == Brightness.light) {
                expect(expected[i], greaterThanOrEqualTo(150));
                expect(expected[i + 1], greaterThanOrEqualTo(190));
                expect(expected[i + 2], greaterThanOrEqualTo(200));
              }
            }
            expect(
              maxDifference,
              lessThanOrEqualTo(2),
              reason: '$animated / $brightness / $size / $left',
            );
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'animated copies reuse shaders and record once at at most 30 fps',
    (tester) async {
      debugGradientPictureBuildCount = 0;
      debugGradientShaderBuildCount = 0;
      var siblingPaints = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatGradientBackgroundHost(
            enabled: true,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(child: ChatGradientBackground()),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PaintProbe(() => siblingPaints++),
                  ),
                ),
                const Positioned(
                  left: 30,
                  top: 50,
                  width: 250,
                  height: 80,
                  child: ChatGradientBackground(pinned: true),
                ),
                const Positioned(
                  left: 30,
                  top: 250,
                  width: 250,
                  height: 80,
                  child: ChatGradientBackground(pinned: true),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'an idle chat must not schedule a frame on every vsync',
      );
      final initialPaints = siblingPaints;
      final initialPictures = debugGradientPictureBuildCount;
      expect(debugGradientShaderBuildCount, 5);
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      expect(debugGradientShaderBuildCount, 5);
      expect(
        debugGradientPictureBuildCount - initialPictures,
        inInclusiveRange(28, 30),
      );
      expect(siblingPaints, initialPaints);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _PaintProbe extends CustomPainter {
  _PaintProbe(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}
