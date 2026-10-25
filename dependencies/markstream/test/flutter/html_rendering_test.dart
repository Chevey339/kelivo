import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:markstream/src/flutter/render/html_style.dart';

import 'markstream_view_test.dart' show host, paragraphs, paragraph, edge;
import 'document_selection_test.dart' show drag;
import 'rich_blocks_test.dart' show selectAll;

class _Links implements LinkHandler {
  final urls = <String>[];
  @override
  void open(BuildContext context, LinkNode node) => urls.add(node.destination);
}

class _Images implements ImageBuilder {
  final images = <ImageNode>[];
  @override
  Widget build(BuildContext context, ImageNode image, MarkstreamTheme theme) {
    images.add(image);
    return const SizedBox(key: ValueKey('html-image'), width: 40, height: 20);
  }
}

TextStyle spanStyle(String text) {
  TextStyle? result;
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is TextSpan && span.text == text) result = style;
    if (span is TextSpan)
      for (final child in span.children ?? <InlineSpan>[]) visit(child, style);
  }

  for (final p in paragraphs()) visit(p.text, const TextStyle());
  return result!;
}

void main() {
  testWidgets(
    'subscripts and superscripts move the glyph baseline at both scales',
    (tester) async {
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          host(
            const MarkstreamView(source: 'H<sub>2</sub>O x<sup>3</sup>'),
            scale: scale,
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
        double baseline(String text) {
          final p = paragraph(text);
          return p
              .localToGlobal(
                Offset(
                  0,
                  p.getDryBaseline(p.constraints, TextBaseline.alphabetic)!,
                ),
              )
              .dy;
        }

        final body = baseline('H');
        expect(baseline('2') - body, closeTo(15.5 * .2 * scale, scale));
        expect(baseline('3') - body, closeTo(-15.5 * .35 * scale, scale));
        expect(tester.takeException(), isNull);
      }
    },
  );
  test(
    'bounded CSS color grammar handles hex, rgb and invalid declarations',
    () {
      expect(htmlColor('#123'), const Color(0xff112233));
      expect(htmlColor('#1234'), const Color(0x44112233));
      expect(htmlColor('#11223380'), const Color(0x80112233));
      expect(htmlColor('rgba(100%, 0%, 0%, .5)'), const Color(0x80ff0000));
      expect(htmlColor('rgb(0, 10, 255)'), const Color(0xff000aff));
      for (final raw in ['url(x)', 'var(--x)', '#12345', 'rgb(NaN,0,0)'])
        expect(htmlColor(raw), isNull);
    },
  );
  testWidgets('native inline HTML applies style and preserves source copy', (
    tester,
  ) async {
    const source =
        'Before <b>Bold</b> <i>Italic</i> <u>Under</u> <del>Deleted</del> <mark>Marked</mark> <span style="color:#123456;background-color:#eee;font-weight:700">Color</span> <font color="blue">Blue</font> <code>code</code> <kbd>Ctrl</kbd> H<sub>2</sub>O x<sup>2</sup><br>After';
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    String? plain;
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        host(
          MarkstreamView(source: source, selectionController: controller),
          width: 280,
          scale: scale,
          selectable: true,
          onSelection: (s) => plain = s?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      expect(spanStyle('Bold').fontWeight, FontWeight.w700);
      expect(spanStyle('Italic').fontStyle, FontStyle.italic);
      expect(
        spanStyle('Under').decoration!.contains(TextDecoration.underline),
        isTrue,
      );
      expect(
        spanStyle('Deleted').decoration!.contains(TextDecoration.lineThrough),
        isTrue,
      );
      expect(spanStyle('Color').color, const Color(0xff123456));
      expect(spanStyle('Color').backgroundColor, const Color(0xffeeeeee));
      expect(spanStyle('Blue').color, const Color(0xff0000ff));
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(
        plain,
        'Before Bold Italic Under Deleted Marked Color Blue code Ctrl H2O x2\nAfter',
      );
      expect(controller.selectedPlainText, plain);
      expect(controller.selectedMarkdown, contains('<sub>2</sub>'));
      expect(
        controller.selectedMarkdown,
        contains(
          '<span style="color:#123456;background-color:#eee;font-weight:700">Color</span>',
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('HTML links and sized images reuse the injected adapters', (
    tester,
  ) async {
    final links = _Links(), images = _Images();
    const source =
        'Before <a href="https://example.com?a=1&amp;b=2"><b>Go</b></a> <a href="javascript:alert(1)">Unsafe</a> <img src="image.png" alt="Picture" width="40" height="20"> After';
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          linkHandler: links,
          imageBuilder: images,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = paragraph('Before');
    final text = p.text.toPlainText();
    await tester.tapAt(edge(p, text.indexOf('Go')));
    expect(links.urls, ['https://example.com?a=1&b=2']);
    await tester.tapAt(edge(p, text.indexOf('Unsafe')));
    expect(links.urls, hasLength(1));
    expect(images.images.single.destination, 'image.png');
    expect(toPlainText(images.images.single), 'Picture');
    expect(
      tester.getSize(find.byKey(const ValueKey('html-image'))),
      const Size(40, 20),
    );
  });
  testWidgets('block subset shares flow, TSV and nested list selection', (
    tester,
  ) async {
    const source =
        '<div><h2>Title</h2><p>First <strong>bold</strong>.</p><center>Centered</center><blockquote>Quoted</blockquote><ol start="3"><li>Three<ul><li>Nested</li></ul></li><li>Four</li></ol><table><tr><th></th><th>Head</th><th></th></tr><tr><td></td><td>Value</td><td></td></tr><tr><td></td><td></td><td></td></tr></table><pre><code class="language-dart">  code();\n\nend();</code></pre><hr><p>Finish</p></div>';
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    String? plain;
    await tester.pumpWidget(
      host(
        MarkstreamView(source: source, selectionController: controller),
        selectable: true,
        onSelection: (s) => plain = s?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkstreamTableBlock), findsOneWidget);
    expect(find.byType(MarkstreamCodeBlock), findsOneWidget);
    final table = tester.widget<MarkstreamTableBlock>(
      find.byType(MarkstreamTableBlock),
    );
    expect(toMarkdown(table.node), isNot(contains('<td>')));
    expect(toMarkdown(table.node), contains('|  | Value |  |'));
    expect(tableToCsv(table.node), ',Head,\r\n,Value,\r\n,,');
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(plain, contains('3. Three\n  \n  - Nested\n4. Four'));
    expect(plain, contains('\tHead\t\n\tValue\t\n\t\t'));
    expect(plain, contains('  code();\n\nend();'));
    expect(
      controller.selectedMarkdown,
      contains('<td></td><td>Value</td><td></td>'),
    );
    expect(
      controller.selectedMarkdown,
      contains('<tr><td></td><td></td><td></td></tr>'),
    );
    expect(controller.selectedMarkdown, contains('<hr>'));
    expect(find.byType(SelectableRegion), findsOneWidget);
  });
  testWidgets('cached HTML links remain interactive through tail updates', (
    tester,
  ) async {
    final links = _Links();
    for (final tail in ['Tail', 'Tail appended', 'Tail appended again']) {
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'Before <a href="https://example.com">Go</a>.\n\n$tail',
            streaming: true,
            linkHandler: links,
          ),
        ),
      );
      await tester.pump();
      final p = paragraph('Before');
      await tester.tapAt(edge(p, p.text.toPlainText().indexOf('Go')));
      expect(tester.takeException(), isNull);
    }
    expect(links.urls, List.filled(3, 'https://example.com'));
  });
  testWidgets('partial HTML list selection preserves numbering and styles', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: '<ol start="7"><li>First</li><li><b>Second</b></li><li>Third</li></ol>',
          selectionController: controller,
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    await drag(tester, 'Second', 1, 'Third', 3);
    expect(controller.selectedMarkdown, contains('<ol start="8">'));
    expect(controller.selectedMarkdown, contains('<b>econd</b>'));
    expect(controller.selectedMarkdown, contains('<li>Thi</li>'));
  });
  testWidgets(
    'unknown shells retain text and active HTML cannot render or open',
    (tester) async {
      await tester.pumpWidget(
        host(
          const MarkstreamView(
            source: '<div><custom>Keep</custom><script>SECRET</script><style>SECRET</style><iframe>SECRET</iframe><p>After</p></div>',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final visible = paragraphs().map((p) => p.text.toPlainText()).join();
      expect(visible, contains('Keep'));
      expect(visible, contains('After'));
      expect(visible, isNot(contains('SECRET')));
    },
  );
}
