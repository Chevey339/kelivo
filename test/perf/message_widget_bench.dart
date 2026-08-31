import "../support/business_test_harness.dart";

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

String _payload(int items) {
  final b = StringBuffer('{"items":[');
  for (var i = 0; i < items; i++) {
    if (i > 0) b.write(',');
    b.write(
      '{"id":"$i","index":"${i + 1}","title":"结果 $i","url":"https://e.com/$i",'
      '"text":"这是搜索结果摘要，长度大约一两百字符，用于模拟真实负载。$i"}',
    );
  }
  b.write(']}');
  return b.toString();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final cfg in const <(String, int, bool, int)>[
    ('0', 0, false, 0),
    ('10-plain', 10, false, 0),
    ('30-plain', 30, false, 0),
    ('60-plain', 60, false, 0),
    ('30-search8', 30, true, 8),
    ('30-search30', 30, true, 30),
  ]) {
    testWidgets('rebuild ${cfg.$1}', (tester) async {
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final tools = <ToolUIPart>[
        for (var i = 0; i < cfg.$2; i++)
          ToolUIPart(
            id: 't$i',
            toolName: cfg.$3 ? 'search_web' : 'read_file',
            arguments: {'path': 'lib/x_$i.dart', 'query': 'q$i'},
            content: cfg.$3 ? _payload(cfg.$4) : '结果 $i',
            loading: false,
          ),
      ];

      final key = GlobalKey<_HState>();
      await tester.pumpWidget(_H(key: key, tools: tools));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        key.currentState!.bump();
        await tester.pump();
      }

      final sw = Stopwatch()..start();
      const n = 40;
      for (var i = 0; i < n; i++) {
        key.currentState!.bump();
        await tester.pump();
      }
      sw.stop();
      var ro = 0;
      void visit(RenderObject r) {
        ro++;
        r.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(ChatMessageWidget)));
      var el = 0;
      void visitE(Element e) {
        el++;
        e.visitChildren(visitE);
      }

      tester.element(find.byType(ChatMessageWidget)).visitChildren(visitE);
      // ignore: avoid_print
      print(
        'RESULT ${cfg.$1} rebuildMs=${(sw.elapsedMicroseconds / n / 1000).toStringAsFixed(2)} renderObjects=$ro elements=$el',
      );
    });
  }
}

class _H extends StatefulWidget {
  const _H({super.key, required this.tools});
  final List<ToolUIPart> tools;
  @override
  State<_H> createState() => _HState();
}

class _HState extends State<_H> {
  int n = 0;
  void bump() => setState(() => n++);

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
          body: SingleChildScrollView(
            child: ChatMessageWidget(
              message: ChatMessage(
                id: 'm1',
                role: 'assistant',
                content: '正在处理$n',
                conversationId: 'c1',
                isStreaming: true,
              ),
              toolParts: widget.tools,
            ),
          ),
        ),
      ),
    );
  }
}
