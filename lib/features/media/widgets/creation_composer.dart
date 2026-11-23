import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/media/media_request.dart';
import '../../../desktop/desktop_glass_popover.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../provider/widgets/provider_avatar.dart';
import '../providers/media_creation_controller.dart';

class CreationComposer extends StatefulWidget {
  const CreationComposer({
    super.key,
    this.topicId,
    required this.desktop,
    required this.onSent,
  });

  final String? topicId;
  final bool desktop;
  final ValueChanged<String> onSent;

  @override
  State<CreationComposer> createState() => _CreationComposerState();
}

class _CreationComposerState extends State<CreationComposer> {
  late final TextEditingController _prompt;
  final _focus = FocusNode();

  MediaCreationController get _controller =>
      context.read<MediaCreationController>();

  @override
  void initState() {
    super.initState();
    _prompt = TextEditingController(
      text: _controller.draftFor(widget.topicId).prompt,
    );
  }

  @override
  void didUpdateWidget(covariant CreationComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId) {
      _prompt.text = _controller.draftFor(widget.topicId).prompt;
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final origin = widget.topicId;
    try {
      final id = await _controller.submit(origin);
      if (!mounted || id == null || widget.topicId != origin) return;
      _prompt.text = _controller.draftFor(origin).prompt;
      if (!widget.desktop) _focus.unfocus();
      widget.onSent(id);
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: switch (error) {
            MediaFailure(kind: MediaFailureKind.referenceTooLarge) =>
              l10n.creationReferenceTooLarge,
            _ => l10n.creationActionFailed,
          },
        );
      }
    }
  }

  Future<void> _pickReference(int limit) async {
    final id = widget.topicId;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (!mounted || result == null) return;
    final existing = _controller.draftFor(id).references;
    _controller.setReferences(
      id,
      [
        ...existing,
        for (final file in result.files)
          if (file.path case final path?) MediaReference(path),
      ].take(limit).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final model = state.model;
    final draft = state.draftFor(widget.topicId);
    final hint = switch ((state.mode, widget.topicId == null)) {
      (MediaMode.image, true) => l10n.creationNewImagePrompt,
      (MediaMode.image, false) => l10n.creationImagePrompt,
      (MediaMode.video, true) => l10n.creationNewVideoPrompt,
      (MediaMode.video, false) => l10n.creationVideoPrompt,
    };
    final limit = model?.capabilities.maxReferences ?? 0;
    final ctrlEnter =
        state.settings.desktopSendShortcut == DesktopSendShortcut.ctrlEnter;
    final radius = BorderRadius.circular(
      widget.desktop ? AppRadii.capsule : 26,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: .07),
              offset: const Offset(0, 8),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: context.appColors.surfaceCard.withValues(alpha: .93),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: .65),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = !widget.desktop || constraints.maxWidth < 530;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (draft.references.isNotEmpty)
                        SizedBox(
                          height: 42,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final ref in draft.references)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Chip(
                                    label: Text(
                                      p.basename(ref.path),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onDeleted: () => state.setReferences(
                                      widget.topicId,
                                      [...draft.references]..remove(ref),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 20,
                          10,
                          10,
                          2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: CallbackShortcuts(
                                bindings: {
                                  if (widget.desktop)
                                    SingleActivator(
                                      LogicalKeyboardKey.enter,
                                      control: ctrlEnter,
                                    ): () =>
                                        unawaited(_send()),
                                },
                                child: TextField(
                                  controller: _prompt,
                                  focusNode: _focus,
                                  minLines: 1,
                                  maxLines: 6,
                                  style: TextStyle(
                                    fontSize: compact ? 16 : 15,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: hint,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onChanged: (value) =>
                                      state.updatePrompt(widget.topicId, value),
                                ),
                              ),
                            ),
                            ValueListenableBuilder(
                              valueListenable: _prompt,
                              builder: (context, value, _) {
                                final enabled =
                                    value.text.trim().isNotEmpty &&
                                    model != null &&
                                    draft.references.length <= limit &&
                                    !state.submitting(widget.topicId);
                                return IosCardPress(
                                  focusable: true,
                                  borderRadius: BorderRadius.circular(99),
                                  baseColor: enabled
                                      ? cs.primary
                                      : context.appColors.surfaceFill,
                                  onTap: enabled ? _send : null,
                                  child: Tooltip(
                                    message: l10n.creationGenerate,
                                    child: SizedBox.square(
                                      dimension: compact ? 36 : 34,
                                      child: Icon(
                                        Lucide.ArrowUp,
                                        size: 19,
                                        color: enabled
                                            ? cs.onPrimary
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                        child: Row(
                          children: [
                            IosIconButton(
                              icon: LucideIcons.imagePlus,
                              size: 17,
                              minSize: 30,
                              tooltip: l10n.creationAddReference,
                              enabled: draft.references.length < limit,
                              onTap: () => _pickReference(limit),
                            ),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: compact ? 65 : 142,
                              child: SegmentedTabs(
                                height: 30,
                                compact: true,
                                iconOnly: compact,
                                radioGroup: true,
                                index: state.mode.index,
                                tabs: [
                                  SegmentedTab(
                                    label: l10n.creationImage,
                                    icon: Lucide.Image,
                                  ),
                                  SegmentedTab(
                                    label: l10n.creationVideo,
                                    icon: LucideIcons.video,
                                  ),
                                ],
                                onChanged: (index) =>
                                    state.setMode(MediaMode.values[index]),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: _ComposerChip(
                                label:
                                    model?.spec.displayName ??
                                    l10n.creationSelectModel,
                                strong: true,
                                leading: model == null
                                    ? null
                                    : ProviderAvatar(
                                        providerKey: model.provider.id,
                                        displayName: model.provider.name,
                                        size: 16,
                                      ),
                                trailing: Lucide.ChevronDown,
                                onTap: (anchor) => _showPicker(
                                  anchor,
                                  width: 340,
                                  title: l10n.creationSelectModel,
                                  content: (close) => _ModelOptions(
                                    onSelected: (value) {
                                      state.selectModel(value);
                                      close();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (model != null) ...[
                              if (compact)
                                Flexible(
                                  child: _ComposerChip(
                                    label:
                                        '${state.ratio == 'auto' ? l10n.creationAuto : state.ratio} · ${l10n.creationImagesCount(state.count)}',
                                    leading: const Icon(
                                      Lucide.SlidersHorizontal,
                                      size: 15,
                                    ),
                                    onTap: (anchor) => _showPicker(
                                      anchor,
                                      width: 320,
                                      title: l10n.creationParameters,
                                      content: (_) => const _ParameterOptions(
                                        ratio: true,
                                        count: true,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                _ComposerChip(
                                  label: state.ratio == 'auto'
                                      ? l10n.creationAuto
                                      : state.ratio,
                                  leading: const Icon(Lucide.Square, size: 15),
                                  onTap: (anchor) => _showPicker(
                                    anchor,
                                    width: 300,
                                    title: l10n.creationAspectRatio,
                                    content: (_) =>
                                        const _ParameterOptions(ratio: true),
                                  ),
                                ),
                                _ComposerChip(
                                  label: l10n.creationImagesCount(state.count),
                                  leading: const Icon(
                                    LucideIcons.images,
                                    size: 15,
                                  ),
                                  onTap: (anchor) => _showPicker(
                                    anchor,
                                    width: 260,
                                    title: l10n.creationCountLabel,
                                    content: (_) =>
                                        const _ParameterOptions(count: true),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext anchor, {
    required double width,
    required String title,
    required Widget Function(VoidCallback) content,
  }) {
    if (!widget.desktop) {
      return showFormSheet<void>(
        anchor,
        builder: (context) => FormSheet(
          title: title,
          children: [content(() => Navigator.of(context).pop())],
        ),
      );
    }
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    return showDesktopGlassPopover(
      anchor,
      anchorRect: box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      width: width,
      builder: (context, handle) => DesktopGlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: content(() => unawaited(handle.close())),
        ),
      ),
    );
  }
}

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({
    required this.label,
    this.leading,
    this.trailing,
    this.strong = false,
    required this.onTap,
  });

  final String label;
  final Widget? leading;
  final IconData? trailing;
  final bool strong;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      focusable: true,
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      onTap: () => onTap(context),
      child: SizedBox(
        height: 30,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 5)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: strong
                      ? AppFontWeights.semibold
                      : AppFontWeights.medium,
                  color: strong ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 3),
              Icon(trailing, size: 13, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelOptions extends StatefulWidget {
  const _ModelOptions({required this.onSelected});
  final ValueChanged<MediaModelChoice> onSelected;

  @override
  State<_ModelOptions> createState() => _ModelOptionsState();
}

class _ModelOptionsState extends State<_ModelOptions> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final groups = <String, List<MediaModelChoice>>{};
    for (final model in state.models) {
      final search =
          '${model.provider.name} ${model.spec.displayName} ${model.spec.id}'
              .toLowerCase();
      if (search.contains(_query)) {
        (groups[model.provider.id] ??= []).add(model);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: l10n.creationSearchModels,
            prefixIcon: const Icon(Lucide.Search, size: 16),
            isDense: true,
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final models in groups.values) ...[
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    models.first.provider.name,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
                for (final model in models)
                  IosCardPress(
                    onTap: () => widget.onSelected(model),
                    focusable: true,
                    baseColor: state.model?.key == model.key
                        ? cs.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        ProviderAvatar(
                          providerKey: model.provider.id,
                          displayName: model.provider.name,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            model.spec.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.model?.key == model.key)
                          Icon(Lucide.Check, size: 16, color: cs.primary),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParameterOptions extends StatelessWidget {
  const _ParameterOptions({this.ratio = false, this.count = false});
  final bool ratio, count;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final ratios = state.model?.capabilities.aspectRatios ?? const ['auto'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ratio) ...[
          Text(l10n.creationAspectRatio),
          const SizedBox(height: 6),
          SegmentedTabs(
            height: 36,
            expand: ratios.length <= 4,
            radioGroup: true,
            tabs: [
              for (final value in ratios)
                SegmentedTab(
                  label: value == 'auto' ? l10n.creationAuto : value,
                ),
            ],
            index: ratios.indexOf(state.ratio),
            onChanged: (index) => state.selectRatio(ratios[index]),
          ),
        ],
        if (ratio && count) const SizedBox(height: 12),
        if (count) ...[
          Text(l10n.creationCountLabel),
          const SizedBox(height: 6),
          SegmentedTabs(
            height: 36,
            radioGroup: true,
            tabs: [for (var i = 1; i <= 4; i++) SegmentedTab(label: '$i')],
            index: state.count - 1,
            onChanged: (index) => state.selectCount(index + 1),
          ),
        ],
      ],
    );
  }
}
