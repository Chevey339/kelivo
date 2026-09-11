import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import 'ios_tactile.dart';
import 'ios_tile_button.dart';

Future<int?> showIosTimePicker(
  BuildContext context, {
  int? initialMinutes,
  required String title,
}) async {
  if (_isDesktopPlatform) {
    return _showIosDesktopTimeDialog(
      context,
      initialMinutes: initialMinutes,
      title: title,
    );
  }

  return _showIosMobileTimePicker(
    context,
    initialMinutes: initialMinutes,
    title: title,
  );
}

bool get _isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

Future<int?> _showIosMobileTimePicker(
  BuildContext context, {
  int? initialMinutes,
  required String title,
}) async {
  final initial = _resolveInitialTimeMinutes(initialMinutes);

  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _IosTimeWheelPanel(
        initialMinutes: initial,
        title: title,
        isDesktop: false,
        onCancel: () => Navigator.of(ctx).pop(),
        onSave: (minutes) => Navigator.of(ctx).pop(minutes),
      );
    },
  );
}

Future<int?> _showIosDesktopTimeDialog(
  BuildContext context, {
  int? initialMinutes,
  required String title,
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
          child: _IosTimeWheelPanel(
            initialMinutes: initial,
            title: title,
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

class _IosTimeWheelPanel extends StatefulWidget {
  const _IosTimeWheelPanel({
    required this.initialMinutes,
    required this.title,
    required this.isDesktop,
    required this.onCancel,
    required this.onSave,
  });

  final int initialMinutes;
  final String title;
  final bool isDesktop;
  final VoidCallback onCancel;
  final ValueChanged<int> onSave;

  @override
  State<_IosTimeWheelPanel> createState() => _IosTimeWheelPanelState();
}

class _IosTimeWheelPanelState extends State<_IosTimeWheelPanel> {
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
    final selectedTime = TimeOfDay(
      hour: _selectedHour,
      minute: _selectedMinute,
    ).format(context);
    final panelColor = widget.isDesktop ? cs.surface : cs.surfaceContainerHigh;

    final panel = Material(
      color: Colors.transparent,
      child: Container(
        key: widget.isDesktop
            ? const ValueKey('ios-time-picker-desktop-sheet')
            : const ValueKey('ios-time-picker-mobile-sheet'),
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
                        fontWeight: AppFontWeights.emphasis,
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
            widget.title,
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
          widget.title,
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
      key: const ValueKey('ios-time-picker-mobile-actions'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: IosCardPress(
              onTap: widget.onCancel,
              haptics: false,
              borderRadius: BorderRadius.circular(13),
              baseColor: cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.09),
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
              baseColor: cs.onSurface.withValues(alpha: isDark ? 0.16 : 0.14),
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
