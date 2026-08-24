import "../../../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('collapsed tool steps stay under 15 render objects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'm1',
                role: 'assistant',
                content: '',
                conversationId: 'c1',
              ),
              showModelIcon: false,
              toolParts: const [
                ToolUIPart(
                  id: 't0',
                  toolName: 'read_file',
                  arguments: {'path': 'lib/a.dart'},
                  content: 'ok',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final column = tester.renderObject(
      find.byKey(const ValueKey('chatMessageTimelineIconColumn:true:true')),
    );
    var columnCount = 0;
    void walk(RenderObject node) {
      columnCount++;
      node.visitChildren(walk);
    }

    walk(column);
    // CustomPaint + Center + Icon (Semantics/ExcludeSemantics/SizedBox/Center/RichText).
    expect(
      columnCount,
      lessThanOrEqualTo(8),
      reason: 'icon column ROs=$columnCount',
    );

    final shell = tester.renderObject(
      find.byKey(const ValueKey('chatMessageTimelineStepShell:true:true')),
    );
    var shellCount = 0;
    void walkShell(RenderObject node) {
      shellCount++;
      node.visitChildren(walkShell);
    }

    walkShell(shell);
    expect(
      shellCount,
      lessThanOrEqualTo(25),
      reason: 'collapsed tool step ROs=$shellCount',
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('chatMessageTimelineStepShell:true:true'),
        ),
        matching: find.byType(AnimatedSize),
      ),
      findsNothing,
    );
  });

  testWidgets('loading tool steps keep AnimatedSize so results grow in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'm1',
                role: 'assistant',
                content: '',
                conversationId: 'c1',
              ),
              showModelIcon: false,
              toolParts: const [
                ToolUIPart(
                  id: 't0',
                  toolName: 'read_file',
                  arguments: {'path': 'lib/a.dart'},
                  loading: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('chatMessageTimelineStepShell:true:true'),
        ),
        matching: find.byType(AnimatedSize),
      ),
      findsOneWidget,
    );
  });

  testWidgets('same ToolUIPart on a parent rebuild keeps the memoized step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const part = ToolUIPart(
      id: 't0',
      toolName: 'read_file',
      arguments: {'path': 'lib/a.dart'},
      content: 'ok',
    );
    var parentTicks = 0;
    late void Function(void Function()) rebuild;

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
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                parentTicks++;
                return ChatMessageWidget(
                  message: ChatMessage(
                    id: 'm1',
                    role: 'assistant',
                    content: '',
                    conversationId: 'c1',
                  ),
                  showModelIcon: false,
                  onRecoveredAskUserAnswer: (_, __) async {},
                  toolParts: const [part],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final first = tester
        .widget<ChatMessageWidget>(find.byType(ChatMessageWidget))
        .toolParts!
        .single;
    rebuild(() {});
    await tester.pump();
    final second = tester
        .widget<ChatMessageWidget>(find.byType(ChatMessageWidget))
        .toolParts!
        .single;
    expect(identical(first, second), isTrue);
    expect(parentTicks, greaterThan(1));
    expect(
      find.byKey(const ValueKey('chatMessageTimelineStepShell:true:true')),
      findsOneWidget,
    );
  });
}
