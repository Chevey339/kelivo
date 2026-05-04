import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../models/stats_models.dart';

const double _heatCellSize = 11;
const double _heatCellPadding = 1.5;
const double _heatCellPitch = _heatCellSize + _heatCellPadding * 2;
const double _heatWeekGap = 1;
const double _heatMonthLabelHeight = 12;
const double _heatMonthLabelGap = 4;
const double _heatWeekdayLabelWidth = 18;
const double _heatLegendMinWidth = 170;

class StatsHeatmap extends StatefulWidget {
  const StatsHeatmap({super.key, required this.days});

  final List<StatsHeatmapDay> days;

  @override
  State<StatsHeatmap> createState() => _StatsHeatmapState();
}

class _StatsHeatmapState extends State<StatsHeatmap> {
  final ScrollController _scrollController = ScrollController();
  bool _scrollToLatestScheduled = false;
  bool _shouldScrollToLatest = true;

  @override
  void didUpdateWidget(covariant StatsHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _shouldScrollToLatest = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeCounts =
        widget.days
            .where((day) => day.count > 0)
            .map((day) => day.count)
            .toList()
          ..sort();
    final q1 = _quantile(activeCounts, 0.25);
    final q2 = _quantile(activeCounts, 0.50);
    final q3 = _quantile(activeCounts, 0.75);

    final weeks = _calendarWeeks(widget.days);
    final contentWidth = _heatmapContentWidth(weeks);
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WeekdayLabels(localeName: localeName),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _scheduleScrollToLatest();
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < weeks.length; i++) ...[
                                  _MonthLabel(
                                    week: weeks[i],
                                    localeName: localeName,
                                  ),
                                  if (i < weeks.length - 1)
                                    const SizedBox(width: _heatWeekGap),
                                ],
                              ],
                            ),
                            const SizedBox(height: _heatMonthLabelGap),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < weeks.length; i++) ...[
                                  Column(
                                    children: [
                                      for (final day in weeks[i])
                                        _HeatCellSlot(
                                          day: day,
                                          level: _level(
                                            day.count,
                                            q1: q1,
                                            q2: q2,
                                            q3: q3,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (i < weeks.length - 1)
                                    const SizedBox(width: _heatWeekGap),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: _heatWeekdayLabelWidth),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: math.min(
                        math.max(contentWidth, _heatLegendMinWidth),
                        constraints.maxWidth,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _HeatmapLegend(
                          style: _legendStyle(context),
                          l10n: l10n,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _scheduleScrollToLatest() {
    if (!_shouldScrollToLatest || _scrollToLatestScheduled) return;
    _scrollToLatestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLatestScheduled = false;
      if (!mounted || !_shouldScrollToLatest || !_scrollController.hasClients) {
        return;
      }
      _shouldScrollToLatest = false;
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent > 0) {
        _scrollController.jumpTo(maxScrollExtent);
      }
    });
  }

  TextStyle _legendStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.56));
  }

  double _heatmapContentWidth(List<List<StatsHeatmapDay>> weeks) {
    if (weeks.isEmpty) return 0;
    return weeks.length * _heatCellPitch +
        math.max(0, weeks.length - 1) * _heatWeekGap;
  }

  int _quantile(List<int> sorted, double p) {
    if (sorted.isEmpty) return 1;
    final index = (sorted.length * p).floor().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  int _level(int count, {required int q1, required int q2, required int q3}) {
    if (count <= 0) return 0;
    if (count <= q1) return 1;
    if (count <= q2) return 2;
    if (count <= q3) return 3;
    return 4;
  }

  List<List<StatsHeatmapDay>> _calendarWeeks(List<StatsHeatmapDay> days) {
    if (days.isEmpty) return const [];
    final byDate = {for (final day in days) _dateOnly(day.date): day};
    final first = _dateOnly(days.first.date);
    final last = _dateOnly(days.last.date);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final weeks = <List<StatsHeatmapDay>>[];
    for (
      var weekStart = start;
      !weekStart.isAfter(last);
      weekStart = weekStart.add(const Duration(days: 7))
    ) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final visibleEnd = weekEnd.isAfter(last) ? last : weekEnd;
      weeks.add([
        for (
          var date = weekStart;
          !date.isAfter(visibleEnd);
          date = date.add(const Duration(days: 1))
        )
          _dayForDate(byDate, date),
      ]);
    }
    return weeks;
  }

  StatsHeatmapDay _dayForDate(
    Map<DateTime, StatsHeatmapDay> byDate,
    DateTime date,
  ) {
    final normalized = _dateOnly(date);
    return byDate[normalized] ?? StatsHeatmapDay(date: normalized, count: 0);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({required this.localeName});

  final String localeName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 10,
      height: 1,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.46),
    );
    return SizedBox(
      width: _heatWeekdayLabelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _heatMonthLabelHeight + _heatMonthLabelGap),
          for (final weekday in const [
            DateTime.sunday,
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
          ])
            SizedBox(
              height: _heatCellPitch,
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    weekday == DateTime.monday ||
                        weekday == DateTime.wednesday ||
                        weekday == DateTime.friday
                    ? Text(
                        DateFormat(
                          'EEEEE',
                          localeName,
                        ).format(DateTime(2024, 1, 7 + weekday)),
                        key: ValueKey('stats-heatmap-weekday-$weekday'),
                        maxLines: 1,
                        style: style,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  const _MonthLabel({required this.week, required this.localeName});

  final List<StatsHeatmapDay> week;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    StatsHeatmapDay? firstOfMonth;
    for (final day in week) {
      if (day.date.day == 1) {
        firstOfMonth = day;
        break;
      }
    }
    final cs = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      fontSize: 10,
      height: 1,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.46),
    );
    return SizedBox(
      width: 14,
      height: 12,
      child: firstOfMonth == null
          ? const SizedBox.shrink()
          : OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: 44,
              child: Text(
                DateFormat.MMM(localeName).format(firstOfMonth.date),
                key: ValueKey(
                  'stats-heatmap-month-${firstOfMonth.date.year}-${firstOfMonth.date.month}',
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: textStyle,
              ),
            ),
    );
  }
}

class _HeatCellSlot extends StatelessWidget {
  const _HeatCellSlot({required this.day, required this.level});

  final StatsHeatmapDay day;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(
        'stats-heatmap-day-${day.date.year}-${day.date.month}-${day.date.day}',
      ),
      padding: const EdgeInsets.all(_heatCellPadding),
      child: _HeatCell(level: level),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.style, required this.l10n})
    : super(key: const ValueKey('stats-heatmap-legend'));

  final TextStyle style;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.statsPageHeatmapLess, style: style),
        const SizedBox(width: 6),
        for (var level = 0; level <= 4; level++) ...[
          _HeatCell(level: level, size: 10),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 3),
        Text(l10n.statsPageHeatmapMore, style: style),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.level, this.size = 11});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alpha = switch (level) {
      0 => 0.10,
      1 => 0.25,
      2 => 0.45,
      3 => 0.68,
      _ => 0.92,
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = level == 0
        ? isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFDDE2E8)
        : cs.primary.withValues(alpha: alpha);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
