import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Cuplivo/core/models/assistant.dart';
import 'package:Cuplivo/core/models/assistant_memory.dart';
import 'package:Cuplivo/core/providers/assistant_provider.dart';
import 'package:Cuplivo/core/providers/mcp_provider.dart';
import 'package:Cuplivo/core/providers/memory_provider.dart';
import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Cuplivo/features/home/services/tool_handler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolHandlerService memory tools', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('edit_memory returns updated content when id exists', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
      );

      late String result;
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
        content: 'old memory',
      );
      final handler = ToolHandlerService(
        contextProvider: context,
      ).buildToolCallHandler(SettingsProvider(), assistant)!;

      result = await handler('edit_memory', {
        'id': memory.id,
        'content': 'new memory',
      });

      expect(result, 'new memory');
    });

    testWidgets('edit_memory returns tool error when id does not exist', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
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

      final result = await handler('edit_memory', {
        'id': 410,
        'content': 'new memory',
      });

      final payload = jsonDecode(result) as Map<String, dynamic>;
      expect(payload['type'], 'tool_error');
      expect(payload['error'], 'memory_not_found');
      expect(payload['tool'], 'edit_memory');
      expect(payload['message'], contains('410'));
    });

    testWidgets('edit_memory returns tool error when update throws', (
      tester,
    ) async {
      final assistant = Assistant(
        id: 'assistant-a',
        name: 'Assistant',
        enableMemory: true,
      );

      await tester.pumpWidget(
        _ToolHandlerTestScope(
          memoryProvider: _ThrowingMemoryProvider(),
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

      final result = await handler('edit_memory', {
        'id': 410,
        'content': 'new memory',
      });

      final payload = jsonDecode(result) as Map<String, dynamic>;
      expect(payload['type'], 'tool_error');
      expect(payload['error'], 'memory_execution_error');
      expect(payload['tool'], 'edit_memory');
      expect(payload['message'], contains('storage offline'));
    });
  });
}

class _ToolHandlerTestScope extends StatelessWidget {
  const _ToolHandlerTestScope({required this.child, this.memoryProvider});

  final Widget child;
  final MemoryProvider? memoryProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(),
        ),
        ChangeNotifierProvider<McpProvider>(create: (_) => McpProvider()),
        ChangeNotifierProvider<McpToolService>(create: (_) => McpToolService()),
        ChangeNotifierProvider<MemoryProvider>(
          create: (_) => memoryProvider ?? MemoryProvider(),
        ),
      ],
      child: child,
    );
  }
}

class _ThrowingMemoryProvider extends MemoryProvider {
  @override
  Future<AssistantMemory?> update({required int id, required String content}) {
    throw StateError('storage offline');
  }
}
