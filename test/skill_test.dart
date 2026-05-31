import 'dart:io';

// Relative imports since we're inside the project
import '../lib/core/models/skill.dart';
import '../lib/core/services/skill/skill_parser.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void check(String name, bool ok, [String? detail]) {
    if (ok) {
      print('  ✅ $name');
      passed++;
    } else {
      print('  ❌ $name${detail != null ? ': $detail' : ''}');
      failed++;
    }
  }

  // Test 1: Parse the actual obsidian-knowledge-worker SKILL.md
  print('\n=== Test 1: Parse obsidian-knowledge-worker SKILL.md ===');
  final home = Platform.environment['HOME'] ?? '/data/data/com.termux/files/home';
  final path = '$home/skills/obsidian-knowledge-worker/SKILL.md';
  print('  Reading: $path');
  final result = SkillParser.parseFile(path);
  check('File parsed successfully', result.isSuccess, result.error ?? '');
  check('Name = obsidian-knowledge-worker', result.meta.name == 'obsidian-knowledge-worker', 'got "${result.meta.name}"');
  check('Description not empty', result.meta.description.isNotEmpty);
  check('Version = 1.0.0', result.meta.version == '1.0.0', 'got "${result.meta.version}"');
  check('Author = Jaye', result.meta.author == 'Jaye');
  check('Has 12+ triggers', result.meta.triggers.length >= 12, 'got ${result.meta.triggers.length}');
  check('Priority = 100', result.meta.priority == 100);
  check('Content not empty', result.content.isNotEmpty);
  check('Content has markdown', result.content.contains('## 一、核心原则'));

  // Test 2: Build Skill object
  print('\n=== Test 2: Build Skill Object ===');
  final skill = Skill.fromMeta(meta: result.meta, content: result.content, filePath: path);
  check('ID generated', skill.id.isNotEmpty);
  check('Name propagated', skill.name == 'obsidian-knowledge-worker');
  check('Content propagated', skill.content.contains('核心原则'));
  check('toMarkdown() roundtrip', skill.toMarkdown().contains('name: obsidian-knowledge-worker'));
  check('toMarkdown() has body', skill.toMarkdown().contains('核心原则'));

  // Test 3: JSON roundtrip
  print('\n=== Test 3: JSON Roundtrip ===');
  final json = skill.toJson();
  final restored = Skill.fromJson(json);
  check('ID preserved', restored.id == skill.id);
  check('Name preserved', restored.name == skill.name);
  check('Content preserved', restored.content == skill.content);
  check('Triggers count preserved', restored.triggers.length == skill.triggers.length);
  check('Priority preserved', restored.priority == skill.priority);

  // Test 4: copyWith
  print('\n=== Test 4: copyWith ===');
  final modified = skill.copyWith(name: 'new-name', enabled: false);
  check('Name changed', modified.name == 'new-name');
  check('Enabled changed', modified.enabled == false);
  check('Original unchanged name', skill.name == 'obsidian-knowledge-worker');
  check('Original unchanged enabled', skill.enabled == true);

  // Test 5: Plain markdown
  print('\n=== Test 5: Plain Markdown ===');
  final plain = SkillParser.parseString('# Hello\n\nThis is a test.');
  check('Plain parse succeeds', plain.isSuccess);
  check('Empty name', plain.meta.name.isEmpty);
  check('Content preserved', plain.content.contains('Hello'));
  check('Default version', plain.meta.version == '1.0.0');

  // Test 6: Edge cases
  print('\n=== Test 6: Edge Cases ===');
  final empty = SkillParser.parseString('');
  check('Empty fails', !empty.isSuccess);
  final noFm = SkillParser.parseString('Just text');
  check('No frontmatter works', noFm.isSuccess);
  check('Content = input', noFm.content == 'Just text');

  print('\n=== ✅ All $passed tests passed ===');
  if (failed > 0) print('  ❌ $failed tests FAILED');
  exit(failed > 0 ? 1 : 0);
}
