import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../core/models/model_spec.dart';
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
import 'creation_advanced_options.dart';
import 'creation_lightbox.dart';

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
    final existing = _controller.imageReferences(id);
    _controller.setReferences(
      id,
      [
        ...existing,
        for (final file in result.files)
          if (file.path case final path?) MediaReference(path),
      ].take(limit).toList(),
    );
  }

  Future<void> _pickFrame(MediaReferenceRole role) async {
    final id = widget.topicId;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (!mounted || result?.files.firstOrNull?.path == null) return;
    _controller.setFrame(id, role, result!.files.first.path);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final model = state.model;
    final video = state.mode == MediaMode.video;
    final references = state.imageReferences(widget.topicId);
    final frames = state.showsFrames(widget.topicId);
    final caps = model?.capabilities;
    final aspectRatio = state.ratioFor(widget.topicId);
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
                  final compact = !widget.desktop || constraints.maxWidth < 650;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!video && limit > 0 && references.isNotEmpty)
                        SizedBox(
                          height: 42,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final ref in references)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Chip(
                                    label: Text(
                                      p.basename(ref.path),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onDeleted: () => state.setReferences(
                                      widget.topicId,
                                      [...references]..remove(ref),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (frames && caps != null)
                        _VideoFrames(
                          topicId: widget.topicId,
                          capabilities: caps,
                          onPick: _pickFrame,
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
                                    state.canSubmit(widget.topicId);
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
                            if (limit > 0)
                              IosIconButton(
                                icon: LucideIcons.imagePlus,
                                size: 17,
                                minSize: 30,
                                tooltip: l10n.creationAddReference,
                                enabled: video
                                    ? caps?.frameRoles.isNotEmpty == true
                                    : references.length < limit,
                                onTap: video
                                    ? () => _pickFrame(
                                        MediaReferenceRole.firstFrame,
                                      )
                                    : () => _pickReference(limit),
                              ),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: compact
                                  ? 65
                                  : video
                                  ? 104
                                  : 126,
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
                                maxWidth: 190,
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
                                  title: video
                                      ? l10n.creationVideoModels
                                      : l10n.creationImageModels,
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
                                    label: [
                                      aspectRatio == 'auto'
                                          ? l10n.creationAuto
                                          : aspectRatio,
                                      if (!video)
                                        l10n.creationImagesCount(state.count),
                                      if (state.duration case final int duration
                                          when video)
                                        l10n.creationDurationSeconds(duration),
                                    ].join(' · '),
                                    leading: const Icon(
                                      Lucide.SlidersHorizontal,
                                      size: 15,
                                    ),
                                    trailing: frames ? LucideIcons.film : null,
                                    onTap: (anchor) => _showPicker(
                                      anchor,
                                      width: 320,
                                      title: l10n.creationParameters,
                                      content: (_) => _ParameterOptions(
                                        ratio: true,
                                        count: !video,
                                        duration: video,
                                        resolution: video,
                                        frames: video,
                                        advanced: true,
                                        topicId: widget.topicId,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                _ComposerChip(
                                  maxWidth: 84,
                                  label: aspectRatio == 'auto'
                                      ? l10n.creationAuto
                                      : aspectRatio,
                                  leading: const Icon(Lucide.Square, size: 15),
                                  onTap: (anchor) => _showPicker(
                                    anchor,
                                    width: 300,
                                    title: l10n.creationAspectRatio,
                                    content: (_) => _ParameterOptions(
                                      ratio: true,
                                      topicId: widget.topicId,
                                    ),
                                  ),
                                ),
                                if (state.duration case final int duration
                                    when video)
                                  _ComposerChip(
                                    maxWidth: 96,
                                    label: l10n.creationDurationSeconds(
                                      duration,
                                    ),
                                    leading: const Icon(Lucide.Timer, size: 15),
                                    onTap: (anchor) => _showPicker(
                                      anchor,
                                      width: 320,
                                      title: l10n.creationDuration,
                                      content: (_) => const _ParameterOptions(
                                        duration: true,
                                      ),
                                    ),
                                  ),
                                if (state.resolutionFor(widget.topicId)
                                    case final String resolution when video)
                                  _ComposerChip(
                                    maxWidth: 72,
                                    label: resolution,
                                    onTap: (anchor) => _showPicker(
                                      anchor,
                                      width: 260,
                                      title: l10n.creationResolution,
                                      content: (_) => _ParameterOptions(
                                        resolution: true,
                                        topicId: widget.topicId,
                                      ),
                                    ),
                                  ),
                                if (video &&
                                    caps?.frameRoles.isNotEmpty == true)
                                  _FrameToggle(
                                    label:
                                        caps!.frameRoles.contains(
                                          MediaReferenceRole.lastFrame,
                                        )
                                        ? l10n.creationFirstLastFrame
                                        : l10n.creationFirstFrame,
                                    selected: frames,
                                    onTap: caps.requiresFirstFrame
                                        ? null
                                        : () => state.showFrames(
                                            widget.topicId,
                                            !frames,
                                          ),
                                  ),
                                if (!video)
                                  _ComposerChip(
                                    maxWidth: 100,
                                    label: l10n.creationImagesCount(
                                      state.count,
                                    ),
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
                                _ComposerChip(
                                  maxWidth: 109,
                                  label: l10n.creationMoreOptions,
                                  leading: Badge(
                                    isLabelVisible: state.hasAdvancedOptions(
                                      widget.topicId,
                                    ),
                                    backgroundColor: cs.primary,
                                    smallSize: 5,
                                    child: const Icon(
                                      Lucide.SlidersHorizontal,
                                      size: 15,
                                    ),
                                  ),
                                  onTap: (anchor) => _showPicker(
                                    anchor,
                                    width: 360,
                                    title: l10n.creationMoreOptions,
                                    content: (_) => ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            (MediaQuery.sizeOf(context).height -
                                                    144)
                                                .clamp(160.0, 500.0),
                                      ),
                                      child: SingleChildScrollView(
                                        child: CreationAdvancedOptions(
                                          topicId: widget.topicId,
                                        ),
                                      ),
                                    ),
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
    this.maxWidth,
    required this.onTap,
  });

  final String label;
  final Widget? leading;
  final IconData? trailing;
  final bool strong;
  final double? maxWidth;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chip = IosCardPress(
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
    return maxWidth == null
        ? chip
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: chip,
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
                        if (model.spec.type == ModelType.chat) ...[
                          const SizedBox(width: 6),
                          Text(
                            l10n.creationChatModelBadge,
                            style: TextStyle(fontSize: 11, color: cs.primary),
                          ),
                        ],
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
  const _ParameterOptions({
    this.ratio = false,
    this.count = false,
    this.duration = false,
    this.resolution = false,
    this.frames = false,
    this.advanced = false,
    this.topicId,
  });

  final bool ratio, count, duration, resolution, frames, advanced;
  final String? topicId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final caps = state.model?.capabilities;
    final ratios = state.ratiosFor(topicId);
    final resolutions = state.resolutionsFor(topicId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ratio && ratios.isNotEmpty) ...[
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
            index: ratios.indexOf(state.ratioFor(topicId)),
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
        if (duration && caps != null && caps.durations.isNotEmpty) ...[
          if (ratio) const SizedBox(height: 12),
          Text(l10n.creationDuration),
          const SizedBox(height: 6),
          SegmentedTabs(
            height: 36,
            expand: caps.durations.length <= 4,
            radioGroup: true,
            tabs: [
              for (final value in caps.durations)
                SegmentedTab(label: l10n.creationDurationSeconds(value)),
            ],
            index: caps.durations.indexOf(state.duration!),
            onChanged: (index) => state.selectDuration(caps.durations[index]),
          ),
        ],
        if (resolution && resolutions.isNotEmpty) ...[
          if (ratio || duration) const SizedBox(height: 12),
          Text(l10n.creationResolution),
          const SizedBox(height: 6),
          SegmentedTabs(
            height: 36,
            radioGroup: true,
            tabs: [for (final value in resolutions) SegmentedTab(label: value)],
            index: resolutions.indexOf(state.resolutionFor(topicId)!),
            onChanged: (index) => state.selectResolution(resolutions[index]),
          ),
        ],
        if (frames && caps != null && caps.frameRoles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _FrameToggle(
              label: caps.frameRoles.contains(MediaReferenceRole.lastFrame)
                  ? l10n.creationFirstLastFrame
                  : l10n.creationFirstFrame,
              selected: state.showsFrames(topicId),
              onTap: caps.requiresFirstFrame
                  ? null
                  : () =>
                        state.showFrames(topicId, !state.showsFrames(topicId)),
            ),
          ),
        ],
        if (advanced) ...[
          const Divider(height: 24),
          CreationAdvancedOptions(topicId: topicId),
        ],
      ],
    );
  }
}

class _FrameToggle extends StatelessWidget {
  const _FrameToggle({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      toggled: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 158),
        child: IosCardPress(
          focusable: true,
          borderRadius: BorderRadius.circular(15),
          baseColor: selected
              ? cs.primary.withValues(alpha: .08)
              : Colors.transparent,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.film, size: 15, color: foreground),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoFrames extends StatelessWidget {
  const _VideoFrames({
    required this.topicId,
    required this.capabilities,
    required this.onPick,
  });

  final String? topicId;
  final MediaCapabilities capabilities;
  final ValueChanged<MediaReferenceRole> onPick;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final hasLast = capabilities.frameRoles.contains(
      MediaReferenceRole.lastFrame,
    );
    final style = TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          for (final role in capabilities.frameRoles) ...[
            _FrameSlot(
              label: role == MediaReferenceRole.firstFrame
                  ? l10n.creationFirstFrame
                  : l10n.creationLastFrame,
              value: state.frame(topicId, role),
              onPick: () => onPick(role),
              onRemove: () => state.setFrame(topicId, role, null),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              hasLast
                  ? l10n.creationFirstFrameRequired
                  : l10n.creationFirstFrameOnly,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameSlot extends StatelessWidget {
  const _FrameSlot({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onRemove,
  });

  final String label;
  final MediaReference? value;
  final VoidCallback onPick, onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    return SizedBox.square(
      dimension: 56,
      child: Stack(
        children: [
          Positioned.fill(
            child: IosCardPress(
              focusable: true,
              borderRadius: radius,
              border: Border.all(color: cs.outlineVariant),
              baseColor: context.appColors.surfaceFill,
              onTap: onPick,
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (value case final reference?)
                      CreationFileImage(reference.path)
                    else
                      Align(
                        alignment: const Alignment(0, -.25),
                        child: Icon(
                          Lucide.Plus,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: value == null
                            ? Colors.transparent
                            : Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: value == null
                                ? cs.onSurfaceVariant
                                : Colors.white,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (value != null)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: IosIconButton(
                icon: Lucide.X,
                size: 12,
                minSize: 20,
                color: Colors.white,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onTap: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}
