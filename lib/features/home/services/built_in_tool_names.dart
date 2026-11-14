import '../../../core/services/memory/memory_tools.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/services/search/web_fetch_tool_service.dart';
import '../../../core/services/workspace/workspace_tools_service.dart';
import 'local_tools_service.dart';

abstract final class BuiltInToolNames {
  /// Registered client functions, independent of the current tool switches.
  static Set<String> get functions => {
    SearchToolService.toolName,
    WebFetchToolService.toolName,
    'read_chat_context',
    ...MemoryTools.allToolNames,
    ...MemoryTools.legacyToolNames,
    ...LocalToolNames.all,
    ...WorkspaceToolsService.toolNames,
  };

  /// MCP must also avoid names used for server events and saved observations.
  static Set<String> get all => {
    ...functions,
    'builtin_search',
    'read_chat_image',
  };
}
