class AssistantRegex {
  const AssistantRegex({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.scopes = const <AssistantRegexScope>[],
    this.visualOnly = false,
    this.replaceOnly = false,
    this.enabled = true,
  }) : assert(!(visualOnly && replaceOnly), 'visualOnly and replaceOnly cannot both be true');

  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final List<AssistantRegexScope> scopes;
  final bool visualOnly;
  final bool replaceOnly;
  final bool enabled;

  AssistantRegex copyWith({
    String? id,
    String? name,
    String? pattern,
    String? replacement,
    List<AssistantRegexScope>? scopes,
    bool? visualOnly,
    bool? replaceOnly,
    bool? enabled,
  }) {
    return AssistantRegex(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      scopes: scopes ?? this.scopes,
      visualOnly: visualOnly ?? this.visualOnly,
      replaceOnly: replaceOnly ?? this.replaceOnly,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pattern': pattern,
        'replacement': replacement,
        'scopes': scopes.map((e) => e.name).toList(),
        'visualOnly': visualOnly,
        'replaceOnly': replaceOnly,
        'enabled': enabled,
      };

  static AssistantRegex fromJson(Map<String, dynamic> json) {
    final rawScopes = json['scopes'];
    List<AssistantRegexScope> scopes = const <AssistantRegexScope>[];
    if (rawScopes is List) {
      scopes = rawScopes
          .map((e) => AssistantRegexScopeX.fromName(e?.toString() ?? ''))
          .whereType<AssistantRegexScope>()
          .toList();
    } else if (rawScopes is String && rawScopes.isNotEmpty) {
      scopes = <AssistantRegexScope>[AssistantRegexScopeX.fromName(rawScopes) ?? AssistantRegexScope.user];
    }

    final visualOnly = json['visualOnly'] as bool? ?? false;
    final replaceOnly = json['replaceOnly'] as bool? ?? false;
    final normalizedReplaceOnly = (visualOnly && replaceOnly) ? false : replaceOnly;

    return AssistantRegex(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      pattern: (json['pattern'] as String?) ?? '',
      replacement: (json['replacement'] as String?) ?? '',
      scopes: scopes,
      visualOnly: visualOnly,
      replaceOnly: normalizedReplaceOnly,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

enum AssistantRegexScope { user, assistant }

extension AssistantRegexScopeX on AssistantRegexScope {
  static AssistantRegexScope? fromName(String name) {
    switch (name.toLowerCase()) {
      case 'user':
        return AssistantRegexScope.user;
      case 'assistant':
        return AssistantRegexScope.assistant;
      default:
        return null;
    }
  }

  String displayKey() {
    switch (this) {
      case AssistantRegexScope.user:
        return 'assistantRegexScopeUser';
      case AssistantRegexScope.assistant:
        return 'assistantRegexScopeAssistant';
    }
  }
}
