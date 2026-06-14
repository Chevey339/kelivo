import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

String proactiveCareNextMessageLabel(BuildContext context, DateTime? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null) return l10n.assistantEditProactiveCareNextMessageTimeUnset;
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} ${TimeOfDay.fromDateTime(local).format(context)}';
}

Future<DateTime?> showProactiveCareDateTimePicker(
  BuildContext context, {
  DateTime? initial,
}) {
  final resolved = _resolveInitialDateTime(initial);
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _ProactiveCareDateTimePanel(
        initial: resolved,
        onCancel: () => Navigator.of(ctx).pop(),
        onSave: (value) => Navigator.of(ctx).pop(value),
      );
    },
  );
}

DateTime _resolveInitialDateTime(DateTime? initial) {
  final now = DateTime.now();
  final candidate = initial ?? now.add(const Duration(hours: 24));
  if (candidate.isBefore(now)) {
    return now.add(const Duration(hours: 24));
  }
  return candidate;
}

class _ProactiveCareDateTimePanel extends StatefulWidget {
  const _ProactiveCareDateTimePanel({
    required this.initial,
    required this.onCancel,
    required this.onSave,
  });

  final DateTime initial;
  final VoidCallback onCancel;
  final ValueChanged<DateTime> onSave;

  @override
  State<_ProactiveCareDateTimePanel> createState() =>
      _ProactiveCareDateTimePanelState();
}

class _ProactiveCareDateTimePanelState
    extends State<_ProactiveCareDateTimePanel> {
  static const double _itemExtent = 42;
  static const double _timePickerHeight = 160;
  static const double _datePickerHeight = 180;

  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final local = widget.initial.toLocal();
    _selectedDate = DateTime(local.year, local.month, local.day);
    _selectedHour = local.hour;
    _selectedMinute = local.minute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  DateTime get _selectedDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedHour,
    _selectedMinute,
  );

  void _save() {
    final selected = _selectedDateTime;
    final now = DateTime.now();
    if (selected.isBefore(now)) {
      widget.onSave(now.add(const Duration(minutes: 1)));
      return;
    }
    widget.onSave(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    const radius = BorderRadius.all(Radius.circular(22));
    final panelColor = isDark
        ? const Color(0xFF1F2023)
        : const Color(0xFFF8F9FA);
    final preview = proactiveCareNextMessageLabel(context, _selectedDateTime);

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12 + bottomInset,
          ),
          decoration: BoxDecoration(color: panelColor, borderRadius: radius),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Center(
                    child: Text(
                      l10n.assistantEditProactiveCareDateTimePickerTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: AppFontWeights.emphasis,
                        color: cs.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: Column(
                    children: [
                      Text(
                        preview,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFontWeights.emphasis,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: _datePickerHeight,
                        child: CupertinoTheme(
                          data: CupertinoTheme.of(context).copyWith(
                            textTheme: CupertinoTheme.of(context).textTheme
                                .copyWith(
                                  dateTimePickerTextStyle: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: AppFontWeights.semibold,
                                  ),
                                ),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: _selectedDate,
                            minimumDate: DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                            ),
                            maximumDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                            onDateTimeChanged: (value) {
                              setState(() {
                                _selectedDate = DateTime(
                                  value.year,
                                  value.month,
                                  value.day,
                                );
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTimeWheels(context, cs, isDark),
                    ],
                  ),
                ),
                _buildActions(context, l10n, cs, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeWheels(BuildContext context, ColorScheme cs, bool isDark) {
    final selectionColor = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.18 : 0.10),
      cs.surface,
    );
    final selectionBorder = cs.primary.withValues(alpha: isDark ? 0.30 : 0.18);

    return SizedBox(
      height: _timePickerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: _itemExtent,
            decoration: BoxDecoration(
              color: selectionColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selectionBorder),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildWheel(
                  controller: _hourController,
                  itemCount: 24,
                  selectedIndex: _selectedHour,
                  cs: cs,
                  onSelected: (value) {
                    setState(() => _selectedHour = value);
                  },
                ),
              ),
              SizedBox(
                width: 28,
                child: Center(
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: AppFontWeights.emphasis,
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildWheel(
                  controller: _minuteController,
                  itemCount: 60,
                  selectedIndex: _selectedMinute,
                  cs: cs,
                  onSelected: (value) {
                    setState(() => _selectedMinute = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required ColorScheme cs,
    required ValueChanged<int> onSelected,
  }) {
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: CupertinoTheme.of(context).textTheme.copyWith(
          pickerTextStyle: TextStyle(
            color: cs.onSurface,
            fontSize: 22,
            fontWeight: AppFontWeights.semibold,
            letterSpacing: 0,
          ),
        ),
      ),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: _itemExtent,
        diameterRatio: 1.35,
        squeeze: 1.08,
        useMagnifier: true,
        magnification: 1.04,
        backgroundColor: Colors.transparent,
        selectionOverlay: const SizedBox.shrink(),
        looping: true,
        onSelectedItemChanged: onSelected,
        children: List.generate(itemCount, (index) {
          final selected = index == selectedIndex;
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: selected ? 23 : 21,
                fontWeight: selected
                    ? AppFontWeights.emphasis
                    : AppFontWeights.medium,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.72),
                letterSpacing: 0,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: IosCardPress(
              onTap: widget.onCancel,
              haptics: false,
              borderRadius: BorderRadius.circular(13),
              baseColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE7E9EC),
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: Text(
                  l10n.backupPageCancel,
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
              onTap: _save,
              haptics: false,
              borderRadius: BorderRadius.circular(13),
              baseColor: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0xFFDADDE2),
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: Text(
                  l10n.backupPageSave,
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
    );
  }
}
