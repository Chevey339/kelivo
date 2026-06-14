import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart' as lucide;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
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
}) async {
  if (_isDesktopPlatform) {
    return _showProactiveCareDesktopDateTimeDialog(context, initial: initial);
  }
  return _showProactiveCareMobileDateTimePicker(context, initial: initial);
}

bool get _isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

DateTime _resolveInitialDateTime(DateTime? initial) {
  final now = DateTime.now();
  final candidate = initial ?? now.add(const Duration(hours: 24));
  if (candidate.isBefore(now)) {
    return now.add(const Duration(hours: 24));
  }
  return candidate;
}

Future<DateTime?> _showProactiveCareMobileDateTimePicker(
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
        isDesktop: false,
        onCancel: () => Navigator.of(ctx).pop(),
        onSave: (value) => Navigator.of(ctx).pop(value),
      );
    },
  );
}

Future<DateTime?> _showProactiveCareDesktopDateTimeDialog(
  BuildContext context, {
  DateTime? initial,
}) {
  final resolved = _resolveInitialDateTime(initial);
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _ProactiveCareDateTimePanel(
            initial: resolved,
            isDesktop: true,
            onCancel: () => Navigator.of(ctx).pop(),
            onSave: (value) => Navigator.of(ctx).pop(value),
          ),
        ),
      );
    },
  );
}

class _ProactiveCareDateTimePanel extends StatefulWidget {
  const _ProactiveCareDateTimePanel({
    required this.initial,
    required this.isDesktop,
    required this.onCancel,
    required this.onSave,
  });

  final DateTime initial;
  final bool isDesktop;
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
    final radius = widget.isDesktop
        ? BorderRadius.circular(18)
        : BorderRadius.circular(22);
    final borderColor = cs.outlineVariant.withValues(
      alpha: widget.isDesktop ? 0.24 : 0.12,
    );
    final panelColor = widget.isDesktop
        ? cs.surface
        : (isDark ? const Color(0xFF1F2023) : const Color(0xFFF8F9FA));
    final preview = proactiveCareNextMessageLabel(context, _selectedDateTime);

    final panel = Material(
      color: Colors.transparent,
      child: Container(
        width: widget.isDesktop ? null : double.infinity,
        margin: widget.isDesktop
            ? EdgeInsets.zero
            : EdgeInsets.only(left: 12, right: 12, bottom: 12 + bottomInset),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: radius,
          border: widget.isDesktop ? Border.all(color: borderColor) : null,
          boxShadow: widget.isDesktop
              ? [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: isDark ? 0.32 : 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, l10n, cs),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.isDesktop ? 22 : 18,
                  widget.isDesktop ? 12 : 8,
                  widget.isDesktop ? 22 : 18,
                  widget.isDesktop ? 8 : 10,
                ),
                child: Column(
                  children: [
                    Text(
                      preview,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.isDesktop ? 18 : 16,
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
              if (widget.isDesktop) _buildDesktopActions(context, l10n, cs),
              if (!widget.isDesktop) _buildMobileActions(context, l10n, cs),
            ],
          ),
        ),
      ),
    );

    if (widget.isDesktop) return panel;
    return SafeArea(top: false, child: panel);
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (widget.isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.assistantEditProactiveCareDateTimePickerTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: AppFontWeights.emphasis,
              color: cs.onSurface,
            ),
          ),
        ),
      );
    }

    return Padding(
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

  Widget _buildDesktopActions(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
      child: Row(
        children: [
          Expanded(
            child: IosTileButton(
              label: l10n.backupPageCancel,
              icon: lucide.Lucide.X,
              onTap: widget.onCancel,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: IosTileButton(
              label: l10n.backupPageSave,
              icon: lucide.Lucide.Check,
              backgroundColor: cs.primary,
              foregroundColor: cs.primary,
              onTap: _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActions(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
