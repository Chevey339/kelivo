import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/features/chat/widgets/quote_source_anchor.dart';
import 'package:Kelivo/features/chat/widgets/viewport_block_list.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/utils/source_text_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

void main() {
  for (final markdown in [false, true]) {
    testWidgets(
      'quote scroll centers its first line past repeated text (markdown: $markdown)',
      (tester) async {
        final scroll = ScrollController();
        final chat = ChatScrollController(
          scrollController: scroll,
          onStateChanged: () {},
          getAutoScrollEnabled: () => false,
          getTopRevealInset: () => 80,
        );
        final actions = QuoteInteractionController(
          onQuote: (_) async {},
          onJump: (_) async => true,
          sourceExists: (_) async => true,
        );
        final prefix =
            'needle at the beginning\n\n${'earlier paragraph\n\n' * 50}';
        final source = '${prefix}needle on the quoted line\nand another line';
        final message = ChatMessage(
          id: 'source',
          conversationId: 'chat',
          role: 'assistant',
          content: source,
        );
        final quote = QuoteRef(
          id: 'quote',
          messageId: message.id,
          start: prefix.length,
          end: source.length,
          text: source.substring(prefix.length),
          model: null,
          createdAt: DateTime(2026),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuoteInteractionScope(
                controller: actions,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      QuoteSourceAnchor(
                        message: message,
                        source: source,
                        sourceMap: SourceTextMap.identity(source.length),
                        markdown: markdown,
                        child: SelectionArea(
                          child: SizedBox(
                            width: 320,
                            child: markdown
                                ? MarkstreamView(source: source)
                                : Text(source),
                          ),
                        ),
                      ),
                      const SizedBox(height: 600),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final request = actions.scrollToSource(
          quote,
          scrollToRect: (rect) =>
              chat.scrollToSourceRect(rect, bottomInset: 120),
          isCurrent: () => true,
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        await request;
        final paragraphs = <RenderParagraph>[];
        void visit(RenderObject object) {
          if (object is RenderParagraph &&
              object.text.toPlainText().contains('needle on the quoted line')) {
            paragraphs.add(object);
          }
          object.visitChildren(visit);
        }

        visit(tester.renderObject(find.byType(QuoteSourceAnchor)));
        final paragraph = paragraphs.single;
        final at = paragraph.text.toPlainText().indexOf(
          'needle on the quoted line',
        );
        final rect = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + 6),
            )
            .first
            .toRect();
        expect(
          paragraph.localToGlobal(rect.center).dy,
          closeTo((80 + 600 - 120) / 2, 1),
        );
        expect(scroll.offset, greaterThan(600));
        expect(actions.navigationFor(message.id), isNull);
        expect(actions.highlightsFor(message.id), isEmpty);
        await tester.pumpWidget(const SizedBox());
        actions.dispose();
        chat.dispose();
        scroll.dispose();
      },
    );
  }

  testWidgets(
    'quote scroll mounts its virtualized block and preserves original offsets',
    (tester) async {
      final scroll = ScrollController();
      final chat = ChatScrollController(
        scrollController: scroll,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
      );
      final actions = QuoteInteractionController(
        onQuote: (_) async {},
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      final texts = List.generate(
        60,
        (i) => 'Block $i\n${'repeated content\n' * 20}quoted line $i',
      );
      final source = texts.join('\n');
      final message = ChatMessage(
        id: 'source',
        conversationId: 'chat',
        role: 'assistant',
        content: source,
      );
      final offset = source.indexOf('quoted line 50');
      final quote = QuoteRef(
        id: 'q',
        messageId: message.id,
        start: offset,
        end: offset + 14,
        text: 'quoted line 50',
        model: null,
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuoteInteractionScope(
              controller: actions,
              child: SingleChildScrollView(
                controller: scroll,
                child: Builder(
                  builder: (context) => ViewportBlockList(
                    itemCount: texts.length,
                    itemKey: (i) => i,
                    structureToken: texts,
                    estimateExtent: (_, _) => 40,
                    revealIndex:
                        QuoteInteractionScope.maybeOf(
                              context,
                            )?.navigationFor(message.id) ==
                            null
                        ? null
                        : 50,
                    itemBuilder: (_, i) => QuoteSourceAnchor(
                      message: message,
                      source: texts[i],
                      sourceMap: SourceTextMap.identity(
                        texts[i].length,
                        offset: source.indexOf(texts[i]),
                      ),
                      markdown: false,
                      child: Text(texts[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(texts[50]), findsNothing);
      final request = actions.scrollToSource(
        quote,
        scrollToRect: (rect) => chat.scrollToSourceRect(rect, bottomInset: 0),
        isCurrent: () => true,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await request;
      await tester.pumpAndSettle();
      expect(find.text(texts[50]), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(texts[50]),
          matching: find.byType(RichText),
        ),
      );
      final at = texts[50].indexOf('quoted line 50');
      final rect = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: at, extentOffset: at + 14),
          )
          .first
          .toRect();
      expect(paragraph.localToGlobal(rect.center).dy, closeTo(300, 1));
      await tester.pumpWidget(const SizedBox());
      actions.dispose();
      chat.dispose();
      scroll.dispose();
    },
  );
}
