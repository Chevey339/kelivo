import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skill_archive.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

const _skillMd = '''
---
name: pdf-tools
description: Extract text and tables from PDF files with pdfplumber.
---
# PDF Tools
''';

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;
  late Directory tmp;
  late Directory skillsDir;
  late SkillsService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(database);
    await database.customSelect('SELECT 1;').getSingle();
    tmp = await Directory.systemTemp.createTemp('kelivo_skills_');
    skillsDir = Directory(p.join(tmp.path, 'skills'));
    service = SkillsService(store: store, skillsDirectory: skillsDir);
    await service.loaded;
  });

  tearDown(() async {
    service.dispose();
    await database.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'rescan drops records without SKILL.md and adopts orphan dirs',
    () async {
      await store.upsert(ExtensionEntityStore.kindSkill, 'ghost', {
        'id': 'ghost',
        'enabled': true,
        'useCount': 0,
        'source': 'file',
        'installedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      final orphan = Directory(p.join(skillsDir.path, 'orphan-skill'));
      await orphan.create(recursive: true);
      await File(p.join(orphan.path, 'SKILL.md')).writeAsString('''
---
name: orphan-skill
description: Found on disk
---
body
''');

      await service.rescan();
      expect(await store.get(ExtensionEntityStore.kindSkill, 'ghost'), isNull);
      expect(service.skills.map((s) => s.record.id), contains('orphan-skill'));
      expect(
        service.skills
            .singleWhere((s) => s.record.id == 'orphan-skill')
            .record
            .source,
        SkillSource.file,
      );
      expect(
        service.skills
            .singleWhere((s) => s.record.id == 'orphan-skill')
            .description,
        'Found on disk',
      );
    },
  );

  test('importFromText writes SKILL.md and dedupes ids', () async {
    final first = await service.importFromText(_skillMd);
    expect(first.record.id, 'pdf-tools');
    expect(first.record.source, SkillSource.paste);
    expect(File(first.skillMdPath).existsSync(), isTrue);
    expect(first.name, 'pdf-tools');

    final second = await service.importFromText(_skillMd);
    expect(second.record.id, 'pdf-tools-2');
    expect(service.skills, hasLength(2));
  });

  test('importFromFile accepts a markdown file', () async {
    final md = File(p.join(tmp.path, 'custom.md'));
    await md.writeAsString('''
---
name: from-file
description: Imported from a markdown file
---
hi
''');
    final skill = await service.importFromFile(md.path);
    expect(skill.record.id, 'from-file');
    expect(skill.record.source, SkillSource.file);
    expect(File(skill.skillMdPath).readAsStringSync(), contains('from-file'));
  });

  test('importFromFile extracts a zip at root or one level down', () async {
    final zipPath = p.join(tmp.path, 'packed.zip');
    File(zipPath).writeAsBytesSync(
      encodeSkillZip({
        'pdf-pack/SKILL.md': utf8.encode(_skillMd),
        'pdf-pack/helper.py': utf8.encode('print(1)'),
      }),
    );
    final skill = await service.importFromFile(zipPath);
    expect(skill.record.id, 'pdf-tools');
    expect(skill.record.source, SkillSource.file);
    expect(File(p.join(skill.dir, 'helper.py')).existsSync(), isTrue);
  });

  test('importFromFile rejects zip-slip', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('../escape/SKILL.md', _skillMd));
    final zipPath = p.join(tmp.path, 'slip.zip');
    File(zipPath).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    expect(
      () => service.importFromFile(zipPath),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'importFromGitHub downloads a codeload zip via the injected client',
    () async {
      final zip = encodeSkillZip({
        'demo-main/SKILL.md': utf8.encode('''
---
name: gh-skill
description: From GitHub
---
hello
'''),
        'demo-main/notes.txt': utf8.encode('n'),
      });
      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response('{"default_branch":"main"}', 200);
        }
        if (request.url.host == 'codeload.github.com') {
          expect(request.url.path, '/acme/demo/zip/main');
          return http.Response.bytes(zip, 200);
        }
        return http.Response('missing', 404);
      });
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      await github.loaded;
      final skill = await github.importFromGitHub(
        'https://github.com/acme/demo',
      );
      expect(skill.record.id, 'gh-skill');
      expect(skill.record.source, SkillSource.github);
      expect(File(p.join(skill.dir, 'notes.txt')).existsSync(), isTrue);

      final nested = await github.importFromGitHub(
        'https://github.com/acme/demo/tree/main',
      );
      expect(nested.record.id, 'gh-skill-2');
    },
  );

  test('importFromGitHub follows a SKILL.md blob URL subdir', () async {
    final zip = encodeSkillZip({
      'demo-main/skills/pdf-tools/SKILL.md': utf8.encode(_skillMd),
      'demo-main/skills/pdf-tools/x.py': utf8.encode('x'),
      'demo-main/README.md': utf8.encode('no'),
    });
    final client = MockClient((request) async {
      if (request.url.host == 'codeload.github.com') {
        expect(request.url.path, contains('/zip/v1'));
        return http.Response.bytes(zip, 200);
      }
      return http.Response('{"default_branch":"main"}', 200);
    });
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: client,
    );
    addTearDown(github.dispose);
    await github.loaded;
    final skill = await github.importFromGitHub(
      'https://github.com/acme/demo/blob/v1/skills/pdf-tools/SKILL.md',
    );
    expect(skill.record.id, 'pdf-tools');
    expect(File(p.join(skill.dir, 'x.py')).existsSync(), isTrue);
    expect(File(p.join(skill.dir, 'README.md')).existsSync(), isFalse);
  });

  test('exportZip, delete, toggle, useCount, updateBody', () async {
    final skill = await service.importFromText(_skillMd);
    final exported = await service.exportZip(
      skill.record.id,
      Directory(tmp.path),
    );
    expect(exported.existsSync(), isTrue);
    expect(p.basename(exported.path), 'pdf-tools.zip');

    await service.setEnabled(skill.record.id, false);
    expect(
      service.skills
          .singleWhere((s) => s.record.id == skill.record.id)
          .record
          .enabled,
      isFalse,
    );

    await service.setEnabled(skill.record.id, true);
    await service.incrementUseCount(skill.record.id);
    expect(
      service.skills
          .singleWhere((s) => s.record.id == skill.record.id)
          .record
          .useCount,
      1,
    );

    await service.updateBody(skill.record.id, '''
---
name: pdf-tools
description: Updated description
---
new body
''');
    final updated = service.skills.singleWhere(
      (s) => s.record.id == skill.record.id,
    );
    expect(updated.description, 'Updated description');
    expect(File(updated.skillMdPath).readAsStringSync(), contains('new body'));

    await service.delete(skill.record.id);
    expect(service.skills, isEmpty);
    expect(Directory(skill.dir).existsSync(), isFalse);
    expect(
      await store.get(ExtensionEntityStore.kindSkill, skill.record.id),
      isNull,
    );
  });

  test(
    'resolveForAssistant respects assistant and conversation overrides',
    () async {
      await service.importFromText(_skillMd);
      await service.importFromText('''
---
name: other
description: Another skill
---
x
''');
      await service.importFromText('''
---
name: disabled
description: Off
---
x
''');
      await service.setEnabled('disabled', false);

      final all = service.resolveForAssistant(null);
      expect(
        all.map((s) => s.record.id),
        unorderedEquals(['pdf-tools', 'other']),
      );

      const assistant = Assistant(id: 'a1', name: 'A', skillIds: ['other']);
      expect(service.resolveForAssistant(assistant).map((s) => s.record.id), [
        'other',
      ]);
      expect(
        service
            .resolveForAssistant(assistant, conversationOverride: ['pdf-tools'])
            .map((s) => s.record.id),
        ['pdf-tools'],
      );
      expect(
        service.resolveForAssistant(assistant, conversationOverride: []),
        isEmpty,
      );
    },
  );

  test('incrementUseCount never throws for a missing id', () async {
    await service.incrementUseCount('nope');
  });
}
