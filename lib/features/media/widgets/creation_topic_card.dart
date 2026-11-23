import 'creation_menu.dart';
import 'creation_controls.dart';
import 'creation_picker.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/plain_text_input.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart'
    show handoffCurve, handoffDuration;
import 'creation_toast.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../providers/media_creation_controller.dart';
import 'creation_lightbox.dart';
import 'creation_waiting_card.dart';

/// Sizes square covers and their two caption lines independently at every text scale.
class CreationTopicGrid extends StatelessWidget {
  const CreationTopicGrid({
    super.key,
    required this.desktop,
    required this.covers,
    required this.itemCount,
    required this.itemBuilder,
  });
  final bool desktop, covers;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final columns = covers ? 3 : 2;
    final gap = covers ? 8.0 : 12.0;
    final captions = covers
        ? 0.0
        : 7.0 +
              (scale.scale(desktop ? 12.5 : 13.5) * 1.35).ceil() +
              2.0 +
              (scale.scale(desktop ? 11 : 11.5) * 1.35).ceil();
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: covers ? gap : (desktop ? 16 : 18),
            mainAxisExtent: width + captions,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class CreationTopicCard extends StatefulWidget {
  const CreationTopicCard({
    super.key,
    required this.topic,
    required this.onOpen,
    this.selected = false,
    this.desktop = false,
    this.wide = false,
  });

  final GenerationTopicRow topic;
  final VoidCallback onOpen;
  final bool selected, desktop, wide;

  @override
  State<CreationTopicCard> createState() => _CreationTopicCardState();
}

class _CreationTopicCardState extends State<CreationTopicCard> {
  bool _hover = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final topic = widget.topic;
    final active = widget.selected;
    final showTools = _hover || _focused;
    final desktop = widget.desktop;
    final mode = media.topicView;
    final list = mode == CreationTopicView.list;
    final batches = media.batchesFor(topic.id);
    final status = batches.lastOrNull?.status;
    final running = batches.any((batch) => batch.status.isActive);
    final allCells = media.coverCells(topic.id);
    final radius = BorderRadius.circular(
      widget.wide
          ? 16
          : mode == CreationTopicView.covers
          ? 10
          : 12,
    );
    final title = media.namingTopic(topic.id)
        ? l10n.creationNaming
        : topic.title;
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: list
            ? (desktop ? 13.5 : 15)
            : (widget.wide
                  ? 15
                  : desktop
                  ? 12.5
                  : 13.5),
        height: 1.35,
        fontWeight: list && !active
            ? AppFontWeights.medium
            : AppFontWeights.semibold,
        color: active ? cs.primary : cs.onSurface,
      ),
    );
    final count = l10n.creationGenerationCount(batches.length);
    final lastActivity = batches.lastOrNull?.createdAt ?? topic.updatedAt;
    final today = DateTime.now();
    final date = DateUtils.isSameDay(lastActivity, today)
        ? l10n.sideDrawerDateToday
        : DateUtils.isSameDay(
            lastActivity,
            DateTime(today.year, today.month, today.day - 1),
          )
        ? l10n.sideDrawerDateYesterday
        : MaterialLocalizations.of(context).formatShortMonthDay(lastActivity);
    final subtitle = Text(
      running
          ? (batches.lastOrNull?.mode == MediaMode.video
                ? l10n.creationWaitingVideo
                : l10n.creationWaitingImage)
          : desktop
          ? '$count · $date'
          : count,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: .58),
        fontSize: list
            ? (desktop ? 11.5 : 12)
            : (widget.wide
                  ? 12
                  : desktop
                  ? 11
                  : 11.5),
        height: 1.35,
      ),
    );

    void menu([Rect? anchor]) =>
        showCreationTopicMenu(context, topic, desktop: desktop, anchor: anchor);

    Widget cover(List<GenerationItemRow?> cells, {bool compact = false}) =>
        ColoredBox(
          color: context.appColors.surfaceFill,
          child: _CoverMosaic(cells: cells, status: status, compact: compact),
        );

    final coverOnly = mode == CreationTopicView.covers;
    final inset = desktop ? 2.5 : 0.0;
    final innerRadius = BorderRadius.circular(radius.topLeft.x - inset);
    final topicCover = AspectRatio(
      aspectRatio: widget.wide ? 1.6 : 1,
      child: AnimatedContainer(
        duration: handoffDuration(context, 140),
        curve: handoffCurve,
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            if (desktop && showTools)
              BoxShadow(
                color: cs.shadow.withValues(alpha: .08),
                offset: const Offset(0, 3),
                blurRadius: 10,
              ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active
                ? cs.primary.withValues(alpha: .76)
                : desktop && showTools
                ? context.appColors.hairline
                : Colors.transparent,
            width: active ? 1.5 : .5,
          ),
        ),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover(allCells),
              if (coverOnly && desktop)
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: CreationHoverActions(
                    visible: showTools,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          6,
                          12,
                          6,
                          4,
                        ),
                        child: Text(
                          title,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (running)
                PositionedDirectional(
                  start: 5,
                  top: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: .86),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: SizedBox.square(
                        dimension: 11,
                        child: CreationSpinner(radius: 6, color: cs.primary),
                      ),
                    ),
                  ),
                ),
              if (desktop)
                PositionedDirectional(
                  end: coverOnly ? 4 : 6,
                  top: coverOnly ? 4 : 6,
                  child: CreationHoverActions(
                    visible: showTools,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x5c000000),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Builder(
                        builder: (anchor) => IosIconButton(
                          icon: Lucide.Ellipsis,
                          size: 14,
                          minSize: coverOnly ? 22 : 24,
                          padding: EdgeInsets.zero,
                          borderRadius: 7,
                          color: Colors.white,
                          tooltip: l10n.chatMessageWidgetMoreTooltip,
                          onTap: () => showCreationTopicMenu(
                            anchor,
                            topic,
                            desktop: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: desktop ? (_) => setState(() => _hover = true) : null,
        onExit: desktop ? (_) => setState(() => _hover = false) : null,
        child: GestureDetector(
          onSecondaryTapDown: desktop
              ? (details) => menu(details.globalPosition & Size.zero)
              : null,
          child: Semantics(
            label: mode == CreationTopicView.covers ? title : null,
            child: IosCardPress(
              focusable: true,
              baseColor: active && mode == CreationTopicView.list
                  ? cs.primary.withValues(alpha: .09)
                  : Colors.transparent,
              borderRadius: radius,
              onTap: widget.onOpen,
              onLongPress: desktop ? null : menu,
              child: switch (mode) {
                CreationTopicView.covers => topicCover,
                CreationTopicView.coverAndTitle => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    topicCover,
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [text, const SizedBox(height: 2), subtitle],
                      ),
                    ),
                  ],
                ),
                CreationTopicView.list => CreationTopicListRow(
                  desktop: desktop,
                  thumbnail: cover(allCells.take(1).toList(), compact: true),
                  title: text,
                  subtitle: subtitle,
                  trailing: running || desktop
                      ? SizedBox.square(
                          dimension: desktop ? 28 : 16,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (running)
                                CreationHoverActions(
                                  visible: !desktop || !showTools,
                                  child: const SizedBox.square(
                                    dimension: 13,
                                    child: CreationSpinner(radius: 6),
                                  ),
                                ),
                              if (desktop)
                                CreationHoverActions(
                                  visible: showTools,
                                  child: Builder(
                                    builder: (anchor) => IosIconButton(
                                      icon: Lucide.Ellipsis,
                                      size: 15,
                                      visualSize: 22,
                                      minSize: 28,
                                      padding: EdgeInsets.zero,
                                      tooltip:
                                          l10n.chatMessageWidgetMoreTooltip,
                                      onTap: () => showCreationTopicMenu(
                                        anchor,
                                        topic,
                                        desktop: true,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : null,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CreationTopicListRow extends StatelessWidget {
  const CreationTopicListRow({
    super.key,
    required this.desktop,
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final bool desktop;
  final Widget thumbnail, title, subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: desktop ? 6 : 8),
    child: Row(
      children: [
        SizedBox.square(
          dimension: desktop ? 40 : 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: thumbnail,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 2), subtitle],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    ),
  );
}

class _CoverMosaic extends StatelessWidget {
  const _CoverMosaic({
    required this.cells,
    required this.status,
    required this.compact,
  });
  final bool compact;

  final List<GenerationItemRow?> cells;
  final GenerationStatus? status;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      final label = switch (status) {
        GenerationStatus.failed => l10n.creationFailed,
        GenerationStatus.interrupted => l10n.creationInterrupted,
        GenerationStatus.cancelled => l10n.creationCancelled,
        _ => null,
      };
      return Semantics(
        label: compact ? label : null,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == null ? Lucide.Image : Lucide.CircleAlert,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              if (label != null && !compact)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    Widget cell(int index) {
      final item = cells[index];
      return Expanded(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item == null)
              const CreationDotField(progress: .4, thumbnail: true)
            else
              CreationMediaCover(item, playOverlay: false, thumbnail: true),
            if (index == 3 && cells.length > 4)
              ColoredBox(
                color: Colors.black.withValues(alpha: .42),
                child: Center(
                  child: Text(
                    '+${cells.length - 4}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget row(int first, int second) =>
        Row(children: [cell(first), const SizedBox(width: 2), cell(second)]);
    return switch (cells.length) {
      1 => Row(children: [cell(0)]),
      2 => row(0, 1),
      3 => Row(
        children: [
          cell(0),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [cell(1), const SizedBox(height: 2), cell(2)],
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          Expanded(child: row(0, 1)),
          const SizedBox(height: 2),
          Expanded(child: row(2, 3)),
        ],
      ),
    };
  }
}

Future<void> showCreationTopicMenu(
  BuildContext context,
  GenerationTopicRow topic, {
  required bool desktop,
  Rect? anchor,
  VoidCallback? onRename,
  VoidCallback? onDeleted,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final actions = [
    ActionSheetItem(
      icon: Lucide.Pencil,
      label: l10n.creationRenameTopic,
      onTap: onRename ?? () => unawaited(renameCreationTopic(context, topic)),
    ),
    ActionSheetItem(
      icon: Lucide.Trash2,
      label: l10n.creationDeleteTopic,
      destructive: true,
      onTap: () async {
        final media = context.read<MediaCreationController>();
        final confirmed = await showCreationDialog<bool>(
          context,
          maxWidth: 380,
          child: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.creationDeleteTopic,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.creationDeleteTopicBody),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CreationAction(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                      CreationAction(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.chatHistoryPageDelete),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        if (confirmed != true || !context.mounted) return;
        try {
          await media.deleteTopic(topic.id);
          if (context.mounted) onDeleted?.call();
        } catch (_) {
          if (context.mounted) {
            showCreationToast(context, message: l10n.creationActionFailed);
          }
        }
      },
    ),
  ];
  if (!desktop) {
    await showCreationActions(context, title: topic.title, items: actions);
    return;
  }
  await showCreationMenu(
    context,
    globalAnchor: anchor,
    items: [
      for (final action in actions)
        DesktopContextMenuItem(
          label: action.label,
          icon: action.icon,
          danger: action.destructive,
          onTap: action.onTap,
        ),
    ],
  );
}

Future<void> renameCreationTopic(
  BuildContext context,
  GenerationTopicRow topic,
) async {
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final media = context.read<MediaCreationController>();
  final selected = await showCreationDialog<String>(
    context,
    maxWidth: 380,
    child: _RenameTopicForm(
      title: topic.title,
      label: l10n.creationRenameTopic,
    ),
  );
  if (selected != null && context.mounted) {
    await media.renameTopic(topic.id, selected);
  }
}

class _RenameTopicForm extends StatefulWidget {
  const _RenameTopicForm({required this.title, required this.label});
  final String title, label;
  @override
  State<_RenameTopicForm> createState() => _RenameTopicFormState();
}

class _RenameTopicFormState extends State<_RenameTopicForm> {
  late final _name = TextEditingController(text: widget.title);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        PlainTextInput(
          controller: _name,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appColors.surfaceFill,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CreationAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            CreationAction(
              tone: CreationActionTone.primary,
              onPressed: () => Navigator.of(context).pop(_name.text),
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
          ],
        ),
      ],
    ),
  );
}
