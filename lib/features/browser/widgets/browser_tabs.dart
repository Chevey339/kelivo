import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/services/browser/browser_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../browser_tabs_route.dart';
import '../models/browser_models.dart';
import 'browser_glass.dart';
import 'browser_favicon.dart';
import 'browser_menu.dart';
import 'browser_surface_controls.dart';
import 'browser_progressive_edge.dart';

class BrowserTabStrip extends StatelessWidget {
  const BrowserTabStrip({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelect,
    required this.onClose,
    this.service,
  });
  final BrowserService? service;
  final List<BrowserTab> tabs;
  final String? activeId;
  final ValueChanged<String> onSelect, onClose;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - 16) / math.max(1, tabs.length))
            .clamp(120.0, 220.0);
        return SingleChildScrollView(
          hitTestBehavior: HitTestBehavior.deferToChild,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              for (final tab in tabs)
                SizedBox(
                  width: width,
                  height: 32,
                  child: _DesktopTab(
                    key: ValueKey(tab.id),
                    tab: tab,
                    service: service,
                    active: tab.id == activeId,
                    onSelect: () => onSelect(tab.id),
                    onClose: () => onClose(tab.id),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _DesktopTab extends StatefulWidget {
  const _DesktopTab({
    super.key,
    required this.tab,
    required this.active,
    required this.onSelect,
    required this.onClose,
    this.service,
  });
  final BrowserService? service;
  final BrowserTab tab;
  final bool active;
  final VoidCallback onSelect, onClose;
  @override
  State<_DesktopTab> createState() => _DesktopTabState();
}

class _DesktopTabState extends State<_DesktopTab> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final title = widget.tab.title.isEmpty ? l.browserNewTab : widget.tab.title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: BrowserSurfaceButton(
          selected: widget.active,
          semanticLabel: title,
          onPressed: widget.onSelect,
          onFocusChanged: (value) => setState(() => _focused = value),
          radius: 1000,
          child: DecoratedBox(
            key: ValueKey('browserDesktopTab-${widget.tab.id}'),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(
                alpha: widget.active ? .09 : .025,
              ),
              borderRadius: BorderRadius.circular(1000),
              border: Border.all(
                color: colors.onSurface.withValues(
                  alpha: widget.active ? .09 : .035,
                ),
                width: .5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 2),
              child: Row(
                children: [
                  BrowserFavicon(
                    url: widget.tab.url,
                    service: widget.service,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.active
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox.square(
                    dimension: 28,
                    child: Offstage(
                      offstage: !(widget.active || _hovered || _focused),
                      child: BrowserSurfaceIconButton(
                        label: l.browserCloseTab,
                        icon: LucideIcons.x,
                        iconSize: 14,
                        size: 28,
                        onPressed: widget.onClose,
                      ),
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

class BrowserTabOverview extends StatefulWidget {
  const BrowserTabOverview({
    super.key,
    required this.service,
    required this.onSelect,
    required this.onClose,
    required this.onNew,
    this.onDone,
    this.scrollController,
    this.transition,
    this.conversationId,
    this.conversationTitle,
  });
  final BrowserService service;
  final ValueChanged<String> onSelect, onClose;
  final VoidCallback onNew;
  final VoidCallback? onDone;
  final ScrollController? scrollController;
  final BrowserTabTransitionController? transition;
  final String? conversationId;
  final String Function(String?)? conversationTitle;
  @override
  State<BrowserTabOverview> createState() => _BrowserTabOverviewState();
}

class _BrowserTabOverviewState extends State<BrowserTabOverview> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _searchExpanded = false;
  late bool _showAll;
  final _scopeButtonKey = GlobalKey();
  bool _scopeMenuOpen = false;
  bool _scopeMenuTransitionStarted = false;
  ScrollController? _gridController;
  @override
  void initState() {
    super.initState();
    _showAll =
        widget.conversationId == null ||
        (widget.service.activeTab != null &&
            widget.service.activeTab!.ownerSessionId != widget.conversationId);
    // Mobile's transition already captured its source before opening. Starting
    // another native snapshot here would overlap JPEG encoding and decoding
    // with the first frames of the page-to-card flight.
    if (widget.transition == null) {
      unawaited(widget.service.refreshActivePreview());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _gridController?.dispose();
    super.dispose();
  }

  Widget _searchField(BuildContext context) => BrowserSurfaceField(
    controller: _search,
    focusNode: _searchFocus,
    autofocus: _searchExpanded,
    hintText: AppLocalizations.of(context)!.browserSearchTabs,
    prefixIcon: LucideIcons.search,
    onChanged: (value) => setState(() => _query = value.toLowerCase()),
  );

  Uint8List? _previewForTab(String id) => widget.transition == null
      ? widget.service.previewForTab(id)
      : widget.transition!.previewForTab(id);

  EdgeInsets _scopePadding(bool desktop) => EdgeInsets.symmetric(
    horizontal: desktop ? 12 : 16,
    vertical: desktop ? 7 : 12,
  );

  Widget _scopeLabel(BuildContext context, {required bool desktop}) {
    final l = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            _showAll ? l.browserTabsAll : l.browserTabsCurrentConversation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: desktop ? 12 : 13,
              height: 1.3,
              fontWeight: desktop ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: desktop ? 4 : 6),
        Icon(LucideIcons.chevronDown, size: desktop ? 12 : 14, color: color),
      ],
    );
  }

  Widget _scopeSelector(BuildContext context, {required bool desktop}) {
    return BrowserTextButton(
      key: _scopeButtonKey,
      filled: true,
      padding: _scopePadding(desktop),
      // Keep its prepared material and layout; the menu owns the visible lens
      // from its first motion frame until it returns to this exact rectangle.
      opacity: _scopeMenuTransitionStarted ? 0 : 1,
      onPressed: () => _chooseScope(context, desktop: desktop),
      child: KeyedSubtree(
        key: const ValueKey('browserTabScope'),
        child: _scopeLabel(context, desktop: desktop),
      ),
    );
  }

  Rect? _scopeAnchor() {
    final box = _scopeButtonKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _chooseScope(
    BuildContext context, {
    required bool desktop,
  }) async {
    if (_scopeMenuOpen) return;
    final anchor = _scopeAnchor();
    if (anchor == null) return;
    final l = AppLocalizations.of(context)!;
    _scopeMenuOpen = true;
    final bool? value;
    try {
      value = await showBrowserMenu<bool>(
        context,
        title: l.browserTabs,
        desktop: desktop,
        anchorRect: anchor,
        resolveAnchor: _scopeAnchor,
        sourceContent: Padding(
          key: const ValueKey('browserTabScopeSource'),
          padding: _scopePadding(desktop),
          child: _scopeLabel(context, desktop: desktop),
        ),
        onTransitionStart: () {
          if (mounted && !desktop && _scopeMenuOpen) {
            setState(() => _scopeMenuTransitionStarted = true);
          }
        },
        items: [
          BrowserMenuEntry(
            value: false,
            icon: !_showAll ? LucideIcons.check : LucideIcons.messageSquare,
            label: l.browserTabsCurrentConversation,
          ),
          BrowserMenuEntry(
            value: true,
            icon: _showAll ? LucideIcons.check : LucideIcons.panelsTopLeft,
            label: l.browserTabsAll,
          ),
        ],
      );
    } finally {
      if (mounted) {
        setState(() {
          _scopeMenuOpen = false;
          _scopeMenuTransitionStarted = false;
        });
      }
    }
    final selected = value;
    if (!mounted || selected == null || selected == _showAll) return;
    widget.transition?.invalidateGeometry();
    setState(() => _showAll = selected);
    final controller = widget.scrollController ?? _gridController;
    if (controller?.hasClients == true) controller!.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) =>
      BrowserMenuHost(child: Builder(builder: _buildOverview));

  Widget _buildOverview(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final desktop =
        ResponsiveHelper.isDesktop(context) ||
        switch (Theme.of(context).platform) {
          TargetPlatform.macOS ||
          TargetPlatform.windows ||
          TargetPlatform.linux => true,
          _ => false,
        };
    return ListenableProvider<BrowserService>.value(
      value: widget.service,
      child: Selector<BrowserService, List<Object?>>(
        // Page progress/media notifications must not rebuild every card and
        // optical control. Records compare cached preview bytes by identity,
        // rather than rescanning all image bytes on every service notification.
        selector: (_, service) => [
          service.activeTabId,
          for (final tab in service.tabs)
            (
              tab.id,
              tab.title,
              tab.url,
              tab.hasContent,
              tab.ownerSessionId,
              _previewForTab(tab.id),
            ),
        ],
        builder: (context, _, _) {
          final scopedTabs = _showAll
              ? widget.service.tabs
              : widget.service.tabsForSession(widget.conversationId);
          final tabs = scopedTabs
              .where(
                (tab) =>
                    '${tab.title} ${tab.url}'.toLowerCase().contains(_query),
              )
              .toList();
          final groups = <String?, List<BrowserTab>>{};
          for (final tab in tabs) {
            (groups[tab.ownerSessionId] ??= []).add(tab);
          }
          final groupEntries = [
            if (groups[widget.conversationId] case final current?)
              MapEntry(widget.conversationId, current),
            for (final group in groups.entries)
              if (group.key != widget.conversationId) group,
          ];
          final grouped = _showAll && widget.conversationId != null;
          final showNewCard = desktop && (_query.isEmpty || tabs.isEmpty);
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = desktop
                  ? (constraints.maxWidth / 330).floor().clamp(1, 4)
                  : (constraints.maxWidth >= 300 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 28
                        ? 2
                        : 1);
              const gap = 18.0;
              const inset = 20.0;
              final cardWidth =
                  (constraints.maxWidth - inset * 2 - gap * (columns - 1)) /
                  columns;
              final labelHeight =
                  MediaQuery.textScalerOf(context).scale(14) * 1.3 + 18;
              final previewHeight = cardWidth * (desktop ? .62 : 1.4);
              final safe = MediaQuery.paddingOf(context);
              final fieldHeight = _searchExpanded
                  ? (MediaQuery.textScalerOf(context).scale(16) * 1.3 + 28)
                        .clamp(44.0, 120.0)
                  : 44.0;
              final scopeHeight = math.max(
                44.0,
                MediaQuery.textScalerOf(context).scale(13) * 1.3 + 24,
              );
              final searchHeight =
                  widget.conversationId == null || _searchExpanded
                  ? fieldHeight
                  : scopeHeight;
              final toolbarHeight =
                  (MediaQuery.textScalerOf(context).scale(15) * 1.3 + 30).clamp(
                    52.0,
                    120.0,
                  );
              final gridPadding = EdgeInsets.fromLTRB(
                inset,
                safe.top + searchHeight + 30,
                inset,
                safe.bottom + toolbarHeight + 38,
              );
              final activeIndex = tabs.indexWhere(
                (tab) => tab.id == widget.service.activeTabId,
              );
              final headerHeight =
                  MediaQuery.textScalerOf(context).scale(12) * 1.3 + 16;
              if (widget.scrollController == null &&
                  widget.transition != null &&
                  _gridController == null) {
                // Scroll only enough to reveal the current row, and never begin
                // beyond the real scroll range. An out-of-range initial offset
                // makes iOS bounce the grid during the flight, leaving its frozen
                // destination at another card's eventual position.
                final row = math.max(0, activeIndex) ~/ columns;
                final rows = (tabs.length / columns).ceil();
                final cellHeight = previewHeight + labelHeight;
                final stride = cellHeight + 22;
                var contentHeight =
                    gridPadding.vertical +
                    rows * cellHeight +
                    math.max(0, rows - 1) * 22;
                var activeBottom = gridPadding.top + row * stride + cellHeight;
                if (grouped) {
                  var offset = gridPadding.top;
                  for (final group in groupEntries) {
                    final index = group.value.indexWhere(
                      (tab) => tab.id == widget.service.activeTabId,
                    );
                    if (index >= 0) {
                      activeBottom =
                          offset +
                          headerHeight +
                          (index ~/ columns) * stride +
                          cellHeight;
                    }
                    offset +=
                        headerHeight +
                        (group.value.length / columns).ceil() * stride;
                  }
                  contentHeight = offset + gridPadding.bottom;
                }
                final maxOffset = math.max(
                  0.0,
                  contentHeight - constraints.maxHeight,
                );
                final revealOffset =
                    activeBottom - (constraints.maxHeight - gridPadding.bottom);
                _gridController = ScrollController(
                  initialScrollOffset: revealOffset.clamp(0.0, maxOffset),
                );
              }
              Widget card(BrowserTab tab) => _TabCard(
                key: ValueKey('browserTabCard-${tab.id}'),
                tab: tab,
                desktop: desktop,
                active: tab.id == widget.service.activeTabId,
                service: widget.service,
                bytes: _previewForTab(tab.id),
                raster: widget.transition?.startPageSnapshotFor(tab),
                previewKey: widget.transition?.previewKeyFor(tab.id),
                onSelect: () => widget.onSelect(tab.id),
                onClose: () => widget.onClose(tab.id),
              );
              final delegate = SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: previewHeight + labelHeight,
                crossAxisSpacing: gap,
                mainAxisSpacing: 22,
              );
              Widget grid(
                EdgeInsets padding,
              ) => NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  widget.transition?.invalidateGeometry();
                  return false;
                },
                child: grouped
                    ? CustomScrollView(
                        key: const ValueKey('browserTabGrid'),
                        controller: widget.scrollController ?? _gridController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(height: padding.top),
                          ),
                          for (final group in groupEntries) ...[
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: headerHeight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: inset,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${group.key == widget.conversationId ? l.browserTabsCurrentConversation : widget.conversationTitle?.call(group.key) ?? (group.key == null ? l.browserTabsUnassigned : l.browserTabsUnknownConversation)} · ${group.value.length}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.3,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                inset,
                                0,
                                inset,
                                22,
                              ),
                              sliver: SliverGrid(
                                gridDelegate: delegate,
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => card(group.value[index]),
                                  childCount: group.value.length,
                                ),
                              ),
                            ),
                          ],
                          if (showNewCard)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: inset,
                              ),
                              sliver: SliverGrid(
                                gridDelegate: delegate,
                                delegate: SliverChildListDelegate.fixed([
                                  _NewTabCard(onNew: widget.onNew),
                                ]),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: padding.bottom),
                          ),
                        ],
                      )
                    : GridView.builder(
                        key: const ValueKey('browserTabGrid'),
                        controller: widget.scrollController ?? _gridController,
                        padding: padding,
                        gridDelegate: delegate,
                        itemCount: tabs.length + (showNewCard ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == tabs.length) {
                            return _NewTabCard(onNew: widget.onNew);
                          }
                          return card(tabs[index]);
                        },
                      ),
              );
              if (desktop) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      child: Row(
                        children: [
                          if (widget.conversationId != null) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: (constraints.maxWidth - 52) / 2,
                              ),
                              child: _scopeSelector(context, desktop: true),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: _searchField(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: grid(
                        const EdgeInsets.fromLTRB(inset, 0, inset, 20),
                      ),
                    ),
                  ],
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  // The viewport itself covers both safe areas. Insets only position
                  // the initial/final cards, so scrolling passes beneath the edges.
                  Positioned.fill(child: grid(gridPadding)),
                  if (tabs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _query.isNotEmpty
                              ? l.browserTabsNoResults
                              : l.browserTabsEmptyConversation,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: (safe.top + searchHeight + 42).clamp(
                      0.0,
                      constraints.maxHeight / 2,
                    ),
                    child: const BrowserProgressiveEdge(
                      key: ValueKey('browserTabsTopEdge'),
                      top: true,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: (safe.bottom + toolbarHeight + 46).clamp(
                      0.0,
                      constraints.maxHeight / 2,
                    ),
                    child: const BrowserProgressiveEdge(
                      key: ValueKey('browserTabsBottomEdge'),
                      top: false,
                    ),
                  ),
                  Positioned(
                    top: safe.top + 12,
                    left: 20,
                    right: 20,
                    child: widget.conversationId == null || _searchExpanded
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: _mobileSearch(context),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _scopeSelector(
                                    context,
                                    desktop: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _mobileSearch(context),
                            ],
                          ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: safe.bottom + 12,
                    child: Row(
                      key: const ValueKey('browserTabActions'),
                      children: [
                        BrowserSurfaceIconButton(
                          size: 52,
                          iconSize: 25,
                          surface: true,
                          label: l.browserNewTab,
                          icon: LucideIcons.plus,
                          onPressed: widget.onNew,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Center(
                            child: BrowserGlass(
                              key: const ValueKey('browserTabCountPill'),
                              radius: 1000,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                                child: Text(
                                  l.browserTabsCount(scopedTabs.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        BrowserSurfaceIconButton(
                          label: l.browserDone,
                          icon: LucideIcons.check,
                          size: 52,
                          iconSize: 25,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          onPressed:
                              widget.onDone ??
                              () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _mobileSearch(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!_searchExpanded) {
      return BrowserSurfaceIconButton(
        label: l.browserSearchTabs,
        icon: LucideIcons.search,
        size: 44,
        surface: true,
        onPressed: () => setState(() => _searchExpanded = true),
      );
    }
    return Row(
      children: [
        Expanded(child: _searchField(context)),
        const SizedBox(width: 10),
        BrowserSurfaceIconButton(
          label: l.browserCancel,
          icon: LucideIcons.x,
          size: 44,
          surface: true,
          onPressed: () {
            _searchFocus.unfocus();
            _search.clear();
            setState(() {
              _searchExpanded = false;
              _query = '';
            });
          },
        ),
      ],
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    super.key,
    required this.tab,
    required this.desktop,
    required this.active,
    required this.bytes,
    required this.service,
    required this.onSelect,
    required this.onClose,
    this.previewKey,
    this.raster,
  });
  final BrowserTab tab;
  final bool desktop;
  final bool active;
  final Uint8List? bytes;
  final BrowserService service;
  final VoidCallback onSelect, onClose;
  final Key? previewKey;
  final ui.Image? raster;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final title = tab.title.isEmpty ? l.browserNewTab : tab.title;
    return BrowserSurfaceButton(
      semanticLabel: title,
      selected: active,
      onPressed: onSelect,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? colors.primary.withValues(alpha: desktop ? .65 : .3)
                      : colors.onSurface.withValues(alpha: desktop ? .1 : .045),
                  width: active ? (desktop ? 2 : 1) : .5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      key: previewKey,
                      borderRadius: BorderRadius.circular(18),
                      child: ColoredBox(
                        color: colors.surfaceContainerLowest,
                        child: raster != null
                            ? RawImage(
                                image: raster,
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                filterQuality: FilterQuality.low,
                              )
                            : bytes != null
                            ? Image.memory(
                                bytes!,
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                // Native thumbnails are already bounded to
                                // 440px. Share the same MemoryImage cache key
                                // with the flight and native attachment cover.
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, __, ___) =>
                                    _TabPlaceholder(tab: tab, service: service),
                              )
                            : _TabPlaceholder(tab: tab, service: service),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: BrowserSurfaceIconButton(
                        label: l.browserCloseTab,
                        icon: LucideIcons.x,
                        size: desktop ? 26 : 30,
                        iconSize: desktop ? 14 : 18,
                        backgroundColor: colors.surfaceContainerHighest
                            .withValues(alpha: .94),
                        onPressed: onClose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 10, 3, 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrowserFavicon(url: tab.url, service: service, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewTabCard extends StatelessWidget {
  const _NewTabCard({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.browserNewTab;
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: BrowserSurfaceButton(
        key: const ValueKey('browserNewTabCard'),
        semanticLabel: label,
        onPressed: onNew,
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: .035),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: .12),
                    width: .5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.plus,
                    size: 34,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 10, 3, 3),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.tab, required this.service});
  final BrowserTab tab;
  final BrowserService service;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrowserFavicon(url: tab.url, service: service, size: 34),
          const SizedBox(height: 14),
          Text(
            tab.title.isEmpty
                ? AppLocalizations.of(context)!.browserNewTab
                : tab.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
