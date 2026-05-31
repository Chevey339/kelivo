/// SKILL.md 解析器
///
/// 解析符合 RikkaHub 兼容格式的 SKILL.md 文件：
///
/// ```yaml
/// ---
/// name: skill-name
/// description: 描述
/// version: 1.0.0
/// author: 作者
/// trigger: [关键词1, 关键词2]
/// priority: 100
/// ---
///
/// # 正文内容
/// ...
/// ```
library;

import 'dart:io';

import '../../models/skill.dart';

class SkillParseResult {
  final SkillMeta meta;
  final String content;
  final String? error;

  const SkillParseResult({
    required this.meta,
    required this.content,
    this.error,
  });

  bool get isSuccess => error == null;
}

class SkillParser {
  const SkillParser._();

  /// 从文件路径解析 SKILL.md
  static SkillParseResult parseFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return SkillParseResult(
          meta: SkillMeta(name: '', description: ''),
          content: '',
          error: 'File not found: $filePath',
        );
      }
      final raw = file.readAsStringSync();
      return parseString(raw, sourcePath: filePath);
    } catch (e) {
      return SkillParseResult(
        meta: SkillMeta(name: '', description: ''),
        content: '',
        error: 'Failed to read file: $e',
      );
    }
  }

  /// 从字符串解析 SKILL.md
  static SkillParseResult parseString(String raw, {String? sourcePath}) {
    if (raw.trim().isEmpty) {
      return SkillParseResult(
        meta: SkillMeta(name: '', description: ''),
        content: '',
        error: 'Empty content',
      );
    }

    try {
      // 寻找 YAML frontmatter 边界
      final trimmed = raw.trim();
      if (!trimmed.startsWith('---')) {
        // 没有 frontmatter — 整个内容作为正文，使用默认元数据
        final filename = sourcePath != null
            ? sourcePath.split('/').last.replaceAll('.md', '').replaceAll('.skill', '')
            : '';
        return SkillParseResult(
          meta: SkillMeta(
            name: filename,
            description: '',
          ),
          content: trimmed,
        );
      }

      // 找到第二个 ---
      final afterFirst = trimmed.substring(3).trimLeft();
      final endIndex = afterFirst.indexOf('\n---');
      if (endIndex == -1) {
        // 没有闭合的 frontmatter — 视为纯正文
        final filename = sourcePath != null
            ? sourcePath.split('/').last.replaceAll('.md', '').replaceAll('.skill', '')
            : '';
        return SkillParseResult(
          meta: SkillMeta(
            name: filename,
            description: '',
          ),
          content: trimmed,
        );
      }

      final yamlBlock = afterFirst.substring(0, endIndex).trim();
      final body = afterFirst.substring(endIndex + 4).trim();

      // 解析 YAML frontmatter（手写解析，不引入 yaml 依赖）
      final meta = _parseYamlFrontmatter(yamlBlock);
      return SkillParseResult(
        meta: meta,
        content: body,
      );
    } catch (e) {
      return SkillParseResult(
        meta: SkillMeta(name: '', description: ''),
        content: '',
        error: 'Parse error: $e',
      );
    }
  }

  /// 手写 YAML 解析器（仅支持 SKILL.md 使用的字段子集）
  static SkillMeta _parseYamlFrontmatter(String yaml) {
    String name = '';
    String description = '';
    String version = '1.0.0';
    String author = '';
    List<String> triggers = [];
    int priority = 100;

    for (final line in yaml.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      final key = trimmed.substring(0, colonIndex).trim().toLowerCase();
      final valueRaw = trimmed.substring(colonIndex + 1).trim();

      switch (key) {
        case 'name':
          name = _stripQuotes(valueRaw);
          break;
        case 'description':
          description = _stripQuotes(valueRaw);
          break;
        case 'version':
          version = _stripQuotes(valueRaw);
          break;
        case 'author':
          author = _stripQuotes(valueRaw);
          break;
        case 'trigger':
        case 'triggers':
          triggers = _parseYamlList(valueRaw);
          break;
        case 'priority':
          priority = int.tryParse(valueRaw) ?? 100;
          break;
      }
    }

    return SkillMeta(
      name: name,
      description: description,
      version: version,
      author: author,
      triggers: triggers,
      priority: priority,
    );
  }

  /// 去除首尾引号
  static String _stripQuotes(String s) {
    var result = s;
    if ((result.startsWith('"') && result.endsWith('"')) ||
        (result.startsWith("'") && result.endsWith("'"))) {
      result = result.substring(1, result.length - 1);
    }
    return result.trim();
  }

  /// 解析 YAML 列表格式：[a, b, c] 或 - a\n - b\n - c
  static List<String> _parseYamlList(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    // 内联格式: [a, b, c]
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      return inner
          .split(',')
          .map((e) => _stripQuotes(e.trim()))
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    // 暂不支持多行列表格式（SKILL.md 通常使用内联格式）
    return [];
  }
}