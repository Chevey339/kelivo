import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:mcp_client/mcp_client.dart' as mcp;
import '../../providers/mcp_provider.dart';
import '../../models/conversation.dart';
import '../../models/conversation_mcp_settings.dart';
import '../chat/chat_service.dart';
import '../../providers/assistant_provider.dart';
import '../../../utils/mcp_structured_image.dart';
import '../api/tool_call_cancellation.dart';
import 'mcp_image_snapshot.dart';

typedef _WorkspaceCatalog = ({
  Object? configuration,
  List<McpToolConfig> tools,
});

class _McpToolRoute {
  const _McpToolRoute({
    required this.server,
    required this.tool,
    required this.exposedName,
    this.scope,
    this.configuration,
  });

  final McpServerConfig server;
  final McpToolConfig tool;
  final String exposedName;
  final McpWorkspaceScope? scope;
  final Object? configuration;
}

class McpToolRouteSnapshot {
  McpToolRouteSnapshot._(List<_McpToolRoute> routes)
    : _routes = List.unmodifiable(routes);

  final List<_McpToolRoute> _routes;

  _McpToolRoute? _find(String exposedName) {
    for (final route in _routes) {
      if (route.exposedName == exposedName) return route;
    }
    return null;
  }

  bool containsExposedName(String name) => _find(name) != null;
}

class McpToolService extends ChangeNotifier {
  McpToolService();

  List<McpToolConfig> listAvailableToolsForConversation(
    McpProvider mcpProvider,
    ChatService chat,
    String conversationId,
  ) {
    final selected = chat.getConversationMcpServers(conversationId).toSet();
    return _exposedToolsForRoutes(
      _toolRoutes(
        mcpProvider,
        selected,
        conversation: chat.getConversation(conversationId),
      ),
    );
  }

  List<McpToolConfig> listAvailableToolsForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants,
    String? assistantId, {
    Conversation? conversation,
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) {
    if (routeSnapshot != null) {
      return _exposedToolsForRoutes(routeSnapshot._routes);
    }
    final a = (assistantId != null)
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = ConversationMcpSettings.effectiveServerIds(
      a,
      conversation,
    ).toSet();
    return _exposedToolsForRoutes(
      _toolRoutes(
        mcpProvider,
        selected,
        conversation: conversation,
        reservedNames: reservedNames,
      ),
    );
  }

  Future<mcp.CallToolResult?> callToolForConversation(
    McpProvider mcpProvider,
    ChatService chat, {
    required String conversationId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
  }) async {
    final selected = chat.getConversationMcpServers(conversationId).toSet();
    final routes = await _prepareRoutes(
      mcpProvider,
      selected,
      chat.getConversation(conversationId),
    );
    final route = routes._find(toolName);
    if (route == null) return null;
    return _dispatch(
      mcpProvider,
      route,
      arguments,
      () =>
          _currentRouteForIdentity(
            mcpProvider,
            chat.getConversationMcpServers(conversationId).toSet(),
            route,
            chat.getConversation(conversationId),
          ) !=
          null,
    );
  }

  Future<McpToolResult> callFlattenedToolForConversation(
    McpProvider mcpProvider,
    ChatService chat, {
    required String conversationId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
  }) async {
    final selected = chat.getConversationMcpServers(conversationId).toSet();
    final routes = await _prepareRoutes(
      mcpProvider,
      selected,
      chat.getConversation(conversationId),
    );
    final route = routes._find(toolName);
    if (route == null) return const McpToolResult();
    final res = await _dispatch(
      mcpProvider,
      route,
      arguments,
      () =>
          _currentRouteForIdentity(
            mcpProvider,
            chat.getConversationMcpServers(conversationId).toSet(),
            route,
            chat.getConversation(conversationId),
          ) !=
          null,
    );
    return _renderResult(mcpProvider, route, res);
  }

  Future<String> callToolTextForConversation(
    McpProvider mcpProvider,
    ChatService chat, {
    required String conversationId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
  }) async {
    return (await callFlattenedToolForConversation(
      mcpProvider,
      chat,
      conversationId: conversationId,
      toolName: toolName,
      arguments: arguments,
    )).markdown;
  }

  Future<McpToolResult> callToolForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    Conversation? conversation,
    Conversation? Function()? readConversation,
    void Function()? checkPermission,
    required String? assistantId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) async {
    Conversation? currentChat() =>
        readConversation == null ? conversation : readConversation();
    Set<String> selection(Conversation? chat) =>
        ConversationMcpSettings.effectiveServerIds(
          assistantId == null
              ? assistants.currentAssistant
              : assistants.getById(assistantId),
          chat,
        ).toSet();
    final chat = currentChat();
    final selected = selection(chat);
    final routes =
        routeSnapshot ??
        await _prepareRoutes(
          mcpProvider,
          selected,
          chat,
          reservedNames: reservedNames,
        );
    final published = routes._find(toolName);
    if (published == null) return const McpToolResult();
    _McpToolRoute? current() {
      final latest = currentChat();
      return _currentRouteForIdentity(
        mcpProvider,
        selection(latest),
        published,
        latest,
      );
    }

    final route = current();
    if (route == null) return const McpToolResult();
    final result = await _dispatch(mcpProvider, route, arguments, () {
      ToolCallCancellation.current?.throwIfCancelled();
      checkPermission?.call();
      return current() != null;
    });
    return _renderResult(mcpProvider, route, result);
  }

  Future<mcp.CallToolResult?> _dispatch(
    McpProvider provider,
    _McpToolRoute route,
    Map<String, dynamic> args,
    bool Function() isAllowed,
  ) {
    final scope = route.scope;
    if (scope != null) {
      return provider.callWorkspaceTool(
        scope,
        route.tool,
        args,
        isAllowed: isAllowed,
      );
    }
    if (!isAllowed()) return Future.value(null);
    return provider.callTool(route.server.id, route.tool.name, args);
  }

  Future<McpToolResult> _renderResult(
    McpProvider provider,
    _McpToolRoute route,
    mcp.CallToolResult? result,
  ) async {
    if (result != null) return _flattenToolResult(result);
    return McpToolResult(
      markdown: _renderToolErrorForModel(
        serverName: route.server.name,
        toolName: route.exposedName,
        errorMessage:
            provider.errorFor(route.server.id) ?? 'MCP server is unavailable.',
      ),
    );
  }

  Future<String> callToolTextForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    Conversation? conversation,
    required String? assistantId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) async {
    return (await callToolForAssistant(
      mcpProvider,
      assistants,
      assistantId: assistantId,
      conversation: conversation,
      toolName: toolName,
      arguments: arguments,
      routeSnapshot: routeSnapshot,
      reservedNames: reservedNames,
    )).markdown;
  }

  bool toolNeedsApprovalForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    Conversation? conversation,
    required String? assistantId,
    required String toolName,
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) {
    final assistant = assistantId != null
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = ConversationMcpSettings.effectiveServerIds(
      assistant,
      conversation,
    ).toSet();
    final publishedRoute = routeSnapshot != null
        ? routeSnapshot._find(toolName)
        : _findRoute(
            mcpProvider,
            selected,
            toolName,
            reservedNames: reservedNames,
            conversation: conversation,
          );
    if (publishedRoute == null) return false;
    final route = _currentRouteForIdentity(
      mcpProvider,
      selected,
      publishedRoute,
      conversation,
    );
    return route?.tool.needsApproval ?? true;
  }

  bool isToolEnabledForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    Conversation? conversation,
    required String? assistantId,
    required String toolName,
    required McpToolRouteSnapshot routeSnapshot,
  }) {
    final assistant = assistantId != null
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = ConversationMcpSettings.effectiveServerIds(
      assistant,
      conversation,
    ).toSet();
    final published = routeSnapshot._find(toolName);
    return published != null &&
        _currentRouteForIdentity(
              mcpProvider,
              selected,
              published,
              conversation,
            ) !=
            null;
  }

  McpToolRouteSnapshot captureRoutesForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    Conversation? conversation,
    required String? assistantId,
    Set<String> reservedNames = const {},
  }) {
    final assistant = assistantId != null
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = ConversationMcpSettings.effectiveServerIds(
      assistant,
      conversation,
    ).toSet();
    return McpToolRouteSnapshot._(
      _toolRoutes(
        mcpProvider,
        selected,
        conversation: conversation,
        reservedNames: reservedNames,
      ),
    );
  }

  Future<McpToolRouteSnapshot> prepareRoutesForAssistant(
    McpProvider provider,
    AssistantProvider assistants, {
    required String? assistantId,
    required Conversation? conversation,
    Set<String> reservedNames = const {},
  }) async {
    await Future.wait([provider.loaded, assistants.loaded]);
    final assistant = assistantId == null
        ? assistants.currentAssistant
        : assistants.getById(assistantId);
    return _prepareRoutes(
      provider,
      ConversationMcpSettings.effectiveServerIds(
        assistant,
        conversation,
      ).toSet(),
      conversation,
      reservedNames: reservedNames,
    );
  }

  Future<McpToolRouteSnapshot> _prepareRoutes(
    McpProvider provider,
    Set<String> selected,
    Conversation? conversation, {
    Set<String> reservedNames = const {},
  }) async {
    final catalogs = <String, _WorkspaceCatalog>{};
    if (conversation != null && provider.supportsStdioWorkspaceBinding) {
      final servers = provider.servers
          .where(
            (s) =>
                s.enabled &&
                s.followConversationWorkspace &&
                selected.contains(s.id),
          )
          .toList();
      if (servers.isNotEmpty) await provider.workspaces?.loaded;
      await Future.wait(
        servers.map((server) async {
          final scope = server.scopeFor(conversation)!;
          final version = provider.workspaceConfigurationFor(scope);
          try {
            final tools = await provider.discoverWorkspaceTools(scope);
            catalogs[server.id] = (configuration: version, tools: tools);
          } on StateError {
            // A failed instance has no declarations. Other selected servers
            // can still serve this chat, and its connection retains the error.
          }
        }),
      );
    }
    return McpToolRouteSnapshot._(
      _toolRoutes(
        provider,
        selected,
        conversation: conversation,
        catalogs: catalogs,
        reservedNames: reservedNames,
      ),
    );
  }

  Future<McpToolResult> _flattenToolResult(mcp.CallToolResult res) async {
    final buf = StringBuffer();
    final imageUris = <String>[];
    final seen = <String>{};
    final remoteSnapshots = <String, Future<String?>>{};
    for (final c in res.content) {
      try {
        if (c is mcp.TextContent) {
          _writeEscapedToolText(buf, c.text);
          continue;
        }
        if (c is mcp.ResourceContent) {
          final t = (c.text ?? '').toString();
          if (t.trim().isNotEmpty) {
            _writeEscapedToolText(buf, t);
          } else {
            final uri = (c.uri).toString();
            if (uri.isNotEmpty) {
              _writeEscapedToolText(buf, 'resource: $uri');
            }
          }
          continue;
        }
        if (c is mcp.ImageContent) {
          final data = (c.data ?? '').toString();
          String? uri;
          if (data.isNotEmpty) {
            uri = await McpImageSnapshot.save(data);
          } else {
            final url = (c.url ?? '').toString();
            uri = await remoteSnapshots.putIfAbsent(
              url,
              () => McpImageSnapshot.download(url),
            );
          }
          if (uri != null && uri.isNotEmpty) {
            if (seen.add(uri)) imageUris.add(uri);
            if (buf.isNotEmpty && !_endsWithLineBreak(buf)) buf.writeln();
            buf.writeln('![](${encodeMarkdownImageDestination(uri)})');
          } else {
            _writeEscapedToolText(
              buf,
              '(Image omitted: unavailable, invalid, unsupported, or too large.)',
            );
          }
          continue;
        }
        final dyn = c as dynamic;
        try {
          final txt = (dyn.text as String?);
          if (txt != null && txt.trim().isNotEmpty) {
            _writeEscapedToolText(buf, txt);
            continue;
          }
        } catch (_) {}
        try {
          final uri = (dyn.uri as String?);
          if (uri != null && uri.isNotEmpty) {
            _writeEscapedToolText(buf, 'resource: $uri');
            continue;
          }
        } catch (_) {}
        try {
          final json = (dyn.toJson as dynamic).call();
          _writeEscapedToolText(
            buf,
            const JsonEncoder.withIndent('  ').convert(json),
          );
          continue;
        } catch (_) {}
        final s = c.toString();
        if (!s.startsWith('Instance of')) {
          _writeEscapedToolText(buf, s);
        }
      } catch (_) {
        ToolCallCancellation.current?.throwIfCancelled();
      }
    }
    return McpToolResult(markdown: buf.toString().trim(), imageUris: imageUris);
  }

  void _writeEscapedToolText(StringBuffer buf, String text) {
    final escaped = escapeMcpStructuredImageText(text);
    if (escaped.trim().isNotEmpty) buf.writeln(escaped);
  }

  bool _endsWithLineBreak(StringBuffer buf) {
    if (buf.isEmpty) return false;
    final s = buf.toString();
    final last = s.codeUnitAt(s.length - 1);
    return last == 0x0A || last == 0x0D;
  }

  List<McpToolConfig> _exposedToolsForRoutes(Iterable<_McpToolRoute> routes) {
    return [
      for (final route in routes) route.tool.copyWith(name: route.exposedName),
    ];
  }

  _McpToolRoute? _findRoute(
    McpProvider provider,
    Set<String> selected,
    String exposedName, {
    Conversation? conversation,
    Set<String> reservedNames = const {},
  }) => _toolRoutes(
    provider,
    selected,
    conversation: conversation,
    reservedNames: reservedNames,
  ).where((route) => route.exposedName == exposedName).firstOrNull;

  _McpToolRoute? _currentRouteForIdentity(
    McpProvider provider,
    Set<String> selected,
    _McpToolRoute published,
    Conversation? conversation,
  ) {
    for (final server in provider.servers) {
      if (server.id != published.server.id ||
          !server.enabled ||
          !selected.contains(server.id) ||
          server.followConversationWorkspace != (published.scope != null)) {
        continue;
      }
      final scope = published.scope;
      if (scope != null &&
          (server.scopeFor(conversation) != scope ||
              provider.workspaceConfigurationFor(scope) !=
                  published.configuration)) {
        return null;
      }
      for (final tool in scope == null ? server.declaredTools : server.tools) {
        if (tool.name == published.tool.name && tool.enabled) {
          return _McpToolRoute(
            server: server,
            tool: scope == null
                ? tool
                : published.tool.copyWith(needsApproval: tool.needsApproval),
            exposedName: published.exposedName,
            scope: scope,
            configuration: published.configuration,
          );
        }
      }
    }
    return null;
  }

  List<_McpToolRoute> _toolRoutes(
    McpProvider provider,
    Set<String> selected, {
    Conversation? conversation,
    Map<String, _WorkspaceCatalog>? catalogs,
    Set<String> reservedNames = const {},
  }) {
    final entries =
        <
          ({
            McpServerConfig server,
            McpToolConfig tool,
            McpWorkspaceScope? scope,
          })
        >[];
    for (final server in provider.servers) {
      if (!server.enabled || !selected.contains(server.id)) continue;
      McpWorkspaceScope? scope;
      var tools = server.declaredTools;
      if (server.followConversationWorkspace) {
        scope = server.scopeFor(conversation);
        if (scope == null || !provider.supportsStdioWorkspaceBinding) continue;
        if (catalogs == null) {
          tools = provider.cachedWorkspaceTools(scope);
        } else {
          final catalog = catalogs[server.id];
          if (catalog == null ||
              catalog.configuration !=
                  provider.workspaceConfigurationFor(scope)) {
            continue;
          }
          tools = server.withToolPreferences(catalog.tools);
        }
      }
      for (final tool in tools.where((tool) => tool.enabled)) {
        entries.add((server: server, tool: tool, scope: scope));
      }
    }

    final originalNameCounts = <String, int>{};
    for (final entry in entries) {
      originalNameCounts.update(
        entry.tool.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final usedNames = <String>{...reservedNames};
    for (final entry in entries) {
      if (originalNameCounts[entry.tool.name] == 1 &&
          !reservedNames.contains(entry.tool.name)) {
        usedNames.add(entry.tool.name);
      }
    }
    final routes = <_McpToolRoute>[];
    for (final entry in entries) {
      final conflicted =
          originalNameCounts[entry.tool.name]! > 1 ||
          reservedNames.contains(entry.tool.name);
      final base = conflicted
          ? _qualifiedToolName(entry.server.name, entry.tool.name)
          : entry.tool.name;
      // Pre-seeded unique originals must not suffix as a self-collision.
      if (!conflicted) {
        usedNames.remove(entry.tool.name);
      }
      final uniqueName = _claimUniqueName(base, usedNames, entry.server.id);
      routes.add(
        _McpToolRoute(
          server: entry.server,
          tool: entry.tool,
          exposedName: uniqueName,
          scope: entry.scope,
          configuration: entry.scope == null
              ? null
              : provider.workspaceConfigurationFor(entry.scope!),
        ),
      );
    }
    return routes;
  }

  String _claimUniqueName(String base, Set<String> usedNames, String serverId) {
    final limited = _limitToolName(base);
    if (!usedNames.contains(limited)) {
      usedNames.add(limited);
      return limited;
    }
    final serverSuffixed = _appendToolNameSuffix(
      limited,
      _serverIdSuffix(serverId),
    );
    if (!usedNames.contains(serverSuffixed)) {
      usedNames.add(serverSuffixed);
      return serverSuffixed;
    }
    var counter = 2;
    var candidate = _appendToolNameSuffix(limited, counter.toString());
    while (usedNames.contains(candidate)) {
      counter++;
      candidate = _appendToolNameSuffix(limited, counter.toString());
    }
    usedNames.add(candidate);
    return candidate;
  }

  String _qualifiedToolName(String serverName, String toolName) {
    final server = _sanitizeToolNamePart(serverName, fallback: 'mcp');
    final tool = _sanitizeToolNamePart(toolName, fallback: 'tool');
    var name = '${server}__$tool';
    if (!RegExp(r'^[a-zA-Z_]').hasMatch(name)) name = 'mcp_$name';
    return _limitToolName(name);
  }

  String _sanitizeToolNamePart(String value, {required String fallback}) {
    var sanitized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'^-+'), '');
    sanitized = sanitized.replaceAll(RegExp(r'[_-]+$'), '');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  String _serverIdSuffix(String serverId) {
    final sanitized = _sanitizeToolNamePart(serverId, fallback: 'server');
    return sanitized.length > 8 ? sanitized.substring(0, 8) : sanitized;
  }

  String _appendToolNameSuffix(String name, String suffix) {
    final separatorAndSuffix = '_$suffix';
    final maxBaseLength = 64 - separatorAndSuffix.length;
    final base = name.length > maxBaseLength
        ? name.substring(0, maxBaseLength)
        : name;
    return '$base$separatorAndSuffix';
  }

  String _limitToolName(String name) {
    return name.length > 64 ? name.substring(0, 64) : name;
  }

  String _renderToolErrorForModel({
    required String serverName,
    required String toolName,
    required String errorMessage,
  }) {
    final map = <String, dynamic>{
      'type': 'tool_error',
      'error': 'tool_unavailable',
      'message': errorMessage,
      'tool': toolName,
      'server': serverName,
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
