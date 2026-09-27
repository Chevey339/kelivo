import '../../../core/database/chat_database_repository.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/utils/model_cost.dart';
import '../models/stats_models.dart';

typedef ModelPricingLookup =
    ModelPricing? Function(String? providerKey, String modelId);

class StatsAggregationService {
  static StatsSnapshot buildDatabaseSnapshot({
    required DateTime now,
    required StatsDateRange range,
    required ChatStatsAggregate aggregate,
    required int launchCount,
    required String unknownProviderLabel,
    required String unknownTopicLabel,
    Map<String, String> assistantNames = const {},
    Map<String, String> providerNames = const {},
    ModelPricingLookup? resolvePricing,
  }) {
    final assistantCounts = <String, int>{};
    for (final row in aggregate.assistants) {
      assistantCounts[row.id] = (assistantCounts[row.id] ?? 0) + row.count;
    }
    final heatmapCounts = {
      for (final row in aggregate.heatmap) row.day: row.count,
    };
    final trendRange = _trendRange(now, range);
    final trendBuckets = <DateTime, Map<String, StatsTokenBucket>>{
      for (
        var day = trendRange.start;
        !day.isAfter(trendRange.end);
        day = StatsDateRange.addCalendarDays(day, 1)
      )
        day: <String, StatsTokenBucket>{},
    };
    final modelRank = [
      for (final row in aggregate.models)
        StatsRankItem(
          id: row.id,
          label: row.label,
          value: row.count,
          providerId: row.providerId,
          cost: estimateModelCost(
            TokenUsage(
              promptTokens: row.inputTokens,
              completionTokens: row.outputTokens,
              cachedTokens: row.cachedTokens,
              cacheWriteTokens: row.cacheWriteTokens,
            ),
            resolvePricing?.call(row.providerId, row.id),
          ),
        ),
    ];
    final costs = _summarizeCosts(modelRank);

    for (final row in aggregate.trend) {
      final providerLabel = row.providerId == '_unknown'
          ? unknownProviderLabel
          : (providerNames[row.providerId] ?? row.providerId);
      trendBuckets[row.day]![providerLabel] = StatsTokenBucket(
        inputTokens: row.inputTokens,
        outputTokens: row.outputTokens,
        cachedTokens: row.cachedTokens,
        uncategorizedTokens: row.uncategorizedTokens,
        activityCount: row.activityCount,
      );
    }
    return StatsSnapshot(
      range: range,
      summary: StatsSummary(
        totalConversations: aggregate.conversations,
        totalMessages: aggregate.totals.messages,
        inputTokens: aggregate.totals.inputTokens,
        outputTokens: aggregate.totals.outputTokens,
        cachedTokens: aggregate.totals.cachedTokens,
        launchCount: launchCount,
        costByCurrency: costs.costByCurrency,
        modelsWithoutPricing: costs.modelsWithoutPricing,
      ),
      heatmap: _buildHeatmap(now, heatmapCounts),
      trend: [
        for (final entry in trendBuckets.entries)
          StatsTrendDay(
            date: entry.key,
            providerTokens: Map.unmodifiable(entry.value),
          ),
      ],
      modelRank: modelRank,
      assistantRank: _assistantRank(
        assistantCounts,
        assistantNames,
        hideUnresolved: assistantNames.isNotEmpty,
      ),
      topicRank: [
        for (final row in aggregate.topics)
          StatsRankItem(
            id: row.id,
            label: row.label.trim().isEmpty ? unknownTopicLabel : row.label,
            value: row.count,
          ),
      ],
    );
  }

  static StatsSnapshot buildSnapshot({
    required DateTime now,
    required StatsDateRange range,
    required List<Conversation> conversations,
    required Map<String, List<ChatMessage>> messagesByConversation,
    required int launchCount,
    required String unknownProviderLabel,
    required String unknownTopicLabel,
    Map<String, String> assistantNames = const {},
    Set<String>? existingAssistantIds,
    Map<String, String> providerNames = const {},
    ModelPricingLookup? resolvePricing,
  }) {
    final rangeMessages = <ChatMessage>[];
    final heatmapCounts = <DateTime, int>{};
    final modelCounts = <(String?, String), int>{};
    final modelTokens = <(String?, String), TokenUsage>{};
    final assistantCounts = <String, int>{};
    final topicCounts = <String, int>{};
    final topicLabels = <String, String>{};

    var inputTokens = 0;
    var outputTokens = 0;
    var cachedTokens = 0;

    for (final conversation in conversations) {
      final messages = messagesByConversation[conversation.id] ?? const [];
      if (range.contains(conversation.createdAt)) {
        final assistantId = conversation.assistantId?.trim().isNotEmpty == true
            ? conversation.assistantId!.trim()
            : '_default';
        final assistantExists =
            existingAssistantIds == null ||
            assistantId == '_default' ||
            existingAssistantIds.contains(assistantId);
        if (assistantExists) {
          assistantCounts[assistantId] =
              (assistantCounts[assistantId] ?? 0) + 1;
        }
      }

      for (final message in messages) {
        final messageDate = StatsDateRange.normalizeDate(message.timestamp);
        heatmapCounts[messageDate] = (heatmapCounts[messageDate] ?? 0) + 1;

        if (!range.contains(message.timestamp)) continue;

        rangeMessages.add(message);
        inputTokens += message.promptTokens ?? 0;
        outputTokens += message.completionTokens ?? 0;
        cachedTokens += message.cachedTokens ?? 0;

        final modelId = message.modelId?.trim();
        if (modelId != null && modelId.isNotEmpty) {
          final providerId = message.providerId?.trim();
          final key = (providerId == '' ? null : providerId, modelId);
          modelCounts[key] = (modelCounts[key] ?? 0) + 1;
          final previous = modelTokens[key] ?? const TokenUsage();
          modelTokens[key] = TokenUsage(
            promptTokens: previous.promptTokens + (message.promptTokens ?? 0),
            completionTokens:
                previous.completionTokens + (message.completionTokens ?? 0),
            cachedTokens: previous.cachedTokens + (message.cachedTokens ?? 0),
            cacheWriteTokens:
                previous.cacheWriteTokens + (message.cacheWriteTokens ?? 0),
          );
        }

        topicCounts[conversation.id] = (topicCounts[conversation.id] ?? 0) + 1;
        final topicTitle = conversation.title.trim();
        topicLabels[conversation.id] = topicTitle.isEmpty
            ? unknownTopicLabel
            : topicTitle;
      }
    }

    final filteredConversationCount = conversations
        .where((conversation) => range.contains(conversation.createdAt))
        .length;

    final trendRange = _trendRange(now, range);
    final trend = _buildTrend(
      trendRange: trendRange,
      conversations: conversations,
      messagesByConversation: messagesByConversation,
      providerNames: providerNames,
      unknownProviderLabel: unknownProviderLabel,
    );

    final modelRank = [
      for (final entry in modelCounts.entries)
        StatsRankItem(
          id: entry.key.$2,
          label: entry.key.$2,
          value: entry.value,
          providerId: entry.key.$1,
          cost: estimateModelCost(
            modelTokens[entry.key]!,
            resolvePricing?.call(entry.key.$1, entry.key.$2),
          ),
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final costs = _summarizeCosts(modelRank);

    return StatsSnapshot(
      range: range,
      summary: StatsSummary(
        totalConversations: filteredConversationCount,
        totalMessages: rangeMessages.length,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cachedTokens: cachedTokens,
        launchCount: launchCount,
        costByCurrency: costs.costByCurrency,
        modelsWithoutPricing: costs.modelsWithoutPricing,
      ),
      heatmap: _buildHeatmap(now, heatmapCounts),
      trend: trend,
      modelRank: modelRank,
      assistantRank: _assistantRank(
        assistantCounts,
        assistantNames,
        existingAssistantIds: existingAssistantIds,
      ),
      topicRank: _rank(topicCounts, (id) => topicLabels[id] ?? id),
    );
  }

  static ({DateTime start, DateTime end}) _trendRange(
    DateTime now,
    StatsDateRange range,
  ) {
    final today = StatsDateRange.normalizeDate(now);
    if (range.isAllTime) {
      return (start: StatsDateRange.addCalendarDays(today, -29), end: today);
    }
    return (
      start: range.start ?? StatsDateRange.addCalendarDays(today, -29),
      end: range.end ?? today,
    );
  }

  static List<StatsHeatmapDay> _buildHeatmap(
    DateTime now,
    Map<DateTime, int> counts,
  ) {
    final today = StatsDateRange.normalizeDate(now);
    final start = StatsDateRange.addCalendarDays(today, -364);
    final days = <StatsHeatmapDay>[];
    for (
      var date = start;
      !date.isAfter(today);
      date = StatsDateRange.addCalendarDays(date, 1)
    ) {
      days.add(StatsHeatmapDay(date: date, count: counts[date] ?? 0));
    }
    return days;
  }

  static List<StatsTrendDay> _buildTrend({
    required ({DateTime start, DateTime end}) trendRange,
    required List<Conversation> conversations,
    required Map<String, List<ChatMessage>> messagesByConversation,
    required Map<String, String> providerNames,
    required String unknownProviderLabel,
  }) {
    final buckets = <DateTime, Map<String, StatsTokenBucket>>{};
    for (
      var date = trendRange.start;
      !date.isAfter(trendRange.end);
      date = StatsDateRange.addCalendarDays(date, 1)
    ) {
      buckets[date] = <String, StatsTokenBucket>{};
    }

    for (final conversation in conversations) {
      final messages = messagesByConversation[conversation.id] ?? const [];
      for (final message in messages) {
        final date = StatsDateRange.normalizeDate(message.timestamp);
        if (date.isBefore(trendRange.start) || date.isAfter(trendRange.end)) {
          continue;
        }
        final inputTokens = message.promptTokens ?? 0;
        final outputTokens = message.completionTokens ?? 0;
        final totalTokens = message.totalTokens ?? 0;
        final cachedTokens = message.cachedTokens ?? 0;
        final knownTokens = inputTokens + outputTokens;
        final uncategorizedTokens = totalTokens > knownTokens
            ? totalTokens - knownTokens
            : 0;
        final providerId = message.providerId?.trim();
        if ((providerId == null || providerId.isEmpty) &&
            inputTokens == 0 &&
            outputTokens == 0 &&
            cachedTokens == 0 &&
            uncategorizedTokens == 0) {
          continue;
        }
        final providerLabel = providerId == null || providerId.isEmpty
            ? unknownProviderLabel
            : (providerNames[providerId] ?? providerId);
        final dayBuckets = buckets[date]!;
        final previous = dayBuckets[providerLabel] ?? const StatsTokenBucket();
        dayBuckets[providerLabel] = previous.add(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          cachedTokens: cachedTokens,
          uncategorizedTokens: uncategorizedTokens,
          activityCount: 1,
        );
      }
    }

    return [
      for (final entry in buckets.entries)
        StatsTrendDay(
          date: entry.key,
          providerTokens: Map.unmodifiable(entry.value),
        ),
    ];
  }

  static List<StatsRankItem> _rank(
    Map<String, int> counts,
    String Function(String id) labelFor,
  ) {
    final entries = counts.entries.toList();
    entries.sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) return byValue;
      return 0;
    });
    return [
      for (final entry in entries)
        StatsRankItem(
          id: entry.key,
          label: labelFor(entry.key),
          value: entry.value,
        ),
    ];
  }

  static ({Map<String, double> costByCurrency, int modelsWithoutPricing})
  _summarizeCosts(List<StatsRankItem> modelRank) {
    final byCurrency = <String, double>{};
    var missing = 0;
    for (final item in modelRank) {
      final cost = item.cost;
      if (cost == null) {
        missing++;
        continue;
      }
      byCurrency[cost.currency] =
          (byCurrency[cost.currency] ?? 0) + cost.amount;
    }
    return (
      costByCurrency: Map.unmodifiable(byCurrency),
      modelsWithoutPricing: missing,
    );
  }

  static List<StatsRankItem> _assistantRank(
    Map<String, int> counts,
    Map<String, String> assistantNames, {
    Set<String>? existingAssistantIds,
    bool hideUnresolved = false,
  }) {
    final valuesByLabel = <String, int>{};
    final representativeIdByLabel = <String, String>{};
    final representativeValueByLabel = <String, int>{};

    for (final entry in counts.entries) {
      final id = entry.key;
      final isDefault = id == '_default';
      final isKnown = assistantNames.containsKey(id);
      if (!isDefault &&
          existingAssistantIds != null &&
          !existingAssistantIds.contains(id)) {
        continue;
      }
      if (!isDefault && hideUnresolved && !isKnown) continue;

      final resolvedLabel = assistantNames[id]?.trim();
      final label = resolvedLabel == null || resolvedLabel.isEmpty
          ? id
          : resolvedLabel;
      valuesByLabel[label] = (valuesByLabel[label] ?? 0) + entry.value;
      final representativeValue = representativeValueByLabel[label];
      if (representativeValue == null || entry.value > representativeValue) {
        representativeIdByLabel[label] = id;
        representativeValueByLabel[label] = entry.value;
      }
    }

    final items = [
      for (final entry in valuesByLabel.entries)
        StatsRankItem(
          id: representativeIdByLabel[entry.key]!,
          label: entry.key,
          value: entry.value,
        ),
    ];
    items.sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) return byValue;
      return a.label.compareTo(b.label);
    });
    return items;
  }
}
