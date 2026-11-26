import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/backup/import_toolbox.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('kelivo_toolbox_'));
  tearDown(() => temp.deleteSync(recursive: true));

  File zip(Map<String, Object?> entries, {String? comment}) {
    final archive = Archive()..comment = comment;
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile.string(entry.key, jsonEncode(entry.value)));
    }
    return File('${temp.path}/export.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
  }

  Map<String, String> assistants(List<String> ids) => {
    'assistants_v1': jsonEncode([
      for (final id in ids) {'id': id},
    ]),
  };

  test(
    'matches the picked basename even when the local path is opaque',
    () async {
      final file = File('${temp.path}/kelivo-import-downloads/1234');
      for (final name in [
        'kelivo-import-deepseek-sql-v5-20261117T080000Z.zip',
        'KELIVO-IMPORT-deepseek-sql-v5-20261117T080000Z (1).ZIP',
        'kelivo-import-deepseek-sql-v5-20261117T080000Z 2.zip',
        'kelivo-import-chatbox.kbackup',
      ]) {
        expect(await isToolboxChatImport(file, fileName: name), isTrue);
      }
      expect(await isToolboxChatImport(file), isFalse);
    },
  );

  test(
    'full backups retain overwrite even if all assistants were imported',
    () async {
      final file = zip({
        'settings.json': assistants(['imported-chatbox-assistant']),
      });
      for (final name in [
        'kelivo_backup_2026-01-01T00-00-00.000000.zip',
        'KELIVO-BACKUP-sql-v5-20261117T080000Z.zip',
        'private.kbackup',
      ]) {
        expect(await isToolboxChatImport(file, fileName: name), isFalse);
      }
    },
  );

  test(
    'renamed Hive and SQL archives match all supported assistant IDs',
    () async {
      final settings = assistants([
        for (final source in importToolboxSources) 'imported-$source-assistant',
      ]);
      for (final entries in [
        {'chats.json': {}, 'settings.json': settings},
        {'database/kelivo.db': 'unused', 'settings.json': settings},
      ]) {
        expect(await isToolboxChatImport(zip(entries)), isTrue);
      }
    },
  );

  test(
    'provider-only imports require every key to have a toolbox source',
    () async {
      final providers = {
        for (final source in importToolboxSources) 'imported-$source-api': {},
      };
      for (final settings in [
        {'provider_configs_v1': jsonEncode(providers)},
        {...assistants([]), 'provider_configs_v1': jsonEncode(providers)},
      ]) {
        expect(
          await isToolboxChatImport(zip({'settings.json': settings})),
          isTrue,
        );
      }
      for (final other in [
        'custom',
        'imported-unknown-api',
        'imported-grokcustom-api',
      ]) {
        final settings = {
          'provider_configs_v1': jsonEncode({...providers, other: {}}),
        };
        expect(
          await isToolboxChatImport(zip({'settings.json': settings})),
          isFalse,
        );
      }
    },
  );

  test(
    'only searches for the ZIP end record within its comment range',
    () async {
      final file = zip({
        'settings.json': assistants(['imported-chatbox-assistant']),
      }, comment: 'x' * 65535);
      expect(await isToolboxChatImport(file), isTrue);
      file.writeAsBytesSync([0], mode: FileMode.append);
      expect(await isToolboxChatImport(file), isFalse);
    },
  );

  test(
    'mixed or malformed assistants cannot fall through to providers',
    () async {
      for (final value in [
        assistants([
          'imported-deepseek-assistant',
          'personal',
        ])['assistants_v1'],
        assistants(['imported-chatbox-assistant-copy'])['assistants_v1'],
        assistants(['imported-other-assistant'])['assistants_v1'],
        '[{}]',
        'malformed',
        '{}',
        null,
      ]) {
        expect(
          await isToolboxChatImport(
            zip({
              'settings.json': {
                'assistants_v1': value,
                'provider_configs_v1': '{"imported-claude-api":{}}',
              },
            }),
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'ignores common manifests, nested settings, and unreadable files',
    () async {
      for (final settings in [
        {},
        {...assistants([]), 'provider_configs_v1': '{}'},
      ]) {
        final file = zip({
          'manifest.json': {
            'format': 'kelivo-backup',
            'appVersion': 'kelivo-page-migrate',
          },
          'nested/settings.json': assistants(['imported-claude-assistant']),
          'settings.json': settings,
        });
        expect(await isToolboxChatImport(file), isFalse);
      }
      final file = File('${temp.path}/unreadable.zip')
        ..writeAsStringSync('invalid');
      expect(await isToolboxChatImport(file), isFalse);
      expect(
        await isToolboxChatImport(file, fileName: 'encrypted.kbackup'),
        isFalse,
      );
    },
  );
}
