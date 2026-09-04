import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';

void main() {
  late AppDatabase database;
  late ChatDatabaseRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ChatDatabaseRepository(database);
    await repository.ensureReady();
  });

  tearDown(() => repository.close());

  test('putConversation round-trips extras', () async {
    final conversation = Conversation(
      id: 'c1',
      title: 'Chat',
      extras: const {
        'workspace.id': 'ws-1',
        'workspace.cwd': 'lib',
        'workspace.tools_used': true,
      },
    );
    await repository.putConversation(conversation);
    final loaded = await repository.getConversation('c1');
    expect(loaded, isNotNull);
    expect(loaded!.extras['workspace.id'], 'ws-1');
    expect(loaded.extras['workspace.cwd'], 'lib');
    expect(loaded.extras['workspace.tools_used'], isTrue);
  });

  test('malformed extras_json becomes an empty map', () async {
    await repository.putConversation(Conversation(id: 'c2', title: 'Chat'));
    await database.customStatement(
      "UPDATE conversation_rows SET extras_json = 'not-json' WHERE id = 'c2';",
    );
    final loaded = await repository.getConversation('c2');
    expect(loaded!.extras, isEmpty);
  });

  test(
    'updateConversationExtras writes atomically and bumps updatedAt',
    () async {
      final createdAt = DateTime.utc(2026, 9, 1);
      await repository.putConversation(
        Conversation(
          id: 'c3',
          title: 'Chat',
          createdAt: createdAt,
          updatedAt: createdAt,
          extras: const {'keep': true},
        ),
      );

      await repository.updateConversationExtras('c3', (current) {
        return const WorkspaceBinding(
          workspaceId: 'ws-1',
          cwd: 'src',
        ).applyTo(current);
      });

      final afterBind = await repository.getConversation('c3');
      expect(afterBind!.extras['keep'], isTrue);
      expect(afterBind.extras[WorkspaceBinding.keyId], 'ws-1');
      expect(afterBind.updatedAt.isAfter(createdAt), isTrue);

      final boundUpdatedAt = afterBind.updatedAt;
      await repository.updateConversationExtras('c3', (current) {
        return Map<String, dynamic>.from(current);
      });
      final unchanged = await repository.getConversation('c3');
      expect(unchanged!.updatedAt, boundUpdatedAt);

      await repository.updateConversationExtras('c3', (current) {
        return const WorkspaceBinding().applyTo(current);
      });
      final unbound = await repository.getConversation('c3');
      expect(unbound!.extras.containsKey(WorkspaceBinding.keyId), isFalse);
      expect(unbound.extras['keep'], isTrue);
      expect(unbound.updatedAt.isAfter(boundUpdatedAt), isTrue);
    },
  );

  test('duplicateConversation keeps extras', () async {
    await repository.putConversation(
      Conversation(
        id: 'source',
        title: 'Chat',
        extras: const {'workspace.id': 'ws-1'},
      ),
    );
    final duplicate = await repository.duplicateConversation('source');
    expect(duplicate, isNotNull);
    expect(duplicate!.extras['workspace.id'], 'ws-1');
    expect(duplicate.id, isNot('source'));
  });
}
