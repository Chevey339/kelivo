import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/legacy_message_graph_adapter.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:crypto/crypto.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_schema/schema.dart';

void main() {
  test(
    'released legacy projection fixture keeps every frozen digest',
    () async {
      final fixture =
          jsonDecode(
                await File(
                  'test/fixtures/database/legacy_message_graph_v1.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(fixture['format'], 'kelivo-legacy-chat-fixture-v1');
      final conversation = Conversation.fromJson(
        Map<String, dynamic>.from(fixture['conversation'] as Map),
      );
      final messages = _orderedMessages(fixture['messages'] as List);
      final graph = const LegacyMessageGraphAdapter().adapt(
        conversation: conversation,
        messages: messages,
      );
      final expected = Map<String, dynamic>.from(fixture['expected'] as Map);

      expect(graph.activeRevisionIds, expected['activeRevisionIds']);
      expect(graph.contextStartRevisionId, expected['contextStartRevisionId']);
      expect(graph.causalityKind, 'legacy_ambiguous');
      final selectedByGroup = {
        for (final slot in graph.slots) slot.groupKey: slot.selectedRevisionId,
      };
      expect(selectedByGroup['a1'], 'a1-v7');
      expect(
        graph.issues.map((issue) => issue.kind),
        containsAll(['selection_ambiguous', 'truncate_inside_slot']),
      );

      final selectedRevision = {
        for (final slot in graph.slots)
          for (final revision in slot.revisions)
            if (revision.id == slot.selectedRevisionId) revision.id: revision,
      };
      final slotBySelectedRevision = {
        for (final slot in graph.slots) slot.selectedRevisionId: slot,
      };
      final visible = [
        for (final revisionId in graph.activeRevisionIds)
          {
            'revisionId': revisionId,
            'role': slotBySelectedRevision[revisionId]!.role,
            'parts': selectedRevision[revisionId]!.parts
                .map((part) => part.payload)
                .toList(),
          },
      ];
      expect(_digest(visible), expected['visibleDigest']);
      expect(_digest(graph.activeRevisionIds), expected['selectionDigest']);

      final boundaryIndex = graph.activeRevisionIds.indexOf(
        graph.contextStartRevisionId!,
      );
      final prompt = [
        for (final revisionId in graph.activeRevisionIds.skip(boundaryIndex))
          {
            'role': slotBySelectedRevision[revisionId]!.role,
            'content': selectedRevision[revisionId]!.parts
                .where((part) => part.kind == 'text')
                .map((part) => part.payload)
                .join(),
          },
      ];
      expect(_digest(prompt), expected['promptDigest']);
      expect(_digest(fixture['assets']), expected['assetDigest']);

      final recovered = const LegacyMessageGraphAdapter().adaptRecoveredOrphans(
        recoveredConversationId: 'recovered-fixture',
        orphanMessages: _orderedMessages(fixture['orphans'] as List),
      );
      expect(recovered.activeRevisionIds, ['orphan-1']);
      expect(recovered.slots.single.revisions.single.finalizedAt, isNull);
      expect(recovered.issues.single.kind, 'orphan_message');
    },
  );

  test('the frozen SQLite v1 schema produces the same projection', () async {
    final fixture =
        jsonDecode(
              await File(
                'test/fixtures/database/legacy_message_graph_v1.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final conversation = Conversation.fromJson(
      Map<String, dynamic>.from(fixture['conversation'] as Map),
    );
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    addTearDown(schema.close);
    schema.rawDatabase.execute(
      'INSERT INTO conversation_rows ('
      'id, title, created_at, updated_at, is_pinned, truncate_index, '
      'version_selections_json, last_summarized_message_count, '
      'chat_suggestions_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        conversation.id,
        conversation.title,
        conversation.createdAt.millisecondsSinceEpoch ~/ 1000,
        conversation.updatedAt.millisecondsSinceEpoch ~/ 1000,
        0,
        conversation.truncateIndex,
        jsonEncode(conversation.versionSelections),
        0,
        '[]',
      ],
    );
    final fixtureMessages = _orderedMessages(fixture['messages'] as List);
    for (final entry in fixtureMessages) {
      final value = entry.message;
      schema.rawDatabase.execute(
        'INSERT INTO message_rows ('
        'id, conversation_id, role, content, timestamp, is_streaming, '
        'reasoning_text, group_id, version, message_order) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
        [
          value.id,
          value.conversationId,
          value.role,
          value.content,
          value.timestamp.millisecondsSinceEpoch ~/ 1000,
          value.isStreaming ? 1 : 0,
          value.reasoningText,
          value.groupId,
          value.version,
          entry.order,
        ],
      );
    }
    final sqliteMessages = [
      for (final row in schema.rawDatabase.select(
        'SELECT * FROM message_rows ORDER BY message_order, id;',
      ))
        LegacyOrderedMessage(
          order: row['message_order'] as int,
          message: ChatMessage(
            id: row['id'] as String,
            conversationId: row['conversation_id'] as String,
            role: row['role'] as String,
            content: row['content'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (row['timestamp'] as int) * 1000,
              isUtc: true,
            ),
            isStreaming: (row['is_streaming'] as int) != 0,
            reasoningText: row['reasoning_text'] as String?,
            groupId: row['group_id'] as String?,
            version: row['version'] as int,
          ),
        ),
    ];
    final graph = const LegacyMessageGraphAdapter().adapt(
      conversation: conversation,
      messages: sqliteMessages,
    );
    final expected = Map<String, dynamic>.from(fixture['expected'] as Map);

    expect(graph.activeRevisionIds, expected['activeRevisionIds']);
    expect(graph.contextStartRevisionId, expected['contextStartRevisionId']);
    expect(_digest(graph.activeRevisionIds), expected['selectionDigest']);
  });
}

List<LegacyOrderedMessage> _orderedMessages(List<dynamic> values) => [
  for (final raw in values)
    LegacyOrderedMessage(
      order: (raw as Map)['order'] as int,
      message: ChatMessage.fromJson(
        Map<String, dynamic>.from(raw['value'] as Map),
      ),
    ),
];

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
