import 'creation_reference_actions.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/media_creation_controller.dart';
import 'creation_lightbox.dart';
import 'creation_controls.dart';
import '../../../theme/app_semantic_colors.dart';

class CreationGallery extends StatefulWidget {
  const CreationGallery({
    super.key,
    required this.desktop,
    required this.onOpenTopic,
    this.onToggleRail,
    this.mobileQuery = '',
    this.artworkRequest,
    this.onArtworkOpened,
  });

  final bool desktop;
  final String mobileQuery;
  final OpenCreationTopic onOpenTopic;
  final VoidCallback? onToggleRail;
  final OpenCreationArtwork? artworkRequest;
  final VoidCallback? onArtworkOpened;

  @override
  State<CreationGallery> createState() => _CreationGalleryState();
}

class _CreationGalleryState extends State<CreationGallery> {
  CreationGalleryFilter _filter = CreationGalleryFilter.all;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  OpenCreationArtwork? _opened;

  @override
  void didUpdateWidget(covariant CreationGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artworkRequest != null &&
        widget.artworkRequest != oldWidget.artworkRequest) {
      _filter = CreationGalleryFilter.all;
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryContext = context;
    final media = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final query = widget.desktop ? _search.text : widget.mobileQuery;
    final chat = context.read<ChatService?>();
    String? conversationTitle(String id) => chat?.getConversation(id)?.title;
    final items = media.galleryItems(
      _filter,
      query,
      conversationTitle: conversationTitle,
    );
    if (widget.artworkRequest case final request? when request != _opened) {
      final item = media.item(request.itemId);
      if (item != null) {
        _opened = request;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.artworkRequest != request) return;
          widget.onArtworkOpened?.call();
          showCreationLightbox(
            galleryContext,
            item,
            desktop: widget.desktop,
            gallery: items,
            onOpenTopic: widget.onOpenTopic,
          );
        });
      }
    }
    final colors = Theme.of(context).colorScheme;
    final labels = [
      l10n.creationFilterAll,
      l10n.creationFilterImages,
      l10n.creationFilterVideos,
      l10n.creationFilterFavorites,
    ];
    void setFilter(int index) =>
        setState(() => _filter = CreationGalleryFilter.values[index]);
    final tabs = SlidingSegmentedTabs(
      height: 28,
      compact: true,
      index: _filter.index,
      tabs: [for (final label in labels) SegmentedTab(label: label)],
      onChanged: setFilter,
    );
    final search = CreationSearchBox(
      controller: _search,
      focusNode: _searchFocus,
      hint: l10n.creationSearchGallery,
      onChanged: (_) => setState(() {}),
    );
    final title = Text(
      l10n.creationGallery,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 15, fontWeight: AppFontWeights.semibold),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.desktop)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 16, 0),
            child: LayoutBuilder(
              builder: (context, box) {
                final heading = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onToggleRail case final toggle?)
                      IosIconButton(
                        icon: Lucide.panelLeft,
                        tooltip: l10n.creationTopics,
                        onTap: toggle,
                      ),
                    Flexible(child: title),
                  ],
                );
                if (box.maxWidth < 540) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: heading,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: search),
                          ],
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(width: 210, child: tabs),
                      ),
                    ],
                  );
                }
                return SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(child: heading),
                            const SizedBox(width: 12),
                            SizedBox(width: 195, child: tabs),
                          ],
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _searchFocus,
                        child: search,
                        builder: (context, child) => AnimatedContainer(
                          duration: handoffDuration(context, 200),
                          curve: handoffCurve,
                          width: box.maxWidth < 670
                              ? 162
                              : _searchFocus.hasFocus
                              ? 280
                              : 220,
                          child: child,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                for (final (i, label) in labels.indexed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Semantics(
                      selected: _filter.index == i,
                      button: true,
                      child: IosCardPress(
                        baseColor: _filter.index == i
                            ? colors.onSurface
                            : context.appColors.surfaceFill,
                        duration: handoffDuration(context, 160),
                        focusable: true,
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        onTap: () => setFilter(i),
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            children: [
                              if (i == 3) ...[
                                Icon(
                                  LucideIcons.star,
                                  size: 13,
                                  color: _filter.index == i
                                      ? colors.surface
                                      : colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: _filter.index == i
                                      ? colors.surface
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: widget.desktop ? 96 : 48,
                    bottom: CreationDockInset.bottomOf(context, 140),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filter == CreationGalleryFilter.favorites
                              ? LucideIcons.star300
                              : LucideIcons.images300,
                          color: colors.onSurface.withValues(alpha: .42),
                          size: widget.desktop ? 56 : 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          query.trim().isNotEmpty
                              ? l10n.creationGalleryNoResults
                              : _filter == CreationGalleryFilter.favorites
                              ? l10n.creationFavoritesEmpty
                              : media.galleryCount == 0
                              ? l10n.creationGalleryEmpty
                              : l10n.creationGalleryNoResults,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = widget.desktop
                        ? ((constraints.maxWidth - 48) ~/ 170).clamp(2, 4)
                        : 3;
                    return GridView.builder(
                      key: ValueKey((_filter, query)),
                      padding: EdgeInsets.fromLTRB(
                        widget.desktop ? 24 : 10,
                        widget.desktop ? 8 : 0,
                        widget.desktop ? 24 : 10,
                        CreationDockInset.bottomOf(context, 168),
                      ),
                      gridDelegate: !widget.desktop
                          ? const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                            )
                          : _MasonryDelegate(
                              columns: columns,
                              ratios: [
                                for (final item in items) _galleryRatio(item),
                              ],
                            ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final batch = media.batch(item.batchId);
                        final conversationId = batch?.conversationId;
                        final title = conversationId == null
                            ? null
                            : conversationTitle(conversationId);
                        return CreationArtworkTile(
                          item: item,
                          galleryTile: true,
                          desktop: widget.desktop,
                          showSource: batch?.source == GenerationSource.chat,
                          sourceLabel: batch?.topicId == null
                              ? title != null && title.trim().isNotEmpty
                                    ? l10n.creationChatSource(title)
                                    : l10n.creationRecentChat
                              : media.topic(batch!.topicId!)?.title,
                          onMenu: (anchor) => showCreationArtworkMenu(
                            galleryContext,
                            item,
                            desktop: widget.desktop,
                            gallery: items,
                            onOpenTopic: widget.onOpenTopic,
                            anchor: anchor,
                          ),
                          onOpen: () => showCreationLightbox(
                            galleryContext,
                            item,
                            desktop: widget.desktop,
                            gallery: items,
                            onOpenTopic: widget.onOpenTopic,
                          ),
                          onEdit: () => showCreationLightbox(
                            galleryContext,
                            item,
                            desktop: widget.desktop,
                            gallery: items,
                            onOpenTopic: widget.onOpenTopic,
                            startEditing: true,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

double _galleryRatio(GenerationItemRow item) {
  final width = item.width;
  final height = item.height;
  return width != null && height != null && width > 0 && height > 0
      ? (width / height).clamp(.52, 2.4)
      : item.mode == MediaMode.video
      ? 16 / 9
      : 1;
}

class CreationArtworkTile extends StatefulWidget {
  const CreationArtworkTile({
    super.key,
    required this.item,
    required this.desktop,
    this.galleryTile = false,
    required this.onOpen,
    this.sourceLabel,
    this.draftTopicId,
    this.onMenu,
    this.onEdit,
    this.showSource = false,
  });

  final GenerationItemRow item;
  final bool desktop;
  final bool galleryTile;
  final VoidCallback onOpen;
  final String? sourceLabel, draftTopicId;
  final ValueChanged<Rect?>? onMenu;
  final VoidCallback? onEdit;
  final bool showSource;

  @override
  State<CreationArtworkTile> createState() => _CreationArtworkTileState();
}

class _CreationArtworkTileState extends State<CreationArtworkTile> {
  bool _hovered = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final showTools = widget.desktop && (_hovered || _focused);
    final l10n = AppLocalizations.of(context)!;
    final media = context.read<MediaCreationController>();
    void openMenu([Rect? anchor]) {
      if (widget.onMenu case final callback?) {
        callback(anchor);
      } else {
        showCreationArtworkMenu(
          context,
          item,
          desktop: widget.desktop,
          draftTopicId: widget.draftTopicId,
          anchor: anchor,
        );
      }
    }

    return Focus(
      skipTraversal: !widget.desktop,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (node, event) {
        if (!node.hasPrimaryFocus ||
            event is! KeyDownEvent ||
            (event.logicalKey != LogicalKeyboardKey.enter &&
                event.logicalKey != LogicalKeyboardKey.space)) {
          return KeyEventResult.ignored;
        }
        widget.onOpen();
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        onEnter: widget.desktop ? (_) => setState(() => _hovered = true) : null,
        onExit: widget.desktop ? (_) => setState(() => _hovered = false) : null,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onOpen,
          onSecondaryTapDown: widget.desktop
              ? (details) => openMenu(details.globalPosition & Size.zero)
              : null,
          onLongPress: widget.desktop ? null : openMenu,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              widget.galleryTile
                  ? widget.desktop
                        ? 12
                        : 8
                  : 16,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CreationMediaCover(item, thumbnail: widget.galleryTile),
                if (widget.desktop)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: CreationHoverActions(
                      visible: showTools,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x5c000000)],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(5, 38, 5, 5),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final size = width < 150 ? 26.0 : 30.0;
                            Widget button(
                              IconData icon,
                              String label,
                              VoidCallback tap, {
                              bool showLabel = false,
                            }) => DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(size / 2),
                              ),
                              child: IosIconButton(
                                builder: (color) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, color: color, size: 14),
                                    if (showLabel) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12.5,
                                          fontWeight: AppFontWeights.semibold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                color: Colors.white,
                                borderRadius: size / 2,
                                minSize: size,
                                tooltip: showLabel ? null : label,
                                padding: EdgeInsets.symmetric(
                                  horizontal: showLabel ? 9 : 4,
                                  vertical: 4,
                                ),
                                onTap: tap,
                              ),
                            );
                            final edit = media.editingModel(item) != null;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: math.max(width, 120),
                                child: Row(
                                  spacing: 3,
                                  children: [
                                    if (edit)
                                      button(
                                        Lucide.Pencil,
                                        l10n.creationEditImage,
                                        widget.onEdit ??
                                            () => showCreationLightbox(
                                              context,
                                              item,
                                              desktop: true,
                                              draftTopicId: widget.draftTopicId,
                                              startEditing: true,
                                            ),
                                        showLabel: width >= 220,
                                      ),
                                    Expanded(
                                      child: Text(
                                        widget.sourceLabel ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    button(
                                      item.favorite
                                          ? LucideIcons.starOff
                                          : LucideIcons.star,
                                      item.favorite
                                          ? l10n.creationUnfavorite
                                          : l10n.creationFavorite,
                                      () => toggleCreationArtworkFavorite(
                                        context,
                                        media,
                                        item,
                                      ),
                                    ),
                                    if (item.mode == MediaMode.image)
                                      button(
                                        LucideIcons.imagePlus,
                                        l10n.creationUseReference,
                                        () => addCreationReferences(
                                          context,
                                          media,
                                          widget.draftTopicId,
                                          [item.path],
                                        ),
                                      ),
                                    Builder(
                                      builder: (anchor) => button(
                                        Lucide.Ellipsis,
                                        l10n.chatMessageWidgetMoreTooltip,
                                        () {
                                          final box =
                                              anchor.findRenderObject()!
                                                  as RenderBox;
                                          openMenu(
                                            Rect.fromPoints(
                                              box.localToGlobal(Offset.zero),
                                              box.localToGlobal(
                                                box.size.bottomRight(
                                                  Offset.zero,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (widget.showSource && widget.sourceLabel != null)
                  PositionedDirectional(
                    start: 6,
                    end: 6,
                    bottom: 6,
                    child: CreationHoverActions(
                      visible: !showTools,
                      child: Text(
                        widget.sourceLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                        ),
                      ),
                    ),
                  ),
                if (item.favorite)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: CreationHoverActions(
                      visible: !showTools,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            LucideIcons.star,
                            color: Color(0xffffd86b),
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MasonryDelegate extends SliverGridDelegate {
  _MasonryDelegate({required this.columns, required this.ratios});

  final int columns;
  final List<double> ratios;
  double? _width;
  bool? _reverse;
  _MasonryLayout? _cached;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final reverse = axisDirectionIsReversed(constraints.crossAxisDirection);
    if (_width == width && _reverse == reverse && _cached != null) {
      return _cached!;
    }
    const gap = 10.0;
    final tileWidth = math.max(1.0, (width - gap * (columns - 1)) / columns);
    final heights = List.filled(columns, 0.0);
    final positions = <SliverGridGeometry>[];
    final bottoms = <double>[];
    for (final ratio in ratios) {
      var column = 0;
      for (var index = 1; index < columns; index++) {
        if (heights[index] < heights[column]) column = index;
      }
      final left =
          (reverse ? columns - 1 - column : column) * (tileWidth + gap);
      final top = heights[column];
      final height = tileWidth / ratio;
      positions.add(
        SliverGridGeometry(
          scrollOffset: top,
          crossAxisOffset: left,
          mainAxisExtent: height,
          crossAxisExtent: tileWidth,
        ),
      );
      bottoms.add(math.max(top + height, bottoms.lastOrNull ?? 0));
      heights[column] += height + gap;
    }
    _width = width;
    _reverse = reverse;
    return _cached = _MasonryLayout(positions, bottoms);
  }

  @override
  bool shouldRelayout(_MasonryDelegate oldDelegate) =>
      columns != oldDelegate.columns || !listEquals(ratios, oldDelegate.ratios);
}

class _MasonryLayout extends SliverGridLayout {
  const _MasonryLayout(this.positions, this.bottoms);

  final List<SliverGridGeometry> positions;
  final List<double> bottoms;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) => _firstIndex(
    (index) => bottoms[index] >= scrollOffset,
  ).clamp(0, math.max(0, positions.length - 1));

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) => math.max(
    0,
    _firstIndex((index) => positions[index].scrollOffset > scrollOffset) - 1,
  );

  int _firstIndex(bool Function(int) predicate) {
    var low = 0;
    var high = positions.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (predicate(middle)) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => positions[index];

  @override
  double computeMaxScrollOffset(int childCount) =>
      childCount == 0 ? 0 : bottoms[childCount - 1];
}
