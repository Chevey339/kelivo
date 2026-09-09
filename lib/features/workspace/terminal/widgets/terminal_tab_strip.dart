import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class TerminalTabStrip extends StatefulWidget {
  const TerminalTabStrip({
    super.key,
    required this.sessions,
    required this.activeId,
    required this.onSelect,
    required this.onAdd,
    required this.onRename,
    required this.onClose,
    this.showAdd = true,
  });

  static const addKey = ValueKey<String>('terminal-tab-add');

  static Key tabKey(String id) => ValueKey<String>('terminal-tab-$id');

  static Key aliveDotKey(String id) =>
      ValueKey<String>('terminal-tab-alive-$id');

  static Key exitBadgeKey(String id) =>
      ValueKey<String>('terminal-tab-exit-$id');

  final List<TerminalSession> sessions;
  final String? activeId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<String> onRename;
  final ValueChanged<String> onClose;
  final bool showAdd;

  @override
  State<TerminalTabStrip> createState() => _TerminalTabStripState();
}

class _TerminalTabStripState extends State<TerminalTabStrip> {
  final Map<String, GlobalKey> _tabKeys = <String, GlobalKey>{};
  String? _ensuredId;

  @override
  void initState() {
    super.initState();
    _scheduleEnsureVisible();
  }

  @override
  void didUpdateWidget(covariant TerminalTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.sessions.map((session) => session.id).toSet();
    _tabKeys.removeWhere((id, _) => !ids.contains(id));
    if (oldWidget.activeId != widget.activeId) {
      _ensuredId = null;
    }
    _scheduleEnsureVisible();
  }

  GlobalKey _keyFor(String id) =>
      _tabKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'terminal-tab-$id'));

  void _scheduleEnsureVisible() {
    final id = widget.activeId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || id != widget.activeId || id == _ensuredId) return;
      final ctx = _tabKeys[id]?.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable != null) {
        final viewport = RenderAbstractViewport.maybeOf(box);
        if (viewport != null) {
          final origin = viewport.getOffsetToReveal(box, 0).offset;
          final pixels = scrollable.position.pixels;
          final view = scrollable.position.viewportDimension;
          final alreadyVisible =
              origin >= pixels - 0.5 &&
              origin + box.size.width <= pixels + view + 0.5;
          if (alreadyVisible) {
            _ensuredId = id;
            return;
          }
        }
      }
      _ensuredId = id;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _showTabMenu(
    BuildContext context,
    TerminalSession session,
    Offset globalPosition,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showAdaptiveActionMenu(
      context,
      anchor: globalPosition,
      title: session.title,
      items: [
        ActionSheetItem(
          icon: Lucide.Pencil,
          label: l10n.terminalRename,
          onTap: () => widget.onRename(session.id),
        ),
        ActionSheetItem(
          icon: Lucide.X,
          label: l10n.terminalClose,
          destructive: true,
          onTap: () => widget.onClose(session.id),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              primary: false,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              itemCount: widget.sessions.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final session = widget.sessions[index];
                return UnconstrainedBox(
                  key: _keyFor(session.id),
                  constrainedAxis: Axis.vertical,
                  alignment: Alignment.centerLeft,
                  child: _TabChip(
                    session: session,
                    active: session.id == widget.activeId,
                    onSelect: () => widget.onSelect(session.id),
                    onActions: (position) =>
                        unawaited(_showTabMenu(context, session, position)),
                  ),
                );
              },
            ),
          ),
          if (widget.showAdd)
            Tooltip(
              message: l10n.terminalNewSession,
              child: IosIconButton(
                key: TerminalTabStrip.addKey,
                icon: Lucide.Plus,
                size: 18,
                minSize: 32,
                semanticLabel: l10n.terminalNewSession,
                color: cs.onSurface.withValues(alpha: 0.8),
                onTap: () {
                  Haptics.light();
                  widget.onAdd();
                },
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.session,
    required this.active,
    required this.onSelect,
    required this.onActions,
  });

  final TerminalSession session;
  final bool active;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final bg = active
        ? cs.primary.withValues(alpha: 0.14)
        : context.appColors.surfaceFill;
    final fg = active ? cs.primary : cs.onSurface.withValues(alpha: 0.82);
    final exitCode = session.exitCode ?? 0;
    final failed = session.exited && exitCode != 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 180),
      child: Listener(
        key: TerminalTabStrip.tabKey(session.id),
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kSecondaryMouseButton) {
            onActions(event.position);
          }
        },
        child: IosCardPress(
          baseColor: bg,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          pressedScale: 0.98,
          onTap: onSelect,
          onLongPress: () {
            final box = context.findRenderObject() as RenderBox?;
            final position = box == null
                ? Offset.zero
                : box.localToGlobal(box.size.center(Offset.zero));
            onActions(position);
          },
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (session.isAlive) ...[
                  Container(
                    key: TerminalTabStrip.aliveDotKey(session.id),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.appColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    session.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active
                          ? AppFontWeights.semibold
                          : AppFontWeights.medium,
                      color: fg,
                    ),
                  ),
                ),
                if (session.exited) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: TerminalTabStrip.exitBadgeKey(session.id),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: failed
                          ? cs.error.withValues(alpha: 0.12)
                          : cs.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.terminalExitCode(exitCode),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFontWeights.semibold,
                        color: failed
                            ? cs.error
                            : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
