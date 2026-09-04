import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FakeSkillsService extends ChangeNotifier implements SkillsService {
  FakeSkillsService({
    List<Skill>? skills,
    this._skillsDirectory,
    this.importError,
  }) : _skills = List<Skill>.from(skills ?? const <Skill>[]);

  final List<Skill> _skills;
  final Directory? _skillsDirectory;

  Object? importError;
  final List<String> importedTexts = <String>[];
  final List<(String, bool)> enabledCalls = <(String, bool)>[];
  final List<String> deletedIds = <String>[];
  final List<(String, String)> updatedBodies = <(String, String)>[];

  @override
  Future<void> loaded = Future<void>.value();

  @override
  ExtensionEntityStore get store => throw UnimplementedError();

  @override
  Directory get skillsDirectory {
    final dir = _skillsDirectory;
    if (dir == null) {
      throw StateError('FakeSkillsService has no skillsDirectory');
    }
    return dir;
  }

  @override
  List<Skill> get skills => List.unmodifiable(_skills);

  @override
  Future<void> rescan() async {
    notifyListeners();
  }

  @override
  Future<Skill> importFromText(String markdown) async {
    importedTexts.add(markdown);
    final error = importError;
    if (error != null) throw error;
    final parsed = SkillFrontmatter.parse(markdown);
    final errors = parsed.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    final root = _skillsDirectory;
    final id = slugify(parsed.name);
    late final String dir;
    late final String mdPath;
    if (root != null) {
      dir = p.join(root.path, id);
      await Directory(dir).create(recursive: true);
      mdPath = p.join(dir, 'SKILL.md');
      await File(mdPath).writeAsString(markdown);
    } else {
      dir = id;
      mdPath = p.join(id, 'SKILL.md');
    }
    final now = DateTime.now().toUtc();
    final skill = Skill(
      record: SkillRecord(
        id: id,
        source: SkillSource.paste,
        installedAt: now,
        updatedAt: now,
      ),
      name: parsed.name.trim(),
      description: parsed.description,
      dir: dir,
      skillMdPath: mdPath,
    );
    _skills
      ..removeWhere((item) => item.record.id == id)
      ..add(skill);
    notifyListeners();
    return skill;
  }

  @override
  Future<Skill> importFromFile(String hostPath) {
    throw UnimplementedError();
  }

  @override
  Future<Skill> importFromGitHub(String url) {
    throw UnimplementedError();
  }

  @override
  Future<File> exportZip(String id, Directory outDir) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _skills.removeWhere((skill) => skill.record.id == id);
    notifyListeners();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    enabledCalls.add((id, enabled));
    final index = _skills.indexWhere((skill) => skill.record.id == id);
    if (index < 0) return;
    final skill = _skills[index];
    _skills[index] = Skill(
      record: skill.record.copyWith(enabled: enabled),
      name: skill.name,
      description: skill.description,
      dir: skill.dir,
      skillMdPath: skill.skillMdPath,
    );
    notifyListeners();
  }

  @override
  Future<void> incrementUseCount(String id) async {}

  @override
  Future<void> updateBody(String id, String markdown) async {
    updatedBodies.add((id, markdown));
    final parsed = SkillFrontmatter.parse(markdown);
    final index = _skills.indexWhere((skill) => skill.record.id == id);
    if (index < 0) return;
    final skill = _skills[index];
    _skills[index] = Skill(
      record: skill.record.copyWith(updatedAt: DateTime.now().toUtc()),
      name: parsed.name.trim().isEmpty ? skill.name : parsed.name.trim(),
      description: parsed.description,
      dir: skill.dir,
      skillMdPath: skill.skillMdPath,
    );
    notifyListeners();
  }

  @override
  List<Skill> resolveForAssistant(
    Assistant? assistant, {
    List<String>? conversationOverride,
  }) {
    final filter = conversationOverride ?? assistant?.skillIds;
    final enabled = [
      for (final skill in _skills)
        if (skill.record.enabled) skill,
    ];
    if (filter == null) return enabled;
    final allowed = filter.toSet();
    return [
      for (final skill in enabled)
        if (allowed.contains(skill.record.id)) skill,
    ];
  }
}

class FakeChatService extends ChatService {
  FakeChatService({this._conversation});

  Conversation? _conversation;
  Map<String, dynamic>? lastExtras;

  @override
  Conversation? getConversation(String id) {
    final conversation = _conversation;
    if (conversation == null || conversation.id != id) return null;
    return conversation;
  }

  @override
  Future<void> updateConversationExtras(
    String conversationId,
    Map<String, dynamic> Function(Map<String, dynamic> current) update,
  ) async {
    final current = Map<String, dynamic>.from(_conversation?.extras ?? {});
    final next = update(current);
    lastExtras = next;
    final existing = _conversation;
    _conversation = (existing ?? Conversation(id: conversationId, title: 't'))
        .copyWith(extras: next);
    notifyListeners();
  }
}

Skill createTempSkill({
  required String id,
  required String name,
  required String description,
  bool enabled = true,
  int useCount = 0,
  SkillSource source = SkillSource.paste,
  Directory? parent,
}) {
  final dir = parent == null
      ? Directory.systemTemp.createTempSync('kelivo_skill_$id')
      : (Directory(p.join(parent.path, id))..createSync(recursive: true));
  final md = File(p.join(dir.path, 'SKILL.md'));
  md.writeAsStringSync('''
---
name: $name
description: $description
---
# $name
''');
  final now = DateTime.utc(2026, 1, 1);
  return Skill(
    record: SkillRecord(
      id: id,
      enabled: enabled,
      useCount: useCount,
      source: source,
      installedAt: now,
      updatedAt: now,
    ),
    name: name,
    description: description,
    dir: dir.path,
    skillMdPath: md.path,
  );
}
