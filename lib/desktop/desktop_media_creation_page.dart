import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/database/app_database.dart';
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
import 'widgets/desktop_pane_surface.dart';

class DesktopMediaCreationPage extends StatefulWidget {
  const DesktopMediaCreationPage({super.key});

  @override
  State<DesktopMediaCreationPage> createState() =>
      _DesktopMediaCreationPageState();
}

class _DesktopMediaCreationPageState extends State<DesktopMediaCreationPage> {
  String? _topicId;
  bool _navigationOpen = false;

  void _open(String? id) {
    setState(() {
      _topicId = id;
      _navigationOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final topic = _topicId == null ? null : media.topic(_topicId!);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final rail = _CreationTopicRail(active: _topicId, onOpen: _open);
        final body = ColoredBox(
          color: cs.surface,
          child: Column(
            children: [
              _CreationHeader(
                key: ValueKey(_topicId),
                topic: topic,
                onDeleted: () => _open(null),
                onToggleRail: compact
                    ? () => setState(() => _navigationOpen = !_navigationOpen)
                    : null,
              ),
              Expanded(
                child: CreationComposerStack(
                  desktop: true,
                  content: CreationTimeline(topicId: _topicId, desktop: true),
                  composer: CreationComposer(
                    topicId: _topicId,
                    desktop: true,
                    onSent: _open,
                  ),
                ),
              ),
            ],
          ),
        );
        if (!compact) {
          return Row(
            children: [
              SizedBox(width: 272, child: rail),
              Expanded(child: body),
            ],
          );
        }
        return Stack(
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
        );
      },
    );
  }
}

class _CreationTopicRail extends StatefulWidget {
  const _CreationTopicRail({required this.active, required this.onOpen});
  final String? active;
  final ValueChanged<String?> onOpen;

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
    final showNew = widget.active == null && _query.trim().isEmpty;
    return DesktopPaneSurface(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: cs.outlineVariant.withValues(alpha: .5)),
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
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: l10n.creationSearchTopics,
                          prefixIcon: const Icon(Lucide.Search, size: 16),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 30,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: context.appColors.surfaceFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                l10n.creationTopicCount(topics.length),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
            if (topics.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  l10n.creationTopicsEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: .75,
                ),
                itemCount: topics.length + (showNew ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showNew && index == 0) return const _NewTopicCard();
                  final topic = topics[index - (showNew ? 1 : 0)];
                  return CreationTopicCard(
                    topic: topic,
                    desktop: true,
                    selected: topic.id == widget.active,
                    onOpen: () => widget.onOpen(topic.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTopicCard extends StatelessWidget {
  const _NewTopicCard();

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
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () =>
                          setState(() => _editing = false),
                    },
                    child: TextField(
                      controller: _title,
                      autofocus: true,
                      decoration: const InputDecoration(isDense: true),
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
                  onTap: _edit,
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
