import 'package:mcp_client/mcp_client.dart' as mcp;

import 'kelivo_fetch_server.dart';

/// Build a function-call-friendly tool name (similar to Cherry Studio strategy)
String buildFunctionCallToolName(String serverName, String toolName) {
  String sanitizedServer = serverName.trim().replaceAll('-', '_');
  String sanitizedTool = toolName.trim().replaceAll('-', '_');
  String name = sanitizedTool;
  if (!sanitizedTool.contains(
    sanitizedServer.substring(0, sanitizedServer.length.clamp(0, 7)),
  )) {
    final head = sanitizedServer.length >= 7
        ? sanitizedServer.substring(0, 7)
        : sanitizedServer;
    name =
        '${head.isNotEmpty ? head : ''}-${sanitizedTool.isNotEmpty ? sanitizedTool : ''}';
  }
  name = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  if (!RegExp(r'^[a-zA-Z]').hasMatch(name)) {
    name = 'tool-$name';
  }
  name = name.replaceAll(RegExp(r'[_-]{2,}'), '_');
  if (name.length > 63) {
    name = name.substring(0, 63);
  }
  if (name.endsWith('_') || name.endsWith('-')) {
    name = name.substring(0, name.length - 1);
  }
  return name;
}

/// Start the in-memory @kelivo/fetch MCP server and connect a client to it.
/// Returns the connected client and a stop() to dispose both ends.
Future<({mcp.Client client, Future<void> Function() stop})>
startFetchMcpInMemory() async {
  final server = KelivoFetchMcpServerEngine();
  final transport = KelivoInMemoryClientTransport(server);

  final client = mcp.McpClient.createClient(
    mcp.McpClient.simpleConfig(name: 'Kelivo App', version: '1.0.0'),
  );
  await client.connect(transport);

  return (
    client: client,
    stop: () async {
      try {
        client.disconnect();
      } catch (_) {}
      try {
        transport.close();
      } catch (_) {}
    },
  );
}

/// List tools from the connected in-memory client and optionally map to stable ids.
Future<List<(mcp.Tool tool, String id)>> listFetchTools(
  mcp.Client client,
) async {
  final tools = await client.listTools();
  const serverName = '@kelivo/fetch';
  return tools
      .map((t) => (t, buildFunctionCallToolName(serverName, t.name)))
      .toList(growable: false);
}

/// Call one of the in-memory fetch tools.
/// name must be one of: fetch_html | fetch_markdown | fetch_txt | fetch_json
Future<mcp.CallToolResult> callFetchTool(
  mcp.Client client,
  String name, {
  required String url,
  Map<String, String>? headers,
}) async {
  final result = await client.callTool(name, {
    'url': url,
    if (headers != null && headers.isNotEmpty) 'headers': headers,
  });
  return result;
}
