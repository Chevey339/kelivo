import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/chat/widgets/plain_message_text.dart';
import 'package:Kelivo/features/chat/widgets/quote_source_highlight.dart';
import 'package:markstream/markstream.dart';
import '../../../support/markdown_render_helpers.dart';

void main() {
  testWidgets(
    'mixed plaintext keeps clipboard breaks, source offsets and line heights',
    (tester) async {
      const source = 'English\r\n\r\nسلام Gemini\n中文';
      const style = TextStyle(fontSize: 16, height: 1.3);
      final target = source.indexOf('中文');
      final key = GlobalKey();
      SelectedContent? selection;
      Future<void> show(Widget content) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SelectionArea(
                onSelectionChanged: (value) => selection = value,
                child: RepaintBoundary(key: key, child: content),
              ),
            ),
          ),
        ),
      );
      await show(const Text(source, style: style));
      final height = tester.getSize(find.byKey(key)).height;
      await show(
        plainMessageText(
          text: source,
          style: style,
          buildSpan: (start, end) => highlightedQuoteSource(
            source,
            [SourceSpan(target, target + 1)],
            Colors.yellow,
            start: start,
            end: end,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(key)).height, closeTo(height, .01));
      final chinese = renderedParagraphsWith('中文').single;
      expect(chinese.textDirection, TextDirection.ltr);
      final rect = textRangeRect(
        key.currentContext!.findRenderObject()!,
        TextRange(start: target, end: target + 1),
      );
      expect(rect, isNotNull);
      final glyph = chinese
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .single
          .toRect();
      expect(rect, glyph.shift(chinese.localToGlobal(Offset.zero)));
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      expect(selection?.plainText, source);
    },
  );
}
