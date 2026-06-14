import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.snapshotOverride, this.showAppBar = true});

  final StatsSnapshot? snapshotOverride;
  final bool showAppBar;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late StatsDateRange _range;

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
        const SizedBox(height: 12),
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
    final conversations = chatService.getAllConversations();
    final messagesByConversation = {
      for (final conversation in conversations)
        conversation.id: chatService.getMessages(conversation.id),
    };
    final assistantNames = {
      for (final assistant in assistantProvider.assistants)
        assistant.id: assistant.name,
      '_default': l10n.statsPageUnknownAssistant,
    };
    final existingAssistantIds = {
      for (final assistant in assistantProvider.assistants) assistant.id,
      '_default',
    };
    final providerNames = {
      for (final entry in settings.providerConfigs.entries)
        entry.key: entry.value.name,
    };
    return StatsAggregationService.buildSnapshot(
      now: now,
      range: _range,
      conversations: conversations,
      messagesByConversation: messagesByConversation,
      launchCount: settings.appLaunchCount,
      assistantNames: assistantNames,
      existingAssistantIds: existingAssistantIds,
      providerNames: providerNames,
      unknownProviderLabel: l10n.statsPageUnknownProvider,
      unknownTopicLabel: l10n.statsPageUnknownTopic,
    );
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
    final selectedBackground = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFD9DDE2);
    final idleBackground = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEEF0F3);
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
        color: isDark ? const Color(0xFF1F2023) : const Color(0xFFF8F9FA),
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
                  baseColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE7E9EC),
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
                  baseColor: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFDADDE2),
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
    final selected = await _showStatsDatePicker(
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

Future<DateTime?> _showStatsDatePicker(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialDate,
}) {
  final isDesktopWidth = MediaQuery.sizeOf(context).width >= 720;
  final normalizedInitial = StatsDateRange.normalizeDate(initialDate);
  if (isDesktopWidth) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: _StatsDatePickerPanel(
          firstDate: firstDate,
          lastDate: lastDate,
          initialDate: normalizedInitial,
          desktop: true,
        ),
      ),
    );
  }

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StatsDatePickerPanel(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: normalizedInitial,
    ),
  );
}

class _StatsDatePickerPanel extends StatefulWidget {
  const _StatsDatePickerPanel({
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
    this.desktop = false,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialDate;
  final bool desktop;

  @override
  State<_StatsDatePickerPanel> createState() => _StatsDatePickerPanelState();
}

class _StatsDatePickerPanelState extends State<_StatsDatePickerPanel> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  var _mode = _CalendarPickerMode.day;

  @override
  void initState() {
    super.initState();
    _selectedDate = StatsDateRange.normalizeDate(widget.initialDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final content = Container(
      width: widget.desktop ? 360 : double.infinity,
      margin: widget.desktop
          ? EdgeInsets.zero
          : EdgeInsets.only(left: 12, right: 12, bottom: 12 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2023) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(widget.desktop ? 18 : 22),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        key: const ValueKey('stats-custom-date-calendar'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IosIconButton(
                key: const ValueKey('stats-date-picker-prev-year'),
                icon: Lucide.ChevronLeft,
                size: 18,
                padding: const EdgeInsets.all(7),
                onTap: _mode == _CalendarPickerMode.day
                    ? (_canShowPreviousMonth() ? () => _shiftMonth(-1) : null)
                    : (_canShowPreviousYear() ? () => _shiftYear(-1) : null),
              ),
              Expanded(
                child: Center(
                  child: IosCardPress(
                    key: const ValueKey('stats-date-picker-title'),
                    onTap: () => setState(() {
                      _mode = _mode == _CalendarPickerMode.day
                          ? _CalendarPickerMode.month
                          : _CalendarPickerMode.day;
                    }),
                    borderRadius: BorderRadius.circular(13),
                    baseColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFECEEF1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      _mode == _CalendarPickerMode.day
                          ? DateFormat('yyyy-MM').format(_visibleMonth)
                          : DateFormat('yyyy').format(_visibleMonth),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                  ),
                ),
              ),
              IosIconButton(
                key: const ValueKey('stats-date-picker-next-year'),
                icon: Lucide.ChevronRight,
                size: 18,
                padding: const EdgeInsets.all(7),
                onTap: _mode == _CalendarPickerMode.day
                    ? (_canShowNextMonth() ? () => _shiftMonth(1) : null)
                    : (_canShowNextYear() ? () => _shiftYear(1) : null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_mode == _CalendarPickerMode.day) ...[
            Row(
              children: [
                for (final label in _weekdayLabels(context))
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.42),
                          fontSize: 11,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            _MonthGrid(
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              firstDate: StatsDateRange.normalizeDate(widget.firstDate),
              lastDate: StatsDateRange.normalizeDate(widget.lastDate),
              onSelected: (date) {
                _selectedDate = date;
                Navigator.of(context).pop(date);
              },
            ),
          ] else
            _YearMonthGrid(
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              firstDate: StatsDateRange.normalizeDate(widget.firstDate),
              lastDate: StatsDateRange.normalizeDate(widget.lastDate),
              onSelected: (month) {
                setState(() {
                  _visibleMonth = DateTime(_visibleMonth.year, month);
                  _mode = _CalendarPickerMode.day;
                });
              },
            ),
        ],
      ),
    );

    if (widget.desktop) return content;
    return SafeArea(top: false, child: content);
  }

  bool _canShowPreviousYear() {
    return _visibleMonth.year > widget.firstDate.year;
  }

  bool _canShowNextYear() {
    return _visibleMonth.year < widget.lastDate.year;
  }

  bool _canShowPreviousMonth() {
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    return _visibleMonth.isAfter(firstMonth);
  }

  bool _canShowNextMonth() {
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    return _visibleMonth.isBefore(lastMonth);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = _clampVisibleMonth(
        DateTime(_visibleMonth.year, _visibleMonth.month + delta),
      );
    });
  }

  void _shiftYear(int delta) {
    setState(() {
      _visibleMonth = _clampVisibleMonth(
        DateTime(_visibleMonth.year + delta, _visibleMonth.month),
      );
    });
  }

  DateTime _clampVisibleMonth(DateTime month) {
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (month.isBefore(firstMonth)) return firstMonth;
    if (month.isAfter(lastMonth)) return lastMonth;
    return month;
  }

  List<String> _weekdayLabels(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final weekStart = DateTime(2026, 5, 4);
    final formatter = DateFormat.E(locale);
    return [
      for (var i = 0; i < 7; i++)
        formatter.format(StatsDateRange.addCalendarDays(weekStart, i)),
    ];
  }
}

enum _CalendarPickerMode { day, month }

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = StatsDateRange.addCalendarDays(
      monthStart,
      DateTime.monday - monthStart.weekday,
    );
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final date = StatsDateRange.addCalendarDays(gridStart, index);
        return _DateCell(
          date: date,
          inVisibleMonth: date.month == visibleMonth.month,
          selected: StatsDateRange.normalizeDate(date) == selectedDate,
          enabled: !date.isBefore(firstDate) && !date.isAfter(lastDate),
          onTap: () => onSelected(StatsDateRange.normalizeDate(date)),
        );
      },
    );
  }
}

class _YearMonthGrid extends StatelessWidget {
  const _YearMonthGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.MMM(locale);
    return GridView.builder(
      key: const ValueKey('stats-custom-month-picker'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.85,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final monthDate = DateTime(visibleMonth.year, month);
        final enabled =
            !_monthIsBefore(monthDate, firstDate) &&
            !_monthIsAfter(monthDate, lastDate);
        return _MonthCell(
          key: ValueKey('stats-month-cell-$month'),
          label: formatter.format(monthDate),
          selected:
              selectedDate.year == visibleMonth.year &&
              selectedDate.month == month,
          enabled: enabled,
          onTap: () => onSelected(month),
        );
      },
    );
  }

  bool _monthIsBefore(DateTime month, DateTime boundary) {
    return month.year < boundary.year ||
        (month.year == boundary.year && month.month < boundary.month);
  }

  bool _monthIsAfter(DateTime month, DateTime boundary) {
    return month.year > boundary.year ||
        (month.year == boundary.year && month.month > boundary.month);
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFDADDE2))
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFECEEF1));
    return IosCardPress(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(13),
      baseColor: background,
      pressedBlendStrength: selected ? 0 : null,
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: enabled ? 0.82 : 0.22),
            fontSize: 12,
            fontWeight: selected
                ? AppFontWeights.heavy
                : AppFontWeights.emphasis,
          ),
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.inVisibleMonth,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool inVisibleMonth;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFDADDE2))
        : Colors.transparent;
    final alpha = !enabled
        ? 0.18
        : inVisibleMonth
        ? 0.82
        : 0.34;
    return IosCardPress(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      baseColor: background,
      pressedBlendStrength: selected ? 0 : null,
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          date.day.toString(),
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: alpha),
            fontSize: 12,
            fontWeight: selected
                ? AppFontWeights.heavy
                : AppFontWeights.semibold,
          ),
        ),
      ),
    );
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
      baseColor: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFECEEF1),
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
