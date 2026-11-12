import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/thinking_sheen.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';

void main() {
  testWidgets('thinking and loading effects leave no continuous ticker', (
    tester,
  ) async {
    Widget effects({bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThinkingSheen(child: Text('Thinking')),
              LoadingIndicator(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(effects());
    final initial = tester.widget<ShaderMask>(find.byType(ShaderMask));
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<ShaderMask>(find.byType(ShaderMask)),
      isNot(same(initial)),
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(effects(reduceMotion: true));
    final paused = tester.widget<ShaderMask>(find.byType(ShaderMask));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<ShaderMask>(find.byType(ShaderMask)), same(paused));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  test('sheen palette stays opaque so srcIn keeps the child alpha', () {
    const color = Color(0xC7556688);
    final light = ThinkingSheenPalette.fromColor(color, isDark: false);
    final dark = ThinkingSheenPalette.fromColor(color, isDark: true);

    expect(light.base.a, 1);
    expect(light.highlight.a, 1);
    expect(dark.base.a, 1);
    expect(dark.highlight.a, 1);
    expect(light.base.r, color.r);
    expect(light.base.g, color.g);
    expect(light.base.b, color.b);
  });

  test('light sheen still lifts toward white', () {
    const color = Color(0xFF556688);
    final light = ThinkingSheenPalette.fromColor(color, isDark: false);

    expect(light.highlight, Color.lerp(color, Colors.white, 0.78));
    expect(
      light.highlight.computeLuminance(),
      greaterThan(light.base.computeLuminance()),
    );
  });

  test('dark sheen darkens the highlight so it reads on bright ink', () {
    const color = Color(0xFFE8E0F0);
    final dark = ThinkingSheenPalette.fromColor(color, isDark: true);

    expect(dark.highlight, Color.lerp(color, Colors.black, 0.82));
    expect(
      dark.highlight.computeLuminance(),
      lessThan(dark.base.computeLuminance()),
    );
  });
}
