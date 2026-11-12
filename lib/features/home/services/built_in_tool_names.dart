import '../../../core/services/memory/memory_tools.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/services/search/web_fetch_tool_service.dart';
import '../../../core/services/workspace/workspace_tools_service.dart';
import 'local_tools_service.dart';

/// Client-side built-in function names that MCP tools must not expose.
///
/// Reservation is static and unconditional: every name here is always
/// reserved, independent of the current assistant's tool switches.
abstract final class BuiltInToolNames {
  static Set<String> get all => {
    SearchToolService.toolName,
    WebFetchToolService.toolName,
    'builtin_search',
    // Prevent MCP tools from impersonating already saved image observations.
    'read_chat_image',
    'read_chat_context',
    ...MemoryTools.allToolNames,
    ...MemoryTools.legacyToolNames,
    ...LocalToolNames.all,
    ...WorkspaceToolsService.toolNames,
  };
}
