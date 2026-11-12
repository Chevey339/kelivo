import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/markdown/highlight_adapter.dart';

Iterable<(String, TextStyle)> runs(
  TextSpan span, [
  TextStyle inherited = const TextStyle(),
]) sync* {
  final style = inherited.merge(span.style);
  if (span.text case final text?) yield (text, style);
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* runs(child, style);
  }
}

void main() {
  setUp(debugResetHighlightNodeCache);

  test(
    'HTML retains tags, CSS and JavaScript with less-than comparisons',
    () async {
      const source =
          '<html><style>.car { color: red; }</style>\n'
          '<script>for (let x = 0; x <= 2; x++) { console.log("go"); }</script></html>';
      final span = await const KelivoCodeHighlighter().highlight(
        source,
        language: 'html',
        style: const TextStyle(color: Colors.white),
        brightness: Brightness.dark,
      );
      expect(span.toPlainText(), source);
      final tokens = runs(span).toList();
      for (final text in ['html', 'color', 'for', 'let', '"go"']) {
        expect(
          tokens.any((run) => run.$1 == text && run.$2.color != Colors.white),
          isTrue,
          reason: text,
        );
      }
    },
  );

  test('unfinished HTML and embedded strings retain all source text', () async {
    for (final source in [
      '<html><script>const label = `value: \${x < 2 ? "yes" : "no"}',
      '<style>/* comment\ncontinued',
      '<div title="unterminated',
    ]) {
      final span = await const KelivoCodeHighlighter().highlight(
        source,
        language: 'html',
        style: const TextStyle(),
        brightness: Brightness.light,
      );
      expect(span.toPlainText(), source);
    }
  });

  test(
    'large blocks parse asynchronously once and reuse syntax across themes',
    () async {
      final source =
          '<html><script>\n${List.filled(1200, 'const label = "中😀";').join('\n')}\n</script></html>';
      const highlighter = KelivoCodeHighlighter();
      final light = highlighter.highlight(
        source,
        language: 'html',
        style: const TextStyle(),
        brightness: Brightness.light,
      );
      final dark = highlighter.highlight(
        source,
        language: 'xml',
        style: const TextStyle(),
        brightness: Brightness.dark,
      );
      expect(light, isA<Future<TextSpan>>());
      expect(dark, isA<Future<TextSpan>>());
      final lightSpan = await light;
      final darkSpan = await dark;
      expect(lightSpan.toPlainText(), source);
      expect(darkSpan.toPlainText(), source);
      expect(debugHighlightParseCount, 1);
      final lightKeyword = runs(
        lightSpan,
      ).firstWhere((run) => run.$1 == 'const');
      final darkKeyword = runs(darkSpan).firstWhere((run) => run.$1 == 'const');
      expect(lightKeyword.$2.color, isNot(darkKeyword.$2.color));
      final cached = highlighter.highlight(
        source,
        language: 'html',
        style: const TextStyle(),
        brightness: Brightness.dark,
      );
      expect(cached, isA<TextSpan>());
      expect(debugHighlightParseCount, 1);
    },
  );
}
