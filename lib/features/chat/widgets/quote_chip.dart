import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/quote_ref.dart';
import '../../../l10n/app_localizations.dart';
import '../../../desktop/desktop_glass_popover.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../shared/widgets/ios_text_button.dart';
import 'selection_panel.dart';
import 'quote_interaction_scope.dart';

bool get selectionUsesDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

String quotePreview(String text, {double width = 11}) {
  final source = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  var used = 0.0;
  final result = StringBuffer();
  for (final character in source.characters) {
    final rune = character.runes.first;
    final cjk =
        (rune >= 0x2e80 && rune <= 0x9fff) ||
        (rune >= 0xac00 && rune <= 0xd7af) ||
        (rune >= 0xf900 && rune <= 0xfaff) ||
        (rune >= 0x20000 && rune <= 0x323af);
    used += cjk ? 1 : .55;
    if (used > width) return '$result…';
    result.write(character);
  }
  return result.toString();
}

/// One visual token for the composer's single U+FFFC and for sent messages.
class QuoteChip extends StatefulWidget {
  const QuoteChip({
    super.key,
    required this.quote,
    this.style,
    this.onRemove,
    this.selected = false,
    this.flashRevision = 0,
  });
  final QuoteRef quote;
  final TextStyle? style;
  final VoidCallback? onRemove;
  final bool selected;
  final int flashRevision;
  @override
  State<QuoteChip> createState() => _QuoteChipState();
}

class _QuoteChipState extends State<QuoteChip> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  Timer? _hoverTimer, _closeTimer, _flashTimer;
  QuoteInteractionController? _actions;
  int _sourceRevision = -1, _sourceCheck = 0;
  bool _hover = false, _missing = false, _flash = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final actions = QuoteInteractionScope.maybeOf(context);
    if (_actions != actions || _sourceRevision != actions?.sourceRevision) {
      _actions = actions;
      _sourceRevision = actions?.sourceRevision ?? -1;
      unawaited(_checkSource());
    }
  }

  Future<void> _checkSource() async {
    final actions = _actions;
    if (actions == null) return;
    final id = widget.quote.messageId;
    final check = ++_sourceCheck;
    final exists = await actions.sourceExists(id);
    if (mounted &&
        check == _sourceCheck &&
        id == widget.quote.messageId &&
        _missing == exists) {
      setState(() => _missing = !exists);
    }
  }

  @override
  void didUpdateWidget(QuoteChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quote.messageId != widget.quote.messageId) {
      unawaited(_checkSource());
    }
    if (oldWidget.flashRevision != widget.flashRevision &&
        widget.flashRevision != 0) {
      _flashTimer?.cancel();
      _flash = true;
      _flashTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  Future<void> _jump() async {
    _portal.hide();
    final found = await _actions?.onJump(widget.quote);
    if (mounted && found != null) setState(() => _missing = !found);
  }

  void _enter() {
    _closeTimer?.cancel();
    setState(() => _hover = true);
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        unawaited(_checkSource());
        _portal.show();
      }
    });
  }

  void _exit() {
    setState(() => _hover = false);
    _hoverTimer?.cancel();
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 150), _portal.hide);
  }

  Widget _mobilePreview(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final timestamp = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(widget.quote.createdAt.toLocal()));
    return SelectionPanel(
      title: l10n.selectionQuote,
      onClose: () => Navigator.pop(context),
      actions: Row(
        children: [
          Expanded(
            child: IosTextButton(
              label: l10n.quoteJumpToSource,
              icon: LucideIcons.arrowUpRight,
              onPressed: () {
                Navigator.pop(context);
                unawaited(_jump());
              },
            ),
          ),
          if (widget.onRemove != null)
            Expanded(
              child: IosTextButton(
                label: l10n.quoteRemove,
                icon: LucideIcons.x,
                color: cs.onSurfaceVariant,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onRemove!();
                },
              ),
            ),
        ],
      ),
      children: [
        Text(
          [
            widget.quote.model ?? l10n.userProviderDefaultUserName,
            timestamp,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          widget.quote.text,
          style: TextStyle(fontSize: 15, height: 1.6, color: cs.onSurface),
        ),
        if (_missing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.quoteSourceMissing,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _desktopPreview(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final timestamp = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(widget.quote.createdAt.toLocal()));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.messageCircleMore,
                size: 13,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.selectionQuote,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                timestamp,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: SelectableText(
                widget.quote.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          if (_missing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.quoteSourceMissing,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.quote.model ?? l10n.userProviderDefaultUserName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                child: IosCardPress(
                  focusable: true,
                  haptics: false,
                  mouseCursor: SystemMouseCursors.basic,
                  baseColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  onTap: () => unawaited(_jump()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.quoteJumpToSource,
                        style: TextStyle(fontSize: 12, color: cs.onSurface),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.arrowUpRight,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _tap() async {
    if (widget.onRemove == null || selectionUsesDesktop) {
      await _jump();
      return;
    }
    await _checkSource();
    if (!mounted) return;
    await showSelectionSheet(context, builder: _mobilePreview);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final body = DefaultTextStyle.of(context).style.merge(widget.style);
    final size = (body.fontSize ?? 14) * 1.14;
    final color = _missing ? cs.onSurfaceVariant : cs.onSurface;
    final textColor = _hover
        ? color
        : color.withValues(alpha: dark ? .95 : .90);
    final canRemove = _hover && widget.onRemove != null && selectionUsesDesktop;
    final child = ColoredBox(
      color: widget.selected || _flash
          ? cs.primary.withValues(alpha: dark ? .34 : .22)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(left: 1, right: 4),
        child: Text.rich(
          TextSpan(
            style: body.copyWith(
              color: textColor,
              decoration: _missing ? TextDecoration.lineThrough : null,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SizedBox.square(
                  dimension: size,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: .6,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: GestureDetector(
                      key: ValueKey(canRemove),
                      onTap: canRemove
                          ? () {
                              _portal.hide();
                              widget.onRemove!();
                            }
                          : _tap,
                      child: Icon(
                        canRemove
                            ? LucideIcons.x
                            : LucideIcons.messageCircleMore,
                        size: size,
                        color: color.withValues(alpha: dark ? .88 : .80),
                      ),
                    ),
                  ),
                ),
              ),
              const WidgetSpan(child: SizedBox(width: 4)),
              TextSpan(text: '“${quotePreview(widget.quote.text)}”'),
            ],
          ),
          maxLines: 1,
        ),
      ),
    );
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final viewport = MediaQuery.sizeOf(overlayContext);
        final width = math.min(320.0, viewport.width - 24);
        final left = origin.dx.clamp(
          12.0,
          math.max(12, viewport.width - width - 12),
        );
        final below = viewport.height - origin.dy > 230;
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: below ? Alignment.bottomLeft : Alignment.topLeft,
            followerAnchor: below ? Alignment.topLeft : Alignment.bottomLeft,
            offset: Offset(left - origin.dx, below ? 8 : -8),
            child: MouseRegion(
              onEnter: (_) => _closeTimer?.cancel(),
              onExit: (_) => _exit(),
              child:
                  DesktopGlassPanel(
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: _desktopPreview(context),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 120.ms)
                      .scale(
                        begin: const Offset(.96, .96),
                        end: const Offset(1, 1),
                        duration: 120.ms,
                      ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: selectionUsesDesktop ? (_) => _enter() : null,
          onExit: selectionUsesDesktop ? (_) => _exit() : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: Semantics(
              button: true,
              label: widget.quote.text,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _closeTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }
}
