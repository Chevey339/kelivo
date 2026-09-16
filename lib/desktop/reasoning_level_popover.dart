import 'dart:async';
import 'dart:ui' as ui;

import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/assistant.dart';
import '../core/models/model_spec.dart';
import '../core/providers/settings_provider.dart';
import '../core/services/api/reasoning/reasoning_level_options.dart';
import '../core/services/model_spec/model_spec_resolver.dart';
import '../features/chat/widgets/reasoning_level_sheet.dart';
import '../icons/lucide_adapter.dart';
import '../icons/reasoning_icons.dart';
import '../l10n/app_localizations.dart';
import '../shared/dialogs/reasoning_budget_custom_dialog.dart';
import '../theme/design_tokens.dart';

Future<void> showDesktopReasoningLevelPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
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
      config: config,
      modelId: modelId,
      assistant: assistant,
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
    required this.config,
    required this.modelId,
    this.assistant,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;
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
                              config: widget.config,
                              modelId: widget.modelId,
                              assistant: widget.assistant,
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
    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(14);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppOverlayColors.desktopPopoverSurface(cs),
            borderRadius: radius,
            border: Border(
              top: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
                width: 0.7,
              ),
              left: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
                width: 0.6,
              ),
              right: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
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
    required this.config,
    required this.modelId,
    this.assistant,
  });

  final Future<void> Function() onDone;
  final ValueChanged<bool> onSuspendedChanged;
  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final spec = ModelSpecResolver.instance.spec(config, modelId);
    if (!spec.supportsReasoning) {
      return Padding(
        key: const ValueKey('reasoning-unsupported'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Text(
          l10n.reasoningLevelNoReasoning,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.62),
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    final snapshot = buildReasoningLevelPickerSnapshot(
      settings: settings,
      config: config,
      modelId: modelId,
      spec: spec,
      assistant: assistant,
    );
    final stops = snapshot.sliderStops;

    Widget tile({
      required Key key,
      required Widget Function(Color color) leadingBuilder,
      required String label,
      required bool selected,
      Widget? trailing,
      required VoidCallback onTap,
    }) {
      final cs = Theme.of(context).colorScheme;
      final onColor = selected ? cs.primary : cs.onSurface;
      final iconColor = selected ? cs.primary : cs.onSurface;
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: _HoverRow(
          leading: leadingBuilder(iconColor),
          label: label,
          selected: selected,
          trailing: trailing,
          onTap: onTap,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.regular,
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
            for (final stop in stops)
              tile(
                key: ValueKey(stop.key),
                leadingBuilder: (c) => ReasoningIcons.levelIcon(
                  stop.level ?? ReasoningLevel.auto,
                  size: 16,
                  color: c,
                ),
                label: reasoningLevelLabel(
                  l10n,
                  stop.level ?? ReasoningLevel.auto,
                ),
                selected: snapshot.isSelected(stop),
                onTap: () async {
                  final request = stop.request;
                  if (request == null) return;
                  await commitReasoningChoice(
                    context.read<SettingsProvider>(),
                    config,
                    modelId,
                    assistant,
                    request,
                  );
                  if (!context.mounted) return;
                  await onDone();
                },
              ),
            if (snapshot.isBudgetStyle)
              tile(
                key: const ValueKey('reasoning-row-custom'),
                leadingBuilder: (c) => Icon(Lucide.Hash, size: 16, color: c),
                label: l10n.reasoningLevelCustomBudget,
                selected: snapshot.customSelected,
                trailing: snapshot.customSelected
                    ? Text(
                        (snapshot.selected.budgetTokens ?? 0).toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFontWeights.semibold,
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
                  final initialValue = snapshot.customSelected
                      ? (snapshot.selected.budgetTokens ?? 2048)
                      : 2048;
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
                    await commitReasoningChoice(
                      context.read<SettingsProvider>(),
                      config,
                      modelId,
                      assistant,
                      requestForCustomBudget(snapshot.spec, chosen),
                    );
                    if (!context.mounted) return;
                    await onDone();
                  } finally {
                    if (restore && context.mounted) {
                      onSuspendedChanged(false);
                    }
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
    final hoverBg = cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.10);

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
                      TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.regular,
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
