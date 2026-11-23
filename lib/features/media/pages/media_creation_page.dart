import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/media_creation_controller.dart';
import '../widgets/creation_composer.dart';
import '../widgets/creation_timeline.dart';
import '../widgets/creation_topic_card.dart';

class MediaCreationPage extends StatefulWidget {
  const MediaCreationPage({super.key, required this.onOpenDrawer});

  final VoidCallback onOpenDrawer;

  @override
  State<MediaCreationPage> createState() => _MediaCreationPageState();
}

class _MediaCreationPageState extends State<MediaCreationPage> {
  bool _searching = false;
  String _query = '';

  void _openTopic(String id) {
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, _, _) => _MobileTopicPage(topicId: id),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  40 * (1 - Curves.easeOutCubic.transform(animation.value)),
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
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
            ? TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.creationSearchTopics,
                  isDense: true,
                ),
              )
            : Text(
                l10n.creationTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
        actions: [
          if (!_searching)
            IosIconButton(
              icon: Lucide.Search,
              tooltip: l10n.creationSearchTopics,
              minSize: 44,
              onTap: () => setState(() => _searching = true),
            ),
        ],
      ),
      body: CreationComposerStack(
        desktop: false,
        composer: CreationComposer(desktop: false, onSent: _openTopic),
        content: topics.isEmpty
            ? const CreationEmptyState()
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l10n.creationTopicCount(topics.length),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: CreationTopicCard(
                        topic: topics.first,
                        wide: true,
                        onOpen: () => _openTopic(topics.first.id),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 156),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 10,
                            childAspectRatio: .75,
                          ),
                      itemCount: topics.length - 1,
                      itemBuilder: (context, index) => CreationTopicCard(
                        topic: topics[index + 1],
                        onOpen: () => _openTopic(topics[index + 1].id),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MobileTopicPage extends StatelessWidget {
  const _MobileTopicPage({required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final topic = state.topic(topicId);
    final name = topic?.title ?? '';
    final naming = state.namingTopic(topicId) || name.isEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        centerTitle: true,
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
              l10n.creationGenerationCount(state.batchesFor(topicId).length),
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (topic != null)
            IosIconButton(
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
        ],
      ),
      body: CreationComposerStack(
        desktop: false,
        composer: CreationComposer(
          topicId: topicId,
          desktop: false,
          onSent: (_) {},
        ),
        content: CreationTimeline(topicId: topicId, desktop: false),
      ),
    );
  }
}

class CreationComposerStack extends StatelessWidget {
  const CreationComposerStack({
    super.key,
    required this.desktop,
    required this.content,
    required this.composer,
  });

  final bool desktop;
  final Widget content, composer;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Stack(
      children: [
        Positioned.fill(child: content),
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
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Align(alignment: Alignment.bottomCenter, child: composer),
          ),
        ),
      ],
    );
  }
}
