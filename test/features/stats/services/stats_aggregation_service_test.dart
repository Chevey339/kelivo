import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/stats/models/stats_models.dart';
import 'package:Kelivo/features/stats/services/stats_aggregation_service.dart';

void main() {
  group('StatsAggregationService', () {
    final now = DateTime(2026, 5, 3, 12);

    Conversation conversation(
      String id, {
      required String title,
      required DateTime createdAt,
      String? assistantId,
      List<String>? messageIds,
    }) {
      return Conversation(
        id: id,
        title: title,
        createdAt: createdAt,
        updatedAt: createdAt,
        assistantId: assistantId,
        messageIds: messageIds ?? const [],
      );
    }

    ChatMessage message(
      String id, {
      required String conversationId,
      required DateTime timestamp,
      String role = 'assistant',
      String? modelId,
      String? providerId,
      int? totalTokens,
      int? promptTokens,
      int? completionTokens,
      int? cachedTokens,
    }) {
      return ChatMessage(
        id: id,
        role: role,
        content: 'message $id',
        timestamp: timestamp,
        conversationId: conversationId,
        modelId: modelId,
        providerId: providerId,
        totalTokens: totalTokens,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        cachedTokens: cachedTokens,
      );
    }

    test(
      'aggregates all-time totals, heatmap, rankings, and provider trend',
      () {
        final conversations = [
          conversation(
            'c1',
            title: 'Alpha topic',
            assistantId: 'a1',
            createdAt: now.subtract(const Duration(days: 4)),
            messageIds: ['m1', 'm2', 'm3'],
          ),
          conversation(
            'c2',
            title: 'Beta topic',
            assistantId: 'a2',
            createdAt: now.subtract(const Duration(days: 40)),
            messageIds: ['m4', 'm5'],
          ),
        ];
        final messagesByConversation = {
          'c1': [
            message(
              'm1',
              conversationId: 'c1',
              timestamp: now.subtract(const Duration(days: 2)),
              role: 'user',
              modelId: 'gpt-5.4-mini',
              providerId: 'openai',
              promptTokens: 10,
            ),
            message(
              'm2',
              conversationId: 'c1',
              timestamp: now.subtract(const Duration(days: 2)),
              modelId: 'gpt-5.4-mini',
              providerId: 'openai',
              completionTokens: 20,
              cachedTokens: 3,
            ),
            message(
              'm3',
              conversationId: 'c1',
              timestamp: now.subtract(const Duration(days: 1)),
              modelId: 'gemini-3-pro-preview',
              providerId: 'google',
              promptTokens: 7,
              completionTokens: 11,
            ),
          ],
          'c2': [
            message(
              'm4',
              conversationId: 'c2',
              timestamp: now.subtract(const Duration(days: 40)),
              modelId: 'mimo-v2-omni',
              providerId: 'mimo',
              promptTokens: 5,
              completionTokens: 9,
              cachedTokens: 1,
            ),
            message(
              'm5',
              conversationId: 'c2',
              timestamp: now.subtract(const Duration(days: 40)),
              role: 'user',
            ),
          ],
        };

        final snapshot = StatsAggregationService.buildSnapshot(
          now: now,
          range: StatsDateRange.allTime(now),
          conversations: conversations,
          messagesByConversation: messagesByConversation,
          launchCount: 12,
          unknownProviderLabel: 'Unknown provider',
          unknownTopicLabel: 'Untitled topic',
          assistantNames: const {'a1': 'Default Assistant', 'a2': 'Research'},
          providerNames: const {
            'openai': 'OpenAI',
            'google': 'Gemini',
            'mimo': 'MiMo',
          },
        );

        expect(snapshot.summary.totalConversations, 2);
        expect(snapshot.summary.totalMessages, 5);
        expect(snapshot.summary.inputTokens, 22);
        expect(snapshot.summary.outputTokens, 40);
        expect(snapshot.summary.cachedTokens, 4);
        expect(snapshot.summary.launchCount, 12);
        expect(snapshot.modelRank.map((e) => (e.id, e.value)).toList(), [
          ('gpt-5.4-mini', 2),
          ('gemini-3-pro-preview', 1),
          ('mimo-v2-omni', 1),
        ]);
        expect(snapshot.modelRank.map((e) => e.providerId).toList(), [
          'openai',
          'google',
          'mimo',
        ]);
        expect(snapshot.assistantRank.map((e) => (e.label, e.value)).toList(), [
          ('Default Assistant', 1),
          ('Research', 1),
        ]);
        expect(snapshot.topicRank.map((e) => (e.label, e.value)).toList(), [
          ('Alpha topic', 3),
          ('Beta topic', 2),
        ]);

        final twoDaysAgo = DateTime(2026, 5, 1);
        final heatCell = snapshot.heatmap.firstWhere(
          (e) => e.date == twoDaysAgo,
        );
        expect(heatCell.count, 2);

        final trendDay = snapshot.trend.firstWhere((e) => e.date == twoDaysAgo);
        expect(trendDay.providerTokens['OpenAI']!.inputTokens, 10);
        expect(trendDay.providerTokens['OpenAI']!.outputTokens, 20);
        expect(trendDay.providerTokens['OpenAI']!.cachedTokens, 3);
      },
    );

    test(
      'filters counters and rankings while all-time trend stays last 30 days',
      () {
        final conversations = [
          conversation(
            'recent',
            title: 'Recent',
            assistantId: 'a1',
            createdAt: now.subtract(const Duration(days: 1)),
            messageIds: ['recent-message'],
          ),
          conversation(
            'old',
            title: 'Old',
            assistantId: 'a2',
            createdAt: now.subtract(const Duration(days: 80)),
            messageIds: ['old-message'],
          ),
        ];
        final messagesByConversation = {
          'recent': [
            message(
              'recent-message',
              conversationId: 'recent',
              timestamp: now.subtract(const Duration(days: 1)),
              modelId: 'recent-model',
              providerId: 'recent-provider',
              promptTokens: 4,
              completionTokens: 6,
            ),
          ],
          'old': [
            message(
              'old-message',
              conversationId: 'old',
              timestamp: now.subtract(const Duration(days: 80)),
              modelId: 'old-model',
              providerId: 'old-provider',
              promptTokens: 100,
              completionTokens: 200,
            ),
          ],
        };

        final last30 = StatsAggregationService.buildSnapshot(
          now: now,
          range: StatsDateRange.last30Days(now),
          conversations: conversations,
          messagesByConversation: messagesByConversation,
          launchCount: 1,
          unknownProviderLabel: 'Unknown provider',
          unknownTopicLabel: 'Untitled topic',
        );

        expect(last30.summary.totalConversations, 1);
        expect(last30.summary.totalMessages, 1);
        expect(last30.summary.inputTokens, 4);
        expect(last30.modelRank.single.id, 'recent-model');

        final allTime = StatsAggregationService.buildSnapshot(
          now: now,
          range: StatsDateRange.allTime(now),
          conversations: conversations,
          messagesByConversation: messagesByConversation,
          launchCount: 1,
          unknownProviderLabel: 'Unknown provider',
          unknownTopicLabel: 'Untitled topic',
        );

        expect(allTime.summary.totalConversations, 2);
        expect(allTime.summary.inputTokens, 104);
        expect(
          allTime.trend.any((d) => d.date == DateTime(2026, 2, 12)),
          false,
        );
      },
    );

    test('keeps heatmap and trend dates aligned across DST boundaries', () {
      final dstNow = DateTime(2026, 3, 10, 12);
      final dstDay = DateTime(2026, 3, 8, 9);
      final conversations = [
        conversation(
          'dst',
          title: 'DST topic',
          createdAt: dstDay,
          messageIds: ['dst-message'],
        ),
      ];
      final messagesByConversation = {
        'dst': [
          message(
            'dst-message',
            conversationId: 'dst',
            timestamp: dstDay,
            providerId: 'openai',
            promptTokens: 3,
            completionTokens: 5,
          ),
        ],
      };

      final snapshot = StatsAggregationService.buildSnapshot(
        now: dstNow,
        range: StatsDateRange.last30Days(dstNow),
        conversations: conversations,
        messagesByConversation: messagesByConversation,
        launchCount: 1,
        unknownProviderLabel: 'Unknown provider',
        unknownTopicLabel: 'Untitled topic',
        providerNames: const {'openai': 'OpenAI'},
      );

      expect(snapshot.range.start, DateTime(2026, 2, 9));
      expect(snapshot.heatmap.length, 365);
      expect(
        snapshot.heatmap.map((day) => day.date),
        contains(DateTime(2026, 3, 8)),
      );
      expect(
        snapshot.heatmap.where(
          (day) => day.date.hour != 0 || day.date.minute != 0,
        ),
        isEmpty,
      );
      expect(
        snapshot.heatmap
            .singleWhere((day) => day.date == DateTime(2026, 3, 8))
            .count,
        1,
      );

      final trendDay = snapshot.trend.singleWhere(
        (day) => day.date == DateTime(2026, 3, 8),
      );
      expect(trendDay.providerTokens['OpenAI']!.inputTokens, 3);
      expect(trendDay.providerTokens['OpenAI']!.outputTokens, 5);
    });

    test('keeps all-time trend dates aligned across DST boundaries', () {
      final dstNow = DateTime(2026, 3, 10, 12);
      final dstDay = DateTime(2026, 3, 8, 9);
      final conversations = [
        conversation(
          'dst',
          title: 'DST topic',
          createdAt: dstDay,
          messageIds: ['dst-message'],
        ),
      ];
      final messagesByConversation = {
        'dst': [
          message(
            'dst-message',
            conversationId: 'dst',
            timestamp: dstDay,
            providerId: 'openai',
            promptTokens: 3,
          ),
        ],
      };

      final snapshot = StatsAggregationService.buildSnapshot(
        now: dstNow,
        range: StatsDateRange.allTime(dstNow),
        conversations: conversations,
        messagesByConversation: messagesByConversation,
        launchCount: 1,
        unknownProviderLabel: 'Unknown provider',
        unknownTopicLabel: 'Untitled topic',
        providerNames: const {'openai': 'OpenAI'},
      );

      final trendDay = snapshot.trend.singleWhere(
        (day) => day.date == DateTime(2026, 3, 8),
      );
      expect(trendDay.providerTokens['OpenAI']!.inputTokens, 3);
      expect(
        snapshot.trend.where(
          (day) => day.date.hour != 0 || day.date.minute != 0,
        ),
        isEmpty,
      );
    });

    test('excludes conversations for assistants that no longer exist', () {
      final conversations = [
        conversation(
          'active',
          title: 'Active topic',
          assistantId: 'a1',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        conversation(
          'deleted',
          title: 'Deleted topic',
          assistantId: '2d111bb3-de7b-4ad6-903d-e09cefd7c933',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final snapshot = StatsAggregationService.buildSnapshot(
        now: now,
        range: StatsDateRange.allTime(now),
        conversations: conversations,
        messagesByConversation: const {},
        launchCount: 1,
        unknownProviderLabel: 'Unknown provider',
        unknownTopicLabel: 'Untitled topic',
        assistantNames: const {'a1': 'Active Assistant'},
        existingAssistantIds: const {'a1'},
      );

      expect(snapshot.summary.totalConversations, 2);
      expect(snapshot.assistantRank.map((e) => e.id).toList(), ['a1']);
      expect(snapshot.assistantRank.single.label, 'Active Assistant');
    });

    test(
      'database snapshot merges duplicate assistant names and hides stale ids',
      () {
        final snapshot = StatsAggregationService.buildDatabaseSnapshot(
          now: now,
          range: StatsDateRange.allTime(now),
          aggregate: const ChatStatsAggregate(
            conversations: 10,
            totals: ChatStatsTotals(
              messages: 0,
              inputTokens: 0,
              outputTokens: 0,
              cachedTokens: 0,
            ),
            heatmap: [],
            trend: [],
            models: [],
            assistants: [
              ChatStatsRank(id: '_default', label: '_default', count: 2),
              ChatStatsRank(id: 'default-id', label: 'default-id', count: 3),
              ChatStatsRank(id: 'research-1', label: 'research-1', count: 1),
              ChatStatsRank(id: 'research-2', label: 'research-2', count: 2),
              ChatStatsRank(
                id: '2d111bb3-de7b-4ad6-903d-e09cefd7c933',
                label: '2d111bb3-de7b-4ad6-903d-e09cefd7c933',
                count: 2,
              ),
            ],
            topics: [],
          ),
          launchCount: 1,
          unknownProviderLabel: 'Unknown provider',
          unknownTopicLabel: 'Untitled topic',
          assistantNames: const {
            '_default': 'Default Assistant',
            'default-id': 'Default Assistant',
            'research-1': 'Research',
            'research-2': 'Research',
          },
        );

        expect(snapshot.assistantRank.map((item) => (item.label, item.value)), [
          ('Default Assistant', 5),
          ('Research', 3),
        ]);
        expect(
          snapshot.assistantRank.map((item) => item.label),
          isNot(contains('2d111bb3-de7b-4ad6-903d-e09cefd7c933')),
        );
      },
    );

    test('uses total tokens as trend fallback for legacy messages', () {
      final conversations = [
        conversation(
          'legacy',
          title: 'Legacy topic',
          createdAt: now.subtract(const Duration(days: 1)),
          messageIds: ['legacy-message'],
        ),
      ];
      final messagesByConversation = {
        'legacy': [
          message(
            'legacy-message',
            conversationId: 'legacy',
            timestamp: now.subtract(const Duration(days: 1)),
            providerId: 'openai',
            totalTokens: 42,
          ),
        ],
      };

      final snapshot = StatsAggregationService.buildSnapshot(
        now: now,
        range: StatsDateRange.allTime(now),
        conversations: conversations,
        messagesByConversation: messagesByConversation,
        launchCount: 1,
        unknownProviderLabel: 'Unknown provider',
        unknownTopicLabel: 'Untitled topic',
        providerNames: const {'openai': 'OpenAI'},
      );

      final trendDay = snapshot.trend.firstWhere(
        (day) => day.date == DateTime(2026, 5, 2),
      );
      expect(trendDay.providerTokens['OpenAI']!.totalTokens, 42);
    });

    test('does not create unknown provider trend rows without token data', () {
      final conversations = [
        conversation(
          'empty-provider',
          title: 'Empty provider topic',
          createdAt: now.subtract(const Duration(days: 1)),
          messageIds: ['empty-provider-message'],
        ),
      ];
      final messagesByConversation = {
        'empty-provider': [
          message(
            'empty-provider-message',
            conversationId: 'empty-provider',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
        ],
      };

      final snapshot = StatsAggregationService.buildSnapshot(
        now: now,
        range: StatsDateRange.allTime(now),
        conversations: conversations,
        messagesByConversation: messagesByConversation,
        launchCount: 1,
        unknownProviderLabel: 'Unknown provider',
        unknownTopicLabel: 'Untitled topic',
      );

      final trendDay = snapshot.trend.firstWhere(
        (day) => day.date == DateTime(2026, 5, 2),
      );
      expect(trendDay.providerTokens, isEmpty);
    });
  });
}
