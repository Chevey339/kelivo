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
import 'creation_toast.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../providers/media_creation_controller.dart';
import 'creation_lightbox.dart';
import 'creation_waiting_card.dart';

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
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final topic = widget.topic;
    final active = widget.selected;
    final desktop = widget.desktop;
    final mode = media.topicView;
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
        fontSize: desktop ? 12.5 : 15,
        fontWeight: AppFontWeights.semibold,
        color: active ? cs.primary : cs.onSurface,
      ),
    );
    final subtitle = Text(
      running
          ? (batches.lastOrNull?.mode == MediaMode.video
                ? l10n.creationWaitingVideo
                : l10n.creationWaitingImage)
          : l10n.creationGenerationCount(batches.length),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: cs.onSurfaceVariant, fontSize: desktop ? 11 : 12),
    );

    void menu([Offset? anchor]) =>
        showCreationTopicMenu(context, topic, desktop: desktop, anchor: anchor);

    Widget cover(List<GenerationItemRow?> cells) => ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: context.appColors.surfaceFill,
        child: _CoverMosaic(cells: cells, status: status),
      ),
    );

    final favoriteCover = AspectRatio(
      aspectRatio: widget.wide ? 1.6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active ? cs.primary : cs.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(active ? 3 : 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover(allCells),
              if (mode == CreationTopicView.covers && _hover)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(5, 15, 5, 4),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              if (running)
                Positioned(
                  left: 5,
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
              if (_hover && desktop)
                Positioned(
                  top: 3,
                  right: 3,
                  child: IosIconButton(
                    icon: Lucide.Ellipsis,
                    minSize: 26,
                    color: Colors.white,
                    tooltip: l10n.chatMessageWidgetMoreTooltip,
                    onTap: menu,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: desktop ? (_) => setState(() => _hover = true) : null,
      onExit: desktop ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onSecondaryTapDown: desktop
            ? (details) => menu(details.globalPosition)
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
              CreationTopicView.covers => favoriteCover,
              CreationTopicView.coverAndTitle => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  favoriteCover,
                  const SizedBox(height: 5),
                  text,
                  subtitle,
                ],
              ),
              CreationTopicView.list => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: cover(allCells.take(1).toList()),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [text, subtitle],
                      ),
                    ),
                    if (running && !_hover)
                      const SizedBox.square(
                        dimension: 13,
                        child: CreationSpinner(radius: 6),
                      ),
                    if (_hover && desktop)
                      IosIconButton(
                        icon: Lucide.Ellipsis,
                        minSize: 28,
                        tooltip: l10n.chatMessageWidgetMoreTooltip,
                        onTap: menu,
                      ),
                  ],
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _CoverMosaic extends StatelessWidget {
  const _CoverMosaic({required this.cells, required this.status});

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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == null ? Lucide.Image : Lucide.CircleAlert,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (label != null)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
          ],
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
  Offset? anchor,
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
  final render = context.findRenderObject() as RenderBox?;
  await showCreationMenu(
    context,
    globalPosition:
        anchor ??
        (render != null && render.hasSize
            ? render.localToGlobal(render.size.center(Offset.zero))
            : Offset.zero),
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
