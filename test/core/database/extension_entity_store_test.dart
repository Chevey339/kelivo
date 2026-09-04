import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(database);
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() => database.close());

  test('upsert, list, get, and delete', () async {
    await store.upsert('workspace', 'ws-1', {
      'id': 'ws-1',
      'name': 'One',
    }, sortOrder: 1);
    await store.upsert(
      'workspace',
      'ws-2',
      {'id': 'ws-2', 'name': 'Two'},
      sortOrder: 0,
      ownerId: 'assistant-1',
    );
    await store.upsert('skill', 'skill-1', {'id': 'skill-1'});

    final workspaces = await store.listByKind('workspace');
    expect(workspaces.map((e) => e.id), <String>['ws-2', 'ws-1']);
    expect(workspaces.first.ownerId, 'assistant-1');
    expect(workspaces.first.payload['name'], 'Two');

    final fetched = await store.get('workspace', 'ws-1');
    expect(fetched, isNotNull);
    expect(fetched!.payload['name'], 'One');

    await store.upsert('workspace', 'ws-1', {'id': 'ws-1', 'name': 'Renamed'});
    expect((await store.get('workspace', 'ws-1'))!.payload['name'], 'Renamed');
    expect((await store.get('workspace', 'ws-1'))!.sortOrder, 1);

    await store.delete('workspace', 'ws-1');
    expect(await store.get('workspace', 'ws-1'), isNull);
    expect(await store.listByKind('workspace'), hasLength(1));
  });

  test('watchKind emits the current rows and later mutations', () async {
    final events = <List<ExtensionEntity>>[];
    final subscription = store.watchKind('workspace').listen(events.add);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, isNotEmpty);
    expect(events.last, isEmpty);

    await store.upsert('workspace', 'ws-1', {'id': 'ws-1'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.last, hasLength(1));
    expect(events.last.single.id, 'ws-1');

    await store.delete('workspace', 'ws-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.last, isEmpty);

    await subscription.cancel();
  });
}
