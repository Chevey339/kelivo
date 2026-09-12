import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/thinking_sheen.dart';

void main() {
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
