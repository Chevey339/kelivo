import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/database/app_database.dart';
import '../core/models/media_creation.dart';
import 'hotkeys/chat_action_bus.dart';
import '../features/media/widgets/creation_gallery.dart';
import '../features/media/widgets/creation_preferences.dart';
import '../features/media/pages/media_creation_page.dart';
import '../features/media/providers/media_creation_controller.dart';
import '../features/media/widgets/creation_composer.dart';
import '../features/media/widgets/creation_timeline.dart';
import '../features/media/widgets/creation_topic_card.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/ios_tactile.dart';
import '../shared/widgets/thinking_sheen.dart';
import '../theme/app_font_weights.dart';
import '../theme/app_semantic_colors.dart';
import '../features/media/widgets/creation_controls.dart';
import '../shared/widgets/plain_text_input.dart';

class DesktopMediaCreationPage extends StatefulWidget {
  const DesktopMediaCreationPage({
    super.key,
    this.artworkRequest,
    this.onArtworkOpened,
  });

  final OpenCreationArtwork? artworkRequest;
  final VoidCallback? onArtworkOpened;

  @override
  State<DesktopMediaCreationPage> createState() =>
      _DesktopMediaCreationPageState();
}

class _DesktopMediaCreationPageState extends State<DesktopMediaCreationPage> {
  String? _topicId;
  bool _navigationOpen = false;
  bool _gallery = false;
  String? _highlightBatch;

  @override
  void initState() {
    super.initState();
    _gallery = widget.artworkRequest != null;
  }

  @override
  void didUpdateWidget(covariant DesktopMediaCreationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artworkRequest != null &&
        widget.artworkRequest != oldWidget.artworkRequest) {
      _gallery = true;
      _topicId = null;
      _highlightBatch = null;
      _navigationOpen = false;
    }
  }

  void _open(String? id, {String? batch}) {
    setState(() {
      _topicId = id;
      _highlightBatch = batch;
      _gallery = false;
      _navigationOpen = false;
    });
  }

  void _showGallery() {
    setState(() {
      _gallery = true;
      _topicId = null;
      _highlightBatch = null;
      _navigationOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final topic = _topicId == null ? null : media.topic(_topicId!);
    return CreationSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final rail = _CreationTopicRail(
            active: _topicId,
            gallery: _gallery,
            onOpen: _open,
            onOpenGallery: _showGallery,
          );
          final toggle = compact
              ? () => setState(() => _navigationOpen = !_navigationOpen)
              : null;
          final activeBatch = _topicId == null
              ? null
              : media
                    .batchesFor(_topicId!)
                    .reversed
                    .where((batch) => batch.status.isActive)
                    .firstOrNull;
          Widget shortcuts(Widget child) => CallbackShortcuts(
            bindings: {
              if (_navigationOpen)
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    setState(() => _navigationOpen = false)
              else if (activeBatch != null)
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    unawaited(media.runner.cancel(activeBatch.id)),
            },
            child: Focus(autofocus: true, child: child),
          );
          final body = ColoredBox(
            color: cs.surface,
            child: Column(
              children: [
                if (!_gallery)
                  _CreationHeader(
                    key: ValueKey(_topicId),
                    topic: topic,
                    onDeleted: () => _open(null),
                    onToggleRail: toggle,
                  ),
                Expanded(
                  child: CreationComposerStack(
                    desktop: true,
                    topicId: _topicId,
                    content: _gallery
                        ? CreationGallery(
                            desktop: true,
                            artworkRequest: widget.artworkRequest,
                            onArtworkOpened: widget.onArtworkOpened,
                            onToggleRail: toggle,
                            onOpenTopic: (id, batch) => _open(id, batch: batch),
                          )
                        : CreationTimeline(
                            key: ValueKey((_topicId, _highlightBatch)),
                            topicId: _topicId,
                            desktop: true,
                            highlightBatchId: _highlightBatch,
                          ),
                    composer: CreationComposer(
                      topicId: _topicId,
                      desktop: true,
                      onSent: (id) {
                        if (id != _topicId) _open(id);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
          if (!compact) {
            return shortcuts(
              Row(
                children: [
                  SizedBox(width: 272, child: rail),
                  Expanded(child: body),
                ],
              ),
            );
          }
          return shortcuts(
            Stack(
              children: [
                Positioned.fill(child: body),
                if (_navigationOpen) ...[
                  Positioned.fill(
                    child: ModalBarrier(
                      color: cs.scrim.withValues(alpha: .2),
                      onDismiss: () => setState(() => _navigationOpen = false),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: math.min(272, constraints.maxWidth * .78),
                    child: rail,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreationTopicRail extends StatefulWidget {
  const _CreationTopicRail({
    required this.active,
    required this.gallery,
    required this.onOpen,
    required this.onOpenGallery,
  });
  final String? active;
  final bool gallery;
  final ValueChanged<String?> onOpen;
  final VoidCallback onOpenGallery;

  @override
  State<_CreationTopicRail> createState() => _CreationTopicRailState();
}

class _CreationTopicRailState extends State<_CreationTopicRail> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final topics = media.searchTopics(_query).toList();
    final showNew =
        !widget.gallery && widget.active == null && _query.trim().isEmpty;
    final covers = media.topicView == CreationTopicView.covers;
    final list = media.topicView == CreationTopicView.list;
    Widget topicAt(int index) {
      if (showNew && index == 0) {
        return list
            ? SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Icon(Lucide.Plus, size: 20, color: cs.primary),
                    const SizedBox(width: 9),
                    Text(l10n.creationNewTopic),
                  ],
                ),
              )
            : _NewTopicCard(minimal: covers);
      }
      final topic = topics[index - (showNew ? 1 : 0)];
      return CreationTopicCard(
        key: ValueKey(topic.id),
        topic: topic,
        desktop: true,
        selected: topic.id == widget.active,
        onOpen: () => widget.onOpen(topic.id),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: cs.onSurface.withValues(alpha: .06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: CreationSearchBox(
                    hint: l10n.creationSearchTopics,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 6),
                IosIconButton(
                  icon: Lucide.SquarePen,
                  size: 18,
                  minSize: 32,
                  tooltip: l10n.creationNewTopic,
                  onTap: () => widget.onOpen(null),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: IosCardPress(
              focusable: true,
              onTap: widget.onOpenGallery,
              borderRadius: BorderRadius.circular(11),
              baseColor: widget.gallery
                  ? cs.primary.withValues(alpha: .1)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.layoutGrid,
                    size: 17,
                    color: widget.gallery ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.creationGallery,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: widget.gallery ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${media.galleryCount}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.creationTopicCount(topics.length),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
                Builder(
                  builder: (anchor) => IosIconButton(
                    icon: creationTopicViewIcon(media.topicView),
                    size: 16,
                    minSize: 28,
                    tooltip: l10n.creationDisplayAndGames,
                    onTap: () => showCreationDisplayMenu(anchor, desktop: true),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (list)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                    sliver: SliverList.builder(
                      itemCount: topics.length + (showNew ? 1 : 0),
                      itemBuilder: (_, index) => topicAt(index),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: covers ? 3 : 2,
                        mainAxisSpacing: covers ? 6 : 14,
                        crossAxisSpacing: covers ? 6 : 10,
                        childAspectRatio: covers ? 1 : .75,
                      ),
                      itemCount: topics.length + (showNew ? 1 : 0),
                      itemBuilder: (_, index) => topicAt(index),
                    ),
                  ),
                if (topics.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _query.trim().isEmpty
                            ? l10n.creationTopicsEmpty
                            : l10n.creationNoMatchingTopics,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withValues(alpha: .42),
                        ),
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewTopicCard extends StatelessWidget {
  const _NewTopicCard({required this.minimal});

  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final media = context.watch<MediaCreationController>();
    final radius = BorderRadius.circular(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            foregroundPainter: _TopicOutline(cs.primary.withValues(alpha: .45)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .06),
                borderRadius: radius,
              ),
              child: Center(child: Icon(Lucide.Plus, color: cs.primary)),
            ),
          ),
        ),
        if (!minimal) ...[
          const SizedBox(height: 5),
          Text(
            l10n.creationNewTopic,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: AppFontWeights.semibold,
              color: cs.primary,
            ),
          ),
          Text(
            media.autoTitle
                ? l10n.creationNameAfterSending
                : l10n.creationPromptTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _TopicOutline extends CustomPainter {
  const _TopicOutline(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.75),
          const Radius.circular(12),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final contour in outline.computeMetrics()) {
      for (double start = 0; start < contour.length; start += 8) {
        canvas.drawPath(
          contour.extractPath(start, math.min(start + 5, contour.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TopicOutline oldDelegate) => oldDelegate.color != color;
}

class _CreationHeader extends StatefulWidget {
  const _CreationHeader({
    super.key,
    required this.topic,
    required this.onDeleted,
    this.onToggleRail,
  });
  final GenerationTopicRow? topic;
  final VoidCallback onDeleted;
  final VoidCallback? onToggleRail;

  @override
  State<_CreationHeader> createState() => _CreationHeaderState();
}

class _CreationHeaderState extends State<_CreationHeader> {
  final _title = TextEditingController();
  bool _editing = false;

  void _edit() {
    final text = widget.topic?.title;
    if (text == null || text.isEmpty) return;
    _title.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    setState(() => _editing = true);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final topic = widget.topic;
    final naming = topic != null && media.namingTopic(topic.id);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
        child: Row(
          children: [
            if (widget.onToggleRail != null) ...[
              IosIconButton(
                icon: Lucide.panelLeft,
                tooltip: l10n.creationTopics,
                onTap: widget.onToggleRail,
              ),
              const SizedBox(width: 4),
            ],
            if (_editing && topic != null)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 300,
                    minHeight: 32,
                  ),
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () =>
                          setState(() => _editing = false),
                    },
                    child: PlainTextInput(
                      controller: _title,
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceFill,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary, width: 1.5),
                      ),
                      autofocus: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      onSubmitted: (value) async {
                        setState(() => _editing = false);
                        await media.renameTopic(topic.id, value);
                      },
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: GestureDetector(
                  onTap: naming || topic == null ? null : _edit,
                  child: ThinkingSheen(
                    enabled: naming,
                    child: Text(
                      topic == null
                          ? l10n.creationNewTopic
                          : naming
                          ? l10n.creationNaming
                          : topic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                topic == null
                    ? media.autoTitle
                          ? l10n.creationNameAfterSending
                          : l10n.creationPromptTitle
                    : '${l10n.creationGenerationCount(media.batchesFor(topic.id).length)} · ${l10n.creationWorksCount(media.worksFor(topic.id).length)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
            const Spacer(),
            if (topic != null)
              Builder(
                builder: (context) => IosIconButton(
                  icon: Lucide.Ellipsis,
                  tooltip: l10n.chatMessageWidgetMoreTooltip,
                  onTap: () => showCreationTopicMenu(
                    context,
                    topic,
                    desktop: true,
                    onRename: _edit,
                    onDeleted: widget.onDeleted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
