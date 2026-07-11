import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('per-assistant search behavior', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp(
        'kelivo_assistant_search_test_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('injects search prompt only when the assistant enables search', () {
      final service = MessageBuilderService(
        chatService: ChatService(),
        contextProvider: _FakeBuildContext(),
      );

      final disabledMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'latest news'},
      ];
      service.injectSearchPrompt(
        disabledMessages,
        SettingsProvider(),
        const Assistant(id: 'assistant-a', name: 'A'),
        false,
      );

      final enabledMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'latest news'},
      ];
      service.injectSearchPrompt(
        enabledMessages,
        SettingsProvider(),
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
      final settings = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AssistantProvider>(
              create: (_) => AssistantProvider(),
            ),
            ChangeNotifierProvider<McpProvider>(create: (_) => McpProvider()),
            ChangeNotifierProvider<McpToolService>(
              create: (_) => McpToolService(),
            ),
          ],
          child: const SizedBox.shrink(),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final service = ToolHandlerService(contextProvider: context);
      late List<Map<String, dynamic>> disabledTools;
      late List<Map<String, dynamic>> enabledTools;
      await tester.runAsync(() async {
        disabledTools = await service.buildToolDefinitions(
          settings,
          const Assistant(id: 'assistant-a', name: 'A'),
          'openai',
          'gpt-4.1',
          false,
          isToolModel: (_, _) => true,
        );
        enabledTools = await service.buildToolDefinitions(
          settings,
          const Assistant(id: 'assistant-b', name: 'B', searchEnabled: true),
          'openai',
          'gpt-4.1',
          false,
          isToolModel: (_, _) => true,
        );
      });

      expect(disabledTools, isEmpty);
      expect(enabledTools.map((tool) => tool['function']['name']), [
        SearchToolService.toolName,
      ]);
    });
  });
}
