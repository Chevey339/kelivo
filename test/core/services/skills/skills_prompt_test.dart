import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skill.dart';
import 'package:Kelivo/core/services/skills/skills_prompt.dart';

Skill _skill({
  required String id,
  required String name,
  required String description,
  int useCount = 0,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Skill(
    record: SkillRecord(
      id: id,
      useCount: useCount,
      source: SkillSource.file,
      installedAt: now,
      updatedAt: now,
    ),
    name: name,
    description: description,
    dir: '/tmp/$id',
    skillMdPath: '/tmp/$id/SKILL.md',
  );
}

void main() {
  test('lists skills with model paths and instructions', () {
    final fragment = buildAvailableSkillsFragment([
      _skill(
        id: 'pdf-tools',
        name: 'pdf-tools',
        description: 'Extract text and tables from PDF files with pdfplumber.',
      ),
    ], skillsModelRoot: '/skills');
    expect(fragment, contains('<available_skills>'));
    expect(
      fragment,
      contains(
        'Use a skill when the task matches its description: call read_file on '
        'its SKILL.md first and follow it.',
      ),
    );
    expect(
      fragment,
      contains(
        '- pdf-tools — Extract text and tables from PDF files with pdfplumber. '
        '(/skills/pdf-tools/SKILL.md)',
      ),
    );
    expect(fragment, endsWith('</available_skills>'));
  });

  test('caps the list at 20 and orders by useCount then name', () {
    final skills = <Skill>[
      for (var i = 0; i < 21; i++)
        _skill(
          id: 's${i.toString().padLeft(2, '0')}',
          name: 's${i.toString().padLeft(2, '0')}',
          description: 'd$i',
          useCount: i == 7 ? 5 : (i == 3 ? 5 : 0),
        ),
    ];
    final fragment = buildAvailableSkillsFragment(
      skills,
      skillsModelRoot: '/skills',
    );
    final items = RegExp(r'^- ', multiLine: true).allMatches(fragment);
    expect(items.length, 20);
    expect(fragment, isNot(contains('s20')));
    final first = fragment.split('\n').firstWhere((l) => l.startsWith('- '));
    expect(first, startsWith('- s03 —'));
    final second = fragment
        .split('\n')
        .where((l) => l.startsWith('- '))
        .skip(1)
        .first;
    expect(second, startsWith('- s07 —'));
  });

  test('clips descriptions to 200 UTF-16 units', () {
    final long = '${'a' * 180}${'😀' * 20}bbbb';
    final fragment = buildAvailableSkillsFragment([
      _skill(id: 'clip', name: 'clip', description: long),
    ], skillsModelRoot: '/skills');
    final match = RegExp(
      r'- clip — (.+) \(/skills/clip/SKILL.md\)',
    ).firstMatch(fragment);
    expect(match, isNotNull);
    final clipped = match!.group(1)!;
    expect(clipped.length, lessThanOrEqualTo(200));
    expect(clipped, isNot(contains('bbbb')));
  });

  test('uses the supplied skillsModelRoot', () {
    final fragment = buildAvailableSkillsFragment([
      _skill(id: 'x', name: 'x', description: 'd'),
    ], skillsModelRoot: '/custom/skills/');
    expect(fragment, contains('(/custom/skills/x/SKILL.md)'));
  });
}
