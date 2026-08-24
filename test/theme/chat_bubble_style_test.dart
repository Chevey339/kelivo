import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';

void main() {
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF4D5C92));

  test('empty overrides are default and omit json fields', () {
    const empty = ChatBubbleStyleOverrides();
    expect(empty.isDefault, isTrue);
    expect(empty.toJson(), isEmpty);
    expect(ChatBubbleStyleOverrides.fromJson(const {}), empty);
  });

  test('copyWith can set and clear nullable fields', () {
    const empty = ChatBubbleStyleOverrides();
    final set = empty.copyWith(
      blurSigma: () => 20,
      backgroundArgbLight: () => 0xFF112233,
    );
    expect(set.isDefault, isFalse);
    expect(set.blurSigma, 20);
    expect(set.backgroundArgbLight, 0xFF112233);

    final cleared = set.copyWith(blurSigma: () => null);
    expect(cleared.blurSigma, isNull);
    expect(cleared.backgroundArgbLight, 0xFF112233);
  });

  test('fromJson accepts ints and doubles', () {
    final parsed = ChatBubbleStyleOverrides.fromJson({
      'borderWidth': 1,
      'frostedOpacity': 0.5,
      'backgroundArgbDark': 0xFFABCDEF,
    });
    expect(parsed.borderWidth, 1.0);
    expect(parsed.frostedOpacity, 0.5);
    expect(parsed.backgroundArgbDark, 0xFFABCDEF);
  });

  test('frosted defaults match previous hardcoded surface', () {
    const overrides = ChatBubbleStyleOverrides();
    final resolved = resolveBubbleStyle(
      cs,
      Brightness.light,
      ChatMessageBackgroundStyle.frosted,
      overrides,
    );
    expect(
      resolved.background,
      cs.surfaceContainerHigh.withValues(alpha: 0.66),
    );
    expect(resolved.border, cs.outlineVariant.withValues(alpha: 0.14));
    expect(resolved.text, cs.onSurface);
    expect(resolved.borderWidth, 0.8);
    expect(resolved.radius, 16);
    expect(resolved.blurSigma, 14);
  });

  test('solid defaults match previous hardcoded surface', () {
    final resolved = resolveBubbleStyle(
      cs,
      Brightness.light,
      ChatMessageBackgroundStyle.solid,
      const ChatBubbleStyleOverrides(),
    );
    expect(resolved.background, cs.surfaceContainerHigh);
    expect(resolved.border, cs.outlineVariant.withValues(alpha: 0.16));
    expect(resolved.blurSigma, 14);
  });

  test('dark color fields apply independently of light', () {
    const overrides = ChatBubbleStyleOverrides(
      backgroundArgbLight: 0xFF111111,
      backgroundArgbDark: 0xFFEEEEEE,
      textArgbDark: 0xFF00FF00,
      frostedOpacity: 0.4,
    );
    final light = resolveBubbleStyle(
      cs,
      Brightness.light,
      ChatMessageBackgroundStyle.frosted,
      overrides,
    );
    final dark = resolveBubbleStyle(
      cs,
      Brightness.dark,
      ChatMessageBackgroundStyle.frosted,
      overrides,
    );
    expect(light.background, const Color(0xFF111111).withValues(alpha: 0.4));
    expect(dark.background, const Color(0xFFEEEEEE).withValues(alpha: 0.4));
    expect(light.text, cs.onSurface);
    expect(dark.text, const Color(0xFF00FF00));
    expect(overrides.hasTextOverride(Brightness.light), isFalse);
    expect(overrides.hasTextOverride(Brightness.dark), isTrue);
  });

  test('frostedSampleScale uses σ/6 and clamps to dpr', () {
    expect(frostedSampleScale(sigma: 0, dpr: 3), 0);
    expect(frostedSampleScale(sigma: -1, dpr: 3), 0);
    expect(frostedSampleScale(sigma: 14, dpr: 3), closeTo(6 / 14, 1e-9));
    expect(frostedSampleScale(sigma: 1, dpr: 0.5), 0.5);
    expect(frostedSampleScale(sigma: 200, dpr: 3), 0.05);
  });
}
