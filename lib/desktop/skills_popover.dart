import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models/assistant.dart';
import '../features/workspace/pages/skills_page.dart';
import '../features/workspace/widgets/desktop_workspace_button.dart';
import '../features/workspace/widgets/skills/conversation_skills_sheet.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/ios_tactile.dart';
import '../theme/app_font_weights.dart';
import '../theme/design_tokens.dart';

const desktopSkillsPopoverKey = ValueKey('desktop-skills-popover');

Future<void> showDesktopSkillsPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required String conversationId,
  required Assistant? assistant,
}) async {
  final anchor = anchorKey.currentContext?.findRenderObject();
  if (anchor is! RenderBox || !anchor.attached || !anchor.hasSize) return;
  final overlay = Navigator.of(context, rootNavigator: true).overlay!;
  final overlayBox = overlay.context.findRenderObject()! as RenderBox;
  final anchorRect =
      anchor.localToGlobal(Offset.zero, ancestor: overlayBox) & anchor.size;
  final manage = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context)!.commonClose,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (popoverContext, animation, _) => _SkillsPopoverPosition(
      anchor: anchor,
      overlay: overlayBox,
      initialRect: anchorRect,
      animation: animation,
      child: _SkillsPopover(
        conversationId: conversationId,
        assistant: assistant,
      ),
    ),
    transitionBuilder: (_, __, ___, child) => child,
  );
  if (manage == true && context.mounted) {
    await openSkillsPage(context);
  }
}

class _SkillsPopoverPosition extends StatefulWidget {
  const _SkillsPopoverPosition({
    required this.anchor,
    required this.overlay,
    required this.initialRect,
    required this.animation,
    required this.child,
  });

  final RenderBox anchor;
  final RenderBox overlay;
  final Rect initialRect;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_SkillsPopoverPosition> createState() => _SkillsPopoverPositionState();
}

class _SkillsPopoverPositionState extends State<_SkillsPopoverPosition> {
  late Rect _anchorRect = widget.initialRect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.sizeOf(context);
    // Read transforms after layout: the composer can sit under a slide
    // transition whose size may not be read from another subtree's layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.anchor.attached) {
        Navigator.of(context).maybePop();
        return;
      }
      final rect =
          widget.anchor.localToGlobal(Offset.zero, ancestor: widget.overlay) &
          widget.anchor.size;
      if (rect != _anchorRect) setState(() => _anchorRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
    delegate: _SkillsPopoverLayout(anchorRect: _anchorRect),
    child: ClipRect(
      child: AnimatedBuilder(
        animation: widget.animation,
        child: widget.child,
        builder: (context, child) {
          final animation = widget.animation;
          final closing = animation.status == AnimationStatus.reverse;
          final offset = closing
              ? Curves.easeOutCubic.transform(1 - animation.value)
              : 0.12 * (1 - Curves.easeOutCubic.transform(animation.value));
          return FractionalTranslation(
            translation: Offset(0, offset),
            child: Opacity(
              opacity: Curves.easeOutCubic.transform(animation.value),
              child: child,
            ),
          );
        },
      ),
    ),
  );
}

class _SkillsPopoverLayout extends SingleChildLayoutDelegate {
  _SkillsPopoverLayout({required this.anchorRect});

  final Rect anchorRect;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final rect = anchorRect;
    final width = math.min(
      (rect.width - 16).clamp(260.0, 720.0),
      math.max(0.0, constraints.maxWidth - 16),
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(
        0.0,
        math.min(420.0, math.min(rect.top, constraints.maxHeight - 8) - 8),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = anchorRect;
    return Offset(
      (rect.center.dx - childSize.width / 2).clamp(
        8.0,
        math.max(8.0, size.width - childSize.width - 8),
      ),
      math.max(8.0, math.min(rect.top, size.height - 8) - childSize.height),
    );
  }

  @override
  bool shouldRelayout(_SkillsPopoverLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect;
}

class _SkillsPopover extends StatelessWidget {
  const _SkillsPopover({required this.conversationId, required this.assistant});

  final String conversationId;
  final Assistant? assistant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      key: desktopSkillsPopoverKey,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppOverlayColors.desktopPopoverSurface(cs),
            border: Border(
              top: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.18),
                width: 0.7,
              ),
              left: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.04 : 0.12),
                width: 0.6,
              ),
              right: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.04 : 0.12),
                width: 0.6,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.skillsSessionTitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      IosIconButton(
                        icon: Lucide.X,
                        size: 16,
                        tooltip: l10n.commonClose,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  ConversationSkillsPanel(
                    conversationId: conversationId,
                    assistant: assistant,
                    compact: true,
                    footerAction: DesktopWorkspaceButton(
                      label: l10n.storageSpaceManageSkills,
                      icon: Lucide.Settings2,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
