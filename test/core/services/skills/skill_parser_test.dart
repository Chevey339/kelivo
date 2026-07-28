import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_parser.dart';

void main() {
  test('accepts frontmatter that ends at end of file', () {
    final result = SkillParser.parseSkillMd(
      '''---
name: test-skill
description: A test skill.
---''',
      directoryPath: '/skills/test-skill',
      now: DateTime.utc(2026, 7, 29),
    );

    expect(result.isError, isFalse);
    expect(result.meta?.name, 'test-skill');
    expect(result.body, isEmpty);
  });
}
