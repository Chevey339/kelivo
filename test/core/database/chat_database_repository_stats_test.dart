import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/features/stats/models/stats_models.dart';
import 'package:Kelivo/features/stats/services/stats_aggregation_service.dart';

void main() {
  test(
    'mixed usage keeps uncategorized tokens in SQL and memory trends',
    () async {
      final root = await Directory.systemTemp.createTemp('chat_stats_mixed_');
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/stats.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime(2026, 9, 27, 12);
      final conversation = Conversation(
        id: 'c',
        title: 'Usage',
        createdAt: now,
        updatedAt: now,
      );
      final mixed =
          const TokenUsage(totalTokens: 120) +
          const TokenUsage(
            promptTokens: 200,
            completionTokens: 30,
            cachedTokens: 60,
          );
      const smallerTotal = TokenUsage(
        promptTokens: 200,
        completionTokens: 30,
        totalTokens: 150,
      );
      final usages = [
        ('mixed', mixed),
        ('totalOnly', const TokenUsage(totalTokens: 120)),
        (
          'exact',
          const TokenUsage(
            promptTokens: 200,
            completionTokens: 30,
            totalTokens: 230,
          ),
        ),
        ('smallerTotal', smallerTotal),
        (
          'missingTotal',
          const TokenUsage(promptTokens: 200, completionTokens: 30),
        ),
        // Clamp per message before summing: a low total cannot cancel a different
        // message's unclassified usage in the same provider/day bucket.
        ('perMessage', mixed),
        ('perMessage', smallerTotal),
      ];
      final messages = [
        for (var i = 0; i < usages.length; i++)
          ChatMessage(
            id: 'm$i',
            role: 'assistant',
            conversationId: 'c',
            timestamp: now,
            providerId: usages[i].$1,
            totalTokens: usages[i].$2.toJson()['totalTokens'] as int?,
            promptTokens: usages[i].$2.promptTokens,
            completionTokens: usages[i].$2.completionTokens,
            cachedTokens: usages[i].$2.cachedTokens,
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
        heatmapStart: DateTime(2026, 1, 1),
        trendStart: DateTime(2026, 9, 27),
        trendEndExclusive: DateTime(2026, 9, 28),
      );
      final range = StatsDateRange.allTime(now);
      final snapshots = {
        'SQL': StatsAggregationService.buildDatabaseSnapshot(
          now: now,
          range: range,
          aggregate: aggregate,
          launchCount: 0,
          unknownProviderLabel: '?',
          unknownTopicLabel: '?',
        ),
        'memory': StatsAggregationService.buildSnapshot(
          now: now,
          range: range,
          conversations: [conversation],
          messagesByConversation: {'c': messages},
          launchCount: 0,
          unknownProviderLabel: '?',
          unknownTopicLabel: '?',
        ),
      };
      const expected = {
        'mixed': (350, 120, 60),
        'totalOnly': (120, 120, 0),
        'exact': (230, 0, 0),
        'smallerTotal': (230, 0, 0),
        'missingTotal': (230, 0, 0),
        'perMessage': (580, 120, 60),
      };
      expect(
        {
          for (final entry in snapshots.entries)
            entry.key: {
              for (final bucket
                  in entry.value.trend.last.providerTokens.entries)
                bucket.key: (
                  bucket.value.totalTokens,
                  bucket.value.uncategorizedTokens,
                  bucket.value.cachedTokens,
                ),
            },
        },
        {'SQL': expected, 'memory': expected},
      );
    },
  );

  test(
    'finish usage survives reload while stats and cost use all requests',
    () async {
      final root = await Directory.systemTemp.createTemp('chat_stats_turn_');
      final file = File('${root.path}/stats.sqlite');
      var repository = ChatDatabaseRepository.open(file: file);
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime(2026, 9, 27, 12);
      final conversation = Conversation(
        id: 'c',
        title: 'Usage',
        createdAt: now,
        updatedAt: now,
      );
      const finish = TokenUsage(
        promptTokens: 200,
        completionTokens: 30,
        cachedTokens: 60,
      );
      final message = ChatMessage(
        id: 'm',
        role: 'assistant',
        content: 'done',
        timestamp: now,
        conversationId: 'c',
        modelId: 'model',
        providerId: 'provider',
        totalTokens: 350,
        promptTokens: 300,
        completionTokens: 50,
        cachedTokens: 70,
        cacheWriteTokens: 30,
        reasoningTokens: 5,
        finishUsage: finish,
        durationMs: 5000,
        firstTokenMs: 1250,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      expect(
        (await repository.getMessage('m'))!.finishUsage!.toJson(),
        finish.toJson(),
      );
      expect((await repository.getMessage('m'))!.firstTokenMs, 1250);
      // The JSON path is also used by message exports and backups.
      final exported = ChatMessage.fromJson(
        message.toJson(),
      ).copyWith(content: 'edited');
      expect(exported.firstTokenMs, 1250);
      await repository.updateMessage(exported);
      await repository.updateMessage(exported.copyWith(firstTokenMs: 1500));
      await repository.updateMessageFields('m', translation: 'translation');
      await repository.close();
      repository = ChatDatabaseRepository.open(file: file);
      final restored = (await repository.getMessage('m'))!;
      expect(restored.finishUsage!.toJson(), finish.toJson());
      expect(restored.firstTokenMs, 1500);
      expect(restored.durationMs, 5000);
      expect(restored.totalTokens, 350);
      expect(restored.content, 'edited');
      expect(restored.translation, 'translation');
      final aggregate = await repository.queryStatsAggregate(
        rangeStart: null,
        rangeEndExclusive: null,
        heatmapStart: now.subtract(const Duration(days: 365)),
        trendStart: DateTime(2026, 9, 27),
        trendEndExclusive: DateTime(2026, 9, 28),
      );
      const pricing = ModelPricing(
        input: 1,
        output: 2,
        cacheRead: 0.1,
        cacheWrite: 1.25,
      );
      final range = StatsDateRange.allTime(now);
      final snapshots = [
        StatsAggregationService.buildDatabaseSnapshot(
          now: now,
          range: range,
          aggregate: aggregate,
          launchCount: 1,
          unknownProviderLabel: '?',
          unknownTopicLabel: '?',
          resolvePricing: (_, _) => pricing,
        ),
        StatsAggregationService.buildSnapshot(
          now: now,
          range: range,
          conversations: [conversation],
          messagesByConversation: {
            'c': [restored],
          },
          launchCount: 1,
          unknownProviderLabel: '?',
          unknownTopicLabel: '?',
          resolvePricing: (_, _) => pricing,
        ),
      ];
      for (final snapshot in snapshots) {
        expect(snapshot.summary.inputTokens, 300);
        expect(snapshot.summary.outputTokens, 50);
        expect(snapshot.summary.cachedTokens, 70);
        expect(
          snapshot.summary.costByCurrency['USD'],
          closeTo(0.0003445, 1e-12),
        );
        expect(snapshot.modelRank.single.value, 1);
      }
    },
  );

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
