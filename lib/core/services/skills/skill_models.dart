/// Metadata describing an imported Agent Skill.
///
/// Follows the Agent Skills open standard (https://agentskills.io).
/// A [SkillMeta] is produced by parsing a `SKILL.md` file's YAML frontmatter
/// (see [SkillParser]) and is the single source of truth for a skill's
/// identity, capabilities and user-controlled global toggle.
class SkillMeta {
  /// Creates a [SkillMeta].
  ///
  /// [name] must match `^[a-z0-9]+(-[a-z0-9]+)*$` and be ≤64 characters.
  /// [description] must be ≤1024 characters.
  /// [compatibility], when provided, must be ≤500 characters.
  ///
  /// Not `const` because [createdAt] is a [DateTime], which is not
  /// const-constructible in Dart. The constructor still uses `required`
  /// keyword arguments for the mandatory fields.
  SkillMeta({
    required this.name,
    required this.description,
    required this.directoryPath,
    required this.createdAt,
    this.version,
    this.license,
    this.compatibility,
    this.metadata,
    this.allowedTools,
    this.globalEnabled = false,
  });

  /// Skill identifier. Must match `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 chars.
  /// Should match the parent directory name after extraction.
  final String name;

  /// Human + AI readable description containing keywords used for retrieval.
  /// Required, ≤1024 characters.
  final String description;

  /// Optional semantic version (e.g. `"1.2.3"`).
  final String? version;

  /// Optional SPDX license identifier (e.g. `"Apache-2.0"`).
  final String? license;

  /// Optional environment / runtime requirements, ≤500 characters.
  final String? compatibility;

  /// Optional arbitrary key-value metadata (e.g. author, homepage).
  final Map<String, dynamic>? metadata;

  /// Optional list of pre-approved tools the skill may invoke.
  final List<String>? allowedTools;

  /// Absolute path to the extracted skill directory on disk.
  final String directoryPath;

  /// Whether the user has allowed the AI to invoke this skill globally.
  /// Toggled from UI; defaults to `false` for safety.
  final bool globalEnabled;

  /// Import timestamp.
  final DateTime createdAt;

  SkillMeta copyWith({
    String? name,
    String? description,
    String? version,
    String? license,
    String? compatibility,
    Map<String, dynamic>? metadata,
    List<String>? allowedTools,
    String? directoryPath,
    bool? globalEnabled,
    DateTime? createdAt,
  }) {
    return SkillMeta(
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      license: license ?? this.license,
      compatibility: compatibility ?? this.compatibility,
      metadata: metadata ?? this.metadata,
      allowedTools: allowedTools ?? this.allowedTools,
      directoryPath: directoryPath ?? this.directoryPath,
      globalEnabled: globalEnabled ?? this.globalEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'description': description,
    if (version != null) 'version': version,
    if (license != null) 'license': license,
    if (compatibility != null) 'compatibility': compatibility,
    if (metadata != null) 'metadata': metadata,
    if (allowedTools != null) 'allowedTools': allowedTools,
    'directoryPath': directoryPath,
    'globalEnabled': globalEnabled,
    'createdAt': createdAt.toIso8601String(),
  };

  static SkillMeta fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final metadata = (rawMetadata is Map)
        ? Map<String, dynamic>.from(rawMetadata)
        : null;

    final rawTools = json['allowedTools'];
    final allowedTools = (rawTools is List)
        ? rawTools.map((e) => e.toString()).toList(growable: false)
        : null;

    final rawCreatedAt = json['createdAt'];
    final createdAt = switch (rawCreatedAt) {
      String s => DateTime.tryParse(s) ?? DateTime.now(),
      int i => DateTime.fromMillisecondsSinceEpoch(i),
      _ => DateTime.now(),
    };

    return SkillMeta(
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      version: json['version'] as String?,
      license: json['license'] as String?,
      compatibility: json['compatibility'] as String?,
      metadata: metadata,
      allowedTools: allowedTools,
      directoryPath: (json['directoryPath'] as String?) ?? '',
      globalEnabled: (json['globalEnabled'] as bool?) ?? false,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SkillMeta && other.name == name);

  @override
  int get hashCode => name.hashCode;
}
