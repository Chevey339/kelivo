import "../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart'
    as scroll_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<ToolUIPart> _tools(int n) => <ToolUIPart>[
  for (var i = 0; i < n; i++)
    ToolUIPart(
      id: 'tool-$i',
      toolName: 'read_file',
      arguments: {'path': 'lib/foo/bar_$i.dart'},
      content: '工具返回的普通文本结果 $i',
      loading: false,
    ),
];

int _countElements(WidgetTester tester) {
  var n = 0;
  void visit(Element e) {
    n++;
    e.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  return n;
}

int _countRenderObjects(WidgetTester tester) {
  var n = 0;
  void visit(RenderObject r) {
    n++;
    r.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return n;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final cfg in const <(int, int)>[(40, 0), (40, 4), (40, 12)]) {
    final rounds = cfg.$1;
    final perTurn = cfg.$2;
    testWidgets('scroll rounds=$rounds tools=$perTurn', (tester) async {
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey<_HState>();
      await tester.pumpWidget(_H(key: key, rounds: rounds, perTurn: perTurn));
      await tester.pump(const Duration(milliseconds: 100));
      final state = key.currentState!;

      final elements = _countElements(tester);
      final renders = _countRenderObjects(tester);

      // Root rebuild (what a HomePage setState costs).
      final rb = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        state.bump();
        await tester.pump();
      }
      rb.stop();

      // Scroll from bottom to top in ~40 steps.
      final pos = state.scrollController.position;
      final total = pos.maxScrollExtent;
      final sc = Stopwatch()..start();
      var frames = 0;
      final worst = <int>[];
      for (var i = 0; i < 40; i++) {
        final f = Stopwatch()..start();
        pos.jumpTo((total * (1 - i / 40)).clamp(0.0, total));
        await tester.pump();
        f.stop();
        worst.add(f.elapsedMicroseconds);
        frames++;
      }
      sc.stop();
      worst.sort();
      // Walk the whole list slowly so every item gets measured.
      var corrections = 0;
      var prev = pos.maxScrollExtent;
      for (var i = 0; i <= 200; i++) {
        pos.jumpTo(
          (pos.maxScrollExtent * (i / 200)).clamp(0.0, pos.maxScrollExtent),
        );
        await tester.pump();
        if ((pos.maxScrollExtent - prev).abs() > 1) corrections++;
        prev = pos.maxScrollExtent;
      }
      final measuredExtent = pos.maxScrollExtent;

      // ignore: avoid_print
      print(
        'RESULT rounds=$rounds tools=$perTurn elements=$elements renders=$renders '
        'estExtent=${total.toStringAsFixed(0)} measuredExtent=${measuredExtent.toStringAsFixed(0)} '
        'extentCorrections=$corrections '
        'rootRebuildMs=${(rb.elapsedMicroseconds / 20 / 1000).toStringAsFixed(2)} '
        'scrollAvgMs=${(sc.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)} '
        'scrollP90Ms=${(worst[(frames * 0.9).floor()] / 1000).toStringAsFixed(2)} '
        'scrollMaxMs=${(worst.last / 1000).toStringAsFixed(2)}',
      );
    });
  }
}

class _H extends StatefulWidget {
  const _H({super.key, required this.rounds, required this.perTurn});
  final int rounds;
  final int perTurn;

  @override
  State<_H> createState() => _HState();
}

class _HState extends State<_H> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  late final scroll_ctrl.ChatScrollController scrollCtrl;
  final processingFilesMessageId = ValueNotifier<String?>(null);
  int tick = 0;

  late final List<ChatMessage> messages = <ChatMessage>[
    for (var i = 0; i < widget.rounds * 2; i++)
      ChatMessage(
        id: 'm-$i',
        role: i.isEven ? 'user' : 'assistant',
        content: i.isEven ? '用户提问 $i' : '好的，我来看看。',
        conversationId: 'c1',
      ),
  ];

  late final Map<String, List<ToolUIPart>> toolParts = {
    for (var i = 1; i < widget.rounds * 2; i += 2)
      'm-$i': _tools(widget.perTurn),
  };

  @override
  void initState() {
    super.initState();
    scrollCtrl = scroll_ctrl.ChatScrollController(
      scrollController: scrollController,
      onStateChanged: () {},
      getAutoScrollEnabled: () => false,
      getAutoScrollIdleSeconds: () => 3,
      isGenerating: () => false,
    );
  }

  void bump() => setState(() => tick++);

  @override
  void dispose() {
    scrollCtrl.dispose();
    scrollController.dispose();
    processingFilesMessageId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
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
          body: MessageListView(
            key: ValueKey(tick == -1),
            scrollController: scrollController,
            listController: scrollCtrl.messageListController,
            messages: messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const {},
            reasoningSegments: const {},
            contentSplits: const {},
            toolParts: toolParts,
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            processingFilesMessageId: processingFilesMessageId,
          ),
        ),
      ),
    );
  }
}
