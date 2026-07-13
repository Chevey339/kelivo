import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/database/chat_database_repository.dart';
import '../models/stats_models.dart';

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
  }) {
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
        totalMessages: aggregate.selectedVersions.messages,
        inputTokens: aggregate.selectedVersions.inputTokens,
        outputTokens: aggregate.selectedVersions.outputTokens,
        cachedTokens: aggregate.selectedVersions.cachedTokens,
        launchCount: launchCount,
        allRevisionMessages: aggregate.allRevisions.messages,
        allRevisionInputTokens: aggregate.allRevisions.inputTokens,
        allRevisionOutputTokens: aggregate.allRevisions.outputTokens,
        allRevisionCachedTokens: aggregate.allRevisions.cachedTokens,
      ),
      heatmap: _buildHeatmap(now, heatmapCounts),
      trend: [
        for (final entry in trendBuckets.entries)
          StatsTrendDay(
            date: entry.key,
            providerTokens: Map.unmodifiable(entry.value),
          ),
      ],
      modelRank: [
        for (final row in aggregate.models)
          StatsRankItem(
            id: row.id,
            label: row.label,
            value: row.count,
            providerId: row.providerId,
          ),
      ],
      assistantRank: [
        for (final row in aggregate.assistants)
          StatsRankItem(
            id: row.id,
            label: assistantNames[row.id] ?? row.label,
            value: row.count,
          ),
      ],
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
  }) {
    final rangeMessages = <ChatMessage>[];
    final heatmapCounts = <DateTime, int>{};
    final modelCounts = <String, int>{};
    final modelProviders = <String, String>{};
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
          modelCounts[modelId] = (modelCounts[modelId] ?? 0) + 1;
          final providerId = message.providerId?.trim();
          if (providerId != null && providerId.isNotEmpty) {
            modelProviders.putIfAbsent(modelId, () => providerId);
          }
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

    return StatsSnapshot(
      range: range,
      summary: StatsSummary(
        totalConversations: filteredConversationCount,
        totalMessages: rangeMessages.length,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cachedTokens: cachedTokens,
        launchCount: launchCount,
      ),
      heatmap: _buildHeatmap(now, heatmapCounts),
      trend: trend,
      modelRank: _rank(
        modelCounts,
        (id) => id,
        providerFor: (id) => modelProviders[id],
      ),
      assistantRank: _rank(assistantCounts, (id) => assistantNames[id] ?? id),
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
        final legacyTotalTokens = message.totalTokens ?? 0;
        final cachedTokens = message.cachedTokens ?? 0;
        final uncategorizedTokens =
            inputTokens == 0 && outputTokens == 0 && legacyTotalTokens > 0
            ? legacyTotalTokens
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
    String Function(String id) labelFor, {
    String? Function(String id)? providerFor,
  }) {
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
          providerId: providerFor?.call(entry.key),
        ),
    ];
  }
}
