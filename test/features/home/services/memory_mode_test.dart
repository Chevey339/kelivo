import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Cuplivo/core/models/assistant.dart';
import 'package:Cuplivo/core/providers/assistant_provider.dart';
import 'package:Cuplivo/core/providers/mcp_provider.dart';
import 'package:Cuplivo/core/providers/memory_provider.dart';
import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Cuplivo/features/home/services/tool_handler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Memory mode', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('assistant defaults to injection memory mode', () {
      final assistant = Assistant(id: 'a1', name: 'Assistant');
      expect(assistant.memoryMode, 'injection');
    });

    test('assistant json round trips injection mode', () {
      final assistant = Assistant(
        id: 'a1',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'injection',
      );
      final decoded = Assistant.fromJson(assistant.toJson());
      expect(decoded.memoryMode, 'injection');
    });

    test('assistant json round trips tool mode', () {
      final assistant = Assistant(
        id: 'a1',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'tool',
      );
      final decoded = Assistant.fromJson(assistant.toJson());
      expect(decoded.memoryMode, 'tool');
    });

    test('assistant json missing memoryMode defaults to injection', () {
      final decoded = Assistant.fromJson(const {
        'id': 'a1',
        'name': 'Assistant',
      });
      expect(decoded.memoryMode, 'injection');
    });

    test('assistant copyWith preserves memoryMode', () {
      final a = Assistant(id: 'a1', name: 'Assistant', memoryMode: 'tool');
      final b = a.copyWith(enableMemory: true);
      expect(b.memoryMode, 'tool');
    });

    testWidgets('tool definitions include read_memory only in tool mode', (
      tester,
    ) async {
      final assistantInjection = Assistant(
        id: 'a1',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'injection',
      );
      final assistantTool = Assistant(
        id: 'a2',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'tool',
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final service = ToolHandlerService(contextProvider: context);

      final injectionDefs = service.buildToolDefinitions(
        SettingsProvider(),
        assistantInjection,
        'openai',
        'gpt-4',
        false,
        isToolModel: (_, __) => true,
      );

      final toolDefs = service.buildToolDefinitions(
        SettingsProvider(),
        assistantTool,
        'openai',
        'gpt-4',
        false,
        isToolModel: (_, __) => true,
      );

      final injectionNames = injectionDefs
          .map((d) => (d['function'] as Map)['name'] as String)
          .toSet();
      final toolNames = toolDefs
          .map((d) => (d['function'] as Map)['name'] as String)
          .toSet();

      expect(injectionNames, contains('create_memory'));
      expect(injectionNames, contains('edit_memory'));
      expect(injectionNames, contains('delete_memory'));
      expect(injectionNames, isNot(contains('read_memory')));

      expect(toolNames, contains('create_memory'));
      expect(toolNames, contains('edit_memory'));
      expect(toolNames, contains('delete_memory'));
      expect(toolNames, contains('read_memory'));
    });

    testWidgets('create_memory returns XML record with id and content', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'assistant-create',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'injection',
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final handler = ToolHandlerService(
        contextProvider: context,
      ).buildToolCallHandler(SettingsProvider(), assistant)!;

      final result = await handler('create_memory', {
        'content': 'user likes cats',
      });

      expect(result, startsWith('<record>'));
      expect(result, contains('<id>'));
      expect(result, contains('<content>user likes cats</content>'));
      expect(result, endsWith('</record>'));
      final idMatch = RegExp(r'<id>(\d+)</id>').firstMatch(result);
      expect(idMatch, isNotNull);
      expect(int.parse(idMatch!.group(1)!), greaterThan(0));
    });

    testWidgets('edit_memory also returns XML record', (tester) async {
      final assistant = Assistant(
        id: 'assistant-edit',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'injection',
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final memoryProvider = context.read<MemoryProvider>();
      final memory = await memoryProvider.add(
        assistantId: assistant.id,
        content: 'old content',
      );

      final handler = ToolHandlerService(
        contextProvider: context,
      ).buildToolCallHandler(SettingsProvider(), assistant)!;

      final result = await handler('edit_memory', {
        'id': memory.id,
        'content': 'updated content',
      });

      expect(result, startsWith('<record>'));
      expect(result, contains('<id>${memory.id}</id>'));
      expect(result, contains('<content>updated content</content>'));
      expect(result, endsWith('</record>'));
    });

    testWidgets('no memory tools when memory disabled', (tester) async {
      final assistant = Assistant(
        id: 'a-no-mem',
        name: 'Assistant',
        enableMemory: false,
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final service = ToolHandlerService(contextProvider: context);

      final defs = service.buildToolDefinitions(
        SettingsProvider(),
        assistant,
        'openai',
        'gpt-4',
        false,
        isToolModel: (_, __) => true,
      );

      final names = defs
          .map((d) => (d['function'] as Map)['name'] as String)
          .toSet();
      expect(names, isNot(contains('create_memory')));
      expect(names, isNot(contains('edit_memory')));
      expect(names, isNot(contains('delete_memory')));
      expect(names, isNot(contains('read_memory')));
    });

    testWidgets('unknown memoryMode treated as injection in tool definitions', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'a-unknown',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'unknown',
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final service = ToolHandlerService(contextProvider: context);

      final defs = service.buildToolDefinitions(
        SettingsProvider(),
        assistant,
        'openai',
        'gpt-4',
        false,
        isToolModel: (_, __) => true,
      );

      final names = defs
          .map((d) => (d['function'] as Map)['name'] as String)
          .toSet();
      expect(names, contains('create_memory'));
      expect(names, contains('edit_memory'));
      expect(names, contains('delete_memory'));
      expect(names, isNot(contains('read_memory')));
    });

    testWidgets('read_memory returns memories for the assistant', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'tool',
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final memoryProvider = context.read<MemoryProvider>();
      await memoryProvider.add(
        assistantId: assistant.id,
        content: 'user likes cats',
      );
      await memoryProvider.add(
        assistantId: assistant.id,
        content: 'user works at Acme',
      );

      final handler = ToolHandlerService(
        contextProvider: context,
      ).buildToolCallHandler(SettingsProvider(), assistant)!;

      final result = await handler('read_memory', {});

      expect(result, contains('<id>'));
      expect(result, contains('user likes cats'));
      expect(result, contains('user works at Acme'));
    });

    testWidgets('read_memory returns empty when no memories exist', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'assistant-b',
        name: 'Assistant',
        enableMemory: true,
        memoryMode: 'tool',
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          child: Builder(
            builder: (context) {
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final handler = ToolHandlerService(
        contextProvider: context,
      ).buildToolCallHandler(SettingsProvider(), assistant)!;

      final result = await handler('read_memory', {});

      expect(result, '<memories>\n</memories>\n');
    });
  });
}

class _ToolHandlerTestScope extends StatelessWidget {
  const _ToolHandlerTestScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(),
        ),
        ChangeNotifierProvider<McpProvider>(create: (_) => McpProvider()),
        ChangeNotifierProvider<McpToolService>(create: (_) => McpToolService()),
        ChangeNotifierProvider<MemoryProvider>(create: (_) => MemoryProvider()),
      ],
      child: child,
    );
  }
}
