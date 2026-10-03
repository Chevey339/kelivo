import '../../../support/business_test_harness.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

const _messageText = 'alpha bravo charlie';
const _wordSelection = TextSelection(baseOffset: 6, extentOffset: 11);

void main() {
  for (final role in ['user', 'assistant']) {
    testWidgets(
      '$role message supports keyboard copy after double-click and drag selection',
      (tester) async {
        final copied = <String>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await _pumpTimeline(tester, role: role);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == _messageText,
          ),
        );

        await _selectWord(tester, paragraph, doubleClick: true);
        expect(paragraph.selections, contains(_wordSelection));
        await _copySelection(tester);
        expect(copied, ['bravo']);

        // Start a separate gesture after the double-click tracking expires.
        await tester.pump(kDoubleTapTimeout);
        await _selectWord(tester, paragraph, doubleClick: false);
        expect(paragraph.selections, contains(_wordSelection));
        await _copySelection(tester);
        expect(copied, ['bravo', 'bravo']);
      },
      variant: TargetPlatformVariant.desktop(),
    );
  }

  testWidgets(
    'clicking the list background still enables keyboard scroll intent',
    (tester) async {
      var scrollIntents = 0;
      final inputFocus = await _pumpTimeline(
        tester,
        onUserScrollIntent: () => scrollIntents++,
      );
      expect(inputFocus.hasFocus, isTrue);

      // The list's top padding is outside the message selection region.
      await tester.tapAt(
        tester.getTopLeft(find.byType(MessageListView)) + const Offset(4, 4),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(inputFocus.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      expect(scrollIntents, 1);
    },
    variant: TargetPlatformVariant.desktop(),
  );
}

Future<void> _copySelection(WidgetTester tester) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

Future<void> _selectWord(
  WidgetTester tester,
  RenderParagraph paragraph, {
  required bool doubleClick,
}) async {
  final word = paragraph.getBoxesForSelection(_wordSelection).first.toRect();
  final start = paragraph.localToGlobal(
    doubleClick ? word.center : Offset(word.left + 1, word.center.dy),
  );
  final mouse = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
  await tester.pump(const Duration(milliseconds: 16));
  if (doubleClick) {
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.down(start);
  } else {
    await mouse.moveTo(
      paragraph.localToGlobal(Offset(word.right - 1, word.center.dy)),
    );
  }
  await tester.pump(const Duration(milliseconds: 16));
  await mouse.up();
  await tester.pump(const Duration(milliseconds: 16));
  await mouse.removePointer();
}

Future<FocusNode> _pumpTimeline(
  WidgetTester tester, {
  String role = 'assistant',
  VoidCallback? onUserScrollIntent,
}) async {
  final scrollController = ScrollController();
  final listController = ListController();
  final processingFilesMessageId = ValueNotifier<String?>(null);
  final inputFocus = FocusNode();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    scrollController.dispose();
    listController.dispose();
    processingFilesMessageId.dispose();
    inputFocus.dispose();
  });
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: MessageListView(
                  scrollController: scrollController,
                  listController: listController,
                  messages: [
                    ChatMessage(
                      id: 'message-1',
                      role: role,
                      content: _messageText,
                      conversationId: 'conversation-1',
                    ),
                  ],
                  byGroup: const {},
                  versionSelections: const {},
                  reasoning: const {},
                  reasoningSegments: const {},
                  contentSplits: const {},
                  toolParts: const {},
                  translations: const {},
                  selecting: false,
                  selectedItems: const {},
                  dividerPadding: EdgeInsets.zero,
                  processingFilesMessageId: processingFilesMessageId,
                  showModelIcon: false,
                  showUserAvatar: false,
                  onUserScrollIntent: onUserScrollIntent,
                ),
              ),
              TextField(focusNode: inputFocus, autofocus: true),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return inputFocus;
}
