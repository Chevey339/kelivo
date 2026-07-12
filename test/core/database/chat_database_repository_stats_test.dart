import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  test('SQL stats separate active branch from all revision usage', () async {
    final root = await Directory.systemTemp.createTemp('chat_stats_test_');
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/stats.sqlite'),
    );
    addTearDown(() async {
      await repository.close();
      await root.delete(recursive: true);
    });
    final now = DateTime(2026, 7, 12, 12);
    final conversation = Conversation(
      id: 'conversation-1',
      title: 'Stats',
      createdAt: now,
      updatedAt: now,
      messageIds: const ['assistant-v1', 'assistant-v2'],
      versionSelections: const {'assistant-slot': 2},
    );
    ChatMessage revision(String id, int version, int tokens) => ChatMessage(
      id: id,
      role: 'assistant',
      content: id,
      timestamp: now,
      conversationId: conversation.id,
      groupId: 'assistant-slot',
      version: version,
      modelId: 'model-a',
      providerId: 'provider-a',
      promptTokens: tokens,
      completionTokens: tokens * 2,
      cachedTokens: version,
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [
        (message: revision('assistant-v1', 1, 10), messageOrder: 0),
        (message: revision('assistant-v2', 2, 20), messageOrder: 1),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.backfillMissingMessageGraphs();

    final aggregate = await repository.queryStatsAggregate(
      rangeStart: DateTime(2026, 7, 12),
      rangeEndExclusive: DateTime(2026, 7, 13),
      heatmapStart: DateTime(2025, 7, 13),
      trendStart: DateTime(2026, 7, 12),
      trendEndExclusive: DateTime(2026, 7, 13),
    );

    expect(aggregate.conversations, 1);
    expect(aggregate.active.messages, 1);
    expect(aggregate.active.inputTokens, 20);
    expect(aggregate.active.outputTokens, 40);
    expect(aggregate.allRevisions.messages, 2);
    expect(aggregate.allRevisions.inputTokens, 30);
    expect(aggregate.allRevisions.outputTokens, 60);
    expect(aggregate.models.single.count, 1);
    expect(aggregate.topics.single.count, 1);
    expect(aggregate.trend.single.activityCount, 1);
  });
}
