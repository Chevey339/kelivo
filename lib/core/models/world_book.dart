enum WorldBookInjectionPosition {
  beforeSystemPrompt,
  afterSystemPrompt,
  topOfChat,
  bottomOfChat,
  atDepth,
}

extension WorldBookInjectionPositionJson on WorldBookInjectionPosition {
  static WorldBookInjectionPosition fromJson(dynamic value) {
    final v = (value ?? '').toString().trim().toUpperCase();
    switch (v) {
      case 'BEFORE_SYSTEM_PROMPT':
        return WorldBookInjectionPosition.beforeSystemPrompt;
      case 'TOP_OF_CHAT':
        return WorldBookInjectionPosition.topOfChat;
      case 'BOTTOM_OF_CHAT':
        return WorldBookInjectionPosition.bottomOfChat;
      case 'AT_DEPTH':
        return WorldBookInjectionPosition.atDepth;
      case 'AFTER_SYSTEM_PROMPT':
      default:
        return WorldBookInjectionPosition.afterSystemPrompt;
    }
  }

  String toJson() {
    return switch (this) {
      WorldBookInjectionPosition.beforeSystemPrompt => 'BEFORE_SYSTEM_PROMPT',
      WorldBookInjectionPosition.afterSystemPrompt => 'AFTER_SYSTEM_PROMPT',
      WorldBookInjectionPosition.topOfChat => 'TOP_OF_CHAT',
      WorldBookInjectionPosition.bottomOfChat => 'BOTTOM_OF_CHAT',
      WorldBookInjectionPosition.atDepth => 'AT_DEPTH',
    };
  }
}

enum WorldBookInjectionRole { user, assistant }

extension WorldBookInjectionRoleJson on WorldBookInjectionRole {
  static WorldBookInjectionRole fromJson(dynamic value) {
    final v = (value ?? '').toString().trim().toUpperCase();
    switch (v) {
      case 'ASSISTANT':
        return WorldBookInjectionRole.assistant;
      case 'USER':
      default:
        return WorldBookInjectionRole.user;
    }
  }

  String toJson() {
    return switch (this) {
      WorldBookInjectionRole.user => 'USER',
      WorldBookInjectionRole.assistant => 'ASSISTANT',
    };
  }
}

class WorldBookEntry {
  final String id;
  final String name;
  final bool enabled;
  final int priority;
  final WorldBookInjectionPosition position;
  final String content;
  final int injectDepth;
  final WorldBookInjectionRole role;
  final List<String> keywords;
  final bool useRegex;
  final bool caseSensitive;
  final int scanDepth;
  final bool constantActive;

  const WorldBookEntry({
    required this.id,
    this.name = '',
    this.enabled = true,
    this.priority = 0,
    this.position = WorldBookInjectionPosition.afterSystemPrompt,
    this.content = '',
    this.injectDepth = 4,
    this.role = WorldBookInjectionRole.user,
    this.keywords = const <String>[],
    this.useRegex = false,
    this.caseSensitive = false,
    this.scanDepth = 4,
    this.constantActive = false,
  });

  WorldBookEntry copyWith({
    String? id,
    String? name,
    bool? enabled,
    int? priority,
    WorldBookInjectionPosition? position,
    String? content,
    int? injectDepth,
    WorldBookInjectionRole? role,
    List<String>? keywords,
    bool? useRegex,
    bool? caseSensitive,
    int? scanDepth,
    bool? constantActive,
  }) {
    return WorldBookEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      position: position ?? this.position,
      content: content ?? this.content,
      injectDepth: injectDepth ?? this.injectDepth,
      role: role ?? this.role,
      keywords: keywords ?? this.keywords,
      useRegex: useRegex ?? this.useRegex,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      scanDepth: scanDepth ?? this.scanDepth,
      constantActive: constantActive ?? this.constantActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'priority': priority,
    'position': position.toJson(),
    'content': content,
    'injectDepth': injectDepth,
    'role': role.toJson(),
    'keywords': keywords,
    'useRegex': useRegex,
    'caseSensitive': caseSensitive,
    'scanDepth': scanDepth,
    'constantActive': constantActive,
  };

  static WorldBookEntry fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    final keywords = (rawKeywords is List)
        ? rawKeywords
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return WorldBookEntry(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
      priority: (json['priority'] as int?) ?? 0,
      position: WorldBookInjectionPositionJson.fromJson(json['position']),
      content: (json['content'] as String?) ?? '',
      injectDepth: (json['injectDepth'] as int?) ?? 4,
      role: WorldBookInjectionRoleJson.fromJson(json['role']),
      keywords: keywords,
      useRegex: (json['useRegex'] as bool?) ?? false,
      caseSensitive: (json['caseSensitive'] as bool?) ?? false,
      scanDepth: (json['scanDepth'] as int?) ?? 4,
      constantActive: (json['constantActive'] as bool?) ?? false,
    );
  }
}

class WorldBook {
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final List<WorldBookEntry> entries;

  const WorldBook({
    required this.id,
    this.name = '',
    this.description = '',
    this.enabled = true,
    this.entries = const <WorldBookEntry>[],
  });

  WorldBook copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    List<WorldBookEntry>? entries,
  }) {
    return WorldBook(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'entries': entries.map((e) => e.toJson()).toList(growable: false),
  };

  static WorldBook fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = (rawEntries is List)
        ? rawEntries
              .whereType<Map>()
              .map((e) => WorldBookEntry.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
        : const <WorldBookEntry>[];
    return WorldBook(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
      entries: entries,
    );
  }
}
