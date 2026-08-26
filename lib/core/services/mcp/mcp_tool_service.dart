import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:mcp_client/mcp_client.dart' as mcp;
import '../../providers/mcp_provider.dart';
import '../chat/chat_service.dart';
import '../../providers/assistant_provider.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../../utils/sandbox_path_resolver.dart';

class _McpToolRoute {
  const _McpToolRoute({
    required this.server,
    required this.tool,
    required this.exposedName,
  });

  final McpServerConfig server;
  final McpToolConfig tool;
  final String exposedName;
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
    return _exposedTools(mcpProvider, selected);
  }

  List<McpToolConfig> listAvailableToolsForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants,
    String? assistantId, {
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) {
    if (routeSnapshot != null) {
      return _exposedToolsForRoutes(routeSnapshot._routes);
    }
    final a = (assistantId != null)
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = (a?.mcpServerIds ?? const <String>[]).toSet();
    return _exposedTools(mcpProvider, selected, reservedNames: reservedNames);
  }

  Future<mcp.CallToolResult?> callToolForConversation(
    McpProvider mcpProvider,
    ChatService chat, {
    required String conversationId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
  }) async {
    final selected = chat.getConversationMcpServers(conversationId).toSet();
    if (selected.isEmpty) return null;

    final route = _findRoute(mcpProvider, selected, toolName);
    if (route == null) return null;
    return mcpProvider.callTool(route.server.id, route.tool.name, arguments);
  }

  Future<McpToolResult> callFlattenedToolForConversation(
    McpProvider mcpProvider,
    ChatService chat, {
    required String conversationId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
  }) async {
    final selected = chat.getConversationMcpServers(conversationId).toSet();
    final route = _findRoute(mcpProvider, selected, toolName);
    final res = route == null
        ? null
        : await mcpProvider.callTool(
            route.server.id,
            route.tool.name,
            arguments,
          );
    if (res == null) {
      if (route != null) {
        final errMsg =
            mcpProvider.errorFor(route.server.id) ??
            'MCP server is unavailable.';
        return McpToolResult(
          markdown: _renderToolErrorForModel(
            serverName: route.server.name,
            toolName: toolName,
            errorMessage: errMsg,
          ),
        );
      }
      return const McpToolResult();
    }
    return _flattenToolResult(res);
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
    required String? assistantId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) async {
    // try servers selected for the assistant
    final a = (assistantId != null)
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = (a?.mcpServerIds ?? const <String>[]).toSet();
    // debugPrint('[MCP/Call/Select] assistant=${assistantId ?? a?.id ?? '(current)'} tool=$toolName selectedServers=${selected.join(',')}');
    if (selected.isEmpty) return const McpToolResult();
    final routes =
        routeSnapshot?._routes ??
        _toolRoutes(mcpProvider, selected, reservedNames: reservedNames);
    for (final publishedRoute in routes) {
      final has = publishedRoute.exposedName == toolName;
      if (has) {
        final route = _currentRouteForIdentity(
          mcpProvider,
          selected,
          publishedRoute,
        );
        if (route == null) return const McpToolResult();
        final s = route.server;
        final res = await mcpProvider.callTool(
          s.id,
          route.tool.name,
          arguments,
        );
        if (res == null) {
          final errMsg =
              mcpProvider.errorFor(s.id) ?? 'MCP server is unavailable.';
          return McpToolResult(
            markdown: _renderToolErrorForModel(
              serverName: s.name,
              toolName: toolName,
              errorMessage: errMsg,
            ),
          );
        }
        return _flattenToolResult(res);
      }
    }
    return const McpToolResult();
  }

  Future<String> callToolTextForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
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
      toolName: toolName,
      arguments: arguments,
      routeSnapshot: routeSnapshot,
      reservedNames: reservedNames,
    )).markdown;
  }

  bool toolNeedsApprovalForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    required String? assistantId,
    required String toolName,
    McpToolRouteSnapshot? routeSnapshot,
    Set<String> reservedNames = const {},
  }) {
    final assistant = assistantId != null
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = (assistant?.mcpServerIds ?? const <String>[]).toSet();
    final publishedRoute = routeSnapshot != null
        ? routeSnapshot._find(toolName)
        : _findRoute(
            mcpProvider,
            selected,
            toolName,
            reservedNames: reservedNames,
          );
    if (publishedRoute == null) return false;
    final route = _currentRouteForIdentity(
      mcpProvider,
      selected,
      publishedRoute,
    );
    return route?.tool.needsApproval ?? true;
  }

  McpToolRouteSnapshot captureRoutesForAssistant(
    McpProvider mcpProvider,
    AssistantProvider assistants, {
    required String? assistantId,
    Set<String> reservedNames = const {},
  }) {
    final assistant = assistantId != null
        ? assistants.getById(assistantId)
        : assistants.currentAssistant;
    final selected = (assistant?.mcpServerIds ?? const <String>[]).toSet();
    return McpToolRouteSnapshot._(
      _toolRoutes(mcpProvider, selected, reservedNames: reservedNames),
    );
  }

  Future<McpToolResult> _flattenToolResult(mcp.CallToolResult res) async {
    final buf = StringBuffer();
    final imageUris = <String>[];
    final seen = <String>{};
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
          final mime = c.mimeType.toString();
          String? uri;
          if (data.isNotEmpty) {
            final savedPath = await AppDirectories.saveBase64Image(
              mime,
              data,
              prefix: 'mcp_img',
            );
            if (savedPath != null) {
              uri = SandboxPathResolver.canonicalize(savedPath);
            }
          } else {
            final url = (c.url ?? '').toString();
            if (url.isNotEmpty) uri = url;
          }
          if (uri != null && uri.isNotEmpty) {
            if (seen.add(uri)) imageUris.add(uri);
            if (buf.isNotEmpty && !_endsWithLineBreak(buf)) buf.writeln();
            buf.writeln('![](${encodeMarkdownImageDestination(uri)})');
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
      } catch (_) {}
    }
    return McpToolResult(
      markdown: buf.toString().trim(),
      imageUris: imageUris,
    );
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

  List<McpToolConfig> _exposedTools(
    McpProvider provider,
    Set<String> selected, {
    Set<String> reservedNames = const {},
  }) {
    return _exposedToolsForRoutes(
      _toolRoutes(provider, selected, reservedNames: reservedNames),
    );
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
    Set<String> reservedNames = const {},
  }) {
    for (final route in _toolRoutes(
      provider,
      selected,
      reservedNames: reservedNames,
    )) {
      if (route.exposedName == exposedName) return route;
    }
    return null;
  }

  _McpToolRoute? _currentRouteForIdentity(
    McpProvider provider,
    Set<String> selected,
    _McpToolRoute publishedRoute,
  ) {
    for (final server in provider.servers) {
      if (server.id != publishedRoute.server.id ||
          !server.enabled ||
          !selected.contains(server.id)) {
        continue;
      }
      for (final tool in server.tools) {
        if (tool.name == publishedRoute.tool.name && tool.enabled) {
          return _McpToolRoute(
            server: server,
            tool: tool,
            exposedName: publishedRoute.exposedName,
          );
        }
      }
    }
    return null;
  }

  List<_McpToolRoute> _toolRoutes(
    McpProvider provider,
    Set<String> selected, {
    Set<String> reservedNames = const {},
  }) {
    final entries = <({McpServerConfig server, McpToolConfig tool})>[];
    for (final server in provider.servers) {
      if (!server.enabled || !selected.contains(server.id)) continue;
      for (final tool in server.tools.where((tool) => tool.enabled)) {
        entries.add((server: server, tool: tool));
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
