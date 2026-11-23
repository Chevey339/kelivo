import '../widgets/creation_reference_actions.dart';
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/media_creation_controller.dart';
import '../widgets/creation_composer.dart';
import '../widgets/creation_controls.dart';
import '../widgets/creation_gallery.dart';
import '../widgets/creation_display_menu.dart';
import '../widgets/creation_reference_picker.dart';
import '../widgets/creation_timeline.dart';
import '../widgets/creation_topic_card.dart';

class MediaCreationPage extends StatefulWidget {
  const MediaCreationPage({
    super.key,
    required this.onOpenDrawer,
    this.artworkRequest,
    this.onArtworkOpened,
  });

  final VoidCallback onOpenDrawer;
  final OpenCreationArtwork? artworkRequest;
  final VoidCallback? onArtworkOpened;

  @override
  State<MediaCreationPage> createState() => _MediaCreationPageState();
}

class _MediaCreationPageState extends State<MediaCreationPage> {
  bool _searching = false;
  String _query = '';
  bool _gallery = false;

  @override
  void initState() {
    super.initState();
    _gallery = widget.artworkRequest != null;
  }

  @override
  void didUpdateWidget(covariant MediaCreationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artworkRequest != null &&
        widget.artworkRequest != oldWidget.artworkRequest) {
      _gallery = true;
      _searching = false;
      _query = '';
    }
  }

  void _openTopic(String id, {String? batch}) {
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder(
          transitionDuration: handoffDuration(context, 380),
          reverseTransitionDuration: handoffDuration(context, 380),
          pageBuilder: (_, _, _) =>
              _MobileTopicPage(topicId: id, highlightBatchId: batch),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  (Directionality.of(context) == TextDirection.rtl ? -40 : 40) *
                      (1 - handoffCurve.transform(animation.value)),
                  0,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final topics = media.searchTopics(_query).toList();
    final searchHint = _gallery
        ? l10n.creationSearchGallery
        : l10n.creationSearchTopics;
    return CreationSurface(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CreationMobileBar(
              searching: _searching,
              leading: IosIconButton(
                icon: _searching ? Lucide.ArrowLeft : Lucide.Menu,
                minSize: 44,
                tooltip: _searching
                    ? MaterialLocalizations.of(context).backButtonTooltip
                    : MaterialLocalizations.of(context).showMenuTooltip,
                onTap: _searching
                    ? () => setState(() {
                        _searching = false;
                        _query = '';
                      })
                    : widget.onOpenDrawer,
              ),
              title: _searching
                  ? CreationSearchBox(
                      hint: searchHint,
                      mobile: true,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                    )
                  : Text(
                      l10n.creationTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              trailing: _searching
                  ? null
                  : IosIconButton(
                      icon: Lucide.Search,
                      size: 20,
                      minSize: 44,
                      tooltip: searchHint,
                      onTap: () => setState(() => _searching = true),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SlidingSegmentedTabs(
                index: _gallery ? 1 : 0,
                height: 38,
                tabs: [
                  SegmentedTab(label: l10n.creationTopics),
                  SegmentedTab(label: l10n.creationGallery),
                ],
                onChanged: (index) => setState(() {
                  _gallery = index == 1;
                  _searching = false;
                  _query = '';
                }),
              ),
            ),
            Expanded(
              child: CreationComposerStack(
                desktop: false,
                composer: CreationComposer(desktop: false, onSent: _openTopic),
                content: _gallery
                    ? CreationGallery(
                        desktop: false,
                        mobileQuery: _query,
                        artworkRequest: widget.artworkRequest,
                        onArtworkOpened: widget.onArtworkOpened,
                        onOpenTopic: (id, batch) =>
                            _openTopic(id, batch: batch),
                      )
                    : _MobileTopics(
                        query: _query,
                        items: topics,
                        display: media.topicView,
                        onOpen: _openTopic,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTopics extends StatelessWidget {
  const _MobileTopics({
    required this.items,
    required this.query,
    required this.display,
    required this.onOpen,
  });

  final String query;
  final List<GenerationTopicRow> items;
  final CreationTopicView display;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final covers = display == CreationTopicView.covers;
    final list = display == CreationTopicView.list;
    final showFirst = display == CreationTopicView.coverAndTitle;
    Widget card(GenerationTopicRow topic, {bool wide = false}) =>
        CreationTopicCard(
          key: ValueKey(topic.id),
          topic: topic,
          wide: wide,
          onOpen: () => onOpen(topic.id),
        );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.creationAllTopicCount(items.length),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .42),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Builder(
                  builder: (anchor) => IosIconButton(
                    icon: creationTopicViewIcon(display),
                    size: 18,
                    minSize: 36,
                    tooltip: l10n.creationDisplayAndGames,
                    onTap: () =>
                        showCreationDisplayMenu(anchor, desktop: false),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            child: query.trim().isEmpty
                ? const CreationEmptyState()
                : Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.creationNoMatchingTopics),
                    ),
                  ),
          ),
        if (items.isNotEmpty) ...[
          if (showFirst)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(child: card(items.first, wide: true)),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              covers ? 6 : 16,
              0,
              covers ? 6 : 16,
              CreationDockInset.bottomOf(context, 156),
            ),
            sliver: list
                ? SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => card(items[i]),
                  )
                : CreationTopicGrid(
                    desktop: false,
                    covers: covers,
                    itemCount: items.length - (showFirst ? 1 : 0),
                    itemBuilder: (_, i) => card(items[i + (showFirst ? 1 : 0)]),
                  ),
          ),
        ],
      ],
    );
  }
}

class _MobileTopicPage extends StatelessWidget {
  const _MobileTopicPage({required this.topicId, this.highlightBatchId});

  final String topicId;
  final String? highlightBatchId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final topic = state.topic(topicId);
    final name = topic?.title ?? '';
    final naming = state.namingTopic(topicId) || name.isEmpty;
    return CreationSurface(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              CreationMobileBar(
                leading: IosIconButton(
                  icon: Lucide.ArrowLeft,
                  minSize: 44,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ThinkingSheen(
                      enabled: naming,
                      child: Text(
                        naming ? l10n.creationNaming : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                    Text(
                      l10n.creationGenerationCount(
                        state.batchesFor(topicId).length,
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: topic == null
                    ? null
                    : IosIconButton(
                        icon: Lucide.Ellipsis,
                        minSize: 42,
                        tooltip: l10n.chatMessageWidgetMoreTooltip,
                        onTap: () => showCreationTopicMenu(
                          context,
                          topic,
                          desktop: false,
                          onDeleted: () => Navigator.of(context).pop(),
                        ),
                      ),
              ),
              Expanded(
                child: CreationComposerStack(
                  desktop: false,
                  topicId: topicId,
                  composer: CreationComposer(
                    topicId: topicId,
                    desktop: false,
                    onSent: (_) {},
                  ),
                  content: CreationTimeline(
                    topicId: topicId,
                    desktop: false,
                    highlightBatchId: highlightBatchId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreationComposerStack extends StatefulWidget {
  const CreationComposerStack({
    super.key,
    required this.desktop,
    required this.content,
    required this.composer,
    this.topicId,
  });

  final bool desktop;
  final String? topicId;
  final Widget content, composer;

  @override
  State<CreationComposerStack> createState() => _CreationComposerStackState();
}

class _CreationComposerStackState extends State<CreationComposerStack> {
  bool _hover = false, _measurePending = false;
  final _dockKey = GlobalKey();
  double _dockHeight = 0;

  void _measureDock() {
    if (_measurePending) return;
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (!mounted) return;
      final size = _dockKey.currentContext?.size;
      if (size != null && size.height != _dockHeight) {
        setState(() => _dockHeight = size.height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _measureDock();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = context.read<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final surface = colors.surface;
    final desktop = widget.desktop;
    final stack = Stack(
      children: [
        Positioned.fill(
          child: CreationDockInset(height: _dockHeight, child: widget.content),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [surface.withValues(alpha: 0), surface],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: desktop ? 24 : 10,
          right: desktop ? 24 : 10,
          bottom: 0,
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _measureDock();
              return false;
            },
            child: SizeChangedLayoutNotifier(
              key: _dockKey,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: widget.composer,
                ),
              ),
            ),
          ),
        ),
        if (_hover)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary, width: 2),
                  color: surface.withValues(alpha: .86),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.imagePlus,
                        color: colors.primary,
                        size: 30,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        media.mode == MediaMode.video
                            ? l10n.creationFirstFrameDrop
                            : l10n.creationReferenceDrop,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (!desktop) return stack;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hover = true),
      onDragExited: (_) => setState(() => _hover = false),
      onDragDone: (details) {
        setState(() => _hover = false);
        final paths = creationImagePaths(
          details.files.map((file) => file.path),
        );
        if (paths.isEmpty) return;
        addCreationReferences(context, media, widget.topicId, paths);
      },
      child: stack,
    );
  }
}
