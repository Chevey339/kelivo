import 'dart:async';
import '../../../shared/widgets/ios_date_picker.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/database/chat_database_repository.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../home/widgets/assistant_avatar.dart';
import '../../home/widgets/model_icon.dart';
import '../models/stats_models.dart';
import '../services/stats_aggregation_service.dart';
import '../widgets/stats_heatmap.dart';
import '../widgets/stats_metric_grid.dart';
import '../widgets/stats_rank_section.dart';
import '../widgets/stats_section_card.dart';
import '../widgets/stats_usage_chart.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.snapshotOverride, this.showAppBar = true});

  final StatsSnapshot? snapshotOverride;
  final bool showAppBar;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late StatsDateRange _range;
  StatsSnapshot? _databaseSnapshot;
  String? _statsSignature;
  String? _pendingStatsSignature;
  String? _failedStatsSignature;
  bool _loadingStats = false;
  int _statsRequestId = 0;

  @override
  void initState() {
    super.initState();
    _range =
        widget.snapshotOverride?.range ??
        StatsDateRange.allTime(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = widget.snapshotOverride ?? _buildSnapshot(context);
    final assistantById = widget.snapshotOverride == null
        ? {
            for (final assistant
                in context.watch<AssistantProvider>().assistants)
              assistant.id: assistant,
          }
        : <String, Assistant>{};
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _RangeSelector(
          selected: _range.preset,
          onChanged: _setPreset,
          onCustom: _pickCustomRange,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 2,
          child: widget.snapshotOverride == null && _loadingStats
              ? LinearProgressIndicator(
                  minHeight: 2,
                  semanticsLabel: l10n.settingsPageCalculating,
                )
              : null,
        ),
        const SizedBox(height: 10),
        StatsSectionCard(
          title: l10n.statsPageHeatmapTitle,
          child: StatsHeatmap(days: snapshot.heatmap),
        ),
        const SizedBox(height: 12),
        StatsSectionCard(
          title: l10n.statsPageSummaryTitle,
          child: StatsMetricGrid(summary: snapshot.summary),
        ),
        const SizedBox(height: 12),
        StatsSectionCard(
          title: l10n.statsPageUsageTrendTitle,
          child: StatsUsageChart(days: snapshot.trend),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final sections = [
              StatsRankSection(
                title: l10n.statsPageModelUsageTitle,
                leftHeader: l10n.statsPageModelColumn,
                rightHeader: l10n.statsPageMessagesColumn,
                items: snapshot.modelRank,
                leadingBuilder: (context, item) => CurrentModelIcon(
                  key: ValueKey('stats-model-icon-${item.id}'),
                  providerKey: item.providerId,
                  modelId: item.id,
                  size: 32,
                  withBackground: false,
                ),
              ),
              StatsRankSection(
                title: l10n.statsPageAssistantUsageTitle,
                leftHeader: l10n.statsPageAssistantColumn,
                rightHeader: l10n.statsPageTopicsColumn,
                items: snapshot.assistantRank,
                leadingBuilder: (context, item) => AssistantAvatar(
                  key: ValueKey('stats-assistant-avatar-${item.id}'),
                  assistant: assistantById[item.id],
                  fallbackName: item.label,
                  size: 20,
                ),
              ),
              StatsRankSection(
                title: l10n.statsPageTopicVolumeTitle,
                leftHeader: l10n.statsPageTopicColumn,
                rightHeader: l10n.statsPageMessagesColumn,
                items: snapshot.topicRank,
                icon: Lucide.MessageSquare,
              ),
            ];
            if (!wide) {
              return Column(
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    sections[i],
                    if (i != sections.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  Expanded(child: sections[i]),
                  if (i != sections.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
      ],
    );

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            minSize: 44,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.statsPageTitle),
      ),
      body: body,
    );
  }

  StatsSnapshot _buildSnapshot(BuildContext context) {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    final chatService = context.watch<ChatService>();
    final settings = context.watch<SettingsProvider>();
    final assistantProvider = context.watch<AssistantProvider>();
    final conversations = chatService.getAllCompleteConversations();
    final assistantNames = {
      for (final assistant in assistantProvider.assistants)
        assistant.id: assistant.name.trim().isEmpty
            ? l10n.statsPageUnknownAssistant
            : assistant.name.trim(),
      '_default': l10n.statsPageUnknownAssistant,
    };
    final providerNames = {
      for (final entry in settings.providerConfigs.entries)
        entry.key: entry.value.name,
    };
    final conversationSignature = conversations
        .map(
          (conversation) =>
              '${conversation.id}:${conversation.updatedAt.microsecondsSinceEpoch}:'
              '${conversation.createdAt.microsecondsSinceEpoch}:'
              '${conversation.assistantId ?? '_default'}:'
              // Signature-only: -1 sentinel is safe here. Real stats come from
              // loadStatsAggregate; once counts settle, signature changes and
              // triggers one recompute.
              '${chatService.getMessageCount(conversation.id)}',
        )
        .join('|');
    final signature =
        '$conversationSignature|${_range.preset.name}:'
        '${_range.start}:${_range.end}:${settings.appLaunchCount}:'
        '${_mapSignature(providerNames)}:${_mapSignature(assistantNames)}:'
        '${chatService.statisticsRevision}';
    if (_failedStatsSignature != null && _failedStatsSignature != signature) {
      _failedStatsSignature = null;
    }
    if (_statsSignature == signature &&
        _pendingStatsSignature != null &&
        _pendingStatsSignature != signature) {
      _statsRequestId++;
      _pendingStatsSignature = null;
      _loadingStats = false;
    } else if (_statsSignature != signature &&
        _pendingStatsSignature != signature &&
        _failedStatsSignature != signature) {
      _loadingStats = true;
      _pendingStatsSignature = signature;
      final requestId = ++_statsRequestId;
      final requestedRange = _range;
      final requestedAssistantNames = Map<String, String>.of(assistantNames);
      final requestedProviderNames = Map<String, String>.of(providerNames);
      final rangeStart = requestedRange.start;
      final rangeEndExclusive = requestedRange.end == null
          ? null
          : StatsDateRange.addCalendarDays(requestedRange.end!, 1);
      final today = StatsDateRange.normalizeDate(now);
      final trendStart = requestedRange.isAllTime
          ? StatsDateRange.addCalendarDays(today, -29)
          : (requestedRange.start ??
                StatsDateRange.addCalendarDays(today, -29));
      final trendEnd = StatsDateRange.addCalendarDays(
        requestedRange.isAllTime ? today : (requestedRange.end ?? today),
        1,
      );
      unawaited(
        chatService
            .loadStatsAggregate(
              rangeStart: rangeStart,
              rangeEndExclusive: rangeEndExclusive,
              heatmapStart: StatsDateRange.addCalendarDays(today, -364),
              trendStart: trendStart,
              trendEndExclusive: trendEnd,
            )
            .then(
              (aggregate) {
                if (!mounted || requestId != _statsRequestId) return;
                setState(() {
                  _databaseSnapshot =
                      StatsAggregationService.buildDatabaseSnapshot(
                        now: now,
                        range: requestedRange,
                        aggregate: aggregate,
                        launchCount: settings.appLaunchCount,
                        assistantNames: requestedAssistantNames,
                        providerNames: requestedProviderNames,
                        unknownProviderLabel: l10n.statsPageUnknownProvider,
                        unknownTopicLabel: l10n.statsPageUnknownTopic,
                      );
                  _statsSignature = signature;
                  _pendingStatsSignature = null;
                  _failedStatsSignature = null;
                  _loadingStats = false;
                });
              },
              onError: (Object _, StackTrace __) {
                if (!mounted || requestId != _statsRequestId) return;
                setState(() {
                  _pendingStatsSignature = null;
                  _failedStatsSignature = signature;
                  _loadingStats = false;
                });
              },
            ),
      );
    }
    return _databaseSnapshot ??
        StatsAggregationService.buildDatabaseSnapshot(
          now: now,
          range: _range,
          aggregate: const ChatStatsAggregate(
            conversations: 0,
            totals: ChatStatsTotals(
              messages: 0,
              inputTokens: 0,
              outputTokens: 0,
              cachedTokens: 0,
            ),
            heatmap: [],
            trend: [],
            models: [],
            assistants: [],
            topics: [],
          ),
          launchCount: settings.appLaunchCount,
          assistantNames: assistantNames,
          providerNames: providerNames,
          unknownProviderLabel: l10n.statsPageUnknownProvider,
          unknownTopicLabel: l10n.statsPageUnknownTopic,
        );
  }

  String _mapSignature(Map<String, String> values) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}=${entry.value}').join(',');
  }

  void _setPreset(StatsDateRangePreset preset) {
    final now = DateTime.now();
    setState(() {
      _range = switch (preset) {
        StatsDateRangePreset.allTime => StatsDateRange.allTime(now),
        StatsDateRangePreset.last30Days => StatsDateRange.last30Days(now),
        StatsDateRangePreset.previousMonth => StatsDateRange.previousMonth(now),
        StatsDateRangePreset.previousQuarter => StatsDateRange.previousQuarter(
          now,
        ),
        StatsDateRangePreset.custom => _range,
      };
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final end = StatsDateRange.normalizeDate(now);
    final start = StatsDateRange.addCalendarDays(end, -29);
    final initialRange = DateTimeRange(
      start: _range.start ?? start,
      end: _range.end ?? end,
    );
    final selected = await _showCustomRangePicker(
      context,
      initialRange: initialRange,
      firstDate: DateTime(2000),
      lastDate: end,
    );
    if (selected == null) return;
    setState(() {
      _range = StatsDateRange.custom(selected.start, selected.end);
    });
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.onChanged,
    required this.onCustom,
  });

  final StatsDateRangePreset selected;
  final ValueChanged<StatsDateRangePreset> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (StatsDateRangePreset.allTime, l10n.statsPageRangeAllTime),
      (StatsDateRangePreset.last30Days, l10n.statsPageRangeLast30Days),
      (StatsDateRangePreset.previousMonth, l10n.statsPageRangePreviousMonth),
      (
        StatsDateRangePreset.previousQuarter,
        l10n.statsPageRangePreviousQuarter,
      ),
      (StatsDateRangePreset.custom, l10n.statsPageRangeCustom),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _RangeButton(
              label: options[i].$2,
              selected: selected == options[i].$1,
              onTap: () {
                if (options[i].$1 == StatsDateRangePreset.custom) {
                  onCustom();
                } else {
                  onChanged(options[i].$1);
                }
              },
            ),
            if (i != options.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

Future<DateTimeRange?> _showCustomRangePicker(
  BuildContext context, {
  required DateTimeRange initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final isDesktopWidth = MediaQuery.sizeOf(context).width >= 720;
  if (isDesktopWidth) {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: _CustomRangeSheet(
          initialRange: initialRange,
          firstDate: firstDate,
          lastDate: lastDate,
          desktop: true,
        ),
      ),
    );
  }
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomRangeSheet(
      initialRange: initialRange,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground = cs.onSurface.withValues(
      alpha: isDark ? 0.16 : 0.14,
    );
    final idleBackground = context.appColors.surfaceFill;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 32,
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedBackground : idleBackground,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? cs.onSurface.withValues(alpha: 0.9)
                  : cs.onSurface.withValues(alpha: isDark ? 0.7 : 0.62),
              fontSize: 12,
              fontWeight: selected
                  ? AppFontWeights.emphasis
                  : AppFontWeights.semibold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomRangeSheet extends StatefulWidget {
  const _CustomRangeSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    this.desktop = false,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool desktop;

  @override
  State<_CustomRangeSheet> createState() => _CustomRangeSheetState();
}

class _CustomRangeSheetState extends State<_CustomRangeSheet> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = StatsDateRange.normalizeDate(widget.initialRange.start);
    _end = StatsDateRange.normalizeDate(widget.initialRange.end);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final content = Container(
      width: widget.desktop ? 420 : double.infinity,
      margin: widget.desktop
          ? EdgeInsets.zero
          : EdgeInsets.only(left: 12, right: 12, bottom: 12 + bottomInset),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(widget.desktop ? 18 : 22),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.statsPageCustomRangeTitle,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.92),
                    fontSize: 15,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
              ),
              IosIconButton(
                icon: Lucide.X,
                size: 18,
                padding: const EdgeInsets.all(7),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: l10n.statsPageCustomRangeStart,
                  date: _start,
                  onTap: () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: l10n.statsPageCustomRangeEnd,
                  date: _end,
                  onTap: () => _pickDate(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: IosCardPress(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(13),
                  baseColor: cs.onSurface.withValues(
                    alpha: isDark ? 0.08 : 0.09,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      l10n.statsPageCustomRangeCancel,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.74),
                        fontSize: 13,
                        fontWeight: AppFontWeights.emphasis,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IosCardPress(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(DateTimeRange(start: _start, end: _end)),
                  borderRadius: BorderRadius.circular(13),
                  baseColor: cs.onSurface.withValues(
                    alpha: isDark ? 0.16 : 0.14,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      l10n.statsPageCustomRangeApply,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.desktop) return content;
    return SafeArea(top: false, child: content);
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _start : _end;
    final selected = await showIosDatePicker(
      context,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      initialDate: initial,
    );
    if (selected == null) return;
    final date = StatsDateRange.normalizeDate(selected);
    setState(() {
      if (start) {
        _start = date;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = date;
        if (_start.isAfter(_end)) _start = _end;
      }
    });
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      baseColor: cs.onSurface.withValues(alpha: isDark ? 0.07 : 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('yyyy-MM-dd').format(date),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: AppFontWeights.emphasis,
            ),
          ),
        ],
      ),
    );
  }
}
