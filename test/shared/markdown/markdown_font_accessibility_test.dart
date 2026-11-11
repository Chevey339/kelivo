import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';
import 'markstream_adapters_test.dart' show host;

Iterable<FontWeight?> probeWeights(
  InlineSpan span, [
  TextStyle inherited = const TextStyle(),
]) sync* {
  final style = inherited.merge(span.style);
  if (span is TextSpan) {
    if (span.text?.contains('probe') ?? false) yield style.fontWeight;
    for (final child in span.children ?? const <InlineSpan>[]) {
      yield* probeWeights(child, style);
    }
  }
}

void main() {
  for (final (label, source) in [
    ('HTML', '<span style="font-weight:700">probe</span>'),
    (
      'HTML with inline widget',
      '<span style="font-weight:700">probe</span> `code`',
    ),
    ('syntax', '```markdown\n**probe**\n```'),
  ]) {
    testWidgets(
      'system bold overrides normalized $label and can be turned off',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        addTearDown(settings.dispose);
        for (final bold in [false, true, false]) {
          await tester.pumpWidget(
            host(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(boldText: bold),
                  child: MarkdownWithCodeHighlight(text: source),
                ),
              ),
              settings: settings,
            ),
          );
          await tester.pumpAndSettle();
          final weights = [
            for (final rich in markdownParagraphs(tester))
              ...probeWeights(rich.text),
          ];
          expect(weights, [bold ? FontWeight.bold : AppFontWeights.strong]);
        }
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }),
    );
  }
}
