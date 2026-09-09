import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/skill_frontmatter.dart';

void main() {
  test('parses standard YAML frontmatter', () {
    const markdown = '''
---
name: pdf-tools
description: Extract text and tables from PDF files with pdfplumber.
license: Apache-2.0
---
# PDF Tools

Use pdfplumber.
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.name, 'pdf-tools');
    expect(
      parsed.description,
      'Extract text and tables from PDF files with pdfplumber.',
    );
    expect(parsed.body, contains('# PDF Tools'));
    expect(parsed.body, contains('Use pdfplumber.'));
    expect(parsed.extras['license'], 'Apache-2.0');
    expect(parsed.validate(), isEmpty);
  });

  test('tolerates BOM and CRLF', () {
    final markdown =
        '\uFEFF---\r\nname: crlf-skill\r\ndescription: "Windows line endings"\r\n---\r\nBody\r\n';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.name, 'crlf-skill');
    expect(parsed.description, 'Windows line endings');
    expect(parsed.body, contains('Body'));
  });

  test('missing frontmatter uses the first heading', () {
    const markdown = '''
# Spreadsheet Helper

Read CSV files.
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.name, 'Spreadsheet Helper');
    expect(parsed.description, isEmpty);
    expect(parsed.body, contains('# Spreadsheet Helper'));
    expect(parsed.validate(), contains('missing description'));
  });

  test('missing frontmatter and heading leaves name empty', () {
    final parsed = SkillFrontmatter.parse('just a body');
    expect(parsed.name, isEmpty);
    expect(parsed.body, 'just a body');
    expect(
      parsed.validate(),
      containsAll(['missing name', 'missing description']),
    );
  });

  test('quoted description keeps colons', () {
    const markdown = '''
---
name: quoted
description: "Extract: text, tables, and images"
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.description, 'Extract: text, tables, and images');
  });

  test('multiline block description', () {
    const markdown = '''
---
name: multi
description: |
  Line one
  Line two
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.description, contains('Line one'));
    expect(parsed.description, contains('Line two'));
  });

  test('validate reports empty frontmatter fields', () {
    const markdown = '''
---
name: ""
description: ""
---
# Heading
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.name, 'Heading');
    expect(parsed.validate(), contains('missing description'));
    expect(
      const SkillFrontmatter(name: '', description: '', body: '').validate(),
      containsAll(['missing name', 'missing description']),
    );
  });

  group('slugify', () {
    test('lowercases and hyphenates', () {
      expect(slugify('PDF Tools'), 'pdf-tools');
    });

    test('strips punctuation and collapses dashes', () {
      expect(slugify('Hello,  World!!!'), 'hello-world');
    });

    test('truncates to 64 characters', () {
      final slug = slugify('A' * 80);
      expect(slug.length, 64);
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(slug), isTrue);
    });

    test('falls back when nothing remains', () {
      expect(slugify('!!!'), 'skill');
      expect(slugify('表格'), 'skill');
    });
  });
}
