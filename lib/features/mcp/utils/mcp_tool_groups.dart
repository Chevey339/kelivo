import '../../../core/models/mcp_presentation.dart';
import '../../../core/providers/mcp_provider.dart';

/// Connected tools in the same group and server order as MCP settings.
/// Empty groups are omitted; ungrouped servers come last.
List<({McpGroup? group, List<McpServerConfig> servers})> mcpToolGroups(
  McpProvider mcp,
) {
  final buckets = <String?, List<McpServerConfig>>{};
  for (final server in mcp.servers) {
    if (mcp.statusFor(server.id) != McpStatus.connected) continue;
    final id = mcp.presentationFor(server.id).groupId;
    (buckets[id] ??= []).add(server);
  }
  return [
    for (final group in mcp.groups)
      if (buckets[group.id] case final servers?)
        (group: group, servers: servers),
    if (buckets[null] case final servers?) (group: null, servers: servers),
  ];
}
