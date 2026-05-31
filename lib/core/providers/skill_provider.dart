/// SkillProvider — 技能管理
///
/// 管理 SKILL.md 的导入、导出、CRUD、触发词匹配和助手绑定。
/// 持久化使用 SharedPreferences。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/skill.dart';
import '../services/skill/skill_parser.dart';

class SkillProvider extends ChangeNotifier {
  static const String _prefsKey = 'skills_v1';

  List<Skill> _skills = [];
  bool _initialized = false;

  List<Skill> get skills => List.unmodifiable(_skills);
  bool get initialized => _initialized;

  /// 获取所有已启用的技能
  List<Skill> get enabledSkills =>
      _skills.where((s) => s.enabled).toList(growable: false);

  // ============================================================================
  // 加载与持久化
  // ============================================================================

  Future<void> initialize() async {
    if (_initialized) return;
    await _load();
    await _importBuiltIns();
    _initialized = true;
  }

  /// 首次启动时从 assets 导入内置技能
  Future<void> _importBuiltIns() async {
    if (_skills.isNotEmpty) return; // 已有技能，跳过
    try {
      // assets/skills/ 下每个子目录包含 SKILL.md
      // 先尝试列出 assets 中的技能目录
      final manifest = await rootBundle.loadString('assets/skills/');
      // 如果 assets/skills/ 返回的是目录列表则处理，否则逐个尝试已知技能
    } catch (_) {
      // rootBundle 无法列出目录，fallback: 逐个尝试已知技能
    }

    final builtInSkillDirs = [
      'obsidian-knowledge-worker',
      'tech-homelab-ops',
      'ai-api-manager',
      'obsidian-plugin-dev',
      'firefox-addon-dev',
    ];

    for (final dir in builtInSkillDirs) {
      try {
        final raw = await rootBundle.loadString('assets/skills/$dir/SKILL.md');
        // 检查是否已存在同名技能（避免重复导入）
        final result = SkillParser.parseString(raw, sourcePath: 'assets/skills/$dir/SKILL.md');
        if (!result.isSuccess || result.meta.name.isEmpty) continue;
        
        final exists = _skills.any((s) => s.name == result.meta.name);
        if (exists) continue;

        final skill = Skill.fromMeta(
          meta: result.meta,
          content: result.content,
          filePath: 'assets/skills/$dir/SKILL.md',
          assistantIds: [],
          enabled: true,
        );
        _skills.add(skill);
      } catch (_) {
        // 忽略加载失败的内置技能
      }
    }

    if (_skills.isNotEmpty) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _skills = list
            .whereType<Map>()
            .map((e) => Skill.fromJson(e.cast<String, dynamic>()))
            .toList(growable: true);
      } else {
        _skills = [];
      }
    } catch (e) {
      debugPrint('[SkillProvider] load error: $e');
      _skills = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_skills.map((s) => s.toJson()).toList());
      await prefs.setString(_prefsKey, json);
    } catch (e) {
      debugPrint('[SkillProvider] persist error: $e');
    }
  }

  // ============================================================================
  // 导入
  // ============================================================================

  /// 从 SKILL.md 文件导入单个技能
  /// [assistantIds] — 绑定的助手 ID 列表，为空则全局生效
  Future<Skill?> importFromFile(String filePath, {List<String>? assistantIds}) async {
    try {
      final result = SkillParser.parseFile(filePath);
      if (!result.isSuccess) {
        debugPrint('[SkillProvider] import failed: ${result.error}');
        return null;
      }

      // 检查是否已存在同名技能
      final existing = _skills.where((s) => s.name == result.meta.name).toList();
      if (existing.isNotEmpty) {
        // 已存在 — 更新版本
        final latest = existing.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
        final updated = latest.copyWith(
          version: result.meta.version,
          description: result.meta.description,
          author: result.meta.author,
          triggers: result.meta.triggers,
          priority: result.meta.priority,
          content: result.content,
          filePath: filePath,
          updatedAt: DateTime.now(),
        );
        await update(updated);
        return updated;
      }

      final skill = Skill.fromMeta(
        meta: result.meta,
        content: result.content,
        filePath: filePath,
        assistantIds: assistantIds ?? [],
      );
      _skills.add(skill);
      await _persist();
      notifyListeners();
      return skill;
    } catch (e) {
      debugPrint('[SkillProvider] importFromFile error: $e');
      return null;
    }
  }

  /// 从 SKILL.md 字符串导入
  Future<Skill?> importFromString(String raw, {String? filePath, List<String>? assistantIds}) async {
    try {
      final result = SkillParser.parseString(raw, sourcePath: filePath);
      if (!result.isSuccess) return null;

      final skill = Skill.fromMeta(
        meta: result.meta,
        content: result.content,
        filePath: filePath,
        assistantIds: assistantIds ?? [],
      );
      _skills.add(skill);
      await _persist();
      notifyListeners();
      return skill;
    } catch (e) {
      debugPrint('[SkillProvider] importFromString error: $e');
      return null;
    }
  }

  /// 从文件夹批量导入所有 SKILL.md
  Future<int> importFromDirectory(String dirPath, {List<String>? assistantIds}) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;

    int count = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && (entity.path.endsWith('.md') || entity.path.endsWith('.skill.md'))) {
          final skill = await importFromFile(entity.path, assistantIds: assistantIds);
          if (skill != null) count++;
        }
      }
    } catch (e) {
      debugPrint('[SkillProvider] importFromDirectory error: $e');
    }
    return count;
  }

  // ============================================================================
  // CRUD
  // ============================================================================

  Skill? getById(String id) {
    try {
      return _skills.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> update(Skill updated) async {
    final idx = _skills.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return;
    _skills[idx] = updated.copyWith(updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _skills.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _skills[idx] = _skills[idx].copyWith(enabled: !_skills[idx].enabled, updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _skills.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _skills.length) return;
    if (newIndex < 0 || newIndex >= _skills.length) return;
    if (oldIndex == newIndex) return;
    final item = _skills.removeAt(oldIndex);
    _skills.insert(newIndex, item);
    await _persist();
    notifyListeners();
  }

  // ============================================================================
  // 助手绑定
  // ============================================================================

  /// 设置技能绑定到哪些助手
  Future<void> setAssistantIds(String skillId, List<String> assistantIds) async {
    final idx = _skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return;
    _skills[idx] = _skills[idx].copyWith(assistantIds: assistantIds, updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  /// 为指定助手启用所有全局技能 + 绑定的技能
  List<Skill> getActiveSkillsForAssistant(String? assistantId) {
    if (!_initialized) return [];
    return _skills.where((s) {
      if (!s.enabled) return false;
      if (s.assistantIds.isEmpty) return true; // 全局生效
      if (assistantId == null) return false;
      return s.assistantIds.contains(assistantId);
    }).toList(growable: false);
  }

  // ============================================================================
  // 触发词匹配
  // ============================================================================

  /// 根据文本匹配技能触发词
  /// 返回匹配的技能列表，按优先级降序排列
  List<Skill> matchByTriggers(String text, {String? assistantId}) {
    if (text.isEmpty) return [];

    final active = getActiveSkillsForAssistant(assistantId);
    if (active.isEmpty) return [];

    final lowerText = text.toLowerCase();
    final matched = <Skill>[];

    for (final skill in active) {
      for (final trigger in skill.triggers) {
        if (trigger.isEmpty) continue;
        if (lowerText.contains(trigger.toLowerCase())) {
          matched.add(skill);
          break; // 一个技能匹配任意一个 trigger 就算
        }
      }
    }

    // 按优先级降序排列
    matched.sort((a, b) => b.priority.compareTo(a.priority));
    return matched;
  }

  // ============================================================================
  // 导出
  // ============================================================================

  /// 导出为 SKILL.md 格式的字符串
  String exportToMarkdown(String skillId) {
    final skill = getById(skillId);
    if (skill == null) return '';
    return skill.toMarkdown();
  }

  /// 导出到文件
  Future<bool> exportToFile(String skillId, String outputPath) async {
    final md = exportToMarkdown(skillId);
    if (md.isEmpty) return false;
    try {
      await File(outputPath).writeAsString(md);
      return true;
    } catch (_) {
      return false;
    }
  }
}