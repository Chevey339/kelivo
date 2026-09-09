import 'package:flutter/material.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Opens a World Book–style keyboard form sheet
/// (`_showBookConfigSheet` in `world_book_page.dart`).
///
/// Text fields inside [FormSheet] should be
/// `IosFormTextField(inlineLabel: false)` — label stacked above a filled
/// radius-12 box. This helper does not wrap fields itself.
Future<T?> showFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.9;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: builder(sheetCtx),
      );
    },
  );
}

/// Sheet body matching `_WorldBookEditSheet`: handle, centred title,
/// content-sized column that scrolls when the keyboard is up.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.padding,
  });

  final String title;
  final List<Widget> children;

  /// Bottom button row. Omit for content-only sheets (e.g. pickers).
  final Widget? actions;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final insets = MediaQuery.viewInsetsOf(context);
    final resolvedPadding =
        padding ??
        EdgeInsets.only(
          left: 10,
          right: 10,
          top: 12,
          bottom: insets.bottom + 16,
        );
    final bodyPadding = padding == null
        ? resolvedPadding
        : resolvedPadding.copyWith(
            bottom: resolvedPadding.bottom + insets.bottom,
          );

    return SafeArea(
      top: false,
      child: Padding(
        padding: bodyPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
            if (actions != null) ...[const SizedBox(height: 10), actions!],
          ],
        ),
      ),
    );
  }
}

/// Equal-width cancel / confirm row matching World Book
/// `_IosOutlineButton` / `_IosFilledButton` (h44, r12, gap 12).
class FormSheetActions extends StatelessWidget {
  const FormSheetActions({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    this.onConfirm,
    this.destructive = false,
    this.busy = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FormSheetOutlineButton(label: cancelLabel, onTap: onCancel),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FormSheetFilledButton(
            label: confirmLabel,
            onTap: onConfirm,
            destructive: destructive,
            busy: busy,
          ),
        ),
      ],
    );
  }
}

/// Label + switch matching World Book `switchRow` (no leading icon).
class FormSheetSwitchRow extends StatelessWidget {
  const FormSheetSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      pressedBlendStrength: 0,
      pressedScale: 1.0,
      haptics: false,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            IosSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _FormSheetOutlineButton extends StatefulWidget {
  const _FormSheetOutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_FormSheetOutlineButton> createState() =>
      _FormSheetOutlineButtonState();
}

class _FormSheetOutlineButtonState extends State<_FormSheetOutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = context.appColors.surfaceFill;
    final overlay = _pressed
        ? cs.onSurface.withValues(alpha: 0.12)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: BoxDecoration(
          color: Color.alphaBlend(overlay, bg),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _FormSheetFilledButton extends StatefulWidget {
  const _FormSheetFilledButton({
    required this.label,
    required this.onTap,
    required this.destructive,
    required this.busy,
  });

  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool busy;

  @override
  State<_FormSheetFilledButton> createState() => _FormSheetFilledButtonState();
}

class _FormSheetFilledButtonState extends State<_FormSheetFilledButton> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = widget.destructive ? cs.error : cs.primary;
    final onFill = widget.destructive ? cs.onError : cs.onPrimary;
    final bg = _enabled ? fill : fill.withValues(alpha: 0.4);
    final overlay = _pressed
        ? onFill.withValues(alpha: 0.12)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: _enabled
          ? () {
              Haptics.light();
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: BoxDecoration(
          color: Color.alphaBlend(overlay, bg),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: widget.busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onFill.withValues(
                    alpha: widget.onTap == null ? 0.6 : 1,
                  ),
                ),
              )
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.emphasis,
                  color: onFill.withValues(alpha: _enabled ? 1 : 0.6),
                ),
              ),
      ),
    );
  }
}
