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

      expect(result, contains('<content>new memory</content>'));
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

  group('ToolHandlerService.sanitizeToolParametersForProvider', () {
    group('OpenAI / Claude', () {
      for (final kind in const [ProviderKind.openai, ProviderKind.claude]) {
        test(
          'preserves additionalProperties (top-level and nested) for $kind',
          () {
            final out = ToolHandlerService.sanitizeToolParametersForProvider(
              _sampleSchema(),
              kind,
            );

            expect(
              out['additionalProperties'],
              isTrue,
              reason: 'top-level additionalProperties must survive',
            );

            final props = out['properties'] as Map<String, dynamic>;
            expect(props.keys, containsAll(<String>['config', 'items']));

            final config = props['config'] as Map<String, dynamic>;
            expect(config['additionalProperties'], isTrue);
            expect((config['properties'] as Map).containsKey('name'), isTrue);

            final arrItem =
                (props['items'] as Map)['items'] as Map<String, dynamic>;
            expect(arrItem['additionalProperties'], isTrue);
            expect((arrItem['properties'] as Map).containsKey('id'), isTrue);

            expect(out.containsKey(r'$schema'), isFalse);
            expect(out['type'], 'object');
            expect(out['required'], ['config']);
          },
        );
      }

      test(
        'preserves a subschema-valued additionalProperties and sanitizes it',
        () {
          final schema = {
            'type': 'object',
            'additionalProperties': {
              r'$schema': 'should-be-removed',
              'type': 'string',
              'const': 'x',
            },
          };

          final out = ToolHandlerService.sanitizeToolParametersForProvider(
            schema,
            ProviderKind.openai,
          );

          final ap = out['additionalProperties'] as Map<String, dynamic>;
          expect(ap.containsKey(r'$schema'), isFalse);
          expect(ap['type'], 'string');
          expect(ap['enum'], ['x']);
        },
      );

      test('does not mutate the input schema (deep clone)', () {
        final input = _sampleSchema();
        ToolHandlerService.sanitizeToolParametersForProvider(
          input,
          ProviderKind.openai,
        );
        expect(input.containsKey(r'$schema'), isTrue);
        expect(input['additionalProperties'], isTrue);
      });
    });

    group('Google / Gemini', () {
      test('drops additionalProperties because Gemini rejects it', () {
        final out = ToolHandlerService.sanitizeToolParametersForProvider(
          _sampleSchema(),
          ProviderKind.google,
        );

        expect(out.containsKey('additionalProperties'), isFalse);

        final props = out['properties'] as Map<String, dynamic>;
        expect(props.keys, containsAll(<String>['config', 'items']));
        expect(
          (props['config'] as Map).containsKey('additionalProperties'),
          isFalse,
        );
        expect((props['config'] as Map)['properties'], isA<Map>());
      });
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

/// Builds a sample JSON Schema with open/free-form object params.
Map<String, dynamic> _sampleSchema() => {
  r'$schema': 'http://json-schema.org/draft-07/schema#',
  'type': 'object',
  'description': 'MCP tool params',
  'additionalProperties': true,
  'required': ['config'],
  'properties': {
    'config': {
      'type': 'object',
      'description': 'Free-form config bag',
      'additionalProperties': true,
      'properties': {
        'name': {'type': 'string'},
      },
    },
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': true,
        'properties': {
          'id': {'type': 'string'},
        },
      },
    },
  },
};
