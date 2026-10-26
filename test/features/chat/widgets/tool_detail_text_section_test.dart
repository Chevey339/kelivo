import 'package:Kelivo/features/chat/widgets/tool_detail_text_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(String label, String text) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        child: CustomScrollView(
          slivers: [ToolDetailTextSection(label: label, text: text)],
        ),
      ),
    ),
  );

  test('range boundaries preserve line endings and surrogate pairs', () {
    for (final source in [
      '',
      for (final lines in [39, 40, 41, 120, 121])
        for (final ending in ['\n', '\r\n'])
          List.filled(lines, 'line😀').join(ending) + ending,
      '${'x' * 3999}😀${'y' * 9000}',
      '${'x' * 3999}\r\n${'y' * 9000}',
    ]) {
      final chunks = ToolDetailTextSection.chunkRangesOf(
        source,
      ).map((range) => range.textInside(source)).toList();
      expect(chunks.join(), source);
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(4000));
        expect('\n'.allMatches(chunk).length, lessThanOrEqualTo(40));
        expect(chunk.isNotEmpty, isTrue);
        final first = chunk.codeUnitAt(0);
        final last = chunk.codeUnitAt(chunk.length - 1);
        expect(first >= 0xDC00 && first <= 0xDFFF, isFalse);
        expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
        expect(chunk.endsWith('\r'), isFalse);
      }
    }
  });

  testWidgets('giant single lines are bounded and refresh on source change', (
    tester,
  ) async {
    final source = 'a' * 500000;
    await tester.pumpWidget(harness('Result', source));
    final visible = tester.widgetList<Text>(find.byType(Text));
    expect(visible.length, lessThan(10));
    expect(visible.every((text) => (text.data?.length ?? 0) <= 4000), isTrue);
    await tester.pumpWidget(harness('Updated label', source));
    expect(find.text('Updated label'), findsOneWidget);
    await tester.pumpWidget(harness('Result', 'replacement'));
    expect(find.text('replacement'), findsOneWidget);
    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsNothing);
  });

  testWidgets(
    'malformed tool text is safe to render without changing the source',
    (tester) async {
      for (final source in ['bad\uD800value\uDC00😀', '${'x' * 9000}\uD800']) {
        await tester.pumpWidget(harness('Result', source));
        expect(
          tester
              .widget<ToolDetailTextSection>(find.byType(ToolDetailTextSection))
              .text,
          source,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(harness('Result', 'bad\uD800value\uDC00😀'));
      expect(find.text('bad�value�😀'), findsOneWidget);
    },
  );

  testWidgets('small result renders as a single eager text block', (
    tester,
  ) async {
    await tester.pumpWidget(harness('Result', 'short result'));

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('short result'), findsOneWidget);
    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsNothing);
  });

  testWidgets('selection preserves artificial chunk and newline boundaries', (
    tester,
  ) async {
    final source = '${'a' * 3999}😀${'b' * 3999}\r\nend';
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (content) => selected = content?.plainText,
            child: CustomScrollView(
              slivers: [
                ToolDetailTextSection(
                  label: 'Result',
                  text: source,
                  textStyle: const TextStyle(fontSize: 1, height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, 'Result$source');
    expect(tester.takeException(), isNull);
  });

  testWidgets('huge result is chunked and only builds visible chunks', (
    tester,
  ) async {
    final text = List<String>.generate(
      10000,
      (index) => 'result-$index',
    ).join('\n');

    await tester.pumpWidget(harness('Result', text));

    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsOneWidget);
    expect(find.textContaining('result-0'), findsOneWidget);
    expect(find.textContaining('result-9999'), findsNothing);

    final builtChunks = tester.widgetList<Text>(find.byType(Text)).length;
    expect(builtChunks, lessThan(20));
  });

  testWidgets('chunk boundaries preserve the original text', (tester) async {
    final text = List<String>.generate(
      500,
      (index) => 'line-$index',
    ).join('\n');

    expect(
      ToolDetailTextSection.chunkRangesOf(
        text,
      ).map((range) => range.textInside(text)).join(),
      text,
    );
    expect(ToolDetailTextSection.shouldChunk(text), isTrue);
    expect(ToolDetailTextSection.shouldChunk('a\nb\nc'), isFalse);
  });

  testWidgets('chunked content can still be scrolled to the end', (
    tester,
  ) async {
    final text = List<String>.generate(400, (index) => 'row-$index').join('\n');

    await tester.pumpWidget(harness('Result', text));
    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tool-detail-text-chunk-9')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('row-399'), findsOneWidget);
  });
}
