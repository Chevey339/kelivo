import 'dart:convert';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
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

import '../../../support/business_test_harness.dart';

void main() {
  for (final interleaved in [false, true]) {
    testWidgets(
      'long ${interleaved ? 'interleaved' : 'contiguous'} tool transcript recycles cards and keeps reading position',
      (tester) async {
        final count = interleaved ? 600 : 5000;
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setCollapseThinkingSteps(false);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        addTearDown(settings.dispose);
        final timelineStorage = PageStorageBucket();
        var generation = 0;
        final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
        final parts = <MessagePart>[
          for (var i = 0; i < count; i++) ...[
            ToolCallPart(
              jsonEncode({
                'id': 't$i',
                'name': 'mcp_read_file',
                'content': 'done',
              }),
            ),
            if (interleaved) TextPart('Explanation $i'),
          ],
          const TextPart('tail'),
        ];
        var snapshot = builder.update(parts);
        late StateSetter update;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return SingleChildScrollView(
                      controller: controller,
                      child: ChatMessageWidget(
                        key: ValueKey(generation),
                        timelineStorage: timelineStorage,
                        message: ChatMessage(
                          id: 'long',
                          role: 'assistant',
                          conversationId: 'c',
                          parts: snapshot,
                          isStreaming: true,
                        ),
                        toolParts: ToolPartSnapshot(const []),
                        showModelIcon: false,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        Future<void> frames() async {
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }

        Finder cards() => find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith('tool-id:'),
        );
        await frames();
        expect(cards().evaluate().length, lessThan(150));
        expect(cards().evaluate(), isNotEmpty);
        controller.jumpTo(controller.position.maxScrollExtent);
        await frames();
        // Extent estimates converge as the final blocks are measured.
        controller.jumpTo(controller.position.maxScrollExtent);
        await frames();
        expect(find.byKey(ValueKey('tool-id:t${count - 1}')), findsOneWidget);
        expect(cards().evaluate().length, lessThan(150));
        controller.jumpTo(controller.position.maxScrollExtent / 2);
        await frames();
        final readingOffset = controller.offset;
        parts[parts.length - 1] = const TextPart('tail with more output');
        snapshot = builder.update(parts, changed: {parts.length - 1});
        update(() {});
        await frames();
        expect(controller.offset, moreOrLessEquals(readingOffset, epsilon: 1));
        expect(cards().evaluate().length, lessThan(150));

        final measuredExtent = controller.position.maxScrollExtent;
        update(() => generation++);
        await frames();
        expect(controller.offset, moreOrLessEquals(readingOffset, epsilon: 1));
        expect(
          controller.position.maxScrollExtent,
          moreOrLessEquals(measuredExtent, epsilon: 1),
        );
        expect(cards().evaluate().length, lessThan(150));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
