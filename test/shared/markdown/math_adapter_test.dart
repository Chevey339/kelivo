import 'dart:ui' as ui;

import 'package:Kelivo/shared/markdown/math_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _expectFormulaPainted(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = boundary.toImageSync();
  final pixels = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  image.dispose();
  var painted = 0;
  for (var i = 3; i < pixels!.lengthInBytes; i += 4) {
    if (pixels.getUint8(i) > 0) painted++;
  }
  expect(painted, greaterThan(20), reason: '$key must paint the formula');
}

void main() {
  testWidgets('identical formulas paint in every mounted occurrence', (
    tester,
  ) async {
    const keys = [ValueKey('user-math'), ValueKey('assistant-math')];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                for (final key in keys)
                  RepaintBoundary(
                    key: key,
                    child: SizedBox(
                      width: 240,
                      height: 80,
                      child: Center(
                        child: const KelivoMathRenderer().build(
                          context,
                          r'\frac{1}{2} + \sqrt{x^2+y^2}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          displayMode: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final key in keys) {
      await _expectFormulaPainted(tester, key);
    }
  });

  testWidgets('each formula retains only its current parse across rebuilds', (
    tester,
  ) async {
    var tex = r'\frac{1}{2}';
    var color = Colors.red;
    var fontSize = 16.0;
    var display = false;
    late StateSetter rebuild;
    const key = ValueKey('formula');
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Center(
              child: RepaintBoundary(
                key: key,
                child: const KelivoMathRenderer().build(
                  context,
                  tex,
                  style: TextStyle(color: color, fontSize: fontSize),
                  displayMode: display,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.widget<Math>(find.byType(Math)).ast;
    final initialHeight = tester.getSize(find.byType(Math)).height;
    await _expectFormulaPainted(tester, key);

    rebuild(() {
      color = Colors.blue;
      fontSize = 24;
      display = true;
    });
    await tester.pumpAndSettle();
    final updated = tester.widget<Math>(find.byType(Math));
    expect(updated.ast, same(first));
    expect(updated.textStyle!.color, Colors.blue);
    expect(updated.mathStyle, MathStyle.display);
    expect(
      tester.getSize(find.byType(Math)).height,
      greaterThan(initialHeight),
    );
    await _expectFormulaPainted(tester, key);

    rebuild(() => tex = r'\frac{');
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsNothing);
    expect(find.text(tex), findsOneWidget);

    rebuild(() => tex = r'\frac{1}{2}');
    await tester.pumpAndSettle();
    expect(tester.widget<Math>(find.byType(Math)).ast, isNot(same(first)));
    await _expectFormulaPainted(tester, key);
    expect(tester.takeException(), isNull);
  });
}
