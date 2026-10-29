import 'dart:ui' as ui;
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/features/chat/widgets/select_copy_sheet.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/markdown/quote_syntax.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

class _Chat extends ChatService {
  @override
  Conversation? getConversation(String id) =>
      Conversation(id: id, title: 'Source', assistantId: 'a');
}

class _Assistants extends AssistantProvider {
  _Assistants() : super(preferences: createBusinessTestPreferences());
  @override
  Assistant? getById(String id) => const Assistant(
    id: 'a',
    name: 'Regex',
    regexRules: [
      AssistantRegex(
        id: 'r',
        name: 'hide fragments',
        pattern: 'PREFIX[ ]|DELETE[ ]',
        replacement: '',
        scopes: [AssistantRegexScope.assistant],
        visualOnly: true,
      ),
    ],
  );
}

Widget _app(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
    ),
    ChangeNotifierProvider<AssistantProvider>(create: (_) => _Assistants()),
    ChangeNotifierProvider<ChatService>(create: (_) => _Chat()),
    ChangeNotifierProvider(
      create: (_) => TtsProvider(preferences: createBusinessTestPreferences()),
    ),
    ChangeNotifierProvider(create: (_) => ToolApprovalService()),
    ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'mixed prose/code references expand their own snapshots before quoting',
    (tester) async {
      final refs = [
        for (var i = 0; i < 2; i++)
          QuoteRef(
            id: 'q$i',
            messageId: 's$i',
            start: 0,
            end: 7,
            text: 'source$i',
            model: null,
            createdAt: DateTime(2026),
          ),
      ];
      const source = 'Normal \uFFFC then code `\uFFFC`';
      final message = ChatMessage(
        id: 'm',
        role: 'user',
        conversationId: 'c',
        content: source,
        quotes: refs,
      );
      final received = <QuoteRef>[];
      final actions = QuoteInteractionController(
        onQuote: (quote) async => received.add(quote),
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      addTearDown(actions.dispose);
      await tester.pumpWidget(
        _app(
          QuoteInteractionScope(
            controller: actions,
            child: AppSelectionArea(
              message: message,
              child: QuoteRenderScope(
                source: source,
                quotes: refs,
                child: const MarkdownWithCodeHighlight(text: source),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect(received.single.text, 'Normal source0 then code source1');
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  for (final source in [
    'First\n\n  second\n\nThird',
    '# Title\n\n\n  second\n\nThird',
    'First\n\n- first\n\n\n- second\n\nThird',
  ]) {
    testWidgets(
      'split paragraph normalization preserves the selected word: $source',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setAssistantBubbleSplitParagraphs(true);
        final received = <QuoteRef>[];
        final actions = QuoteInteractionController(
          onQuote: (quote) async => received.add(quote),
          onJump: (_) async => true,
          sourceExists: (_) async => true,
        );
        addTearDown(actions.dispose);
        addTearDown(settings.dispose);
        final message = ChatMessage(
          id: 'm',
          role: 'assistant',
          conversationId: 'c',
          content: source,
        );
        await tester.pumpWidget(
          _app(
            ChangeNotifierProvider.value(
              value: settings,
              child: QuoteInteractionScope(
                controller: actions,
                child: ChatMessageWidget(
                  message: message,
                  showModelIcon: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paragraph = markdownParagraph(tester, 'second');
        final offset = paragraph.text.toPlainText().indexOf('second');
        Offset point(int index, bool trailing) {
          final box = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: index, extentOffset: index + 1),
              )
              .single;
          return paragraph.localToGlobal(
            Offset(
              trailing ? box.right - 1 : box.left + 1,
              box.toRect().center.dy,
            ),
          );
        }

        final gesture = await tester.startGesture(
          point(offset, false),
          kind: ui.PointerDeviceKind.mouse,
        );
        await gesture.moveTo(point(offset + 5, true));
        await gesture.up();
        await gesture.removePointer();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quote'));
        await tester.pumpAndSettle();
        expect(
          received.single.text,
          source.contains('- second') ? '- second' : 'second',
        );
        expect(
          (received.single.start, received.single.end),
          (source.indexOf('second'), source.indexOf('second') + 6),
        );
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  testWidgets(
    'copy sheet selection after a semantic card maps back to Markdown source',
    (tester) async {
      const source =
          '**Before**\n\n```kelivo-ui\nui 1 catalog "kelivo.native/1"\nroot = Text(text="card")\n```\n\nAfter';
      final message = ChatMessage(
        id: 'm',
        role: 'assistant',
        conversationId: 'c',
        content: source,
      );
      message.hydrateGenerationState(GenerationRunState.completed);
      final received = <QuoteRef>[];
      final actions = QuoteInteractionController(
        onQuote: (quote) async => received.add(quote),
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      addTearDown(actions.dispose);
      await tester.pumpWidget(
        _app(
          QuoteInteractionScope(
            controller: actions,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSelectCopySheet(context, message: message),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final paragraph = renderParagraphs(
        find.byType(AppSelectionArea),
      ).singleWhere((p) => p.text.toPlainText().contains('After'));
      final offset = paragraph.text.toPlainText().indexOf('After');
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          )
          .single;
      await tester.longPressAt(paragraph.localToGlobal(box.toRect().center));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect(received.single.text, 'After');
      expect(
        (received.single.start, received.single.end),
        (source.lastIndexOf('After'), source.length),
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'the second identical paragraph after a tool quotes its own original range',
    (tester) async {
      final received = <QuoteRef>[];
      final actions = QuoteInteractionController(
        onQuote: (quote) async => received.add(quote),
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      addTearDown(actions.dispose);
      final message = ChatMessage(
        id: 'm',
        role: 'assistant',
        conversationId: 'c',
        parts: const [
          TextPart('same text'),
          ToolCallPart(
            '{"id":"t","name":"search","arguments":{},"content":"result"}',
          ),
          TextPart('same text'),
        ],
      );
      await tester.pumpWidget(
        _app(
          QuoteInteractionScope(
            controller: actions,
            child: ChatMessageWidget(message: message, showModelIcon: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final areas = find.byWidgetPredicate(
        (widget) =>
            widget is AppSelectionArea && widget.sourceText == 'same text',
      );
      expect(areas, findsNWidgets(2));
      final second = tester.state<SelectableRegionState>(
        find
            .descendant(of: areas.last, matching: find.byType(SelectableRegion))
            .first,
      );
      second.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect((received.single.start, received.single.end), (9, 18));
      expect(received.single.text, 'same text');
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'a word after multiple visual deletions retains its original source offset',
    (tester) async {
      final received = <QuoteRef>[];
      final actions = QuoteInteractionController(
        onQuote: (quote) async => received.add(quote),
        onJump: (_) async => true,
        sourceExists: (_) async => true,
      );
      addTearDown(actions.dispose);
      final message = ChatMessage(
        id: 'm',
        role: 'assistant',
        conversationId: 'c',
        content: 'PREFIX keep DELETE target',
      );
      await tester.pumpWidget(
        _app(
          QuoteInteractionScope(
            controller: actions,
            child: ChatMessageWidget(message: message, showModelIcon: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = markdownParagraph(tester, 'keep target');
      Offset point(int index, bool trailing) {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: index, extentOffset: index + 1),
            )
            .single;
        return paragraph.localToGlobal(
          Offset(
            trailing ? box.right - 1 : box.left + 1,
            box.toRect().center.dy,
          ),
        );
      }

      final gesture = await tester.startGesture(
        point(5, false),
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.moveTo(point(10, true));
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      expect(received.single.text, 'target');
      expect((received.single.start, received.single.end), (19, 25));
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
