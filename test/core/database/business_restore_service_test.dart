import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';

void main() {
  late AppDatabase database;
  late BusinessRepository repository;
  late BusinessRestoreService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
    service = BusinessRestoreService(repository);
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() => database.close());

  test(
    'overwrite validates then atomically replaces only business data',
    () async {
      await service.overwrite({
        'assistants_v1': jsonEncode([
          {'id': 'old', 'name': 'Old'},
        ]),
        'theme_mode_v1': 'light',
      });
      await database.customStatement(
        'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
        ['unrelated_chat_meta', 'preserved'],
      );

      await service.overwrite({
        'assistants_v1': jsonEncode([
          {'id': 'new', 'name': 'New'},
        ]),
        'theme_mode_v1': 'dark',
        'plugin_future_key_v1': <String>['a', 'b'],
        'flutter_log_enabled_v1': true,
        'pinned_chat_ids': <String>['ignored'],
      });

      final exported = await service.exportSettings();
      expect(jsonDecode(exported['assistants_v1']! as String), [
        {'id': 'new', 'name': 'New'},
      ]);
      expect(exported['theme_mode_v1'], 'dark');
      expect(exported['plugin_future_key_v1'], <String>['a', 'b']);
      expect(exported, isNot(contains('flutter_log_enabled_v1')));
      expect(exported, isNot(contains('pinned_chat_ids')));
      expect(await repository.hasMigrationReceipt(), isTrue);
      final chatMeta = await database
          .customSelect('SELECT value FROM chat_storage_meta_rows;')
          .get();
      expect(
        chatMeta.any((row) => row.read<String>('value') == 'preserved'),
        isTrue,
      );
    },
  );

  test('invalid overwrite leaves the complete old snapshot intact', () async {
    await service.overwrite({
      'assistants_v1': jsonEncode([
        {'id': 'old', 'name': 'Old'},
      ]),
      'theme_mode_v1': 'light',
    });
    final before = await service.exportSettings();

    await expectLater(
      service.overwrite({
        'assistants_v1': jsonEncode({'invalid': true}),
        'theme_mode_v1': 'dark',
      }),
      throwsA(isA<FormatException>()),
    );

    expect(await service.exportSettings(), before);
  });

  test(
    'database failure rolls back the complete overwrite transaction',
    () async {
      await service.overwrite({
        'assistants_v1': jsonEncode([
          {'id': 'old', 'name': 'Old'},
        ]),
        'theme_mode_v1': 'light',
      });
      final before = await service.exportSettings();
      await database.customStatement('''
CREATE TRIGGER fail_restored_assistant
BEFORE INSERT ON assistant_rows
WHEN NEW.id = 'fail'
BEGIN
  SELECT RAISE(ABORT, 'injected_restore_failure');
END;
''');

      await expectLater(
        service.overwrite({
          'assistants_v1': jsonEncode([
            {'id': 'fail', 'name': 'New'},
          ]),
          'theme_mode_v1': 'dark',
        }),
        throwsA(anything),
      );

      expect(await service.exportSettings(), before);
    },
  );

  test(
    'merge applies frozen key rules in one repository transaction',
    () async {
      await service.overwrite({
        'provider_configs_v1': jsonEncode({
          'local': {'id': 'local', 'apiKey': 'local'},
        }),
        'providers_order_v1': <String>['local'],
        'theme_mode_v1': 'light',
      });

      await service.merge({
        'provider_configs_v1': jsonEncode({
          'incoming': {'id': 'incoming', 'apiKey': 'secret'},
        }),
        'providers_order_v1': <String>['incoming'],
        'theme_mode_v1': 'dark',
      });

      final exported = await service.exportSettings();
      expect(exported['providers_order_v1'], <String>['incoming', 'local']);
      expect(jsonDecode(exported['provider_configs_v1']! as String), {
        'incoming': {'id': 'incoming', 'apiKey': 'secret'},
        'local': {'id': 'local', 'apiKey': 'local'},
      });
      expect(exported['theme_mode_v1'], 'dark');
    },
  );

  test('database failure rolls back every merged business key', () async {
    await service.overwrite({
      'assistants_v1': jsonEncode([
        {'id': 'local', 'name': 'Local'},
      ]),
      'theme_mode_v1': 'light',
    });
    final before = await service.exportSettings();
    await database.customStatement('''
CREATE TRIGGER fail_merged_assistant
BEFORE INSERT ON assistant_rows
WHEN NEW.id = 'incoming'
BEGIN
  SELECT RAISE(ABORT, 'injected_merge_failure');
END;
''');

    await expectLater(
      service.merge({
        'assistants_v1': jsonEncode([
          {'id': 'incoming', 'name': 'Incoming'},
        ]),
        'theme_mode_v1': 'dark',
      }),
      throwsA(anything),
    );

    expect(await service.exportSettings(), before);
  });
}
