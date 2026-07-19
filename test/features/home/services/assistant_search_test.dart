import "../../../support/business_test_harness.dart";
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('per-assistant search behavior', () {
    test('injects search prompt only when the assistant enables search', () {
      SharedPreferences.setMockInitialValues({});
      final service = MessageBuilderService(
        chatService: ChatService(),
        contextProvider: _FakeBuildContext(),
      );

      final disabledMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'latest news'},
      ];
      service.injectSearchPrompt(
        disabledMessages,
        SettingsProvider(createBusinessTestPreferences()),
        const Assistant(id: 'assistant-a', name: 'A'),
        false,
      );

      final enabledMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'latest news'},
      ];
      service.injectSearchPrompt(
        enabledMessages,
        SettingsProvider(createBusinessTestPreferences()),
        const Assistant(id: 'assistant-b', name: 'B', searchEnabled: true),
        false,
      );

      expect(disabledMessages.length, 1);
      expect(enabledMessages.first['role'], 'system');
      expect(
        (enabledMessages.first['content'] as String),
        contains(SearchToolService.toolName),
      );
    });

    testWidgets('builds search tool only when the assistant enables search', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(createBusinessTestPreferences());

      late List<Map<String, dynamic>> disabledTools;
      late List<Map<String, dynamic>> enabledTools;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AssistantProvider>(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider<McpProvider>(
              create: (_) =>
                  McpProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<McpToolService>(
              create: (_) => McpToolService(),
            ),
          ],
          child: Builder(
            builder: (context) {
              final service = ToolHandlerService(contextProvider: context);
              disabledTools = service.buildToolDefinitions(
                settings,
                const Assistant(id: 'assistant-a', name: 'A'),
                'openai',
                'gpt-4.1',
                false,
                isToolModel: (_, _) => true,
              );
              enabledTools = service.buildToolDefinitions(
                settings,
                const Assistant(
                  id: 'assistant-b',
                  name: 'B',
                  searchEnabled: true,
                ),
                'openai',
                'gpt-4.1',
                false,
                isToolModel: (_, _) => true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(disabledTools, isEmpty);
      expect(enabledTools.map((tool) => tool['function']['name']), [
        SearchToolService.toolName,
      ]);
    });
  });
}
