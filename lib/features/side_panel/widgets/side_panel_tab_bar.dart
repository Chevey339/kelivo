import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../desktop/widgets/desktop_pointer_surface.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/surface_ladder.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../browser/widgets/browser_favicon.dart';
import '../desktop_side_panel_controller.dart';

String sidePanelTabTitle(SidePanelTab tab, AppLocalizations l) => switch (tab) {
  PinnedTab(kind: SidePanelTabKind.topics) => l.sidePanelTopics,
  PinnedTab() => l.sidePanelFiles,
  PreviewTab() => p.basename(tab.path),
  WebTab() =>
    tab.page?.title.isNotEmpty == true
        ? tab.page!.title
        : tab.page?.url != 'about:blank'
        ? tab.page?.url ?? l.browserNewTab
        : l.browserNewTab,
};

class SidePanelTabIcon extends StatelessWidget {
  const SidePanelTabIcon({super.key, required this.tab});
  final SidePanelTab tab;
  @override
  Widget build(BuildContext context) {
    final value = tab;
    if (value is WebTab) {
      return SizedBox.square(
        dimension: 16,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: value.evicted ? .45 : 1,
              child: BrowserFavicon(
                url: value.page?.url ?? '',
                service: value.browser,
                size: 14,
              ),
            ),
            if (value.evicted)
              const Positioned(
                right: -2,
                bottom: -2,
                child: Icon(LucideIcons.rotateCw, size: 8),
              ),
          ],
        ),
      );
    }
    return Icon(switch (value.kind) {
      SidePanelTabKind.topics => LucideIcons.messagesSquare,
      SidePanelTabKind.files => LucideIcons.folderCode,
      _ => LucideIcons.fileText,
    }, size: 14);
  }
}

class SidePanelTabBar extends StatefulWidget {
  const SidePanelTabBar({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onAllTabs,
    required this.onContextMenu,
    required this.onClose,
    required this.conversationTitle,
  });
  final DesktopSidePanelController controller;
  final VoidCallback onAdd, onAllTabs, onClose;
  final void Function(SidePanelTab, Offset) onContextMenu;
  final String Function(String) conversationTitle;

  @override
  State<SidePanelTabBar> createState() => SidePanelTabBarState();
}

class SidePanelTabBarState extends State<SidePanelTabBar> {
  DesktopSidePanelController get controller => widget.controller;
  VoidCallback get onAdd => widget.onAdd;
  VoidCallback get onAllTabs => widget.onAllTabs;
  VoidCallback get onClose => widget.onClose;
  void Function(SidePanelTab, Offset) get onContextMenu => widget.onContextMenu;
  String Function(String) get conversationTitle => widget.conversationTitle;
  final _nodes = <String, FocusNode>{};
  bool _keyboardFocus = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_keyEvent);
  }

  bool _keyEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final navigation =
        event.logicalKey == LogicalKeyboardKey.tab ||
        (_nodes.values.any((node) => node.hasFocus) &&
            (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight));
    if (event is KeyDownEvent &&
        !keyboard.isMetaPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        navigation) {
      if (!_keyboardFocus) setState(() => _keyboardFocus = true);
    }
    return false;
  }

  void focusActiveTab({bool? showHighlight}) {
    if (showHighlight != null) {
      setState(() => _keyboardFocus = showHighlight);
    }
    _nodes[controller.activeTab.id]?.requestFocus();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyEvent);
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ladder = SurfaceLadder.fromScheme(cs);
    final pinned = controller.tabs.where((tab) => tab.pinned).toList();
    final resources = controller.tabs.where((tab) => !tab.pinned).toList();
    return Semantics(
      container: true,
      label: l.sidePanelAllTabs,
      child: DesktopPointerSurface(
        child: Listener(
          onPointerDown: (_) {
            if (_keyboardFocus) setState(() => _keyboardFocus = false);
          },
          child: Container(
            key: const ValueKey('sidePanelTabBar'),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ladder.hairline, width: .5),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth + AppSpacing.xs * 2;
                final visible = DesktopSidePanelController.visibleResources(
                  resources,
                  DesktopSidePanelController.resourceCapacity(
                    width,
                    pinned.length,
                  ),
                  controller.activeTab.id,
                );
                final hidden = resources.length - visible.length;
                final ordered = [...pinned, ...visible];
                for (final id in _nodes.keys.toList()) {
                  if (!controller.tabs.any((tab) => tab.id == id)) {
                    final retired = _nodes.remove(id)!;
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => retired.dispose(),
                    );
                  }
                }
                void moveFocus(SidePanelTab tab, int delta) {
                  final index = ordered.indexWhere((item) => item.id == tab.id);
                  _nodes[ordered[(index + delta) % ordered.length].id]
                      ?.requestFocus();
                }

                Widget tabButton(SidePanelTab tab) {
                  final title = sidePanelTabTitle(tab, l);
                  final background =
                      tab is WebTab &&
                          tab.conversationId != null &&
                          tab.conversationId != controller.conversationId
                      ? l.sidePanelBackgroundIn(
                          conversationTitle(tab.conversationId!),
                        )
                      : null;
                  final node = _nodes.putIfAbsent(
                    tab.id,
                    () => FocusNode(debugLabel: 'Panel tab ${tab.id}'),
                  );
                  return _TabButton(
                    key: ValueKey('sidePanelTab-${tab.id}'),
                    tab: tab,
                    focusNode: node,
                    showKeyboardFocus: _keyboardFocus,
                    onPrevious: () => moveFocus(tab, -1),
                    onNext: () => moveFocus(tab, 1),
                    title: title,
                    selected: controller.activeTab.id == tab.id,
                    semanticLabel: [
                      title,
                      if (tab.pinned) l.sidePanelPinned,
                      if (tab is WebTab && tab.evicted)
                        l.sidePanelEvictedTooltip,
                      if (background != null) background,
                    ].join(' · '),
                    background: background,
                    onActivate: () => controller.activate(tab.id),
                    onClose: () {
                      final focused = node.hasFocus;
                      controller.closeTab(tab.id);
                      if (focused) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) focusActiveTab();
                        });
                      }
                    },
                    onContextMenu: (position) => onContextMenu(tab, position),
                  );
                }

                return FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: Row(
                    children: [
                      for (final tab in pinned)
                        SizedBox(width: 70, child: tabButton(tab)),
                      if (resources.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxs / 2,
                          ),
                          child: SizedBox(
                            width: .5,
                            height: 18,
                            child: ColoredBox(color: ladder.hairlineStrong),
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, space) {
                            final total = math.max(
                              0.0,
                              space.maxWidth - (hidden > 0 ? 40 : 0),
                            );
                            final perTab = visible.isEmpty
                                ? 0.0
                                : math.min(168.0, total / visible.length);
                            final enlargeActive =
                                width >= 440 &&
                                perTab < 116 &&
                                visible.length > 1 &&
                                visible.any(
                                  (tab) => tab.id == controller.activeTab.id,
                                );
                            return Row(
                              children: [
                                for (final tab in visible)
                                  SizedBox(
                                    width: enlargeActive
                                        ? (tab.id == controller.activeTab.id
                                              ? 116
                                              : (total - 116) /
                                                    (visible.length - 1))
                                        : perTab,
                                    child: tabButton(tab),
                                  ),
                                const Spacer(),
                                if (hidden > 0)
                                  SizedBox(
                                    width: 40,
                                    child: Semantics(
                                      button: true,
                                      label: l.sidePanelMoreTabs(hidden),
                                      child: IosCardPress(
                                        mouseCursor: SystemMouseCursors.basic,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.capsule,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        onTap: onAllTabs,
                                        child: Center(
                                          child: Text(
                                            '» $hidden',
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      SidePanelIconButton(
                        key: const ValueKey('sidePanelAdd'),
                        icon: LucideIcons.plus,
                        label: l.browserNewTab,
                        onTap: onAdd,
                      ),
                      SidePanelIconButton(
                        key: const ValueKey('sidePanelAllTabs'),
                        icon: LucideIcons.chevronDown,
                        label: l.sidePanelAllTabs,
                        onTap: onAllTabs,
                      ),
                      SidePanelIconButton(
                        icon: controller.isExpanded
                            ? LucideIcons.minimize2
                            : LucideIcons.maximize2,
                        label: controller.isExpanded
                            ? l.sidePanelCollapse
                            : l.sidePanelExpand,
                        onTap: () =>
                            controller.setExpanded(!controller.isExpanded),
                      ),
                      SidePanelIconButton(
                        icon: LucideIcons.panelRightClose,
                        label: l.sidePanelToggle,
                        onTap: onClose,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SidePanelIconButton extends StatelessWidget {
  const SidePanelIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IosIconButton(
      icon: icon,
      semanticLabel: label,
      size: 14,
      minSize: 24,
      padding: const EdgeInsets.all(4),
      onTap: onTap,
      mouseCursor: SystemMouseCursors.basic,
    ),
  );
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    super.key,
    required this.tab,
    required this.focusNode,
    required this.showKeyboardFocus,
    required this.onPrevious,
    required this.onNext,
    required this.title,
    required this.semanticLabel,
    required this.selected,
    required this.onActivate,
    required this.onClose,
    required this.onContextMenu,
    this.background,
  });
  final SidePanelTab tab;
  final FocusNode focusNode;
  final bool showKeyboardFocus;
  final VoidCallback onPrevious, onNext;
  final String title, semanticLabel;
  final String? background;
  final bool selected;
  final VoidCallback onActivate, onClose;
  final ValueChanged<Offset> onContextMenu;
  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hover = false, _focusRing = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = context.appColors.surfaceFill;
    final evicted = widget.tab is WebTab && (widget.tab as WebTab).evicted;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: Tooltip(
        message: widget.semanticLabel,
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          mouseCursor: SystemMouseCursors.basic,
          onFocusChange: (value) => setState(() => _focusRing = value),
          onShowHoverHighlight: (value) => setState(() => _hover = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.delete): DeleteCharacterIntent(
              forward: true,
            ),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                PreviousFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
          },
          actions: {
            PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
              onInvoke: (_) {
                widget.onPrevious();
                return null;
              },
            ),
            NextFocusIntent: CallbackAction<NextFocusIntent>(
              onInvoke: (_) {
                widget.onNext();
                return null;
              },
            ),
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
            DeleteCharacterIntent: CallbackAction<DeleteCharacterIntent>(
              onInvoke: (_) {
                if (widget.tab.closable) widget.onClose();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.focusNode.requestFocus();
              widget.onActivate();
            },
            onSecondaryTapDown: (details) =>
                widget.onContextMenu(details.globalPosition),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tight = constraints.maxWidth < 64;
                return Container(
                  height: 32,
                  padding: EdgeInsets.symmetric(
                    horizontal: tight || widget.tab.pinned
                        ? AppSpacing.xxs
                        : AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? fill
                        : _hover
                        ? fill.withValues(alpha: fill.a * .5)
                        : null,
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                    border: _focusRing && widget.showKeyboardFocus
                        ? Border.all(color: cs.primary, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: widget.tab.pinned
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      SidePanelTabIcon(tab: widget.tab),
                      if (!tight) const SizedBox(width: 4),
                      Flexible(
                        fit: widget.tab.pinned ? FlexFit.loose : FlexFit.tight,
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurface.withValues(
                                    alpha: evicted ? .45 : 1,
                                  ),
                                ),
                              ),
                              if (widget.background != null)
                                Text(
                                  widget.background!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.tab.closable &&
                          (widget.selected || _hover || _focusRing))
                        SizedBox(
                          width: 16,
                          child: IosIconButton(
                            icon: LucideIcons.x,
                            size: 12,
                            minSize: 16,
                            padding: EdgeInsets.zero,
                            semanticLabel: AppLocalizations.of(
                              context,
                            )!.browserCloseTab,
                            onTap: widget.onClose,
                            mouseCursor: SystemMouseCursors.basic,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
