import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('cold native glass updates every mounted surface after loading',
      (tester) async {
    LightweightLiquidGlass.resetForTesting();
    final childKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            for (var index = 0; index < 2; index++)
              LightweightLiquidGlass(
                shape: const LiquidRoundedSuperellipse(borderRadius: 12),
                child: SizedBox(
                  key: index == 0 ? childKey : null,
                  width: 120,
                  height: 48,
                ),
              ),
          ],
        ),
      ),
    );
    final childElement = childKey.currentContext;
    await tester.runAsync(() async {
      await Future.wait([
        LightweightLiquidGlass.preWarm(),
        LightweightLiquidGlass.preWarm(),
      ]);
    });
    await tester.pump();
    final effects = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_LightweightGlassEffect',
    );
    expect(effects, findsNWidgets(2));
    for (final element in effects.evaluate()) {
      // Inspect the actual renderer, rather than accepting its tint fallback
      // as proof that shader preparation reached every mounted glass widget.
      final dynamic renderer = element.findRenderObject()!;
      expect(renderer.shader, isNotNull);
    }
    expect(childKey.currentContext, same(childElement));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
