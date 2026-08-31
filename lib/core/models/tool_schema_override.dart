/// User override of a built-in tool's schema **descriptions only**.
///
/// Parameter names, types, enums, and required lists stay locked. A null or
/// empty [description] / empty param value means "use the built-in default".
class ToolSchemaOverride {
  const ToolSchemaOverride({
    this.description,
    this.paramDescriptions = const {},
  });

  /// Top-level `function.description`. Null or blank = default.
  final String? description;

  /// Flattened parameter path → description, e.g. `query`, `questions.items.id`.
  final Map<String, String> paramDescriptions;

  bool get isEmpty {
    final descEmpty = description == null || description!.trim().isEmpty;
    if (!descEmpty) return false;
    for (final value in paramDescriptions.values) {
      if (value.trim().isNotEmpty) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    final params = <String, String>{
      for (final e in paramDescriptions.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value,
    };
    return {
      if (description != null && description!.trim().isNotEmpty)
        'description': description,
      if (params.isNotEmpty) 'paramDescriptions': params,
    };
  }

  factory ToolSchemaOverride.fromJson(Map<String, dynamic> json) {
    final rawDesc = json['description'];
    final description = rawDesc is String ? rawDesc : null;
    final rawParams = json['paramDescriptions'];
    final params = <String, String>{};
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          params['${entry.key}'] = value;
        }
      }
    }
    return ToolSchemaOverride(
      description: description,
      paramDescriptions: params,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ToolSchemaOverride) return false;
    if (other.description != description) return false;
    if (other.paramDescriptions.length != paramDescriptions.length) {
      return false;
    }
    for (final entry in paramDescriptions.entries) {
      if (other.paramDescriptions[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    description,
    Object.hashAll(
      paramDescriptions.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
