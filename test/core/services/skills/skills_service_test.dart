import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  for (final knownLength in [true, false]) {
    test(
      'GitHub streams a >20 MB zip with progress (length=$knownLength)',
      () async {
        final payload = Uint8List(21 * 1024 * 1024)..[0] = 42;
        final archive = Archive()
          ..addFile(ArchiveFile.string('demo-main/SKILL.md', _skillMd))
          ..addFile(
            ArchiveFile.noCompress(
              'demo-main/large.bin',
              payload.length,
              payload,
            ),
          );
        final zip = ZipEncoder().encodeBytes(archive);
        expect(zip.length, greaterThan(20 * 1024 * 1024));
        Stream<List<int>> chunks() async* {
          for (var start = 0; start < zip.length; start += 1024 * 1024) {
            yield Uint8List.sublistView(
              zip,
              start,
              (start + 1024 * 1024).clamp(0, zip.length),
            );
            if (start == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 120));
            }
          }
        }

        final client = MockClient.streaming(
          (request, _) async => http.StreamedResponse(
            chunks(),
            200,
            contentLength: knownLength ? zip.length : null,
          ),
        );
        final github = SkillsService(
          store: store,
          skillsDirectory: skillsDir,
          httpClient: client,
        );
        addTearDown(github.dispose);
        final progress = <SkillImportProgress>[];
        final skill = await github.importFromGitHub(
          'https://github.com/acme/demo/tree/main',
          onProgress: progress.add,
        );
        final downloaded = progress
            .where((p) => p.phase == SkillImportPhase.downloading)
            .toList();
        expect(
          downloaded.any(
            (p) => p.receivedBytes > 0 && p.receivedBytes < zip.length,
          ),
          isTrue,
        );
        expect(downloaded.last.receivedBytes, zip.length);
        expect(downloaded.last.totalBytes, knownLength ? zip.length : null);
        expect(downloaded.last.fraction, knownLength ? 1 : null);
        expect(
          progress.map((p) => p.phase).toSet(),
          SkillImportPhase.values.toSet(),
        );
        expect(
          await File(p.join(skill.dir, 'large.bin')).length(),
          payload.length,
        );
        expect(
          await skillsDir
              .list()
              .where((e) => p.basename(e.path).startsWith('.import-'))
              .isEmpty,
          isTrue,
        );
      },
    );
  }

  test(
    'GitHub rejects oversized content length without reading the body',
    () async {
      var bodyCancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => bodyCancelled = true,
      );
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          body.stream,
          200,
          contentLength: kSkillImportMaxBytes + 1,
        ),
      );
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      await expectLater(
        github.importFromGitHub('https://github.com/acme/demo/tree/main'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'zip exceeds 200 MB',
          ),
        ),
      );
      expect(bodyCancelled, isTrue);
      await body.close();
      expect(await skillsDir.list().isEmpty, isTrue);
    },
  );

  test(
    'GitHub enforces the limit while streaming without content length',
    () async {
      var stopped = false;
      Stream<List<int>> chunks() async* {
        try {
          final chunk = Uint8List(1024 * 1024);
          for (var i = 0; i < 202; i++) {
            yield chunk;
          }
          fail('should stop reading once the download limit is reached');
        } finally {
          stopped = true;
        }
      }

      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(chunks(), 200),
      );
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      await expectLater(
        github.importFromGitHub('https://github.com/acme/demo/tree/main'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'zip exceeds 200 MB',
          ),
        ),
      );
      expect(stopped, isTrue);
      expect(await skillsDir.list().isEmpty, isTrue);
    },
  );

  test(
    'GitHub cancellation aborts downloading and removes partial files',
    () async {
      final cancel = Completer<void>();
      final started = Completer<void>();
      final body = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async {
        final abortable = request as http.AbortableRequest;
        unawaited(
          abortable.abortTrigger!.then((_) {
            body.addError(http.RequestAbortedException());
            unawaited(body.close());
          }),
        );
        started.complete();
        return http.StreamedResponse(body.stream, 200);
      });
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      final result = github.importFromGitHub(
        'https://github.com/acme/demo/tree/main',
        cancelSignal: cancel.future,
      );
      final assertion = expectLater(
        result,
        throwsA(isA<http.RequestAbortedException>()),
      );
      await started.future;
      body.add([1, 2, 3]);
      cancel.complete();
      await assertion;
      expect(github.skills, isEmpty);
      expect(await skillsDir.list().isEmpty, isTrue);
    },
  );

  test('cancel during extraction never installs the completed skill', () async {
    final cancel = Completer<void>();
    final zip = encodeSkillZip({'demo-main/SKILL.md': utf8.encode(_skillMd)});
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: MockClient((_) async => http.Response.bytes(zip, 200)),
    );
    addTearDown(github.dispose);
    await expectLater(
      github.importFromGitHub(
        'https://github.com/acme/demo/tree/main',
        cancelSignal: cancel.future,
        onProgress: (value) {
          if (value.phase == SkillImportPhase.extracting) cancel.complete();
        },
      ),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(github.skills, isEmpty);
    expect(await skillsDir.list().isEmpty, isTrue);
  });

  test('download failure cleans up and allows retry', () async {
    var calls = 0;
    final zip = encodeSkillZip({'demo-main/SKILL.md': utf8.encode(_skillMd)});
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          calls++ == 0
              ? Stream<List<int>>.error(
                  const SocketException('connection reset'),
                )
              : Stream.value(zip),
          200,
        ),
      ),
    );
    addTearDown(github.dispose);
    await expectLater(
      github.importFromGitHub('https://github.com/acme/demo/tree/main'),
      throwsA(isA<SocketException>()),
    );
    expect(await skillsDir.list().isEmpty, isTrue);
    final skill = await github.importFromGitHub(
      'https://github.com/acme/demo/tree/main',
    );
    expect(skill.record.id, 'pdf-tools');
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
