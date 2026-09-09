enum SkillSource { paste, file, github, bundled }

class SkillRecord {
  final String id;
  final bool enabled;
  final int useCount;
  final SkillSource source;
  final DateTime installedAt;
  final DateTime updatedAt;

  const SkillRecord({
    required this.id,
    this.enabled = true,
    this.useCount = 0,
    required this.source,
    required this.installedAt,
    required this.updatedAt,
  });

  SkillRecord copyWith({
    String? id,
    bool? enabled,
    int? useCount,
    SkillSource? source,
    DateTime? installedAt,
    DateTime? updatedAt,
  }) {
    return SkillRecord(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      useCount: useCount ?? this.useCount,
      source: source ?? this.source,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'useCount': useCount,
    'source': source.name,
    'installedAt': installedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SkillRecord.fromJson(Map<String, dynamic> json) {
    return SkillRecord(
      id: json['id'] as String,
      enabled: json['enabled'] as bool? ?? true,
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
      source: skillSourceFromString(json['source'] as String?),
      installedAt: DateTime.parse(json['installedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static SkillSource skillSourceFromString(String? value) {
    switch (value) {
      case 'file':
        return SkillSource.file;
      case 'github':
        return SkillSource.github;
      case 'bundled':
        return SkillSource.bundled;
      case 'paste':
      default:
        return SkillSource.paste;
    }
  }
}
