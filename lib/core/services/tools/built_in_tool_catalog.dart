import '../../services/memory/memory_prompts.dart';
import '../../services/memory/memory_tools.dart';
import '../../services/search/search_tool_service.dart';
import '../../../features/home/services/local_tools_service.dart';

enum BuiltInToolGroup { search, memory, local }

class BuiltInToolCatalogEntry {
  const BuiltInToolCatalogEntry({
    required this.name,
    required this.defaultDefinition,
    required this.group,
  });

  final String name;
  final Map<String, dynamic> defaultDefinition;
  final BuiltInToolGroup group;

  String? get defaultDescription {
    final function = defaultDefinition['function'];
    if (function is! Map) return null;
    final desc = function['description'];
    return desc is String ? desc : null;
  }
}

/// Ungated catalog of built-in tool schemas for the settings editor.
///
/// MCP tools are excluded: their names are dynamic and overrides would go stale.
abstract final class BuiltInToolCatalog {
  BuiltInToolCatalog._();

  static List<BuiltInToolCatalogEntry> entries({
    required MemoryPromptLang lang,
    required bool legacyMemoryMode,
  }) {
    final out = <BuiltInToolCatalogEntry>[
      BuiltInToolCatalogEntry(
        name: SearchToolService.toolName,
        defaultDefinition: SearchToolService.getToolDefinition(),
        group: BuiltInToolGroup.search,
      ),
    ];

    final memoryDefs = legacyMemoryMode
        ? MemoryTools.legacyDefinitions(lang)
        : MemoryTools.catalogDefinitions(lang);
    for (final def in memoryDefs) {
      final name = _toolName(def);
      if (name == null) continue;
      out.add(
        BuiltInToolCatalogEntry(
          name: name,
          defaultDefinition: def,
          group: BuiltInToolGroup.memory,
        ),
      );
    }

    for (final name in LocalToolNames.all) {
      if (!LocalToolsService.isAvailableOnThisPlatform(name)) continue;
      out.add(
        BuiltInToolCatalogEntry(
          name: name,
          defaultDefinition: LocalToolsService.definitionFor(name),
          group: BuiltInToolGroup.local,
        ),
      );
    }
    return out;
  }

  static String? _toolName(Map<String, dynamic> def) {
    final function = def['function'];
    if (function is! Map) return null;
    final name = function['name'];
    return name is String ? name : null;
  }
}
