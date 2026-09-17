import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/features/stats/models/stats_models.dart';
import 'package:Kelivo/features/stats/services/stats_aggregation_service.dart';

void main() {
  test(
    'SQL and in-memory costs keep same-name models separate by provider',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chat_stats_providers_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/stats.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime(2026, 7, 12, 12);
      final conversation = Conversation(
        id: 'c',
        title: 'Stats',
        createdAt: now,
        updatedAt: now,
      );
      final messages = [
        for (final provider in ['a-usd', 'b-cny', 'c-missing'])
          ChatMessage(
            id: provider,
            role: 'assistant',
            content: 'reply',
            timestamp: now,
            conversationId: 'c',
            modelId: 'same-model',
            providerId: provider,
            promptTokens: 1000000,
          ),
      ];
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [
          for (var i = 0; i < messages.length; i++)
            (message: messages[i], messageOrder: i),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final aggregate = await repository.queryStatsAggregate(
        rangeStart: null,
        rangeEndExclusive: null,
        heatmapStart: DateTime(2025, 7, 13),
        trendStart: DateTime(2026, 7, 12),
        trendEndExclusive: DateTime(2026, 7, 13),
      );
      expect(
        aggregate.models.map(
          (row) => (row.id, row.providerId, row.inputTokens),
        ),
        [
          ('same-model', 'a-usd', 1000000),
          ('same-model', 'b-cny', 1000000),
          ('same-model', 'c-missing', 1000000),
        ],
      );
      ModelPricing? pricing(String? provider, String model) =>
          switch (provider) {
            'a-usd' => const ModelPricing(input: 1, output: 0),
            'b-cny' => const ModelPricing(
              input: 10,
              output: 0,
              currency: 'CNY',
            ),
            _ => null,
          };
      final range = StatsDateRange.allTime(now);
      final snapshots = [
        StatsAggregationService.buildDatabaseSnapshot(
          now: now,
          range: range,
          aggregate: aggregate,
          launchCount: 1,
          unknownProviderLabel: '?',
          unknownTopicLabel: '?',
          resolvePricing: pricing,
        ),
        StatsAggregationService.buildSnapshot(
          now: now,
          range: range,
          conversations: [conversation],
          messagesByConversation: {'c': messages},
          launchCount: 1,
          unknownProviderLabel: '?',
          unknownTopicLabel: '?',
          resolvePricing: pricing,
        ),
      ];
      for (final snapshot in snapshots) {
        expect(snapshot.summary.costByCurrency, {'USD': 1.0, 'CNY': 10.0});
        expect(snapshot.summary.modelsWithoutPricing, 1);
        expect(snapshot.modelRank, hasLength(3));
        expect(snapshot.modelRank.map((item) => item.providerId).toSet(), {
          'a-usd',
          'b-cny',
          'c-missing',
        });
      }
    },
  );

  test('SQL stats count every message version in one usage total', () async {
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

    final aggregate = await repository.queryStatsAggregate(
      rangeStart: DateTime(2026, 7, 12),
      rangeEndExclusive: DateTime(2026, 7, 13),
      heatmapStart: DateTime(2025, 7, 13),
      trendStart: DateTime(2026, 7, 12),
      trendEndExclusive: DateTime(2026, 7, 13),
    );

    expect(aggregate.conversations, 1);
    expect(aggregate.totals.messages, 2);
    expect(aggregate.totals.inputTokens, 30);
    expect(aggregate.totals.outputTokens, 60);
    expect(aggregate.models.single.count, 2);
    expect(aggregate.topics.single.count, 2);
    expect(aggregate.trend.single.activityCount, 2);
  });

  test('SQL stats omit empty-provider activity without token data', () async {
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
      messageIds: const ['user-message'],
    );
    final message = ChatMessage(
      id: 'user-message',
      role: 'user',
      content: 'hello',
      timestamp: now,
      conversationId: conversation.id,
      providerId: '',
      totalTokens: 0,
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    final aggregate = await repository.queryStatsAggregate(
      rangeStart: DateTime(2026, 7, 12),
      rangeEndExclusive: DateTime(2026, 7, 13),
      heatmapStart: DateTime(2025, 7, 13),
      trendStart: DateTime(2026, 7, 12),
      trendEndExclusive: DateTime(2026, 7, 13),
    );

    expect(aggregate.totals.messages, 1);
    expect(aggregate.trend, isEmpty);
  });
}
