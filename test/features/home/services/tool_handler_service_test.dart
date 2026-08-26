import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolHandlerService tool schema sanitization', () {
    for (final kind in const [ProviderKind.openai, ProviderKind.claude]) {
      test('preserves and sanitizes additionalProperties for $kind', () {
        final input = <String, dynamic>{
          'type': 'object',
          'additionalProperties': true,
          'properties': {
            'config': {
              'type': 'object',
              'additionalProperties': {
                r'$schema': 'https://json-schema.org/draft/2020-12/schema',
                'type': 'string',
                'const': 'enabled',
              },
            },
            'entries': {
              'type': 'array',
              'items': {'type': 'object', 'additionalProperties': false},
            },
          },
        };

        final output = ToolHandlerService.sanitizeToolParametersForProvider(
          input,
          kind,
        );

        expect(output['additionalProperties'], isTrue);
        final properties = output['properties'] as Map<String, dynamic>;
        expect(
          (properties['config'] as Map)['additionalProperties'],
          <String, dynamic>{
            'type': 'string',
            'enum': ['enabled'],
          },
        );
        expect(
          ((properties['entries'] as Map)['items']
              as Map)['additionalProperties'],
          isFalse,
        );
      });
    }

    test('inlines local \$ref targets so nested objects survive', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        r'$defs': {
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
              'text': {'type': 'string'},
            },
            'required': ['post', 'text'],
          },
        },
        'properties': {
          'action': {'type': 'string'},
          'payload': {r'$ref': r'#/$defs/Payload'},
        },
        'required': ['action', 'payload'],
      }, ProviderKind.openai);

      final payload = output['properties']['payload'] as Map<String, dynamic>;
      expect(payload['type'], 'object');
      expect((payload['properties'] as Map).keys.toSet(), {'post', 'text'});
      expect(payload['required'], ['post', 'text']);
      expect(output, isNot(contains(r'$defs')));
    });

    test('keeps a sibling description after inlining a \$ref', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        r'$defs': {
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
            },
          },
        },
        'properties': {
          'payload': {r'$ref': r'#/$defs/Payload', 'description': 'the body'},
        },
      }, ProviderKind.openai);

      expect(output['properties']['payload'], {
        'type': 'object',
        'description': 'the body',
        'properties': {
          'post': {'type': 'integer'},
        },
      });
    });

    test('passes an unresolvable \$ref through without inventing a type', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        'properties': {
          'remote': {
            r'$ref': 'https://example.com/s.json',
            'description': 'kept',
          },
          'dangling': {r'$ref': r'#/$defs/Missing'},
          'anchor': {r'$ref': '#Payload'},
        },
      }, ProviderKind.openai);

      final props = output['properties'] as Map<String, dynamic>;
      expect(props['remote'], {'description': 'kept'});
      expect(props['dangling'], isEmpty);
      expect(props['anchor'], isEmpty);
    });

    test('cuts a recursive \$ref without inventing a type', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        r'$defs': {
          'Node': {
            'type': 'object',
            'properties': {
              'child': {r'$ref': r'#/$defs/Node'},
            },
          },
        },
        'properties': {
          'root': {r'$ref': r'#/$defs/Node'},
        },
      }, ProviderKind.openai);

      var node = output['properties']['root'] as Map<String, dynamic>;
      expect(node['type'], 'object');
      var depth = 0;
      while (node['properties'] is Map &&
          (node['properties'] as Map)['child'] is Map &&
          ((node['properties'] as Map)['child'] as Map).isNotEmpty) {
        node = (node['properties'] as Map)['child'] as Map<String, dynamic>;
        depth++;
        if (depth > 40) break;
      }
      expect(depth, lessThan(40));
    });

    test('keeps a parameter that is named like a schema keyword', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        r'$defs': {
          'Tag': {'type': 'string'},
        },
        'properties': {
          'definitions': {'type': 'string', 'description': 'a real parameter'},
          r'$defs': {'type': 'integer'},
          'tag': {r'$ref': r'#/$defs/Tag'},
        },
        'required': ['definitions'],
      }, ProviderKind.openai);

      final props = output['properties'] as Map<String, dynamic>;
      expect(props.keys.toSet(), {'definitions', r'$defs', 'tag'});
      expect(props['definitions'], {
        'type': 'string',
        'description': 'a real parameter',
      });
      expect(props['tag'], {'type': 'string'});
      expect(output, isNot(contains(r'$defs')));
    });

    test(
      'does not advertise a boolean property from a \$ref to true or false',
      () {
        for (final kind in const [ProviderKind.google, ProviderKind.openai]) {
          final output = ToolHandlerService.sanitizeToolParametersForProvider({
            'type': 'object',
            r'$defs': {'Denied': false, 'Anything': true},
            'properties': {
              'blocked': {r'$ref': r'#/$defs/Denied'},
              'ok': {r'$ref': r'#/$defs/Anything', 'description': 'all values'},
            },
          }, kind);

          final props = output['properties'] as Map<String, dynamic>;
          expect(props['blocked'], isA<Map>());
          expect(props['blocked'], isNot(isTrue));
          expect(props['blocked'], isNot(isFalse));
          expect(props['ok'], isA<Map>());
          expect(props['ok'], isNot(isTrue));
          expect(props['ok'], isNot(isFalse));
          expect(props['ok']['description'], 'all values');
        }
      },
    );

    test('tuple-form items fan-out still advertises a later payload', () {
      Map<String, dynamic> fanout(String next) => {
        'type': 'object',
        'properties': {
          for (var i = 0; i < 10; i++) 'f$i': {r'$ref': '#/\$defs/$next'},
        },
      };

      final schema = <String, dynamic>{
        r'$defs': {
          'A': fanout('B'),
          'B': fanout('C'),
          'C': fanout('D'),
          'D': fanout('E'),
          'E': {'type': 'string'},
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
              'text': {'type': 'string'},
            },
          },
        },
        'type': 'object',
        'properties': {
          'early': {
            'type': 'array',
            'items': [
              {'type': 'string'},
              {r'$ref': r'#/$defs/A'},
            ],
          },
          'payload': {r'$ref': r'#/$defs/Payload'},
        },
      };

      for (final kind in ProviderKind.values) {
        final output = ToolHandlerService.sanitizeToolParametersForProvider(
          schema,
          kind,
        );
        final payload = output['properties']['payload'] as Map<String, dynamic>;
        expect(payload['type'], 'object', reason: '$kind');
        expect((payload['properties'] as Map).keys.toSet(), {
          'post',
          'text',
        }, reason: '$kind');
        expect((output['properties']['early'] as Map)['items'], {
          'type': 'string',
        });
      }
    });

    test(
      'Google additionalProperties fan-out still advertises payload fields',
      () {
        Map<String, dynamic> fanout(String next) => {
          'type': 'object',
          'properties': {
            for (var i = 0; i < 10; i++) 'f$i': {r'$ref': '#/\$defs/$next'},
          },
        };

        final schema = <String, dynamic>{
          r'$defs': {
            'A': fanout('B'),
            'B': fanout('C'),
            'C': fanout('D'),
            'D': fanout('E'),
            'E': {'type': 'string'},
            'Payload': {
              'type': 'object',
              'properties': {
                'post': {'type': 'integer'},
                'text': {'type': 'string'},
              },
            },
          },
          'type': 'object',
          'additionalProperties': {r'$ref': r'#/$defs/A'},
          'properties': {
            'payload': {r'$ref': r'#/$defs/Payload'},
          },
        };

        final google = ToolHandlerService.sanitizeToolParametersForProvider(
          schema,
          ProviderKind.google,
        );
        expect(google, isNot(contains('additionalProperties')));
        final googlePayload =
            google['properties']['payload'] as Map<String, dynamic>;
        expect(googlePayload['type'], 'object');
        expect((googlePayload['properties'] as Map).keys.toSet(), {
          'post',
          'text',
        });

        for (final kind in const [ProviderKind.openai, ProviderKind.claude]) {
          final output = ToolHandlerService.sanitizeToolParametersForProvider(
            schema,
            kind,
          );
          final extra = output['additionalProperties'] as Map;
          expect(extra['type'], 'object', reason: '$kind');
          expect(extra.containsKey(r'$ref'), isFalse, reason: '$kind');
        }
      },
    );

    test('continues to drop additionalProperties for Google', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        'additionalProperties': true,
        'properties': {
          'config': {'type': 'object', 'additionalProperties': true},
        },
      }, ProviderKind.google);

      expect(output, isNot(contains('additionalProperties')));
      expect(
        output['properties']['config'],
        isNot(contains('additionalProperties')),
      );
    });
  });

  group('ToolHandlerService MCP approval identity', () {
    testWidgets('requestApproval uses the provider toolCallId for MCP tools', (
      tester,
    ) async {
      final mcpProvider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'srv-id',
          enabled: true,
          name: 'Test MCP',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(enabled: true, name: 'echo', needsApproval: true),
          ],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final toolSvc = McpToolService();
      final settings = SettingsProvider(createBusinessTestPreferences());
      final approval = ToolApprovalService();
      addTearDown(mcpProvider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(toolSvc.dispose);
      addTearDown(settings.dispose);
      addTearDown(approval.dispose);

      await assistants.loaded;
      await settings.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['srv-id']),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
            ChangeNotifierProvider<McpProvider>.value(value: mcpProvider),
            ChangeNotifierProvider<McpToolService>.value(value: toolSvc),
          ],
          child: const SizedBox.shrink(),
        ),
      );

      final service = ToolHandlerService(
        contextProvider: tester.element(find.byType(SizedBox)),
      );
      final handler = service.buildToolCallHandler(
        settings,
        assistants.getById(assistantId),
        approvalService: approval,
        conversationId: 'conv-1',
      );
      expect(handler, isNotNull);

      final future = handler!('echo', <String, dynamic>{
        'city': 'Seattle',
      }, toolCallId: 'provider-call-99');
      await tester.pump();

      final pending = approval.pendingFor(
        toolCallId: 'provider-call-99',
        conversationId: 'conv-1',
      );
      expect(pending, isNotNull);
      expect(pending!.toolName, 'echo');
      expect(pending.conversationId, 'conv-1');
      expect(mcpProvider.calls, isEmpty);

      approval.approve('provider-call-99', conversationId: 'conv-1');
      final result = await future;
      expect(result, isA<McpToolResult>());
      expect((result as McpToolResult).markdown, 'srv-id:echo');
      expect(mcpProvider.calls, [(serverId: 'srv-id', toolName: 'echo')]);
    });
  });
}

class _RecordingMcpProvider extends McpProvider {
  _RecordingMcpProvider(this._servers)
    : super(preferences: createBusinessTestPreferences());

  final List<McpServerConfig> _servers;
  final List<({String serverId, String toolName})> calls = [];

  @override
  List<McpServerConfig> get servers => List.unmodifiable(_servers);

  @override
  Future<void> connect(String id) async {}

  @override
  Future<mcp.CallToolResult?> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    calls.add((serverId: serverId, toolName: toolName));
    return mcp.CallToolResult([mcp.TextContent(text: '$serverId:$toolName')]);
  }
}
