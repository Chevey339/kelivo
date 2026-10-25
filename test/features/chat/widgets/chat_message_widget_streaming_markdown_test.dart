import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/citation_syntax.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:markstream/markstream.dart';
import '../../../support/markdown_render_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({required Widget child}) {
  SharedPreferences.setMockInitialValues(const {});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TtsProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

String _allRichTextPlainText(WidgetTester tester) {
  return markdownParagraphs(
    tester,
  ).map((paragraph) => paragraph.text.toPlainText()).join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [390.0, 1000.0]) {
    testWidgets(
      'reasoning preview pauses follow after scrolling up and resumes at bottom $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var reasoning = List.generate(
          80,
          (i) => 'Paragraph $i **bold** text.',
        ).join('\n\n');
        late StateSetter rebuild;
        await tester.pumpWidget(
          _buildHarness(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SizedBox(
                  width: 360,
                  child: ChatMessageWidget(
                    message: ChatMessage(
                      id: 'review-reasoning-follow',
                      role: 'assistant',
                      content: '',
                      conversationId: 'conversation-1',
                      isStreaming: true,
                    ),
                    reasoningText: reasoning,
                    reasoningLoading: true,
                    showModelIcon: false,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final scrollable = find.byType(Scrollable);
        expect(scrollable, findsOneWidget);
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(100));
        await tester.drag(scrollable, const Offset(0, 65));
        await tester.pump(const Duration(milliseconds: 500));
        expect(position.extentAfter, greaterThan(1));
        final readingOffset = position.pixels;
        rebuild(() => reasoning += '\n\nA new streaming reasoning paragraph.');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        final afterUpdate = position.pixels;
        expect(
          afterUpdate,
          moreOrLessEquals(readingOffset, epsilon: 1),
          reason:
              'New reasoning must preserve the user reading position after scrolling upward',
        );
        position.jumpTo(position.maxScrollExtent);
        rebuild(() => reasoning += '\n\nFollowing again.');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(position.extentAfter, lessThanOrEqualTo(1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'streaming preserves completed citation chips until their indices change',
    (tester) async {
      var tail = '';
      var index = '2';
      late StateSetter rebuild;
      await tester.pumpWidget(
        _buildHarness(
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ChatMessageWidget(
                message: ChatMessage(
                  id: 'streaming-citations',
                  role: 'assistant',
                  content: 'See [cite:abc].\n\nTail $tail',
                  translation: 'Translated [cite:abc].\n\nTail $tail',
                  conversationId: 'conversation-1',
                  isStreaming: true,
                ),
                // Recreate the tool list too: equal result data must not notify
                // every cached citation when the stream publishes a new token.
                toolParts: [
                  ToolUIPart(
                    id: 'search',
                    toolName: 'search_web',
                    arguments: const {},
                    content: '{"items":[{"id":"abc","index":"$index"}]}',
                  ),
                ],
                showModelIcon: false,
              );
            },
          ),
        ),
      );
      await tester.pump();
      final chips = find.descendant(
        of: find.byType(CitationScope),
        matching: find.text('2'),
      );
      expect(chips, findsNWidgets(2));
      final initialLabels = tester.widgetList<Text>(chips).toList();
      for (var i = 0; i < 5; i++) {
        rebuild(() => tail += 'token ');
        await tester.pump();
        final currentLabels = tester.widgetList<Text>(chips).toList();
        for (var j = 0; j < initialLabels.length; j++) {
          expect(currentLabels[j], same(initialLabels[j]));
        }
      }

      rebuild(() => index = '9');
      await tester.pump();
      expect(chips, findsNothing);
      expect(
        find.descendant(
          of: find.byType(CitationScope),
          matching: find.text('9'),
        ),
        findsNWidgets(2),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [390.0, 1000.0]) {
    testWidgets('reasoning overflow retains the renderer at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _buildHarness(
          child: SizedBox(
            width: 360,
            child: ChatMessageWidget(
              message: ChatMessage(
                id: 'reasoning-overflow',
                role: 'assistant',
                content: '',
                conversationId: 'conversation-1',
                isStreaming: true,
              ),
              reasoningText: List.generate(
                80,
                (i) => 'Paragraph $i **bold** 中文。',
              ).join('\n\n'),
              reasoningLoading: true,
              showModelIcon: false,
            ),
          ),
        ),
      );
      final markdown = find.byType(MarkstreamView);
      expect(markdown, findsOneWidget);
      final first = tester.state(markdown);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      // The first layout detects overflow and enables its edge fade next frame.
      await tester.pump();
      expect(tester.state(markdown), same(first));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position,
        same(position),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('ChatMessageWidget preserves table scroll when streaming ends', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final streaming = ValueNotifier(true);
      addTearDown(streaming.dispose);
      await tester.pumpWidget(
        _buildHarness(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: ValueListenableBuilder<bool>(
                valueListenable: streaming,
                builder: (context, value, _) => ChatMessageWidget(
                  message: ChatMessage(
                    id: 'table-scroll',
                    role: 'assistant',
                    content:
                        '| A | B | C | D | E |\n'
                        '| --- | --- | --- | --- | --- |\n'
                        '| apple | banana | cherry | date | elderberry |',
                    conversationId: 'conversation-1',
                    isStreaming: value,
                  ),
                  enableStreamingTextMotion: true,
                  showModelIcon: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final viewport = find.byKey(const ValueKey('markstream-table-scroll'));
      final scroll = find.descendant(
        of: viewport,
        matching: find.byType(Scrollable),
      );
      final state = tester.state<ScrollableState>(scroll);
      await tester.drag(viewport, const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 300));
      final offset = state.position.pixels;
      expect(offset, greaterThan(50));

      final gesture = await tester.startGesture(tester.getCenter(viewport));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      final beforeComplete = state.position.pixels;
      streaming.value = false;
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scroll), same(state));
      expect(state.position.pixels, beforeComplete);
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(state.position.pixels, greaterThan(beforeComplete));
      await gesture.up();
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets(
    'ChatMessageWidget keeps a partial streaming table row in table layout',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'streaming-table',
              role: 'assistant',
              content: '''
| 水果 | 颜色 | 价格 |
| - | - | - |
| 葡萄 🍇''',
              conversationId: 'conversation-1',
              isStreaming: true,
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Table), findsOneWidget);
      expect(markdownParagraph(tester, '葡萄 🍇').text.toPlainText(), '葡萄 🍇');
      expect(_allRichTextPlainText(tester), isNot(contains('| 葡萄 🍇')));
    },
  );

  testWidgets(
    'ChatMessageWidget keeps unfinished streaming Mermaid in the Mermaid block',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      MermaidImageCache.clear();

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'streaming-mermaid',
              role: 'assistant',
              content: '''
```mermaid
graph TD
A-->B''',
              conversationId: 'conversation-1',
              isStreaming: true,
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Generating image'), findsOneWidget);
      expect(_allRichTextPlainText(tester), isNot(contains('graph TD')));
    },
  );
}
