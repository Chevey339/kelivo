/// Skill 数据模型 — 简化版
///
/// 源自 RikkaHub 的设计：技能存储在 ~/skills/<name>/SKILL.md
/// - 用 name 作为唯一键（同时也是目录名）
/// - 没有 UUID id（简化）
/// - 没有 assistantIds（绑到 Assistant.enabledSkills）
/// - triggers 仅作元数据说明（不再用于匹配）
library;

/// 技能文件（支持多文件技能目录）
class SkillFile {
  final String relativePath; // 相对路径，如 "SKILL.md" 或 "examples/basic.md"
  final String content;
  final int sizeBytes;

  const SkillFile({
    required this.relativePath,
    required this.content,
    this.sizeBytes = 0,
  });

  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'content': content,
    'sizeBytes': sizeBytes,
  };

  factory SkillFile.fromJson(Map<String, dynamic> json) => SkillFile(
    relativePath: (json['relativePath'] as String?) ?? '',
    content: (json['content'] as String?) ?? '',
    sizeBytes: (json['sizeBytes'] as int?) ?? 0,
  );
}

/// 技能元数据（对应 SKILL.md 的 YAML frontmatter）
class SkillMeta {
  final String name; // 唯一键 + 目录名
  final String description;
  final String version;
  final String author;
  final String compatibility; // 兼容性标注（如 "obsidian-plugin-dev"）
  final List<String> triggers; // 仅作元数据，不再用于匹配

  const SkillMeta({
    required this.name,
    this.description = '',
    this.version = '1.0.0',
    this.author = '',
    this.compatibility = '',
    this.triggers = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'compatibility': compatibility,
    'triggers': triggers,
  };

  factory SkillMeta.fromJson(Map<String, dynamic> json) => SkillMeta(
    name: (json['name'] as String?)?.trim() ?? '',
    description: (json['description'] as String?)?.trim() ?? '',
    version: (json['version'] as String?)?.trim() ?? '1.0.0',
    author: (json['author'] as String?)?.trim() ?? '',
    compatibility: (json['compatibility'] as String?)?.trim() ?? '',
    triggers: _parseStringList(json['triggers'] ?? json['trigger']),
  );

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    }
    return [];
  }
}

/// 完整的 Skill 对象
class Skill {
  final String name; // 唯一键（同时也是 ~/skills/<name>/ 目录名）
  final String description;
  final String version;
  final String author;
  final String compatibility;
  final List<String> triggers;
  final String content; // SKILL.md 正文（不含 frontmatter）
  final List<SkillFile> files; // 子文件列表
  final String? filePath; // SKILL.md 源文件路径
  final DateTime createdAt;
  final DateTime updatedAt;

  const Skill({
    required this.name,
    this.description = '',
    this.version = '1.0.0',
    this.author = '',
    this.compatibility = '',
    this.triggers = const [],
    this.content = '',
    this.files = const [],
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 SKILL.md 解析结果构建
  factory Skill.fromMeta({
    required SkillMeta meta,
    required String content,
    List<SkillFile> files = const [],
    String? filePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return Skill(
      name: meta.name,
      description: meta.description,
      version: meta.version,
      author: meta.author,
      compatibility: meta.compatibility,
      triggers: meta.triggers,
      content: content,
      files: files,
      filePath: filePath,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// 获取 SKILL.md 完整格式（含 frontmatter）
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('name: $name');
    buf.writeln('description: $description');
    buf.writeln('version: $version');
    if (author.isNotEmpty) buf.writeln('author: $author');
    if (compatibility.isNotEmpty) buf.writeln('compatibility: $compatibility');
    if (triggers.isNotEmpty) {
      buf.writeln('trigger: [${triggers.join(', ')}]');
    }
    buf.writeln('---');
    buf.writeln();
    buf.write(content.trim());
    return buf.toString();
  }

  Skill copyWith({
    String? name,
    String? description,
    String? version,
    String? author,
    String? compatibility,
    List<String>? triggers,
    String? content,
    List<SkillFile>? files,
    String? filePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Skill(
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      compatibility: compatibility ?? this.compatibility,
      triggers: triggers ?? this.triggers,
      content: content ?? this.content,
      files: files ?? this.files,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'compatibility': compatibility,
    'triggers': triggers,
    'content': content,
    'files': files.map((f) => f.toJson()).toList(),
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      name: (json['name'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      version: (json['version'] as String?)?.trim() ?? '1.0.0',
      author: (json['author'] as String?)?.trim() ?? '',
      compatibility: (json['compatibility'] as String?)?.trim() ?? '',
      triggers: _parseStringList(json['triggers'] ?? json['trigger']),
      content: (json['content'] as String?) ?? '',
      files: (() {
        final raw = json['files'];
        if (raw is List) {
          return raw.whereType<Map>().map((e) => SkillFile.fromJson(e.cast<String, dynamic>())).toList();
        }
        return const <SkillFile>[];
      })(),
      filePath: (json['filePath'] as String?)?.trim(),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() => 'Skill(name: $name, v$version)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Skill && other.name == name);

  @override
  int get hashCode => name.hashCode;
}
