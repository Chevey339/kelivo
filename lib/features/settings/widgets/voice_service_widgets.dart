import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Shared visual vocabulary for the TTS and ASR halves of Voice Services.
///
/// These controls intentionally mirror the compact settings surfaces already
/// used by Kelivo instead of introducing stock dropdowns or switches.
class VoiceServiceSectionHeader extends StatelessWidget {
  const VoiceServiceSectionHeader({
    super.key,
    required this.title,
    required this.addTooltip,
    required this.onAdd,
    this.desktop = false,
    this.first = false,
    this.leadingAction,
  });

  final String title;
  final String addTooltip;
  final VoidCallback onAdd;
  final bool desktop;
  final bool first;
  final Widget? leadingAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: desktop ? 14 : 13,
              fontWeight: desktop
                  ? AppFontWeights.regular
                  : AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: desktop ? 0.9 : 0.8),
            ),
          ),
        ),
        if (leadingAction != null) ...[
          leadingAction!,
          const SizedBox(width: 6),
        ],
        VoiceServiceHeaderIconButton(
          icon: Lucide.Plus,
          tooltip: addTooltip,
          onTap: onAdd,
        ),
      ],
    );

    if (desktop) return SizedBox(height: 36, child: content);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 6 : 18, 6, 6),
      child: content,
    );
  }
}

class VoiceServiceHeaderIconButton extends StatefulWidget {
  const VoiceServiceHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<VoiceServiceHeaderIconButton> createState() =>
      _VoiceServiceHeaderIconButtonState();
}

class _VoiceServiceHeaderIconButtonState
    extends State<VoiceServiceHeaderIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alpha = _pressed ? 0.10 : (_hovered ? 0.06 : 0.0);
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () {
              Haptics.light();
              widget.onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 18, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceServiceMobileCard extends StatelessWidget {
  const VoiceServiceMobileCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(children: children);
  }
}

Widget voiceServiceMobileDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}

class VoiceServicePageIconButton extends StatefulWidget {
  const VoiceServicePageIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 22,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  State<VoiceServicePageIconButton> createState() =>
      _VoiceServicePageIconButtonState();
}

class _VoiceServicePageIconButtonState
    extends State<VoiceServicePageIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            Haptics.light();
            widget.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: color.withValues(alpha: _pressed ? 0.7 : 1),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceServiceTactileRow extends StatefulWidget {
  const VoiceServiceTactileRow({
    super.key,
    required this.builder,
    this.onTap,
    this.pressedScale = 0.98,
    this.haptics = false,
  });

  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;

  @override
  State<VoiceServiceTactileRow> createState() => _VoiceServiceTactileRowState();
}

class _VoiceServiceTactileRowState extends State<VoiceServiceTactileRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics &&
                  context.read<SettingsProvider>().hapticsOnListItemTap) {
                Haptics.soft();
              }
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}

class VoiceServiceSmallIconButton extends StatefulWidget {
  const VoiceServiceSmallIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  State<VoiceServiceSmallIconButton> createState() =>
      _VoiceServiceSmallIconButtonState();
}

class _VoiceServiceSmallIconButtonState
    extends State<VoiceServiceSmallIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.destructive ? cs.error : cs.onSurface;
    final background = _pressed || _hovered
        ? cs.onSurface.withValues(alpha: _pressed ? 0.09 : 0.05)
        : Colors.transparent;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: widget.enabled
              ? (_) => setState(() => _hovered = true)
              : null,
          onExit: widget.enabled
              ? (_) => setState(() => _hovered = false)
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: widget.enabled
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: widget.enabled
                ? () => setState(() => _pressed = false)
                : null,
            onTap: widget.enabled
                ? () {
                    Haptics.soft();
                    widget.onTap();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: 18,
                color: base.withValues(alpha: widget.enabled ? 0.9 : 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceServiceSelectRow<T> extends StatelessWidget {
  const VoiceServiceSelectRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
          _VoiceServiceSelectButton<T>(
            value: value,
            options: options,
            labelFor: labelFor,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class VoiceServiceMobileSelectRow<T> extends StatelessWidget {
  const VoiceServiceMobileSelectRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: VoiceServiceTactileRow(
        haptics: true,
        onTap: () async {
          if (options.isEmpty) return;
          final selected = await _showVoiceServiceMobileOptions<T>(
            context,
            current: value,
            options: options,
            labelFor: labelFor,
          );
          if (selected != null) onSelected(selected);
        },
        builder: (pressed) {
          final foreground = cs.onSurface.withValues(
            alpha: pressed ? 0.68 : 0.9,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.medium,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  labelFor(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.regular,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Lucide.ChevronRight, size: 16, color: foreground),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<T?> _showVoiceServiceMobileOptions<T>(
  BuildContext context, {
  required T current,
  required List<T> options,
  required String Function(T value) labelFor,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                VoiceServiceTactileRow(
                  onTap: () => Navigator.of(sheetContext).pop(options[index]),
                  haptics: true,
                  builder: (pressed) {
                    final selected = options[index] == current;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labelFor(options[index]),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: selected
                                    ? AppFontWeights.semibold
                                    : AppFontWeights.regular,
                                color: cs.onSurface.withValues(
                                  alpha: pressed ? 0.68 : 0.9,
                                ),
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Lucide.Check, size: 18, color: cs.primary),
                        ],
                      ),
                    );
                  },
                ),
                if (index != options.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant.withValues(alpha: 0.18),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _VoiceServiceSelectButton<T> extends StatefulWidget {
  const _VoiceServiceSelectButton({
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onSelected,
  });

  final T value;
  final List<T> options;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  State<_VoiceServiceSelectButton<T>> createState() =>
      _VoiceServiceSelectButtonState<T>();
}

class _VoiceServiceSelectButtonState<T>
    extends State<_VoiceServiceSelectButton<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (widget.options.isEmpty) return;
          final selected = await _showVoiceServiceOptions<T>(
            context,
            current: widget.value,
            options: widget.options,
            labelFor: widget.labelFor,
          );
          if (selected != null) widget.onSelected(selected);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.12),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.labelFor(widget.value),
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Lucide.ChevronDown,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> _showVoiceServiceOptions<T>(
  BuildContext context, {
  required T current,
  required List<T> options,
  required String Function(T value) labelFor,
}) {
  final cs = Theme.of(context).colorScheme;
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: context.overlaySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < options.length; index++) ...[
                    _VoiceServiceDialogOption(
                      label: labelFor(options[index]),
                      selected: options[index] == current,
                      onTap: () =>
                          Navigator.of(dialogContext).pop(options[index]),
                    ),
                    if (index != options.length - 1)
                      Divider(
                        height: 10,
                        thickness: 0.6,
                        indent: 4,
                        endIndent: 4,
                        color: cs.outlineVariant.withValues(alpha: 0.12),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _VoiceServiceDialogOption extends StatefulWidget {
  const _VoiceServiceDialogOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_VoiceServiceDialogOption> createState() =>
      _VoiceServiceDialogOptionState();
}

class _VoiceServiceDialogOptionState extends State<_VoiceServiceDialogOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = widget.selected
        ? cs.primary.withValues(alpha: 0.08)
        : _hovered
        ? cs.onSurface.withValues(alpha: 0.04)
        : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (widget.selected)
                Icon(Lucide.Check, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
