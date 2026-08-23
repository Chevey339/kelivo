import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';

void main() {
  late Directory root;
  late ChatDatabaseRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat_parts_roundtrip_');
    repository = ChatDatabaseRepository.open(
      file: File('${root.path}/parts.sqlite'),
    );
    await repository.ensureReady();
  });

  tearDown(() async {
    await repository.close();
    await root.delete(recursive: true);
  });

  test('interleaved reasoning and tool parts keep arrival order', () async {
    final now = DateTime.utc(2026, 8, 16, 12);
    const conversationId = 'conversation-interleaved';
    const messageId = 'message-interleaved';
    final message = ChatMessage(
      id: messageId,
      role: 'assistant',
      conversationId: conversationId,
      timestamp: now,
      parts: const [
        ReasoningPart('plan'),
        TextPart('hello '),
        ToolCallPart('{"id":"call_1","name":"lookup"}'),
        TextPart('world'),
        ImagePart(uri: 'https://example.com/a.png'),
        ReasoningPart('check'),
        ToolCallPart('{"id":"call_2","name":"search"}'),
        TextPart(' done'),
      ],
    );

    await repository.putMigrationBatch(
      conversations: [
        Conversation(
          id: conversationId,
          title: 'Interleaved',
          createdAt: now,
          updatedAt: now,
          messageIds: const [messageId],
        ),
      ],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    final reloaded = await repository.getMessage(messageId);
    expect(reloaded, isNotNull);
    expect(reloaded!.parts.map((part) => part.kind).toList(), [
      'reasoning',
      'text',
      'tool_call',
      'text',
      'image',
      'reasoning',
      'tool_call',
      'text',
    ]);
    expect((reloaded.parts[0] as ReasoningPart).text, 'plan');
    expect((reloaded.parts[1] as TextPart).text, 'hello ');
    expect((reloaded.parts[2] as ToolCallPart).payloadJson, contains('lookup'));
    expect((reloaded.parts[3] as TextPart).text, 'world');
    expect((reloaded.parts[4] as ImagePart).uri, 'https://example.com/a.png');
    expect((reloaded.parts[5] as ReasoningPart).text, 'check');
    expect((reloaded.parts[6] as ToolCallPart).payloadJson, contains('search'));
    expect((reloaded.parts[7] as TextPart).text, ' done');
    expect(reloaded.content, 'hello world done');
    expect(reloaded.reasoningText, 'plan\ncheck');
    expect(await repository.getToolEvents(messageId), [
      {'id': 'call_1', 'name': 'lookup'},
      {'id': 'call_2', 'name': 'search'},
    ]);

    await repository.updateMessage(reloaded);
    final again = await repository.getMessage(messageId);
    expect(again!.parts.map((part) => part.kind).toList(), [
      'reasoning',
      'text',
      'tool_call',
      'text',
      'image',
      'reasoning',
      'tool_call',
      'text',
    ]);
  });

  test('tool event overlay matches existing parts by id', () async {
    final now = DateTime.utc(2026, 8, 16, 13);
    const conversationId = 'conversation-tool-ids';
    const messageId = 'message-tool-ids';
    await repository.putConversation(
      Conversation(
        id: conversationId,
        title: 'Tool ids',
        createdAt: now,
        updatedAt: now,
        messageIds: const [messageId],
      ),
    );
    await repository.putMessage(
      ChatMessage(
        id: messageId,
        role: 'assistant',
        conversationId: conversationId,
        timestamp: now,
        parts: const [
          TextPart('before'),
          ToolCallPart('{"id":"call_b","name":"second","content":"old-b"}'),
          TextPart('mid'),
          ToolCallPart('{"id":"call_a","name":"first","content":"old-a"}'),
        ],
      ),
    );

    await repository.setToolEvents(messageId, [
      {'id': 'call_a', 'name': 'first', 'content': 'new-a'},
      {'id': 'call_b', 'name': 'second', 'content': 'new-b'},
    ]);

    final reloaded = await repository.getMessage(messageId);
    expect(reloaded!.parts.map((part) => part.kind).toList(), [
      'text',
      'tool_call',
      'text',
      'tool_call',
    ]);
    expect(jsonDecode((reloaded.parts[1] as ToolCallPart).payloadJson), {
      'id': 'call_b',
      'name': 'second',
      'content': 'new-b',
    });
    expect(jsonDecode((reloaded.parts[3] as ToolCallPart).payloadJson), {
      'id': 'call_a',
      'name': 'first',
      'content': 'new-a',
    });
  });

  test('text+image+file parts roundtrip preserves order and payload', () async {
    final now = DateTime.utc(2026, 8, 9, 12);
    const conversationId = 'conversation-parts';
    const messageId = 'message-parts';
    final conversation = Conversation(
      id: conversationId,
      title: 'Parts',
      createdAt: now,
      updatedAt: now,
      messageIds: const [messageId],
    );
    final message = ChatMessage(
      id: messageId,
      role: 'user',
      conversationId: conversationId,
      timestamp: now,
      parts: const [
        TextPart('帮我看看'),
        ImagePart(uri: '/tmp/a.png', mime: 'image/png', assetId: 'asset-image'),
        FilePart(
          uri: '/tmp/spec.pdf',
          name: 'spec.pdf',
          mime: 'application/pdf',
          assetId: 'asset-file',
        ),
        TextPart('谢谢'),
      ],
    );

    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    final reloaded = await repository.getMessage(messageId);
    expect(reloaded, isNotNull);
    expect(reloaded!.content, '帮我看看谢谢');
    expect(reloaded.parts, hasLength(4));

    expect(reloaded.parts[0], isA<TextPart>());
    expect((reloaded.parts[0] as TextPart).text, '帮我看看');

    expect(reloaded.parts[1], isA<ImagePart>());
    final image = reloaded.parts[1] as ImagePart;
    expect(image.uri, '/tmp/a.png');
    expect(image.mime, 'image/png');
    expect(image.assetId, 'asset-image');
    expect(image.unavailable, isFalse);

    expect(reloaded.parts[2], isA<FilePart>());
    final file = reloaded.parts[2] as FilePart;
    expect(file.uri, '/tmp/spec.pdf');
    expect(file.name, 'spec.pdf');
    expect(file.mime, 'application/pdf');
    expect(file.assetId, 'asset-file');
    expect(file.unavailable, isFalse);

    expect(reloaded.parts[3], isA<TextPart>());
    expect((reloaded.parts[3] as TextPart).text, '谢谢');

    // Encode payloads must match the domain model contract exactly.
    for (var i = 0; i < message.parts.length; i++) {
      expect(
        reloaded.parts[i].encodePayload(),
        message.parts[i].encodePayload(),
      );
      expect(reloaded.parts[i].kind, message.parts[i].kind);
    }
  });

  test(
    'attachment parts mark asset references dirty without marker strings',
    () async {
      final now = DateTime.utc(2026, 8, 9, 13);
      const conversationId = 'conversation-dirty';
      const messageId = 'message-dirty';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Dirty',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'user',
              conversationId: conversationId,
              timestamp: now,
              parts: const [
                TextPart('plain text only — no markers'),
                ImagePart(uri: '/tmp/b.png', mime: 'image/png'),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      expect(await repository.hasPendingAssetReferenceSync(), isTrue);
    },
  );
  test('appendMessageVersion content-only keeps prior ImagePart', () async {
    final now = DateTime.utc(2026, 8, 9, 14);
    const conversationId = 'conversation-append-parts';
    const messageId = 'message-append-parts';
    await repository.putMigrationBatch(
      conversations: [
        Conversation(
          id: conversationId,
          title: 'Append',
          createdAt: now,
          updatedAt: now,
          messageIds: const [messageId],
        ),
      ],
      messages: [
        (
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: conversationId,
            timestamp: now,
            groupId: messageId,
            version: 0,
            parts: const [
              ImagePart(uri: '/tmp/keep.png', mime: 'image/png'),
              TextPart('original caption'),
            ],
          ),
          messageOrder: 0,
        ),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    final result = await repository.appendMessageVersion(
      messageId: messageId,
      content: 'edited caption',
    );
    expect(result, isNotNull);
    final persisted = await repository.getMessage(result!.message.id);
    expect(persisted, isNotNull);
    expect(persisted!.content, 'edited caption');
    expect(persisted.parts, hasLength(2));
    expect(persisted.parts[0], isA<ImagePart>());
    expect((persisted.parts[0] as ImagePart).uri, '/tmp/keep.png');
    expect((persisted.parts[0] as ImagePart).mime, 'image/png');
    expect(persisted.parts[1], isA<TextPart>());
    expect((persisted.parts[1] as TextPart).text, 'edited caption');
  });

  test(
    'appendMessageVersion content-only keeps interleaved TextPart slots',
    () async {
      final now = DateTime.utc(2026, 8, 9, 14);
      const conversationId = 'conversation-append-interleave';
      const messageId = 'message-append-interleave';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Append interleave',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              conversationId: conversationId,
              timestamp: now,
              groupId: messageId,
              version: 0,
              parts: const [
                TextPart('我查一下'),
                ToolCallPart('{"id":"search","name":"search"}'),
                TextPart('结果是 X'),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final result = await repository.appendMessageVersion(
        messageId: messageId,
        content: '我查一下结果是 X',
      );
      expect(result, isNotNull);
      final persisted = await repository.getMessage(result!.message.id);
      expect(persisted!.parts.map((part) => part.kind), [
        'text',
        'tool_call',
        'text',
      ]);
      expect((persisted.parts[0] as TextPart).text, '我查一下');
      expect((persisted.parts[2] as TextPart).text, '结果是 X');
    },
  );

  test(
    'appendMessageVersion content-only keeps collapsed assistant reasoning',
    () async {
      final now = DateTime.utc(2026, 8, 22, 12);
      const conversationId = 'conversation-append-reasoning';
      const messageId = 'message-append-reasoning';
      const reasoningJson =
          '{"v":2,"segments":[{"text":"plan then check","expanded":false,'
          '"toolStartIndex":0}],"contentSplits":{"offsets":[5],'
          '"reasoningCounts":[1],"toolCounts":[1]},'
          '"reasoningDetails":[{"id":"rd_1","type":"reasoning.encrypted",'
          '"data":"sig","format":"anthropic-claude-v1"}]}';
      final reasoningStart = DateTime.utc(2026, 8, 22, 11, 59);
      final reasoningFinished = DateTime.utc(2026, 8, 22, 12);
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Append reasoning',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              conversationId: conversationId,
              timestamp: now,
              groupId: messageId,
              version: 0,
              totalTokens: 42,
              translation: 'old translation',
              reasoningText: 'plan then check',
              reasoningStartAt: reasoningStart,
              reasoningFinishedAt: reasoningFinished,
              reasoningSegmentsJson: reasoningJson,
              parts: const [
                ReasoningPart('plan then check'),
                TextPart('original answer'),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final result = await repository.appendMessageVersion(
        messageId: messageId,
        content: 'edited answer',
      );
      expect(result, isNotNull);
      final created = result!.message;
      expect(created.content, 'edited answer');
      expect(created.parts.map((part) => part.kind), ['reasoning', 'text']);
      expect((created.parts[0] as ReasoningPart).text, 'plan then check');
      expect((created.parts[1] as TextPart).text, 'edited answer');
      expect(created.reasoningText, 'plan then check');
      expect(
        created.reasoningStartAt?.millisecondsSinceEpoch,
        reasoningStart.millisecondsSinceEpoch,
      );
      expect(
        created.reasoningFinishedAt?.millisecondsSinceEpoch,
        reasoningFinished.millisecondsSinceEpoch,
      );
      expect(created.reasoningSegmentsJson, reasoningJson);
      expect(created.translation, isNull);
      expect(created.totalTokens, isNull);

      final persisted = await repository.getMessage(created.id);
      expect(persisted, isNotNull);
      expect(persisted!.content, 'edited answer');
      expect(persisted.parts.map((part) => part.kind), ['reasoning', 'text']);
      expect((persisted.parts[0] as ReasoningPart).text, 'plan then check');
      expect(persisted.reasoningText, 'plan then check');
      expect(
        persisted.reasoningStartAt?.millisecondsSinceEpoch,
        reasoningStart.millisecondsSinceEpoch,
      );
      expect(
        persisted.reasoningFinishedAt?.millisecondsSinceEpoch,
        reasoningFinished.millisecondsSinceEpoch,
      );
      expect(persisted.reasoningSegmentsJson, reasoningJson);
      expect(persisted.translation, isNull);
      expect(persisted.totalTokens, isNull);
    },
  );

  test(
    'appendMessageVersion content-only keeps interleaved reasoning tool text',
    () async {
      final now = DateTime.utc(2026, 8, 22, 13);
      const conversationId = 'conversation-append-reasoning-interleave';
      const messageId = 'message-append-reasoning-interleave';
      const reasoningJson =
          '{"v":2,"segments":['
          '{"text":"plan","expanded":false,"toolStartIndex":0},'
          '{"text":"check","expanded":false,"toolStartIndex":1}'
          '],"contentSplits":{"offsets":[6,11],'
          '"reasoningCounts":[1,2],"toolCounts":[1,1]},'
          '"reasoningDetails":[{"id":"rd_2","type":"reasoning.encrypted",'
          '"data":"sig2","format":"anthropic-claude-v1"}]}';
      final reasoningStart = DateTime.utc(2026, 8, 22, 12, 50);
      final reasoningFinished = DateTime.utc(2026, 8, 22, 13);
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Append reasoning interleave',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              conversationId: conversationId,
              timestamp: now,
              groupId: messageId,
              version: 0,
              reasoningText: 'plan\ncheck',
              reasoningStartAt: reasoningStart,
              reasoningFinishedAt: reasoningFinished,
              reasoningSegmentsJson: reasoningJson,
              parts: const [
                ReasoningPart('plan'),
                TextPart('hello '),
                ToolCallPart('{"id":"call_1","name":"lookup"}'),
                TextPart('world'),
                ReasoningPart('check'),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final result = await repository.appendMessageVersion(
        messageId: messageId,
        content: 'hello world',
      );
      expect(result, isNotNull);
      expect(result!.message.parts.map((part) => part.kind), [
        'reasoning',
        'text',
        'tool_call',
        'text',
        'reasoning',
      ]);
      expect((result.message.parts[0] as ReasoningPart).text, 'plan');
      expect((result.message.parts[4] as ReasoningPart).text, 'check');
      expect(result.message.reasoningText, 'plan\ncheck');
      expect(
        result.message.reasoningStartAt?.millisecondsSinceEpoch,
        reasoningStart.millisecondsSinceEpoch,
      );
      expect(
        result.message.reasoningFinishedAt?.millisecondsSinceEpoch,
        reasoningFinished.millisecondsSinceEpoch,
      );
      expect(result.message.reasoningSegmentsJson, reasoningJson);

      final persisted = await repository.getMessage(result.message.id);
      expect(persisted!.parts.map((part) => part.kind), [
        'reasoning',
        'text',
        'tool_call',
        'text',
        'reasoning',
      ]);
      expect((persisted.parts[1] as TextPart).text, 'hello ');
      expect((persisted.parts[3] as TextPart).text, 'world');
      expect(persisted.reasoningSegmentsJson, reasoningJson);
    },
  );

  test(
    'appendMessageVersion explicit parts does not inherit reasoning metadata',
    () async {
      final now = DateTime.utc(2026, 8, 22, 14);
      const conversationId = 'conversation-append-explicit-parts';
      const messageId = 'message-append-explicit-parts';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Append explicit parts',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              conversationId: conversationId,
              timestamp: now,
              groupId: messageId,
              version: 0,
              reasoningText: 'old plan',
              reasoningStartAt: DateTime.utc(2026, 8, 22, 13, 50),
              reasoningFinishedAt: now,
              reasoningSegmentsJson:
                  '{"segments":[{"text":"old plan","expanded":false}]}',
              parts: const [ReasoningPart('old plan'), TextPart('old answer')],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final result = await repository.appendMessageVersion(
        messageId: messageId,
        content: 'replacement',
        parts: const [TextPart('replacement')],
      );
      expect(result, isNotNull);
      expect(result!.message.parts, hasLength(1));
      expect(result.message.parts.single, isA<TextPart>());
      expect(result.message.reasoningText, isNull);
      expect(result.message.reasoningStartAt, isNull);
      expect(result.message.reasoningFinishedAt, isNull);
      expect(result.message.reasoningSegmentsJson, isNull);
    },
  );

  test(
    'unknown future_widget part persists and writes back unchanged',
    () async {
      final now = DateTime.utc(2026, 8, 9, 14);
      const conversationId = 'conversation-unknown';
      const messageId = 'message-unknown';
      const unknownPayload = '{"widget":"chart","v":2}';
      final message = ChatMessage(
        id: messageId,
        role: 'assistant',
        conversationId: conversationId,
        timestamp: now,
        parts: const [
          TextPart('hello'),
          UnknownPart(rawKind: 'future_widget', payload: unknownPayload),
        ],
      );

      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Unknown',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final reloaded = await repository.getMessage(messageId);
      expect(reloaded, isNotNull);
      expect(reloaded!.parts, hasLength(2));
      expect(reloaded.parts[1], isA<UnknownPart>());
      final unknown = reloaded.parts[1] as UnknownPart;
      expect(unknown.kind, 'future_widget');
      expect(unknown.rawKind, 'future_widget');
      expect(unknown.payload, unknownPayload);
      expect(unknown.encodePayload(), unknownPayload);

      // Write back unchanged.
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Unknown',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [(message: reloaded, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final again = await repository.getMessage(messageId);
      expect(again, isNotNull);
      expect(again!.parts[1], isA<UnknownPart>());
      expect(again.parts[1].kind, 'future_widget');
      expect(again.parts[1].encodePayload(), unknownPayload);

      final raw = sqlite.sqlite3.open('${root.path}/parts.sqlite');
      try {
        final rows = raw.select(
          "SELECT kind, payload FROM message_part_rows "
          "WHERE revision_id = '$messageId' ORDER BY ordinal;",
        );
        expect(rows.map((row) => row['kind']).toList(), [
          'text',
          'future_widget',
        ]);
        expect(rows[1]['payload'], unknownPayload);
      } finally {
        raw.close();
      }
    },
  );

  test(
    'malformed attachment is isolated and survives an edited message write-back',
    () async {
      final now = DateTime.utc(2026, 8, 10, 10);
      const conversationId = 'conversation-malformed';
      const malformedId = 'message-malformed';
      const healthyId = 'message-healthy';
      const malformedPayload = '{"uri":"/tmp/corrupt.png",broken';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Malformed',
            createdAt: now,
            updatedAt: now,
            messageIds: const [malformedId, healthyId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: malformedId,
              role: 'user',
              conversationId: conversationId,
              timestamp: now,
              parts: const [
                TextPart('before'),
                ImagePart(uri: '/tmp/corrupt.png'),
                TextPart('after'),
              ],
            ),
            messageOrder: 0,
          ),
          (
            message: ChatMessage(
              id: healthyId,
              role: 'assistant',
              conversationId: conversationId,
              timestamp: now,
              content: 'healthy',
            ),
            messageOrder: 1,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final raw = sqlite.sqlite3.open('${root.path}/parts.sqlite');
      try {
        raw.execute(
          'UPDATE message_part_rows SET payload = ? '
          'WHERE revision_id = ? AND ordinal = 1;',
          [malformedPayload, malformedId],
        );
        raw.execute(
          'DELETE FROM asset_reference_dirty_rows WHERE revision_id = ?;',
          [malformedId],
        );
      } finally {
        raw.close();
      }

      final single = await repository.getMessage(malformedId);
      expect(single, isNotNull);
      expect(single!.content, 'beforeafter');
      expect(single.parts, hasLength(3));
      expect(single.parts[0], isA<TextPart>());
      expect(single.parts[1], isA<MalformedPart>());
      expect(single.parts[2], isA<TextPart>());
      final malformed = single.parts[1] as MalformedPart;
      expect(malformed.rawKind, 'image');
      expect(malformed.rawPayload, malformedPayload);
      expect(malformed.isAttachmentKind, isTrue);

      final batch = await repository.getMessagesRange(
        conversationId,
        start: 0,
        limit: 10,
      );
      expect(batch, hasLength(2));
      expect(batch[0].parts[1], isA<MalformedPart>());
      expect(batch[1].content, 'healthy');

      await repository.updateMessage(single.copyWith(content: 'edited'));

      final persisted = sqlite.sqlite3.open('${root.path}/parts.sqlite');
      try {
        final row = persisted.select(
          'SELECT ordinal, kind, payload FROM message_part_rows '
          'WHERE revision_id = ? AND kind = ?;',
          [malformedId, 'image'],
        ).single;
        expect(row['ordinal'], 1);
        expect(row['payload'], malformedPayload);
        expect(
          persisted.select(
            'SELECT 1 FROM asset_reference_dirty_rows '
            'WHERE revision_id = ?;',
            [malformedId],
          ).length,
          1,
        );
      } finally {
        persisted.close();
      }
    },
  );

  test(
    'attachment payload validation paginates and reports progress',
    () async {
      final now = DateTime.utc(2026, 8, 10, 11);
      const conversationId = 'conversation-validation-progress';
      const messageId = 'message-validation-progress';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Validation progress',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'user',
              conversationId: conversationId,
              timestamp: now,
              parts: [
                for (var i = 0; i < 257; i++) ImagePart(uri: '/tmp/$i.png'),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final progress = <({int processed, int total})>[];
      await repository.validateAttachmentPartPayloads(
        onProgress: (processed, total) {
          progress.add((processed: processed, total: total));
        },
      );

      expect(progress.first, (processed: 0, total: 257));
      expect(progress, contains((processed: 256, total: 257)));
      expect(progress.last, (processed: 257, total: 257));
    },
  );

  test(
    'attachment payload validation enforces a byte budget per page',
    () async {
      final now = DateTime.utc(2026, 8, 10, 12);
      const conversationId = 'conversation-validation-byte-budget';
      const messageId = 'message-validation-byte-budget';
      final inlineBody = List.filled(1100000, 'A').join();
      final inlineUri = 'data:image/png;base64,$inlineBody';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Validation byte budget',
            createdAt: now,
            updatedAt: now,
            messageIds: const [messageId],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'user',
              conversationId: conversationId,
              timestamp: now,
              parts: [
                ImagePart(uri: inlineUri),
                ImagePart(uri: inlineUri),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final progress = <({int processed, int total})>[];
      final metadataWindows = <int>[];
      await repository.validateAttachmentPartPayloads(
        onProgress: (processed, total) {
          progress.add((processed: processed, total: total));
        },
        onMetadataWindow: metadataWindows.add,
      );

      expect(metadataWindows, [2]);
      expect(progress, [
        (processed: 0, total: 2),
        (processed: 1, total: 2),
        (processed: 2, total: 2),
      ]);
    },
  );
}
