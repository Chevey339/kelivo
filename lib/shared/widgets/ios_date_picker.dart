import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import '../../icons/lucide_adapter.dart';
import '../../theme/app_font_weights.dart';
import '../../theme/app_semantic_colors.dart';
import 'ios_tactile.dart';

DateTime _calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);
DateTime _addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

Future<DateTime?> showIosDatePicker(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialDate,
}) {
  final useDialog = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => MediaQuery.sizeOf(context).width >= 720,
  };
  final normalizedInitial = _calendarDate(initialDate);
  if (useDialog) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: _IosDatePickerPanel(
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
    builder: (context) => _IosDatePickerPanel(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: normalizedInitial,
    ),
  );
}

class _IosDatePickerPanel extends StatefulWidget {
  const _IosDatePickerPanel({
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
  State<_IosDatePickerPanel> createState() => _IosDatePickerPanelState();
}

class _IosDatePickerPanelState extends State<_IosDatePickerPanel> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  var _mode = _CalendarPickerMode.day;

  @override
  void initState() {
    super.initState();
    _selectedDate = _calendarDate(widget.initialDate);
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
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(widget.desktop ? 18 : 22),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        key: const ValueKey('ios-date-picker-calendar'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IosIconButton(
                key: const ValueKey('ios-date-picker-prev-year'),
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
                    key: const ValueKey('ios-date-picker-title'),
                    onTap: () => setState(() {
                      _mode = _mode == _CalendarPickerMode.day
                          ? _CalendarPickerMode.month
                          : _CalendarPickerMode.day;
                    }),
                    borderRadius: BorderRadius.circular(13),
                    baseColor: cs.onSurface.withValues(
                      alpha: isDark ? 0.08 : 0.06,
                    ),
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
                key: const ValueKey('ios-date-picker-next-year'),
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
              firstDate: _calendarDate(widget.firstDate),
              lastDate: _calendarDate(widget.lastDate),
              onSelected: (date) {
                _selectedDate = date;
                Navigator.of(context).pop(date);
              },
            ),
          ] else
            _YearMonthGrid(
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              firstDate: _calendarDate(widget.firstDate),
              lastDate: _calendarDate(widget.lastDate),
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
        formatter.format(_addCalendarDays(weekStart, i)),
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
    final gridStart = _addCalendarDays(
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
        final date = _addCalendarDays(gridStart, index);
        return _DateCell(
          date: date,
          inVisibleMonth: date.month == visibleMonth.month,
          selected: _calendarDate(date) == selectedDate,
          enabled: !date.isBefore(firstDate) && !date.isAfter(lastDate),
          onTap: () => onSelected(_calendarDate(date)),
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
      key: const ValueKey('ios-date-picker-months'),
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
          key: ValueKey('ios-date-picker-month-$month'),
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
        ? cs.onSurface.withValues(alpha: isDark ? 0.18 : 0.14)
        : context.appColors.surfaceFill;
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
        ? cs.onSurface.withValues(alpha: isDark ? 0.18 : 0.14)
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
