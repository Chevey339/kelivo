import "../../../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugTimelineToolStepBuilds = 0;
  });

  test('timelineToolStepKey namespaces whitespace ids and fallbacks', () {
    expect(
      timelineToolStepKey(id: ' ', sourceOrdinal: 0, toolName: 'search'),
      'tool-fallback:0:search',
    );
    expect(
      timelineToolStepKey(id: '  ', sourceOrdinal: 1, toolName: 'search'),
      'tool-fallback:1:search',
    );
    expect(
      timelineToolStepKey(
        id: 'fallback:0:search',
        sourceOrdinal: 0,
        toolName: 'search',
      ),
      'tool-id:fallback:0:search',
    );
    expect(
      timelineToolStepKey(id: ' ', sourceOrdinal: 0, toolName: 'search'),
      isNot(
        timelineToolStepKey(
          id: 'fallback:0:search',
          sourceOrdinal: 0,
          toolName: 'search',
        ),
      ),
    );
    expect(
      timelineToolStepKey(id: ' ', sourceOrdinal: 0, toolName: 'search'),
      isNot(timelineToolStepKey(id: ' ', sourceOrdinal: 1, toolName: 'search')),
    );
  });

  testWidgets('collapsed tool steps stay under 25 render objects', (
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

  testWidgets('empty tool ids stay unique and stable across collapse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setCollapseThinkingSteps(true);

    final tools = <ToolUIPart>[
      for (var i = 0; i < 4; i++)
        ToolUIPart(
          id: '',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'ok $i',
        ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'empty-ids',
                role: 'assistant',
                content: '',
                conversationId: 'c1',
              ),
              showModelIcon: false,
              toolParts: tools,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final collapsed = _toolKeys(tester);
    expect(collapsed.toSet(), hasLength(collapsed.length));
    expect(collapsed, isNot(contains('tool-')));
    expect(
      collapsed,
      containsAll(<String>[
        timelineToolStepKey(id: '', sourceOrdinal: 2, toolName: 'read_file'),
        timelineToolStepKey(id: '', sourceOrdinal: 3, toolName: 'read_file'),
      ]),
    );

    await tester.tap(find.textContaining('more steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final expanded = _toolKeys(tester);
    expect(expanded.toSet(), hasLength(4));
    expect(expanded, containsAll(collapsed));

    await tester.tap(find.textContaining('Collapse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_toolKeys(tester), collapsed);
  });

  testWidgets('whitespace tool ids stay unique across collapse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setCollapseThinkingSteps(true);

    final tools = <ToolUIPart>[
      for (var i = 0; i < 4; i++)
        ToolUIPart(
          id: ' ',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'ok $i',
        ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'whitespace-ids',
                role: 'assistant',
                content: '',
                conversationId: 'c1',
              ),
              showModelIcon: false,
              toolParts: tools,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final keys = _toolKeys(tester);
    expect(keys.toSet(), hasLength(keys.length));
    expect(keys, isNot(contains('tool-id: ')));
    expect(
      keys,
      containsAll(<String>[
        timelineToolStepKey(id: ' ', sourceOrdinal: 2, toolName: 'read_file'),
        timelineToolStepKey(id: ' ', sourceOrdinal: 3, toolName: 'read_file'),
      ]),
    );
  });

  testWidgets('empty-id tools keep identity across a streaming tick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const part = ToolUIPart(
      id: '',
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
                    id: 'empty-id-stream',
                    role: 'assistant',
                    content: '',
                    conversationId: 'c1',
                    isStreaming: true,
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
    final firstKey = _toolKeys(tester).single;
    rebuild(() {});
    await tester.pump();
    final second = tester
        .widget<ChatMessageWidget>(find.byType(ChatMessageWidget))
        .toolParts!
        .single;
    expect(identical(first, second), isTrue);
    expect(parentTicks, greaterThan(1));
    expect(_toolKeys(tester), [firstKey]);
    expect(
      firstKey,
      timelineToolStepKey(id: '', sourceOrdinal: 0, toolName: 'read_file'),
    );
  });

  testWidgets('reasoning without toggle is not pressable', (tester) async {
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'imported-reasoning',
                role: 'assistant',
                conversationId: 'c1',
                parts: const [ReasoningPart('imported plan')],
              ),
              showModelIcon: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final press = tester.widget<IosCardPress>(
      find.descendant(
        of: find.byKey(
          const ValueKey('chatMessageTimelineStepShell:true:true'),
        ),
        matching: find.byType(IosCardPress),
      ),
    );
    expect(press.onTap, isNull);
    final region = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(IosCardPress).first,
        matching: find.byType(MouseRegion),
      ),
    );
    expect(region.cursor, isNot(SystemMouseCursors.click));
  });

  testWidgets('empty-id tools separated by body keep distinct live tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setShowToolResultSummary(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'multi-empty',
                role: 'assistant',
                conversationId: 'c1',
                parts: const [
                  ToolCallPart(
                    '{"id":"","name":"read_file","arguments":{"path":"a.dart"}}',
                  ),
                  TextPart('middle'),
                  ToolCallPart(
                    '{"id":"","name":"read_file","arguments":{"path":"b.dart"}}',
                  ),
                ],
              ),
              showModelIcon: false,
              toolParts: const [
                ToolUIPart(
                  id: '',
                  toolName: 'read_file',
                  arguments: {'path': 'a.dart'},
                  content: 'LIVE-A',
                ),
                ToolUIPart(
                  id: '',
                  toolName: 'read_file',
                  arguments: {'path': 'b.dart'},
                  content: 'LIVE-B',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('LIVE-A'), findsOneWidget);
    expect(find.textContaining('LIVE-B'), findsOneWidget);
    expect(find.textContaining('middle'), findsOneWidget);
    final keys = _toolKeys(tester);
    expect(keys.toSet(), hasLength(2));
  });

  testWidgets('empty-id builtin_search does not replace a real tool', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setShowToolResultSummary(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'search-empty',
                role: 'assistant',
                conversationId: 'c1',
                parts: const [
                  ToolCallPart(
                    '{"id":"","name":"builtin_search","arguments":{}}',
                  ),
                  ToolCallPart(
                    '{"id":"t1","name":"read_file","arguments":{"path":"a.dart"}}',
                  ),
                ],
              ),
              showModelIcon: false,
              toolParts: const [
                ToolUIPart(
                  id: '',
                  toolName: 'builtin_search',
                  arguments: {},
                  content: 'SEARCH-SHOULD-NOT-SHOW',
                ),
                ToolUIPart(
                  id: 't1',
                  toolName: 'read_file',
                  arguments: {'path': 'a.dart'},
                  content: 'LIVE-FILE',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('SEARCH-SHOULD-NOT-SHOW'), findsNothing);
    expect(find.textContaining('LIVE-FILE'), findsOneWidget);
    expect(_toolKeys(tester), hasLength(1));
  });

  testWidgets('empty-id fallback does not collide with real id read_file-0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setShowToolResultSummary(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                id: 'id-collision',
                role: 'assistant',
                conversationId: 'c1',
                parts: const [
                  ToolCallPart(
                    '{"id":"","name":"read_file","arguments":{"path":"a.dart"}}',
                  ),
                  ToolCallPart(
                    '{"id":"read_file-0","name":"grep","arguments":{"q":"x"}}',
                  ),
                ],
              ),
              showModelIcon: false,
              toolParts: const [
                ToolUIPart(
                  id: 'read_file-0',
                  toolName: 'grep',
                  arguments: {'q': 'x'},
                  content: 'GREP-LIVE',
                ),
                ToolUIPart(
                  id: '',
                  toolName: 'read_file',
                  arguments: {'path': 'a.dart'},
                  content: 'READ-LIVE',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('READ-LIVE'), findsOneWidget);
    expect(find.textContaining('GREP-LIVE'), findsOneWidget);
    final keys = _toolKeys(tester);
    expect(keys.toSet(), hasLength(2));
    expect(keys, contains('tool-id:read_file-0'));
    expect(keys.where((key) => key == 'tool-id:read_file-0'), hasLength(1));
    expect(keys.any((key) => key.startsWith('tool-fallback:')), isTrue);
  });

  testWidgets(
    'unchanged tool steps do not rebuild on a streaming parent tick',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final tools = <ToolUIPart>[
        for (var i = 0; i < 3; i++)
          ToolUIPart(
            id: 't$i',
            toolName: 'read_file',
            arguments: {'path': 'lib/$i.dart'},
            content: 'ok $i',
          ),
      ];
      var content = 'hello';
      late void Function(void Function()) rebuild;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
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
                  return ChatMessageWidget(
                    message: ChatMessage(
                      id: 'm1',
                      role: 'assistant',
                      content: content,
                      conversationId: 'c1',
                    ),
                    showModelIcon: false,
                    toolParts: tools,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final afterFirst = debugTimelineToolStepBuilds;
      expect(afterFirst, 3);

      content = 'hello world';
      rebuild(() {});
      await tester.pump();
      expect(debugTimelineToolStepBuilds, afterFirst);

      tools[1] = ToolUIPart(
        id: 't1',
        toolName: 'read_file',
        arguments: const {'path': 'lib/1.dart'},
        content: 'changed',
      );
      rebuild(() {});
      await tester.pump();
      expect(debugTimelineToolStepBuilds, afterFirst + 1);
    },
  );
}

List<String> _toolKeys(WidgetTester tester) {
  final keys = <String>[];
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('tool-')) {
      keys.add(key.value);
    }
    element.visitChildren(visit);
  }

  tester.element(find.byType(ChatMessageWidget)).visitChildren(visit);
  return keys;
}
