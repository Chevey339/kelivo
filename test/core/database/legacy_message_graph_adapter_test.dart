import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/legacy_message_graph_adapter.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retired legacy message graph adapter', () {
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(1783784523123456);

  ChatMessage message({
    required String id,
    required String groupId,
    required int version,
    required String role,
    String conversationId = 'conversation-1',
    String? reasoning,
    bool streaming = false,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    groupId: groupId,
    version: version,
    role: role,
    content: 'content-$id',
    timestamp: timestamp.add(Duration(microseconds: version)),
    reasoningText: reasoning,
    isStreaming: streaming,
  );

  test(
    'selection dual interpretation preserves visible ordinal projection',
    () {
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Legacy',
        versionSelections: const {'assistant-group': 1},
      );
      final projection = const LegacyMessageGraphAdapter().adapt(
        conversation: conversation,
        messages: [
          LegacyOrderedMessage(
            message: message(
              id: 'u1',
              groupId: 'user-group',
              version: 0,
              role: 'user',
            ),
            order: 0,
          ),
          LegacyOrderedMessage(
            message: message(
              id: 'a1-v1',
              groupId: 'assistant-group',
              version: 1,
              role: 'assistant',
            ),
            order: 1,
          ),
          LegacyOrderedMessage(
            message: message(
              id: 'a1-v7',
              groupId: 'assistant-group',
              version: 7,
              role: 'assistant',
              reasoning: 'reasoning',
            ),
            order: 2,
          ),
        ],
      );

      expect(projection.activeRevisionIds, ['u1', 'a1-v7']);
      expect(projection.causalityKind, 'legacy_ambiguous');
      final issue = projection.issues.singleWhere(
        (candidate) => candidate.kind == 'selection_ambiguous',
      );
      expect(issue.details['ordinalCandidate'], 'a1-v7');
      expect(issue.details['versionCandidate'], 'a1-v1');
      final alternate = projection.slots.last.revisions.last;
      expect(alternate.parentRevisionId, 'u1');
      expect(alternate.parts.map((part) => part.kind), ['reasoning', 'text']);
    },
  );

  test(
    'invalid selection, duplicate version and truncate ambiguity are issues',
    () {
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Legacy',
        truncateIndex: 1,
        versionSelections: const {'assistant-group': 99},
      );
      final projection = const LegacyMessageGraphAdapter().adapt(
        conversation: conversation,
        messages: [
          LegacyOrderedMessage(
            message: message(
              id: 'a1-first',
              groupId: 'assistant-group',
              version: 3,
              role: 'assistant',
            ),
            order: 0,
          ),
          LegacyOrderedMessage(
            message: message(
              id: 'a1-second',
              groupId: 'assistant-group',
              version: 3,
              role: 'assistant',
              streaming: true,
            ),
            order: 1,
          ),
        ],
      );

      expect(
        projection.issues.map((issue) => issue.kind),
        containsAll([
          'duplicate_version',
          'selection_invalid',
          'truncate_inside_slot',
        ]),
      );
      expect(
        projection.slots.single.revisions.map(
          (revision) => revision.revisionNo,
        ),
        [3, 4],
      );
      expect(projection.slots.single.revisions.last.finalizedAt, isNull);
      expect(
        projection.contextStartRevisionId,
        projection.slots.single.selectedRevisionId,
      );
    },
  );

  test('adapter output and stable IDs are deterministic', () {
    final conversation = Conversation(id: 'conversation-1', title: 'Legacy');
    final input = [
      LegacyOrderedMessage(
        message: message(id: 'u1', groupId: 'u1', version: 0, role: 'user'),
        order: 0,
      ),
    ];
    final first = const LegacyMessageGraphAdapter().adapt(
      conversation: conversation,
      messages: input,
    );
    final second = const LegacyMessageGraphAdapter().adapt(
      conversation: conversation,
      messages: input,
    );

    expect(second.branchId, first.branchId);
    expect(second.slots.single.id, first.slots.single.id);
    expect(second.activeRevisionIds, first.activeRevisionIds);
  });

  test('orphans can be projected into an explicit Recovered conversation', () {
    final orphan = message(
      id: 'orphan-1',
      groupId: 'orphan-1',
      version: 0,
      role: 'assistant',
      conversationId: 'missing-conversation',
    );
    final projection = const LegacyMessageGraphAdapter().adaptRecoveredOrphans(
      recoveredConversationId: 'recovered',
      orphanMessages: [LegacyOrderedMessage(message: orphan, order: 0)],
    );

    expect(projection.conversationId, 'recovered');
    expect(projection.activeRevisionIds, ['orphan-1']);
    expect(projection.causalityKind, 'legacy_ambiguous');
    expect(projection.issues.single.kind, 'orphan_message');
    expect(projection.issues.single.severity, 'recovered');
  });

  test('repository atomically persists projection, parts and issues', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    final repository = ChatDatabaseRepository(database);
    addTearDown(repository.close);
    await repository.ensureReady();
    final conversation = Conversation(
      id: 'conversation-1',
      title: 'Legacy',
      versionSelections: const {'assistant-group': 1},
    );
    await database
        .into(database.conversationRows)
        .insert(
          ConversationRowsCompanion.insert(
            id: conversation.id,
            title: conversation.title,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    final graph = const LegacyMessageGraphAdapter().adapt(
      conversation: conversation,
      messages: [
        LegacyOrderedMessage(
          message: message(
            id: 'a1-v1',
            groupId: 'assistant-group',
            version: 1,
            role: 'assistant',
          ),
          order: 0,
        ),
        LegacyOrderedMessage(
          message: message(
            id: 'a1-v7',
            groupId: 'assistant-group',
            version: 7,
            role: 'assistant',
          ),
          order: 1,
        ),
      ],
    );
    await repository.beginLegacyGraphMigration(
      migrationRunId: 'run-1',
      sourceKind: 'hive',
      sourceHash: 'sha256:fixture',
      startedAt: timestamp,
    );

    final persisted = await repository.putLegacyMessageGraph(
      migrationRunId: 'run-1',
      graph: graph,
    );
    await repository.completeLegacyGraphMigration(
      migrationRunId: 'run-1',
      completedAt: timestamp,
    );

    expect(persisted.revisions.map((revision) => revision.id), ['a1-v7']);
    expect(await database.select(database.messagePartRows).get(), hasLength(2));
    expect(
      (await database.select(database.migrationIssueRows).get()).single.kind,
      'selection_ambiguous',
    );
    expect(
      (await database.select(database.migrationRunRows).getSingle()).status,
      'completed',
    );
  });
  }, skip: 'PD-15 replaced the message graph with the linear model');
}
