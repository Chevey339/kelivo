import 'dart:ui' as ui;

import 'package:Kelivo/shared/markdown/math_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

const _captureKey = ValueKey('formula-capture');
const _viewportWidth = 200.0;
const _margin = 32.0;
const _pixelRatio = 3.0;

Future<({List<int> rows, int outsideInk})> _capture(
  WidgetTester tester, {
  required String tex,
  required double fontSize,
  required double scale,
  required bool fenced,
  required bool reference,
  required double scrollOffset,
}) async {
  final theme = MarkstreamTheme.fromColorScheme(
    const ColorScheme.light(),
    bodyStyle: TextStyle(fontSize: fontSize, color: Colors.black),
  );
  // The reference paints the same formula without viewport clipping. Compare
  // only the horizontal viewport's interior, including all vertical ink.
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _captureKey,
            child: SizedBox(
              width: _viewportWidth + 2 * _margin,
              height: 180,
              child: Padding(
                padding: const EdgeInsets.all(_margin),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: reference
                      ? Padding(
                          padding: theme.mathPadding,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: Builder(
                              builder: (context) =>
                                  const KelivoMathRenderer().build(
                                    context,
                                    tex,
                                    style: theme.body,
                                    displayMode: true,
                                  ),
                            ),
                          ),
                        )
                      : MarkstreamView(
                          source: fenced
                              ? '```math\n$tex\n```'
                              : '\$\$\n$tex\n\$\$',
                          theme: theme,
                          mathRenderer: const KelivoMathRenderer(),
                          extensions: MarkstreamExtensions(
                            codeBlockBuilders: {
                              'math': (context, node, rendering) =>
                                  KelivoMathBlock(
                                    node: node,
                                    theme: rendering.theme,
                                    fallback: const Text('Parse error'),
                                  ),
                            },
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
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position;
  expect(position.maxScrollExtent, greaterThan(scrollOffset));
  position.jumpTo(scrollOffset);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = boundary.toImageSync(pixelRatio: _pixelRatio);
  try {
    final pixels = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final left = (_margin * _pixelRatio).round();
    final right = ((_margin + _viewportWidth) * _pixelRatio).round();
    final rows = List<int>.filled(image.height, 0);
    var outsideInk = 0;
    for (var y = 0; y < image.height; y++) {
      // Ignore the left/right edge pixels: clipping there is intentional.
      for (var x = left + 3; x < right - 3; x++) {
        rows[y] += pixels!.getUint8((y * image.width + x) * 4 + 3);
      }
      for (var x = right + 3; x < image.width; x++) {
        outsideInk += pixels!.getUint8((y * image.width + x) * 4 + 3);
      }
    }
    return (rows: rows, outsideInk: outsideInk);
  } finally {
    image.dispose();
  }
}

void main() {
  setUpAll(() async {
    // Ahem's rectangular glyphs do not reproduce KaTeX's paint overhang.
    await (FontLoader('packages/flutter_math_fork/KaTeX_Main')..addFont(
          rootBundle.load(
            'packages/flutter_math_fork/lib/katex_fonts/fonts/KaTeX_Main-Regular.ttf',
          ),
        ))
        .load();
  });

  for (final fenced in [false, true]) {
    for (final fontSize in [15.5, 24.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'wide math preserves vertical glyph ink, fence=$fenced size=$fontSize scale=$scale',
          (tester) async {
            for (final tex in [
              r'129 + 510 + 954 + 1494 + 2030 + 2582 + 3188',
              List.filled(10, r'2^{123}+3^{456}').join('+'),
              List.filled(10, r'\frac{123}{456}').join('+'),
            ]) {
              for (final offset in [0.0, 48.0]) {
                final reference = await _capture(
                  tester,
                  tex: tex,
                  fontSize: fontSize,
                  scale: scale,
                  fenced: fenced,
                  reference: true,
                  scrollOffset: offset,
                );
                final actual = await _capture(
                  tester,
                  tex: tex,
                  fontSize: fontSize,
                  scale: scale,
                  fenced: fenced,
                  reference: false,
                  scrollOffset: offset,
                );
                expect(reference.rows.any((ink) => ink > 0), isTrue);
                expect(
                  actual.rows,
                  reference.rows,
                  reason: 'No vertical ink may be clipped: $tex at $offset',
                );
                expect(reference.outsideInk, greaterThan(0));
                expect(
                  actual.outsideInk,
                  0,
                  reason: 'Long formulas must still clip horizontally',
                );
              }
            }
          },
        );
      }
    }
  }
}
