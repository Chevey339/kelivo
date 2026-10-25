/// App-owned MCP organization and appearance. This metadata is backed up with
/// business preferences and never changes the interoperable MCP server config.
class McpGroup {
  const McpGroup({required this.id, required this.name});
  final String id;
  final String name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory McpGroup.fromJson(Map<String, dynamic> json) =>
      McpGroup(id: json['id'] as String, name: json['name'] as String);
}

enum McpIconType { emoji, file, url, asset, lobehub }

class McpServerIcon {
  const McpServerIcon({required this.type, required this.value});
  final McpIconType type;
  final String value;
  Map<String, dynamic> toJson() => {'type': type.name, 'value': value};
  factory McpServerIcon.fromJson(Map<String, dynamic> json) => McpServerIcon(
    type: McpIconType.values.byName(json['type'] as String),
    value: json['value'] as String,
  );
}

class McpServerPresentation {
  const McpServerPresentation({this.groupId, this.icon});
  final String? groupId;
  final McpServerIcon? icon;
  Map<String, dynamic> toJson() => {
    if (groupId != null) 'groupId': groupId,
    if (icon != null) 'icon': icon!.toJson(),
  };
  factory McpServerPresentation.fromJson(Map<String, dynamic> json) =>
      McpServerPresentation(
        groupId: json['groupId'] as String?,
        icon: json['icon'] is Map
            ? McpServerIcon.fromJson(
                Map<String, dynamic>.from(json['icon'] as Map),
              )
            : null,
      );
}

class McpPresentation {
  McpPresentation({
    List<McpGroup> groups = const [],
    Map<String, McpServerPresentation> servers = const {},
    Set<String> collapsed = const {},
  }) : groups = List.unmodifiable(groups),
       servers = Map.unmodifiable(servers),
       collapsed = Set.unmodifiable(collapsed);
  final List<McpGroup> groups;
  final Map<String, McpServerPresentation> servers;
  final Set<String> collapsed;

  McpPresentation copyWith({
    List<McpGroup>? groups,
    Map<String, McpServerPresentation>? servers,
    Set<String>? collapsed,
  }) => McpPresentation(
    groups: groups ?? this.groups,
    servers: servers ?? this.servers,
    collapsed: collapsed ?? this.collapsed,
  );
  Map<String, dynamic> toJson() => {
    'groups': groups.map((group) => group.toJson()).toList(),
    'servers': servers.map((id, value) => MapEntry(id, value.toJson())),
    'collapsed': collapsed.toList(),
  };
  factory McpPresentation.fromJson(Map<String, dynamic> json) {
    final groups = (json['groups'] as List? ?? const [])
        .map(
          (item) => McpGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final ids = groups.map((group) => group.id).toSet();
    if (ids.length != groups.length || ids.contains('')) {
      throw const FormatException('Invalid MCP groups');
    }
    final servers = <String, McpServerPresentation>{};
    for (final entry in (json['servers'] as Map? ?? const {}).entries) {
      final value = McpServerPresentation.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      servers[entry.key as String] = McpServerPresentation(
        groupId: ids.contains(value.groupId) ? value.groupId : null,
        icon: value.icon,
      );
    }
    return McpPresentation(
      groups: groups,
      servers: servers,
      collapsed: (json['collapsed'] as List? ?? const [])
          .cast<String>()
          .where((id) => id == '__ungrouped__' || ids.contains(id))
          .toSet(),
    );
  }
}
