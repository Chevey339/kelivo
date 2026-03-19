import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/providers/assistant_provider.dart';
import '../core/providers/settings_provider.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/dialogs/reasoning_budget_custom_dialog.dart';

Future<void> showDesktopReasoningBudgetPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  String? modelProvider,
  String? modelId,
}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(
    offset.dx,
    offset.dy,
    size.width,
    size.height,
  );

  final completer = Completer<void>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ReasoningPopoverOverlay(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      modelProvider: modelProvider,
      modelId: modelId,
      onClose: () {
        try {
          entry.remove();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _ReasoningPopoverOverlay extends StatefulWidget {
  const _ReasoningPopoverOverlay({
    required this.anchorRect,
    required this.anchorWidth,
    this.modelProvider,
    this.modelId,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final String? modelProvider;
  final String? modelId;
  final VoidCallback onClose;

  @override
  State<_ReasoningPopoverOverlay> createState() =>
      _ReasoningPopoverOverlayState();
}

class _ReasoningPopoverOverlayState extends State<_ReasoningPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _closing = false;
  bool _suspended = false;
  Offset _offset = const Offset(0, 0.12);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _offset = Offset.zero);
      try {
        await _controller.forward();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    setState(() => _offset = const Offset(0, 1.0));
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Slightly narrower than input width
    final width = (widget.anchorWidth - 16).clamp(260.0, 720.0);
    final left =
        (widget.anchorRect.left + (widget.anchorRect.width - width) / 2).clamp(
          8.0,
          screen.width - width - 8.0,
        );
    final clipHeight = widget.anchorRect.top.clamp(0.0, screen.height);

    return IgnorePointer(
      ignoring: _suspended,
      child: Opacity(
        opacity: _suspended ? 0.0 : 1.0,
        child: Stack(
          children: [
            // tap outside to close
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: clipHeight,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: left,
                      width: width,
                      bottom: 0,
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          offset: _offset,
                          child: _GlassPanel(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: _ReasoningContent(
                              onDone: _close,
                              onSuspendedChanged: (v) {
                                if (_suspended == v) return;
                                setState(() => _suspended = v);
                              },
                              modelProvider: widget.modelProvider,
                              modelId: widget.modelId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.borderRadius});
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Match the preferred grey smudge style
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: isDark ? 0.28 : 0.56,
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
                width: 0.7,
              ),
              left: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
                width: 0.6,
              ),
              right: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
                width: 0.6,
              ),
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

class _ReasoningContent extends StatelessWidget {
  const _ReasoningContent({
    required this.onDone,
    required this.onSuspendedChanged,
    this.modelProvider,
    this.modelId,
  });
  final Future<void> Function() onDone;
  final ValueChanged<bool> onSuspendedChanged;
  final String? modelProvider;
  final String? modelId;

  bool _isCustomSelected(int? budget, {required bool showXhigh}) {
    final v = budget ?? -1;
    final presets = <int>{-1, 0, 1024, 16000, 32000, if (showXhigh) 64000};
    return !presets.contains(v);
  }

  bool _showXhighOption(BuildContext context, SettingsProvider settings) {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final currentProvider =
        modelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final currentModelId =
        modelId ?? assistant?.chatModelId ?? settings.currentModelId;
    if (currentProvider == null || currentModelId == null) return false;
    return settings.supportsOpenAIXhighReasoning(
      currentProvider,
      currentModelId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final showXhigh = _showXhighOption(context, sp);
    final selected = sp.thinkingBudget ?? -1;
    final customActive = _isCustomSelected(
      sp.thinkingBudget,
      showXhigh: showXhigh,
    );

    Widget tile({
      required Widget Function(Color color) leadingBuilder,
      required String label,
      required int value,
      bool? activeOverride,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      final cs = Theme.of(context).colorScheme;
      final active = activeOverride ?? (selected == value);
      final onColor = active ? cs.primary : cs.onSurface;
      final iconColor = active ? cs.primary : cs.onSurface;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: _HoverRow(
          leading: leadingBuilder(iconColor),
          label: label,
          selected: active,
          trailing: trailing,
          onTap:
              onTap ??
              () async {
                await context.read<SettingsProvider>().setThinkingBudget(value);
                await onDone();
              },
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ).copyWith(color: onColor),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(
              leadingBuilder: (c) => Icon(Lucide.X, size: 16, color: c),
              label: l10n.reasoningBudgetSheetOff,
              value: 0,
            ),
            tile(
              leadingBuilder: (c) => Icon(Lucide.Settings2, size: 16, color: c),
              label: l10n.reasoningBudgetSheetAuto,
              value: -1,
            ),
            tile(
              leadingBuilder: (c) => SvgPicture.asset(
                'assets/icons/deepthink.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
              ),
              label: l10n.reasoningBudgetSheetLight,
              value: 1024,
            ),
            tile(
              leadingBuilder: (c) => SvgPicture.asset(
                'assets/icons/deepthink.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
              ),
              label: l10n.reasoningBudgetSheetMedium,
              value: 16000,
            ),
            tile(
              leadingBuilder: (c) => SvgPicture.asset(
                'assets/icons/deepthink.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
              ),
              label: l10n.reasoningBudgetSheetHeavy,
              value: 32000,
            ),
            if (showXhigh)
              tile(
                leadingBuilder: (c) => SvgPicture.asset(
                  'assets/icons/deepthink.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
                ),
                label: l10n.reasoningBudgetSheetXhigh,
                value: 64000,
              ),
            tile(
              leadingBuilder: (c) => Icon(Lucide.Hash, size: 16, color: c),
              label: l10n.reasoningBudgetSheetCustomLabel,
              value: -999999,
              activeOverride: customActive,
              trailing: customActive
                  ? Text(
                      selected.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.none,
                      ),
                    )
                  : Icon(
                      Lucide.ChevronRight,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
              onTap: () async {
                final initialValue = selected >= 1024 ? selected : 2048;
                onSuspendedChanged(true);
                var restore = true;
                try {
                  final chosen = await ReasoningBudgetCustomDialog.show(
                    context,
                    initialValue: initialValue,
                  );
                  if (!context.mounted) return;
                  if (chosen == null) return;
                  restore = false;
                  await context.read<SettingsProvider>().setThinkingBudget(
                    chosen,
                  );
                  if (!context.mounted) return;
                  await onDone();
                } finally {
                  if (restore && context.mounted) onSuspendedChanged(false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.labelStyle,
  });
  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final TextStyle? labelStyle;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseBg = Colors.transparent;
    final hoverBg = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.12 : 0.10,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : baseBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Center(child: widget.leading),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      widget.labelStyle ??
                      const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.none,
                      ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: widget.selected
                    ? Icon(
                        Lucide.Check,
                        key: const ValueKey('check'),
                        size: 16,
                        color: cs.primary,
                      )
                    : const SizedBox(width: 16, key: ValueKey('space')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
