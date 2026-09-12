import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('plain suffixes still run source-dependent preprocessing', (
    tester,
  ) async {
    final source = ValueNotifier('Paragraph to');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: source,
            builder: (_, value, _) => GptMarkdown(
              value,
              streaming: true,
              preprocessBlocks: (text) => text.replaceAll('token', '**token**'),
            ),
          ),
        ),
      ),
    );
    source.value += 'ken';
    await tester.pump();
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(rich.text.toPlainText(), 'Paragraph token');
    final weights = <FontWeight?>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'token') {
        weights.add(span.style?.fontWeight);
      }
      return true;
    });
    expect(weights, contains(FontWeight.bold));
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });
  testWidgets('cached plain appends agree with a fresh Markdown parse', (
    tester,
  ) async {
    final source = ValueNotifier('');
    const cached = ValueKey('cached');
    const fresh = ValueKey('fresh');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder<String>(
              valueListenable: source,
              builder: (_, value, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 350,
                    child: GptMarkdown(value, key: cached, streaming: true),
                  ),
                  SizedBox(width: 350, child: GptMarkdown(value, key: fresh)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    List<Object?> spans(Key key) {
      final result = <Object?>[];
      void walk(InlineSpan span, TextStyle parent) {
        final style = parent.merge(span.style);
        final format = (
          style.fontFamily,
          style.fontSize,
          style.fontWeight,
          style.fontStyle,
          style.height,
          style.letterSpacing,
          style.decoration,
          style.color,
        );
        if (span is TextSpan) {
          for (final unit in (span.text ?? '').codeUnits) {
            result.add((unit, format));
          }
          for (final child in span.children ?? const <InlineSpan>[]) {
            walk(child, style);
          }
        } else {
          result.add((span.runtimeType, format));
        }
      }

      for (final text in tester.widgetList<RichText>(
        find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
      )) {
        result.add('paragraph');
        walk(text.text, const TextStyle());
      }
      return result;
    }

    for (final chunks in const [
      ['Paragraph ', '**bold**', ' 中文', ', words.', ' and more'],
      ['Paragraph *unfinished', ' grows', '*', ' normal'],
      ['Paragraph [link', ' label', '](https://example.com)', ' text'],
      ['Paragraph\n#', ' heading', '\n', 'body'],
      ['Paragraph\u2028#', ' heading', '\u2028', 'body'],
      ['Paragraph\u2029#', ' heading', '\u2029', 'body'],
      ['Paragraph\n1', '.', ' item', '\n2. another'],
      ['Paragraph\n-', ' item', '\n', 'next'],
      ['Paragraph ```', 'code', '```', ' tail'],
      ['中文', '追加', '。', '继续', '**加粗**', '后续'],
      ['Paragraph <u>under', 'lined text', '</u>', ' normal'],
      ['Paragraph \\', '#', ' escaped'],
      ['Paragraph **bold**', '*', ' tail', '**', ' more'],
      ['Paragraph *italic*', '*', '*triple', '***', ' tail'],
      ['Paragraph **bold**', ' after', ' continues', ' **next**', ' end'],
      ['Paragraph *unclosed', ' **nested**', ' more', '*', ' end'],
    ]) {
      source.value = '';
      await tester.pump();
      for (final chunk in chunks) {
        source.value += chunk;
        await tester.pump();
        expect(spans(cached), spans(fresh), reason: source.value);
        expect(
          tester.getSize(find.byKey(cached)),
          tester.getSize(find.byKey(fresh)),
          reason: source.value,
        );
      }
    }
    // Token boundaries may split opening/closing emphasis anywhere. Compare
    // every intermediate frame against the same parser without the cache.
    source.value = 'Prose ';
    await tester.pump();
    for (final unit
        in 'plain **bold** after *italic* ***nested*** *open **inner** close* '
            .split('')) {
      source.value += unit;
      await tester.pump();
      expect(spans(cached), spans(fresh), reason: source.value);
    }
    for (final fragment in [
      '**x* tail **',
      '*x** tail *',
      '***x*** tail ',
      '****x**** tail ',
      '**a *b* c** tail ',
      '*a **b** c* tail ',
    ]) {
      source.value = 'Prose ';
      await tester.pump();
      for (final unit in fragment.split('')) {
        source.value += unit;
        await tester.pump();
        expect(spans(cached), spans(fresh), reason: source.value);
      }
    }
    source.value = 'Prose ${'**bold** plain ' * 200}';
    await tester.pump();
    for (final chunk in ['more ', '*ital', 'ic* ', '**next**', ' end']) {
      source.value += chunk;
      await tester.pump();
      expect(spans(cached), spans(fresh), reason: 'grouped prefix: $chunk');
      expect(
        tester.getSize(find.byKey(cached)),
        tester.getSize(find.byKey(fresh)),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });
}
