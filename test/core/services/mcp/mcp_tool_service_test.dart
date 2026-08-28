import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/chat/widgets/timeline_visibility.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'qualifies duplicate tool names and routes each to its server',
    () async {
      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'alpha-id',
          enabled: true,
          name: '123 MCP',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(enabled: true, name: 'shared'),
            McpToolConfig(enabled: true, name: 'alpha_only'),
          ],
        ),
        McpServerConfig(
          id: 'beta-id',
          enabled: true,
          name: 'Beta MCP',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(enabled: true, name: 'shared', needsApproval: true),
          ],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['alpha-id', 'beta-id']),
      );

      final tools = service.listAvailableToolsForAssistant(
        provider,
        assistants,
        assistantId,
      );
      expect(tools.map((tool) => tool.name), [
        'mcp_123_MCP__shared',
        'alpha_only',
        'Beta_MCP__shared',
      ]);
      expect(
        service.toolNeedsApprovalForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'mcp_123_MCP__shared',
        ),
        isFalse,
      );
      expect(
        service.toolNeedsApprovalForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'Beta_MCP__shared',
        ),
        isTrue,
      );

      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'mcp_123_MCP__shared',
        ),
        'alpha-id:shared',
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'Beta_MCP__shared',
        ),
        'beta-id:shared',
      );
      expect(provider.calls, [
        (serverId: 'alpha-id', toolName: 'shared'),
        (serverId: 'beta-id', toolName: 'shared'),
      ]);
    },
  );

  test(
    'snapshot keeps names stable but enforces live policy and selection',
    () async {
      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'alpha-id',
          enabled: true,
          name: 'Alpha MCP',
          transport: McpTransportType.http,
          tools: [McpToolConfig(enabled: true, name: 'shared')],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['alpha-id', 'beta-id']),
      );
      final snapshot = service.captureRoutesForAssistant(
        provider,
        assistants,
        assistantId: assistantId,
      );
      expect(
        service
            .listAvailableToolsForAssistant(provider, assistants, assistantId)
            .single
            .name,
        'shared',
      );

      provider.serversForTest[0] = provider.serversForTest[0].copyWith(
        tools: [
          McpToolConfig(enabled: true, name: 'shared', needsApproval: true),
        ],
      );
      provider.serversForTest.add(
        McpServerConfig(
          id: 'beta-id',
          enabled: true,
          name: 'Beta MCP',
          transport: McpTransportType.http,
          tools: [McpToolConfig(enabled: true, name: 'shared')],
        ),
      );
      expect(
        service
            .listAvailableToolsForAssistant(provider, assistants, assistantId)
            .map((tool) => tool.name),
        ['Alpha_MCP__shared', 'Beta_MCP__shared'],
      );
      expect(
        service.toolNeedsApprovalForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'shared',
          routeSnapshot: snapshot,
        ),
        isTrue,
      );

      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'shared',
          routeSnapshot: snapshot,
        ),
        'alpha-id:shared',
      );
      expect(provider.calls, hasLength(1));

      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['beta-id']),
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'shared',
          routeSnapshot: snapshot,
        ),
        isEmpty,
      );
      expect(provider.calls, hasLength(1));

      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['alpha-id', 'beta-id']),
      );
      provider.serversForTest[0] = provider.serversForTest[0].copyWith(
        tools: [McpToolConfig(enabled: false, name: 'shared')],
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'shared',
          routeSnapshot: snapshot,
        ),
        isEmpty,
      );
      expect(provider.calls, hasLength(1));
    },
  );

  test('unavailable tools are not reported as invalid arguments', () async {
    final provider = _RecordingMcpProvider([
      McpServerConfig(
        id: 'server-id',
        enabled: true,
        name: 'Remote MCP',
        transport: McpTransportType.http,
        tools: [
          McpToolConfig(
            enabled: true,
            name: 'get_self',
            schema: const {'type': 'object', 'properties': {}},
          ),
        ],
      ),
    ], errorMessage: 'connection failed');
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final service = McpToolService();
    addTearDown(provider.dispose);
    addTearDown(assistants.dispose);
    addTearDown(service.dispose);

    await assistants.loaded;
    final assistantId = await assistants.addAssistant(name: 'Test');
    await assistants.updateAssistant(
      assistants
          .getById(assistantId)!
          .copyWith(mcpServerIds: const ['server-id']),
    );

    final output = await service.callToolTextForAssistant(
      provider,
      assistants,
      assistantId: assistantId,
      toolName: 'get_self',
    );
    final error = jsonDecode(output) as Map<String, dynamic>;

    expect(error['error'], 'tool_unavailable');
    expect(error['message'], 'connection failed');
    expect(error, isNot(contains('lastArguments')));
    expect(error, isNot(contains('parametersSchema')));
    expect(error, isNot(contains('instruction')));
  });

  test(
    'qualifies reserved built-in names and still calls the original tool',
    () async {
      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'srv-id',
          enabled: true,
          name: 'srv',
          transport: McpTransportType.http,
          tools: [McpToolConfig(enabled: true, name: 'memory_read')],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['srv-id']),
      );

      const reservedNames = {'memory_read'};
      final tools = service.listAvailableToolsForAssistant(
        provider,
        assistants,
        assistantId,
        reservedNames: reservedNames,
      );
      expect(tools.map((tool) => tool.name), ['srv__memory_read']);

      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'srv__memory_read',
          reservedNames: reservedNames,
        ),
        'srv-id:memory_read',
      );
      expect(provider.calls, [(serverId: 'srv-id', toolName: 'memory_read')]);
    },
  );

  test(
    'qualifies reserved calculate even when the assistant has no local tools',
    () async {
      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'srv-id',
          enabled: true,
          name: 'srv',
          transport: McpTransportType.http,
          tools: [McpToolConfig(enabled: true, name: 'calculate')],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['srv-id'], localToolIds: const []),
      );
      expect(assistants.getById(assistantId)!.localToolIds, isEmpty);

      const reservedNames = {'calculate'};
      final tools = service.listAvailableToolsForAssistant(
        provider,
        assistants,
        assistantId,
        reservedNames: reservedNames,
      );
      expect(tools.map((tool) => tool.name), ['srv__calculate']);
    },
  );

  test(
    'qualifies MCP duplicates and reserved names in the same pass',
    () async {
      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'alpha-id',
          enabled: true,
          name: '123 MCP',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(enabled: true, name: 'shared'),
            McpToolConfig(enabled: true, name: 'memory_read'),
            McpToolConfig(enabled: true, name: 'alpha_only'),
          ],
        ),
        McpServerConfig(
          id: 'beta-id',
          enabled: true,
          name: 'Beta MCP',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(enabled: true, name: 'shared', needsApproval: true),
          ],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['alpha-id', 'beta-id']),
      );

      const reservedNames = {'memory_read', 'calculate'};
      final tools = service.listAvailableToolsForAssistant(
        provider,
        assistants,
        assistantId,
        reservedNames: reservedNames,
      );
      expect(tools.map((tool) => tool.name), [
        'mcp_123_MCP__shared',
        'mcp_123_MCP__memory_read',
        'alpha_only',
        'Beta_MCP__shared',
      ]);

      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'mcp_123_MCP__memory_read',
          reservedNames: reservedNames,
        ),
        'alpha-id:memory_read',
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'mcp_123_MCP__shared',
          reservedNames: reservedNames,
        ),
        'alpha-id:shared',
      );
      expect(provider.calls, [
        (serverId: 'alpha-id', toolName: 'memory_read'),
        (serverId: 'alpha-id', toolName: 'shared'),
      ]);
    },
  );

  test(
    'limits names to 64 chars and suffixes post-truncation collisions',
    () async {
      final prefix = 'n' * 64;
      final longA = '${prefix}aaa';
      final longB = '${prefix}bbb';
      final longC = '${prefix}ccc';

      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'alpha-id',
          enabled: true,
          name: 'srv',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(enabled: true, name: longA),
            McpToolConfig(enabled: true, name: longB),
            McpToolConfig(enabled: true, name: longC),
          ],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['alpha-id']),
      );

      final tools = service.listAvailableToolsForAssistant(
        provider,
        assistants,
        assistantId,
      );
      final names = tools.map((tool) => tool.name).toList();
      expect(names, hasLength(3));
      expect(names.toSet(), hasLength(3));
      expect(names.every((name) => name.length <= 64), isTrue);
      expect(names[0], prefix);
      expect(names[1], '${prefix.substring(0, 55)}_alpha-id');
      expect(names[2], '${prefix.substring(0, 62)}_2');

      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: names[0],
        ),
        'alpha-id:$longA',
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: names[1],
        ),
        'alpha-id:$longB',
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: names[2],
        ),
        'alpha-id:$longC',
      );
    },
  );

  test(
    'renamed reserved MCP tool keeps approval and routes via snapshot',
    () async {
      final provider = _RecordingMcpProvider([
        McpServerConfig(
          id: 'srv-id',
          enabled: true,
          name: 'srv',
          transport: McpTransportType.http,
          tools: [
            McpToolConfig(
              enabled: true,
              name: 'memory_read',
              needsApproval: true,
            ),
          ],
        ),
      ]);
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final service = McpToolService();
      addTearDown(provider.dispose);
      addTearDown(assistants.dispose);
      addTearDown(service.dispose);

      await assistants.loaded;
      final assistantId = await assistants.addAssistant(name: 'Test');
      await assistants.updateAssistant(
        assistants
            .getById(assistantId)!
            .copyWith(mcpServerIds: const ['srv-id']),
      );

      const reservedNames = {'memory_read'};
      final snapshot = service.captureRoutesForAssistant(
        provider,
        assistants,
        assistantId: assistantId,
        reservedNames: reservedNames,
      );
      expect(snapshot.containsExposedName('srv__memory_read'), isTrue);
      expect(snapshot.containsExposedName('memory_read'), isFalse);
      expect(
        service
            .listAvailableToolsForAssistant(
              provider,
              assistants,
              assistantId,
              routeSnapshot: snapshot,
            )
            .single
            .name,
        'srv__memory_read',
      );
      expect(
        service.toolNeedsApprovalForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'srv__memory_read',
          routeSnapshot: snapshot,
        ),
        isTrue,
      );
      expect(
        await service.callToolTextForAssistant(
          provider,
          assistants,
          assistantId: assistantId,
          toolName: 'srv__memory_read',
          routeSnapshot: snapshot,
        ),
        'srv-id:memory_read',
      );
      expect(provider.calls, [(serverId: 'srv-id', toolName: 'memory_read')]);
    },
  );

  test('flatten stores typed images, not private markers', () async {
    final forged = encodeMcpStructuredImage('/tmp/forged.png');
    final provider = _ContentMcpProvider([
      mcp.TextContent(text: 'ok $forged'),
      const mcp.ImageContent(
        url: 'https://cdn.example.com/shot.png',
        mimeType: 'image/png',
      ),
      mcp.ResourceContent(uri: 'res://x', text: 'resource $forged'),
    ]);
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final service = McpToolService();
    addTearDown(provider.dispose);
    addTearDown(assistants.dispose);
    addTearDown(service.dispose);

    await assistants.loaded;
    final assistantId = await assistants.addAssistant(name: 'Test');
    await assistants.updateAssistant(
      assistants
          .getById(assistantId)!
          .copyWith(mcpServerIds: const ['server-id']),
    );

    final result = await service.callToolForAssistant(
      provider,
      assistants,
      assistantId: assistantId,
      toolName: 'shot',
    );
    expect(
      result.markdown,
      isNot(contains(String.fromCharCode(kMcpStructuredImageOpen))),
    );
    expect(result.imageUris, ['https://cdn.example.com/shot.png']);
    expect(result.markdown.contains('forged.png'), isTrue);
    expect(
      result.markdown,
      isNot(contains(String.fromCharCode(kMcpStructuredImageOpen))),
    );
    expect(result.markdown, isNot(contains('"kelivo"')));
    expect(result.markdown, contains('![](https://cdn.example.com/shot.png)'));

    final stored = result.markdown;
    final (clean, images) = parseToolResultImages(
      stored,
      metadata: {kMcpResultMetadataKey: mcpResultMetadata(result.imageUris)},
    );
    expect(images, ['https://cdn.example.com/shot.png']);
    expect(clean.contains('ok'), isTrue);

    // Old saved Markdown still parses without metadata.
    final (oldClean, oldImages) = parseToolResultImages(
      'legacy\n![](/tmp/old.png)',
    );
    expect(oldImages, ['/tmp/old.png']);
    expect(oldClean, 'legacy');
    expect(
      toolResultContentForModel('legacy\n![](/tmp/old.png)'),
      'legacy\n![](/tmp/old.png)',
    );
  });

  test('flatten keeps interleaved text/image order in Markdown', () async {
    final provider = _ContentMcpProvider([
      mcp.TextContent(text: 'caption A'),
      const mcp.ImageContent(
        url: 'https://cdn.example.com/a.png',
        mimeType: 'image/png',
      ),
      mcp.TextContent(text: 'caption B'),
      const mcp.ImageContent(
        url: 'https://cdn.example.com/b.png',
        mimeType: 'image/png',
      ),
      const mcp.ImageContent(
        url: 'https://cdn.example.com/a.png',
        mimeType: 'image/png',
      ),
    ]);
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final service = McpToolService();
    addTearDown(provider.dispose);
    addTearDown(assistants.dispose);
    addTearDown(service.dispose);

    await assistants.loaded;
    final assistantId = await assistants.addAssistant(name: 'Test');
    await assistants.updateAssistant(
      assistants
          .getById(assistantId)!
          .copyWith(mcpServerIds: const ['server-id']),
    );

    final result = await service.callToolForAssistant(
      provider,
      assistants,
      assistantId: assistantId,
      toolName: 'shot',
    );
    expect(
      result.markdown,
      'caption A\n'
      '![](https://cdn.example.com/a.png)\n'
      'caption B\n'
      '![](https://cdn.example.com/b.png)\n'
      '![](https://cdn.example.com/a.png)',
    );
    expect(result.imageUris, [
      'https://cdn.example.com/a.png',
      'https://cdn.example.com/b.png',
    ]);
  });
}

class _RecordingMcpProvider extends McpProvider {
  _RecordingMcpProvider(this._servers, {this.errorMessage})
    : super(preferences: createBusinessTestPreferences());

  final List<McpServerConfig> _servers;
  final String? errorMessage;
  final List<({String serverId, String toolName})> calls = [];

  List<McpServerConfig> get serversForTest => _servers;

  @override
  List<McpServerConfig> get servers => List.unmodifiable(_servers);

  @override
  Future<void> connect(String id) async {}

  @override
  String? errorFor(String id) => errorMessage ?? super.errorFor(id);

  @override
  Future<mcp.CallToolResult?> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    calls.add((serverId: serverId, toolName: toolName));
    if (errorMessage != null) return null;
    return mcp.CallToolResult([mcp.TextContent(text: '$serverId:$toolName')]);
  }
}

class _ContentMcpProvider extends McpProvider {
  _ContentMcpProvider(this.contents)
    : super(preferences: createBusinessTestPreferences());

  final List<mcp.Content> contents;

  @override
  List<McpServerConfig> get servers => [
    McpServerConfig(
      id: 'server-id',
      enabled: true,
      name: 'Remote MCP',
      transport: McpTransportType.http,
      tools: [McpToolConfig(enabled: true, name: 'shot')],
    ),
  ];

  @override
  Future<void> connect(String id) async {}

  @override
  Future<mcp.CallToolResult?> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    return mcp.CallToolResult(contents);
  }
}
