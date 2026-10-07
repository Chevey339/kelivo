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
import 'package:Kelivo/core/services/search/web_fetch_service.dart';
import 'package:Kelivo/core/services/search/web_fetch_tool_service.dart';
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

    testWidgets('builds web tools only when the assistant enables search', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(createBusinessTestPreferences());
      final fetchOffSettings = SettingsProvider(
        createBusinessTestPreferences(),
      );
      await Future.wait([settings.loaded, fetchOffSettings.loaded]);
      await fetchOffSettings.setWebFetchMode(WebFetchMode.off);
      final nativeCases = [
        (
          id: 'native-claude',
          kind: ProviderKind.claude,
          url: 'https://api.anthropic.com',
          model: 'claude-sonnet-4-5-20250929',
          tool: 'web_fetch',
          native: true,
        ),
        (
          id: 'relay-claude',
          kind: ProviderKind.claude,
          url: 'https://relay.example.com',
          model: 'claude-sonnet-4-5-20250929',
          tool: 'web_fetch',
          native: false,
        ),
        (
          id: 'router',
          kind: ProviderKind.openai,
          url: 'https://openrouter.ai/api/v1',
          model: 'anthropic/claude-sonnet-4.5',
          tool: 'web_fetch',
          native: true,
        ),
        (
          id: 'google',
          kind: ProviderKind.google,
          url: 'https://generativelanguage.googleapis.com',
          model: 'gemini-3-pro',
          tool: 'url_context',
          native: true,
        ),
      ];
      for (final entry in nativeCases) {
        await settings.setProviderConfig(
          entry.id,
          ProviderConfig(
            id: entry.id,
            enabled: true,
            name: entry.id,
            apiKey: 'key',
            baseUrl: entry.url,
            providerType: entry.kind,
            modelOverrides: {
              entry.model: {
                'builtInTools': [entry.tool],
              },
            },
          ),
        );
      }
      const searchAssistant = Assistant(
        id: 'assistant-b',
        name: 'B',
        searchEnabled: true,
      );

      late List<Map<String, dynamic>> disabledTools;
      late List<Map<String, dynamic>> enabledTools;
      late List<Map<String, dynamic>> fetchOffTools;
      final nativeTools = <String, List<Map<String, dynamic>>>{};
      late List<Map<String, dynamic>> builtInSearchTools;
      late List<Map<String, dynamic>> unsupportedTools;
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
                searchAssistant,
                'openai',
                'gpt-4.1',
                false,
                isToolModel: (_, _) => true,
              );
              fetchOffTools = service.buildToolDefinitions(
                fetchOffSettings,
                searchAssistant,
                'openai',
                'gpt-4.1',
                false,
                isToolModel: (_, _) => true,
              );
              for (final entry in nativeCases) {
                nativeTools[entry.id] = service.buildToolDefinitions(
                  settings,
                  searchAssistant,
                  entry.id,
                  entry.model,
                  false,
                  isToolModel: (_, _) => true,
                );
              }
              builtInSearchTools = service.buildToolDefinitions(
                settings,
                searchAssistant,
                'openai',
                'gpt-4.1',
                true,
                isToolModel: (_, _) => true,
              );
              unsupportedTools = service.buildToolDefinitions(
                settings,
                searchAssistant,
                'openai',
                'gpt-4.1',
                false,
                isToolModel: (_, _) => false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(disabledTools, isEmpty);
      expect(enabledTools.map((tool) => tool['function']['name']), [
        SearchToolService.toolName,
        WebFetchToolService.toolName,
      ]);
      expect(fetchOffTools.map((tool) => tool['function']['name']), [
        SearchToolService.toolName,
      ]);
      expect(builtInSearchTools, isEmpty);
      expect(unsupportedTools, isEmpty);
      for (final entry in nativeCases) {
        expect(nativeTools[entry.id]!.map((tool) => tool['function']['name']), [
          SearchToolService.toolName,
          if (!entry.native) WebFetchToolService.toolName,
        ], reason: entry.id);
      }
    });
  });
}
