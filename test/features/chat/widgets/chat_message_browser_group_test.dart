import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/browser/widgets/browser_page_card.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

ToolCallPart browserPart(
  String id, {
  bool loading = false,
  String? image,
}) => ToolCallPart(
  jsonEncode({
    'id': id,
    'name': LocalToolNames.browser,
    'arguments': {'action': 'open', 'url': 'https://example.com'},
    if (!loading)
      'content':
          '${jsonEncode({
            'ok': true,
            'page': {'tab_id': 'tab-1', 'url': 'https://example.com', 'title': 'Page $id'},
          })}${image == null ? '' : '\n![]($image)'}',
  }),
);
void main() {
  late SettingsProvider settings;
  late ToolApprovalService approval;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    approval = ToolApprovalService();
  });
  Future<void> pump(
    WidgetTester tester,
    List<MessagePart> parts, {
    bool streaming = false,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: approval),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageWidget(
                message: ChatMessage(
                  id: 'message',
                  conversationId: 'chat',
                  role: 'assistant',
                  parts: parts,
                  isStreaming: streaming,
                ),
                showModelIcon: false,
                showTokenStats: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'four browser calls become one group regardless of summary setting',
    (tester) async {
      await tester.runAsync(() => settings.setShowToolResultSummary(false));
      await pump(tester, [for (var i = 0; i < 4; i++) browserPart('call-$i')]);
      expect(find.text('Browsing'), findsOneWidget);
      expect(find.text('4 steps'), findsOneWidget);
      expect(find.byType(BrowserPageCard), findsOneWidget);
      expect(find.text('Browser control'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reasoning separates groups and only last has a full card', (
    tester,
  ) async {
    await tester.runAsync(() => settings.setCollapseThinkingSteps(false));
    await pump(tester, [
      browserPart('a'),
      const ReasoningPart('Check another page'),
      browserPart('b'),
    ]);
    final cards = tester
        .widgetList<BrowserPageCard>(find.byType(BrowserPageCard))
        .toList();
    expect(cards, hasLength(2));
    expect(cards.first.lite, isTrue);
    expect(cards.last.lite, isFalse);
    await tester.tap(find.text('Browsing').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('browser-step-a')), findsOneWidget);
    expect(find.byType(BrowserPageCard), findsNWidgets(2));
    expect(tester.getSize(find.byType(BrowserPageCard).first).height, 36);
    expect(find.byKey(const ValueKey('browser-actions-toggle')), findsNothing);
  });
  testWidgets('pending browser approval stays separate and actionable', (
    tester,
  ) async {
    await tester.runAsync(() => settings.setCollapseThinkingSteps(false));
    final decision = approval.requestApproval(
      toolCallId: 'pending',
      toolName: LocalToolNames.browser,
      arguments: const {'action': 'click'},
      conversationId: 'chat',
    );
    await pump(tester, [
      browserPart('a'),
      browserPart('pending', loading: true),
      browserPart('b'),
    ], streaming: true);
    expect(find.byType(BrowserPageCard), findsNWidgets(2));
    expect(find.bySemanticsLabel('Approve'), findsOneWidget);
    expect(find.bySemanticsLabel('Deny'), findsOneWidget);
    approval.approve('pending', conversationId: 'chat');
    await decision;
    await tester.pump();
    expect(find.byType(BrowserPageCard), findsOneWidget);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets(
    'group expansion survives streaming append and a trailing reasoning step',
    (tester) async {
      await tester.runAsync(() => settings.setCollapseThinkingSteps(false));
      await pump(tester, [browserPart('a')]);
      await tester.tap(find.text('Browsing'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is KeyedSubtree &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'browser-step-',
              ),
        ),
        findsOneWidget,
      );
      await pump(tester, [
        browserPart('a'),
        browserPart('b'),
        const ReasoningPart('Done'),
      ]);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is KeyedSubtree &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'browser-step-',
              ),
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'image visibility setting hides tool screenshots but keeps page card',
    (tester) async {
      const image =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      await tester.runAsync(() => settings.setHideToolResultImages(true));
      await pump(tester, [browserPart('image', image: image)]);
      await tester.tap(find.text('Browsing'));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserPageCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tool-image-thumbnails:image')),
        findsNothing,
      );
      await tester.runAsync(() => settings.setHideToolResultImages(false));
      await tester.pump();
      expect(find.byType(BrowserPageCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tool-image-thumbnails:image')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('an approval arriving after grouping exposes its own buttons', (
    tester,
  ) async {
    await tester.runAsync(() => settings.setCollapseThinkingSteps(false));
    await pump(tester, [
      browserPart('a'),
      browserPart('later', loading: true),
      browserPart('c'),
    ]);
    expect(find.byType(BrowserPageCard), findsOneWidget);
    final decision = approval.requestApproval(
      toolCallId: 'later',
      toolName: LocalToolNames.browser,
      arguments: const {'action': 'click'},
      conversationId: 'chat',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BrowserPageCard), findsNWidgets(2));
    expect(find.bySemanticsLabel('Approve'), findsOneWidget);
    approval.approve('later', conversationId: 'chat');
    await decision;
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
