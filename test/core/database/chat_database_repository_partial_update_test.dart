import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  late Directory root;
  late ChatDatabaseRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat_partial_update_');
    repository = ChatDatabaseRepository.open(
      file: File('${root.path}/partial.sqlite'),
    );
  });

  tearDown(() async {
    await repository.close();
    await root.delete(recursive: true);
  });

  Future<ChatMessage> seedMessage({
    String conversationId = 'conversation-1',
    String messageId = 'message-1',
    List<String> mcpServerIds = const <String>[],
    List<Map<String, dynamic>> toolEvents = const <Map<String, dynamic>>[],
  }) async {
    final now = DateTime.utc(2026, 7, 12);
    final conversation = Conversation(
      id: conversationId,
      title: 'Conversation',
      createdAt: now,
      updatedAt: now,
      messageIds: [messageId],
      mcpServerIds: mcpServerIds,
    );
    final message = ChatMessage(
      id: messageId,
      role: 'assistant',
      content: 'original content',
      timestamp: now,
      conversationId: conversationId,
      reasoningText: 'original reasoning',
      totalTokens: 10,
      durationMs: 100,
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: {messageId: toolEvents},
      geminiSignaturesByMessageId: const {},
    );
    return message;
  }

  test('partial update writes only the given fields', () async {
    final message = await seedMessage(
      toolEvents: const [
        {'id': 'tool-1', 'content': 'tool output'},
      ],
    );

    final updated = await repository.updateMessageFields(
      message.id,
      translation: 'translated',
    );

    expect(updated, isNotNull);
    expect(updated!.translation, 'translated');
    expect(updated.content, 'original content');
    expect(updated.reasoningText, 'original reasoning');
    expect(updated.totalTokens, 10);
    expect(updated.durationMs, 100);

    final reloaded = await repository.getMessage(message.id);
    expect(reloaded!.translation, 'translated');
    expect(reloaded.content, 'original content');
    // A translation-only update must not touch the persisted parts.
    expect(await repository.getToolEvents(message.id), [
      {'id': 'tool-1', 'content': 'tool output'},
    ]);
  });

  test('concurrent disjoint updates do not clobber each other', () async {
    final message = await seedMessage();

    // Mirrors the translation-write vs. image-sanitization collision pair:
    // each writer updates its own columns only, so both must survive.
    final results = await Future.wait([
      repository.updateMessageFields(message.id, translation: 'translated'),
      repository.updateMessageFields(message.id, content: 'sanitized content'),
    ]);
    expect(results.every((result) => result != null), isTrue);

    final reloaded = await repository.getMessage(message.id);
    expect(reloaded!.translation, 'translated');
    expect(reloaded.content, 'sanitized content');
    expect(reloaded.reasoningText, 'original reasoning');
  });

  test('content update rebuilds parts and preserves tool events', () async {
    final message = await seedMessage(
      toolEvents: const [
        {'id': 'tool-1', 'content': 'tool output'},
      ],
    );

    final updated = await repository.updateMessageFields(
      message.id,
      content: 'rewritten content',
    );
    expect(updated!.content, 'rewritten content');

    final reloaded = await repository.getMessage(message.id);
    expect(reloaded!.content, 'rewritten content');
    expect(reloaded.reasoningText, 'original reasoning');
    expect(await repository.getToolEvents(message.id), [
      {'id': 'tool-1', 'content': 'tool output'},
    ]);
  });

  test('returns null when the message does not exist', () async {
    expect(
      await repository.updateMessageFields('missing', translation: 't'),
      isNull,
    );
  });

  test(
    'summaries match full loads field-by-field with ordered MCP ids',
    () async {
      final now = DateTime.utc(2026, 7, 12);
      final conversations = [
        Conversation(
          id: 'c-1',
          title: 'One',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 3)),
          mcpServerIds: const ['server-a', 'server-b'],
          isPinned: true,
          assistantId: 'assistant-1',
          truncateIndex: 2,
          versionSelections: const {'slot': 1},
          summary: 'summary',
          lastSummarizedMessageCount: 4,
          chatSuggestions: const ['hint'],
        ),
        Conversation(
          id: 'c-2',
          title: 'Two',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
        Conversation(
          id: 'c-3',
          title: 'Three',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
          mcpServerIds: const ['server-c'],
        ),
      ];
      await repository.putMigrationBatch(
        conversations: conversations,
        messages: const [],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final summaries = await repository.getAllConversationSummaries();
      final full = await repository.getAllConversations();

      expect(summaries.map((c) => c.id), full.map((c) => c.id));
      for (var i = 0; i < summaries.length; i++) {
        final summary = summaries[i];
        final reference = full[i];
        expect(summary.messageIds, isEmpty);
        expect(summary.title, reference.title);
        expect(summary.createdAt, reference.createdAt);
        expect(summary.updatedAt, reference.updatedAt);
        expect(summary.isPinned, reference.isPinned);
        expect(summary.mcpServerIds, reference.mcpServerIds);
        expect(summary.assistantId, reference.assistantId);
        expect(summary.truncateIndex, reference.truncateIndex);
        expect(summary.versionSelections, reference.versionSelections);
        expect(summary.summary, reference.summary);
        expect(
          summary.lastSummarizedMessageCount,
          reference.lastSummarizedMessageCount,
        );
        expect(summary.chatSuggestions, reference.chatSuggestions);
      }
      expect(summaries.firstWhere((c) => c.id == 'c-1').mcpServerIds, [
        'server-a',
        'server-b',
      ]);
    },
  );
}
