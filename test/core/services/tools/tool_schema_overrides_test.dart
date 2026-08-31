import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/tool_schema_override.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/core/services/tools/tool_schema_overrides.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  group('ToolSchemaOverrides.apply', () {
    test('overrides top-level and parameter descriptions', () {
      final defs = [SearchToolService.getToolDefinition()];
      final result = ToolSchemaOverrides.apply(defs, {
        SearchToolService.toolName: const ToolSchemaOverride(
          description: 'Custom search description',
          paramDescriptions: {'query': 'Custom query description'},
        ),
      });

      expect(identical(result[0], defs[0]), isFalse);
      final fn = result[0]['function'] as Map;
      expect(fn['description'], 'Custom search description');
      expect(
        (fn['parameters'] as Map)['properties']['query']['description'],
        'Custom query description',
      );
      expect(
        (defs[0]['function'] as Map)['description'],
        SearchToolService.toolDescription,
      );
    });

    test('does not mutate const local tool maps', () {
      final original = LocalToolsService.definitionFor(LocalToolNames.timeInfo);
      final originalDesc =
          (original['function'] as Map)['description'] as String;
      late final List<Map<String, dynamic>> result;
      expect(() {
        result = ToolSchemaOverrides.apply(
          [original],
          {
            LocalToolNames.timeInfo: const ToolSchemaOverride(
              description: 'custom time',
            ),
          },
        );
      }, returnsNormally);

      expect((original['function'] as Map)['description'], originalDesc);
      expect((result[0]['function'] as Map)['description'], 'custom time');
      expect(identical(result[0], original), isFalse);
    });

    test('ignores unknown tool names, unknown paths, and empty strings', () {
      final defs = [SearchToolService.getToolDefinition()];
      final originalDesc =
          (defs[0]['function'] as Map)['description'] as String;
      final originalQuery =
          ((defs[0]['function'] as Map)['parameters']
                  as Map)['properties']['query']['description']
              as String;

      final result = ToolSchemaOverrides.apply(defs, {
        'not_a_real_tool': const ToolSchemaOverride(description: 'nope'),
        SearchToolService.toolName: const ToolSchemaOverride(
          description: '   ',
          paramDescriptions: {'query': '', 'does.not.exist': 'ignored'},
        ),
      });

      expect(identical(result[0], defs[0]), isTrue);
      expect((result[0]['function'] as Map)['description'], originalDesc);
      expect(
        (result[0]['function']
            as Map)['parameters']['properties']['query']['description'],
        originalQuery,
      );
    });

    test('leaves MCP tool names untouched', () {
      final mcp = <String, dynamic>{
        'type': 'function',
        'function': {
          'name': 'echo',
          'description': 'MCP echo',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string', 'description': 'to echo'},
            },
          },
        },
      };
      final defs = [mcp];
      final result = ToolSchemaOverrides.apply(defs, {
        'echo': const ToolSchemaOverride(
          description: 'should not apply',
          paramDescriptions: {'text': 'should not apply'},
        ),
      });

      expect(identical(result[0], mcp), isTrue);
      expect((mcp['function'] as Map)['description'], 'MCP echo');
    });

    test('overrides nested parameter paths such as questions.items.id', () {
      final defs = [LocalToolsService.definitionFor(LocalToolNames.askUser)];
      final result = ToolSchemaOverrides.apply(defs, {
        LocalToolNames.askUser: const ToolSchemaOverride(
          paramDescriptions: {'questions.items.id': 'Stable question id'},
        ),
      });

      final items =
          (result[0]['function']
                  as Map)['parameters']['properties']['questions']['items']
              as Map;
      expect(items['properties']['id']['description'], 'Stable question id');
    });
  });

  group('ToolSchemaOverrides.describeParams', () {
    test('lists nested ask_user paths from the default schema', () {
      final params = ToolSchemaOverrides.describeParams(
        LocalToolsService.definitionFor(LocalToolNames.askUser),
      );
      expect(
        params.map((p) => p.path),
        containsAll(['questions', 'questions.items.id']),
      );
      final id = params.firstWhere((p) => p.path == 'questions.items.id');
      expect(id.type, 'string');
      expect(id.defaultDescription, isNotEmpty);
    });
  });
}
