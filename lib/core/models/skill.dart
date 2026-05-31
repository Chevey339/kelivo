/// Skill 数据模型
///
/// 一个 Skill 代表一个可导入的知识/技能包，包含 YAML frontmatter 元数据
/// 和 Markdown 正文。Skills 可以通过触发关键词自动注入到对话上下文中。
library;

import 'package:uuid/uuid.dart';

/// 技能元数据（对应 SKILL.md 的 YAML frontmatter）
class SkillMeta {
  final String name;
  final String description;
  final String version;
  final String author;
  final List<String> triggers;
  final int priority;

  const SkillMeta({
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.author = '',
    this.triggers = const [],
    this.priority = 100,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'trigger': triggers,
    'priority': priority,
  };

  factory SkillMeta.fromJson(Map<String, dynamic> json) {
    final rawTriggers = json['trigger'] ?? json['triggers'];
    final triggers = (rawTriggers is List)
        ? rawTriggers.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false)
        : <String>[];
    return SkillMeta(
      name: (json['name'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      version: (json['version'] as String?)?.trim() ?? '1.0.0',
      author: (json['author'] as String?)?.trim() ?? '',
      triggers: triggers,
      priority: (json['priority'] as int?) ?? 100,
    );
  }
}

/// 完整的 Skill 对象
class Skill {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final List<String> triggers;
  final int priority;
  final bool enabled;
  final String content;           // SKILL.md 正文（不含 frontmatter）
  final List<String> assistantIds; // [] = 全局生效, [id1, id2] = 绑定特定助手
  final String? filePath;          // 源文件路径（导入时记录，用于重载）
  final DateTime createdAt;
  final DateTime updatedAt;

  const Skill({
    required this.id,
    required this.name,
    this.description = '',
    this.version = '1.0.0',
    this.author = '',
    this.triggers = const [],
    this.priority = 100,
    this.enabled = true,
    this.content = '',
    this.assistantIds = const [],
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 SKILL.md 解析结果构建（自动生成 id）
  factory Skill.fromMeta({
    required SkillMeta meta,
    required String content,
    String? filePath,
    List<String> assistantIds = const [],
    bool enabled = true,
  }) {
    final now = DateTime.now();
    return Skill(
      id: const Uuid().v4(),
      name: meta.name,
      description: meta.description,
      version: meta.version,
      author: meta.author,
      triggers: meta.triggers,
      priority: meta.priority,
      enabled: enabled,
      content: content,
      assistantIds: assistantIds,
      filePath: filePath,
      createdAt: now,
      updatedAt: now,
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
    if (triggers.isNotEmpty) {
      buf.writeln('trigger: [${triggers.join(', ')}]');
    }
    buf.writeln('priority: $priority');
    buf.writeln('---');
    buf.writeln();
    buf.write(content.trim());
    return buf.toString();
  }

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    String? author,
    List<String>? triggers,
    int? priority,
    bool? enabled,
    String? content,
    List<String>? assistantIds,
    String? filePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      triggers: triggers ?? this.triggers,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      content: content ?? this.content,
      assistantIds: assistantIds ?? this.assistantIds,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'triggers': triggers,
    'priority': priority,
    'enabled': enabled,
    'content': content,
    'assistantIds': assistantIds,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      version: (json['version'] as String?)?.trim() ?? '1.0.0',
      author: (json['author'] as String?)?.trim() ?? '',
      triggers: _parseStringList(json['triggers']),
      priority: (json['priority'] as int?) ?? 100,
      enabled: (json['enabled'] as bool?) ?? true,
      content: (json['content'] as String?) ?? '',
      assistantIds: _parseStringList(json['assistantIds']),
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
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  @override
  String toString() => 'Skill(id: $id, name: $name, v$version, enabled: $enabled)';
}