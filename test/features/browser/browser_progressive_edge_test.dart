import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_progressive_edge.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  void unchangedToolbarFade(
    String description, {
    bool top = false,
    bool filterBackdrop = false,
    Brightness brightness = Brightness.dark,
    BrowserSurfaceStyle style = BrowserSurfaceStyle.liquid,
    bool reduceTransparency = false,
    bool highContrast = false,
  }) {
    testWidgets('toolbar fade leaves $description unchanged', (tester) async {
      Future<void> mount(bool fade) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: MediaQueryData(highContrast: highContrast),
            child: GlassAccessibilityScope(
              reduceTransparency: reduceTransparency,
              child: BrowserGlassScope(
                style: style,
                child: SizedBox(
                  width: 390,
                  height: 108,
                  child: BrowserProgressiveEdge(
                    top: top,
                    filterBackdrop: filterBackdrop,
                    fadeBehindToolbar: fade,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      LinearGradient gradient() {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(BrowserProgressiveEdge),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as BoxDecoration).gradient! as LinearGradient;
      }

      await mount(false);
      final original = gradient();
      await mount(true);
      expect(gradient(), original);
      expect(tester.takeException(), isNull);
    });
  }

  unchangedToolbarFade('the top edge', top: true);
  unchangedToolbarFade('light mode', brightness: Brightness.light);
  unchangedToolbarFade('frosted mode', style: BrowserSurfaceStyle.frosted);
  unchangedToolbarFade('solid mode', style: BrowserSurfaceStyle.solid);
  unchangedToolbarFade('reduced transparency', reduceTransparency: true);
  unchangedToolbarFade('high contrast', highContrast: true);
  unchangedToolbarFade('Flutter backdrop filtering', filterBackdrop: true);

  test('blur uniforms follow the edge rect in device pixels on both axes', () {
    for (final axis in [0.0, 1.0]) {
      final uniforms = progressiveBlurUniforms(
        origin: const Offset(12, 700),
        size: const Size(390, 120),
        devicePixelRatio: 3,
        maxSigma: 10,
        falloff: 1.6,
        direction: ProgressiveBlurDirection.bottomToTop,
        axis: axis,
      );
      expect(uniforms, [30, 1.6, 1, axis, 36, 2100, 1170, 360]);

      // A route translation changes the region origin, not sigma, extent, or
      // axis. Using the old origin would smear the whole edge during a pop.
      final translated = progressiveBlurUniforms(
        origin: const Offset(92, 700),
        size: const Size(390, 120),
        devicePixelRatio: 3,
        maxSigma: 10,
        falloff: 1.6,
        direction: ProgressiveBlurDirection.bottomToTop,
        axis: axis,
      );
      expect(translated, [30, 1.6, 1, axis, 276, 2100, 1170, 360]);
    }
  });

  test('top and bottom gradients retain opposite shader directions', () {
    List<double> uniforms(ProgressiveBlurDirection direction) =>
        progressiveBlurUniforms(
          origin: Offset.zero,
          size: const Size(390, 120),
          devicePixelRatio: 2,
          maxSigma: 10,
          falloff: 1.6,
          direction: direction,
          axis: 0,
        );
    expect(uniforms(ProgressiveBlurDirection.topToBottom)[2], 0);
    expect(uniforms(ProgressiveBlurDirection.bottomToTop)[2], 1);
  });

  for (final solid in [false, true]) {
    testWidgets(
      '${solid ? 'solid' : 'native backdrop'} edge keeps its bounded gradient without a filter',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BrowserGlassScope(
              style: solid
                  ? BrowserSurfaceStyle.solid
                  : BrowserSurfaceStyle.liquid,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 390,
                  height: 120,
                  child: BrowserProgressiveEdge(
                    top: true,
                    filterBackdrop: solid,
                  ),
                ),
              ),
            ),
          ),
        );
        final edge = find.byType(BrowserProgressiveEdge);
        final clip = find.descendant(of: edge, matching: find.byType(ClipRect));
        expect(tester.getSize(clip), const Size(390, 120));
        expect(find.byType(ProgressiveBlur), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        final decoration = tester.widget<DecoratedBox>(
          find.descendant(of: edge, matching: find.byType(DecoratedBox)),
        );
        final gradient =
            (decoration.decoration as BoxDecoration).gradient!
                as LinearGradient;
        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
        expect(gradient.colors.last.a, 0);
        expect(gradient.colors.first.a, greaterThan(gradient.colors[1].a));
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  }
}
