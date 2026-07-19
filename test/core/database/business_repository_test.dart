import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_repository.dart';

void main() {
  late AppDatabase database;
  late BusinessRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() => database.close());

  BusinessEntityValue row(
    String id,
    int sortOrder, {
    String? assistantId,
    String? payload,
  }) => BusinessEntityValue(
    id: id,
    sortOrder: sortOrder,
    payload:
        payload ??
        (assistantId == null
            ? '{"id":"$id"}'
            : '{"id":"$id","assistantId":"$assistantId"}'),
    assistantId: assistantId,
  );

  test('entity CRUD reads in stable sort order', () async {
    await repository.upsertEntity(BusinessEntityKind.assistant, row('b', 2));
    await repository.upsertEntity(BusinessEntityKind.assistant, row('a', 2));
    await repository.upsertEntity(BusinessEntityKind.assistant, row('c', 0));

    expect(
      (await repository.readEntities(
        BusinessEntityKind.assistant,
      )).map((value) => value.id),
      <String>['c', 'a', 'b'],
    );

    await repository.upsertEntity(
      BusinessEntityKind.assistant,
      row('b', 1, payload: '{"id":"b","name":"updated"}'),
    );
    await repository.deleteEntity(BusinessEntityKind.assistant, 'a');

    final values = await repository.readEntities(BusinessEntityKind.assistant);
    expect(values.map((value) => value.id), <String>['c', 'b']);
    expect(values.last.payload, contains('updated'));
  });

  test('assistant memories use their projection for filtered reads', () async {
    await repository.replaceEntities(BusinessEntityKind.assistantMemory, [
      row('2', 1, assistantId: 'assistant-b'),
      row('1', 2, assistantId: 'assistant-a'),
      row('3', 0, assistantId: 'assistant-a'),
    ]);

    final values = await repository.readMemoriesForAssistant('assistant-a');
    expect(values.map((value) => value.id), <String>['3', '1']);
    expect(values.every((value) => value.assistantId == 'assistant-a'), isTrue);
  });

  test(
    'preference values preserve their JSON scalar and string-list types',
    () async {
      await repository.setPreference('bool', true);
      await repository.setPreference('int', 7);
      await repository.setPreference('double', 0.75);
      await repository.setPreference('string', 'seven');
      await repository.setPreference('list', <String>['a', 'b']);

      expect(await repository.getPreference('bool'), isTrue);
      expect(await repository.getPreference('int'), 7);
      expect(await repository.getPreference('double'), 0.75);
      expect(await repository.getPreference('string'), 'seven');
      expect(await repository.getPreference('list'), <String>['a', 'b']);

      await repository.removePreference('string');
      expect(await repository.getPreference('string'), isNull);
      expect(
        (await repository.preferenceSnapshot()).keys,
        isNot(contains('string')),
      );
    },
  );

  test(
    'synchronizeEntities deletes missing ids and upserts changed rows',
    () async {
      await repository.replaceEntities(BusinessEntityKind.provider, [
        row('removed', 0),
        row('updated', 1),
      ]);

      await repository.synchronizeEntities(BusinessEntityKind.provider, [
        row('updated', 0, payload: '{"id":"updated","apiKey":"secret"}'),
        row('added', 1),
      ]);

      final values = await repository.readEntities(BusinessEntityKind.provider);
      expect(values.map((value) => value.id), <String>['updated', 'added']);
      expect(values.first.payload, contains('secret'));
    },
  );

  test('synchronizeEntities does not rewrite unchanged entity rows', () async {
    await repository.replaceEntities(BusinessEntityKind.assistant, [
      row('unchanged', 0),
      row('updated', 1),
    ]);
    final before = {
      for (final result
          in await database
              .customSelect('SELECT id, updated_at FROM assistant_rows;')
              .get())
        result.read<String>('id'): result.read<int>('updated_at'),
    };
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await repository.synchronizeEntities(BusinessEntityKind.assistant, [
      row('unchanged', 0),
      row('updated', 1, payload: '{"id":"updated","name":"changed"}'),
      row('added', 2),
    ]);

    final after = {
      for (final result
          in await database
              .customSelect('SELECT id, updated_at FROM assistant_rows;')
              .get())
        result.read<String>('id'): result.read<int>('updated_at'),
    };
    expect(after['unchanged'], before['unchanged']);
    expect(after['updated'], greaterThan(before['updated']!));
    expect(after, contains('added'));
  });

  test(
    'replaceSnapshot is atomic and can publish the migration receipt',
    () async {
      final initial = BusinessSnapshot(
        entities: {
          BusinessEntityKind.assistant: [row('old', 0)],
        },
        preferences: const {'theme_mode_v1': 'light'},
      );
      await repository.replaceSnapshot(initial);

      final replacement = BusinessSnapshot(
        entities: {
          BusinessEntityKind.assistant: [row('new', 0)],
          BusinessEntityKind.assistantMemory: [row('1', 0, assistantId: 'new')],
        },
        preferences: const {
          'theme_mode_v1': 'dark',
          'pinned_models_v1': <String>['provider::model'],
        },
      );
      await repository.replaceSnapshot(replacement, writeReceipt: true);

      final actual = await repository.readSnapshot();
      expect(actual.entities[BusinessEntityKind.assistant]!.single.id, 'new');
      expect(actual.preferences, replacement.preferences);
      expect(await repository.hasMigrationReceipt(), isTrue);

      final invalid = BusinessSnapshot(
        entities: {
          BusinessEntityKind.assistant: [row('invalid', -1)],
        },
        preferences: const {'theme_mode_v1': 'system'},
      );
      await expectLater(
        repository.replaceSnapshot(invalid),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        (await repository.readEntities(BusinessEntityKind.assistant)).single.id,
        'new',
      );
      expect(await repository.getPreference('theme_mode_v1'), 'dark');

      await repository.clearMigrationReceipt();
      expect(await repository.hasMigrationReceipt(), isFalse);
    },
  );

  test(
    'replaceSnapshot rolls back deletes after a mid-transaction failure',
    () async {
      await repository.replaceSnapshot(
        BusinessSnapshot(
          entities: {
            BusinessEntityKind.assistant: [row('old', 0)],
          },
          preferences: const {'theme_mode_v1': 'light'},
        ),
      );
      await database.customStatement('''
CREATE TRIGGER fail_business_insert
BEFORE INSERT ON assistant_rows
WHEN NEW.id = 'fail'
BEGIN
  SELECT RAISE(ABORT, 'injected_business_failure');
END;
''');

      await expectLater(
        repository.replaceSnapshot(
          BusinessSnapshot(
            entities: {
              BusinessEntityKind.assistant: [row('fail', 0)],
            },
            preferences: const {'theme_mode_v1': 'dark'},
          ),
          writeReceipt: true,
        ),
        throwsA(anything),
      );

      final snapshot = await repository.readSnapshot();
      expect(snapshot.entities[BusinessEntityKind.assistant]!.single.id, 'old');
      expect(snapshot.preferences['theme_mode_v1'], 'light');
      expect(await repository.hasMigrationReceipt(), isFalse);
    },
  );

  test(
    'migration validation and receipt publication share one transaction',
    () async {
      await repository.replaceSnapshot(
        BusinessSnapshot(
          entities: {
            BusinessEntityKind.assistant: [row('old', 0)],
          },
          preferences: const {'theme_mode_v1': 'light'},
        ),
      );

      await expectLater(
        repository.replaceSnapshotForMigration(
          BusinessSnapshot(
            entities: {
              BusinessEntityKind.assistant: [row('new', 0)],
            },
            preferences: const {'theme_mode_v1': 'dark'},
          ),
          validatePersisted: (_) => throw StateError('injected_validation'),
        ),
        throwsA(isA<StateError>()),
      );

      final snapshot = await repository.readSnapshot();
      expect(snapshot.entities[BusinessEntityKind.assistant]!.single.id, 'old');
      expect(snapshot.preferences['theme_mode_v1'], 'light');
      expect(await repository.hasMigrationReceipt(), isFalse);
    },
  );

  test(
    'rejects unreadable entity payloads and inconsistent projections',
    () async {
      await expectLater(
        repository.upsertEntity(
          BusinessEntityKind.assistant,
          row('bad-json', 0, payload: 'not-json'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.upsertEntity(
          BusinessEntityKind.assistant,
          row('not-map', 0, payload: '[]'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.upsertEntity(
          BusinessEntityKind.assistantMemory,
          row(
            'memory',
            0,
            assistantId: 'assistant-a',
            payload: '{"id":"memory","assistantId":"assistant-b"}',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        await repository.readEntities(BusinessEntityKind.assistant),
        isEmpty,
      );
      expect(
        await repository.readEntities(BusinessEntityKind.assistantMemory),
        isEmpty,
      );
    },
  );

  test('transformSnapshot reads and replaces inside one transaction', () async {
    await repository.replaceSnapshot(
      BusinessSnapshot(
        entities: {
          BusinessEntityKind.assistant: [row('existing', 0)],
        },
        preferences: const {'theme_mode_v1': 'light'},
      ),
    );

    await repository.transformSnapshot((current) {
      expect(current.preferences['theme_mode_v1'], 'light');
      return BusinessSnapshot(
        entities: {
          ...current.entities,
          BusinessEntityKind.assistant: [
            ...current.entities[BusinessEntityKind.assistant]!,
            row('merged', 1),
          ],
        },
        preferences: {...current.preferences, 'theme_mode_v1': 'dark'},
      );
    }, writeReceipt: true);

    final actual = await repository.readSnapshot();
    expect(
      actual.entities[BusinessEntityKind.assistant]!.map((value) => value.id),
      <String>['existing', 'merged'],
    );
    expect(actual.preferences['theme_mode_v1'], 'dark');
    expect(await repository.hasMigrationReceipt(), isTrue);
  });
}
