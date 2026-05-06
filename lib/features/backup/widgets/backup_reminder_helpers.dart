import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../icons/lucide_adapter.dart' as lucide;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';

String backupReminderFrequencyLabel(AppLocalizations l10n, int days) {
  return switch (days) {
    1 => l10n.backupReminderEveryDay,
    3 => l10n.backupReminderEveryThreeDays,
    7 => l10n.backupReminderEveryWeek,
    14 => l10n.backupReminderEveryFourteenDays,
    30 => l10n.backupReminderEveryMonth,
    _ => l10n.backupReminderCustomDays(days),
  };
}

String backupReminderTimeLabel(BuildContext context, int? minutes) {
  if (minutes == null) {
    return AppLocalizations.of(context)!.backupReminderDisabled;
  }
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return time.format(context);
}

String backupReminderDateTimeLabel(BuildContext context, DateTime? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null) return l10n.backupReminderNever;
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} ${TimeOfDay.fromDateTime(local).format(context)}';
}

String backupReminderNextLabel(BuildContext context, DateTime? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null) return l10n.backupReminderDisabled;
  if (!DateTime.now().isBefore(value)) return l10n.backupReminderDueNow;
  return backupReminderDateTimeLabel(context, value);
}

Future<int?> showBackupReminderTimePicker(
  BuildContext context, {
  int? initialMinutes,
}) async {
  if (_isDesktopPlatform) {
    return _showBackupReminderDesktopTimeDialog(
      context,
      initialMinutes: initialMinutes,
    );
  }

  return _showBackupReminderMobileTimePicker(
    context,
    initialMinutes: initialMinutes,
  );
}

bool get _isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

Future<int?> _showBackupReminderMobileTimePicker(
  BuildContext context, {
  int? initialMinutes,
}) async {
  final initial = _resolveInitialTimeMinutes(initialMinutes);

  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _BackupReminderTimeWheelPanel(
        initialMinutes: initial,
        isDesktop: false,
        onCancel: () => Navigator.of(ctx).pop(),
        onSave: (minutes) => Navigator.of(ctx).pop(minutes),
      );
    },
  );
}

Future<int?> _showBackupReminderDesktopTimeDialog(
  BuildContext context, {
  int? initialMinutes,
}) {
  final initial = _resolveInitialTimeMinutes(initialMinutes);

  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _BackupReminderTimeWheelPanel(
            initialMinutes: initial,
            isDesktop: true,
            onCancel: () => Navigator.of(ctx).pop(),
            onSave: (minutes) => Navigator.of(ctx).pop(minutes),
          ),
        ),
      );
    },
  );
}

int _resolveInitialTimeMinutes(int? initialMinutes) {
  final now = DateTime.now();
  final minutes = initialMinutes ?? (now.hour * 60 + now.minute);
  return minutes.clamp(0, 23 * 60 + 59);
}

class _BackupReminderTimeWheelPanel extends StatefulWidget {
  const _BackupReminderTimeWheelPanel({
    required this.initialMinutes,
    required this.isDesktop,
    required this.onCancel,
    required this.onSave,
  });

  final int initialMinutes;
  final bool isDesktop;
  final VoidCallback onCancel;
  final ValueChanged<int> onSave;

  @override
  State<_BackupReminderTimeWheelPanel> createState() =>
      _BackupReminderTimeWheelPanelState();
}

class _BackupReminderTimeWheelPanelState
    extends State<_BackupReminderTimeWheelPanel> {
  static const double _itemExtent = 42;
  static const double _pickerHeight = 210;

  late int _selectedHour;
  late int _selectedMinute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialMinutes ~/ 60;
    _selectedMinute = widget.initialMinutes % 60;
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

  int get _selectedMinutes => _selectedHour * 60 + _selectedMinute;

  void _save() {
    widget.onSave(_selectedMinutes);
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
    final selectedTime = backupReminderTimeLabel(context, _selectedMinutes);
    final panelColor = widget.isDesktop
        ? cs.surface
        : (isDark ? const Color(0xFF1F2023) : const Color(0xFFF8F9FA));

    final panel = Material(
      color: Colors.transparent,
      child: Container(
        key: widget.isDesktop
            ? const ValueKey('backup-reminder-time-desktop-sheet')
            : const ValueKey('backup-reminder-time-mobile-sheet'),
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
                  widget.isDesktop ? 18 : 12,
                  widget.isDesktop ? 22 : 18,
                  widget.isDesktop ? 8 : 14,
                ),
                child: Column(
                  children: [
                    Text(
                      selectedTime,
                      style: TextStyle(
                        fontSize: widget.isDesktop ? 30 : 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildWheels(context, cs, isDark),
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
            l10n.backupReminderTimeTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
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
          l10n.backupReminderTimeTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }

  Widget _buildWheels(BuildContext context, ColorScheme cs, bool isDark) {
    final selectionColor = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.18 : 0.10),
      cs.surface,
    );
    final selectionBorder = cs.primary.withValues(alpha: isDark ? 0.30 : 0.18);

    return SizedBox(
      height: _pickerHeight,
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
                      fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w600,
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
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      key: const ValueKey('backup-reminder-time-mobile-actions'),
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w800,
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

Future<int?> showBackupReminderCustomDaysDialog(
  BuildContext context, {
  required int initialDays,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _BackupReminderCustomDaysDialog(initialDays: initialDays),
  );
}

class _BackupReminderCustomDaysDialog extends StatefulWidget {
  const _BackupReminderCustomDaysDialog({required this.initialDays});

  final int initialDays;

  @override
  State<_BackupReminderCustomDaysDialog> createState() =>
      _BackupReminderCustomDaysDialogState();
}

class _BackupReminderCustomDaysDialogState
    extends State<_BackupReminderCustomDaysDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDays.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.backupReminderCustomDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupReminderCustomDialogDescription),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.backupReminderCustomDaysLabel,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              validator: (value) {
                final days = int.tryParse(value ?? '');
                if (days == null || days < 1 || days > 365) {
                  return l10n.backupReminderCustomDaysInvalid;
                }
                return null;
              },
              onFieldSubmitted: (_) {
                _submit();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.backupPageCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.backupPageOK)),
      ],
    );
  }
}
