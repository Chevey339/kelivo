import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/media_creation.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/media/creation_prompt_enhancer.dart';
import '../../../core/services/media/media_models.dart';
import '../../../core/services/media/media_request.dart';
import 'creation_picker.dart';
import '../../../desktop/desktop_settings_navigation_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../provider/widgets/provider_avatar.dart';
import '../../model/pages/default_model_page.dart';
import '../../settings/widgets/settings_search_target.dart';
import '../providers/media_creation_controller.dart';
import 'creation_advanced_options.dart';
import 'creation_controls.dart';
import '../../../shared/widgets/plain_text_input.dart';
import 'creation_enhancement_panel.dart';
import 'creation_lightbox.dart';
import 'creation_reference_picker.dart';

typedef _Enhancement = ({
  String requestId,
  String original,
  MediaMode mode,
  String? modelKey,
  String template,
  List<String>? references,
  String modelName,
  List<CreationPromptSpan>? spans,
  String? rewrite,
});

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
  _Enhancement? _enhancement;

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
      _discardEnhancement();
      _prompt.text = _controller.draftFor(widget.topicId).prompt;
    }
  }

  @override
  void dispose() {
    _discardEnhancement();
    _prompt.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final origin = widget.topicId;
    try {
      final id = await _controller.submit(origin);
      if (!mounted || id == null || widget.topicId != origin) return;
      _dismissEnhancement();
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

  Future<void> _pickReferences(
    BuildContext context, {
    MediaReferenceRole? role,
  }) async {
    final id = widget.topicId;
    final media = _controller;
    final model = media.model;
    if (model == null) return;
    final maximum = role == null
        ? model.capabilities.maxReferences - media.imageReferences(id).length
        : 1;
    if (maximum <= 0) return;
    await showCreationReferenceSources(
      context,
      desktop: widget.desktop,
      limit: maximum,
      frameRole: role,
      onSelected: (paths) {
        if (!mounted || widget.topicId != id || model.key != media.model?.key) {
          return;
        }
        _referenceResult(
          media.addReferencePaths(id, paths, frameRole: role),
          expected: paths.length,
        );
      },
    );
  }

  void _referenceResult(int count, {required int expected}) {
    final l10n = AppLocalizations.of(context)!;
    final max = _controller.model?.capabilities.maxReferences ?? 0;
    if (count < expected && _controller.mode == MediaMode.image) {
      showAppSnackBar(
        context,
        message: l10n.creationReferenceLimitReached(max),
      );
    } else if (count > 0) {
      showAppSnackBar(context, message: l10n.creationReferenceAdded);
    }
  }

  Future<void> _paste() async {
    final topicId = widget.topicId;
    try {
      final result = await readCreationClipboard();
      if (!mounted || topicId != widget.topicId) return;
      if (result.paths.isNotEmpty) {
        _referenceResult(
          _controller.addReferencePaths(topicId, result.paths),
          expected: result.paths.length,
        );
      } else if (result.text case final text?) {
        _dismissEnhancement();
        final value = _prompt.value;
        final selection = value.selection;
        final start = selection.isValid ? selection.start : value.text.length;
        final end = selection.isValid ? selection.end : value.text.length;
        final next = value.text.replaceRange(start, end, text);
        _prompt.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: start + text.length),
        );
        _controller.updatePrompt(topicId, next);
      }
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message:
            error is MediaFailure &&
                error.kind == MediaFailureKind.referenceTooLarge
            ? l10n.creationReferenceTooLarge
            : l10n.creationActionFailed,
      );
    }
  }

  void _discardEnhancement() {
    if (_enhancement case final pending?) {
      ChatApiService.cancelRequest(pending.requestId);
      _enhancement = null;
    }
  }

  void _dismissEnhancement() {
    if (_enhancement != null) setState(_discardEnhancement);
  }

  bool _matchesEnhancement(_Enhancement value, MediaCreationController media) =>
      value.mode == media.mode &&
      value.original == media.draftFor(widget.topicId).prompt &&
      value.modelKey ==
          media.settings.creationModelKey(CreationModelSlot.promptEnhance) &&
      value.template == media.settings.promptEnhancePrompt &&
      (value.references == null ||
          listEquals(
            value.references,
            media.enhancementReferencePaths(widget.topicId),
          ));

  Future<void> _enhance({bool again = false}) async {
    final media = _controller;
    final l10n = AppLocalizations.of(context)!;
    final original = media.draftFor(widget.topicId).prompt;
    if (original.trim().isEmpty) return;
    final selected = resolvePromptEnhancementModel(media.settings);
    if (selected == null) {
      showAppSnackBar(
        context,
        message: l10n.creationEnhanceNeedsModel,
        actionLabel: l10n.creationDefaultEnhance,
        onAction: () {
          if (!mounted) return;
          if (widget.desktop) {
            DesktopSettingsNavigationBus.instance.openDefaultModel();
          } else {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SettingsSearchTarget(
                  label: l10n.creationDefaultEnhance,
                  child: const DefaultModelPage(),
                ),
              ),
            );
          }
        },
      );
      return;
    }
    if (!widget.desktop) _focus.unfocus();
    final _Enhancement request = (
      requestId: const Uuid().v4(),
      original: original,
      mode: media.mode,
      modelKey: media.settings.creationModelKey(
        CreationModelSlot.promptEnhance,
      ),
      template: media.settings.promptEnhancePrompt,
      references: selected.spec.supportsImageInput
          ? media.enhancementReferencePaths(widget.topicId)
          : null,
      modelName: selected.spec.displayName,
      spans: null,
      rewrite: null,
    );
    setState(() {
      _discardEnhancement();
      _enhancement = request;
    });
    bool current() =>
        mounted &&
        _enhancement?.requestId == request.requestId &&
        _matchesEnhancement(request, media);
    try {
      final rewrite = await CreationPromptEnhancer.rewrite(
        provider: selected.provider,
        model: selected.spec,
        original: request.original,
        template: request.template,
        references: request.references ?? const [],
        requestId: request.requestId,
        again: again,
      );
      if (!current()) return;
      if (rewrite.isEmpty) throw StateError('Empty rewritten prompt');
      final spans = await CreationPromptEnhancer.diff(
        request.original,
        rewrite,
      );
      if (!current()) return;
      setState(
        () => _enhancement = (
          requestId: request.requestId,
          original: request.original,
          mode: request.mode,
          modelKey: request.modelKey,
          template: request.template,
          references: request.references,
          modelName: request.modelName,
          spans: spans,
          rewrite: rewrite,
        ),
      );
    } catch (_) {
      if (!mounted || !current()) return;
      _dismissEnhancement();
      showAppSnackBar(context, message: l10n.creationActionFailed);
    }
  }

  void _applyEnhancement() {
    final result = _enhancement;
    final rewrite = result?.rewrite;
    if (result == null ||
        rewrite == null ||
        !_matchesEnhancement(result, _controller)) {
      return;
    }
    _controller.updatePrompt(widget.topicId, rewrite);
    _prompt.value = TextEditingValue(
      text: rewrite,
      selection: TextSelection.collapsed(offset: rewrite.length),
    );
    _dismissEnhancement();
  }

  KeyEventResult _handleDesktopKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final composing = _prompt.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final modified = keyboard.isControlPressed || keyboard.isMetaPressed;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyV && modified) {
      unawaited(_paste());
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final ctrlEnter =
        _controller.settings.desktopSendShortcut ==
        DesktopSendShortcut.ctrlEnter;
    if (ctrlEnter ? modified : !modified && !keyboard.isShiftPressed) {
      unawaited(_send());
    } else {
      final value = _prompt.value;
      final selection = value.selection;
      final start = selection.isValid ? selection.start : value.text.length;
      final end = selection.isValid ? selection.end : value.text.length;
      final text = value.text.replaceRange(start, end, '\n');
      _dismissEnhancement();
      _prompt.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: start + 1),
      );
      _controller.updatePrompt(widget.topicId, text);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final model = state.model;
    final video = state.mode == MediaMode.video;
    final draftPrompt = state.draftFor(widget.topicId).prompt;
    if (draftPrompt != _prompt.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final text = _controller.draftFor(widget.topicId).prompt;
        if (_prompt.text != text) {
          _prompt.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      });
    }
    final references = state.imageReferences(widget.topicId);
    final frames = state.showsFrames(widget.topicId);
    final caps = model?.capabilities;
    final aspectRatio = state.ratioFor(widget.topicId);
    final hint = model == null
        ? l10n.creationNoModelPlaceholder
        : switch ((state.mode, widget.topicId == null)) {
            (MediaMode.image, true) => l10n.creationNewImagePrompt,
            (MediaMode.image, false) => l10n.creationImagePrompt,
            (MediaMode.video, true) => l10n.creationNewVideoPrompt,
            (MediaMode.video, false) => l10n.creationVideoPrompt,
          };
    if (_enhancement case final value?
        when !_matchesEnhancement(value, state)) {
      _discardEnhancement();
    }
    final enhancement = _enhancement;
    final limit = model?.capabilities.maxReferences ?? 0;
    final radius = BorderRadius.circular(widget.desktop ? 28 : 26);
    final unavailable =
        model == null &&
        state.modelsFor(video ? MediaMode.image : MediaMode.video).isEmpty;
    return ExcludeFocus(
      excluding: unavailable,
      child: IgnorePointer(
        ignoring: unavailable,
        child: Opacity(
          opacity: unavailable ? .6 : 1,
          child: ConstrainedBox(
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
                      color: context.appColors.surfaceCard.withValues(
                        alpha: .93,
                      ),
                      border: Border.all(
                        color: cs.onSurface.withValues(
                          alpha: cs.brightness == Brightness.dark ? .14 : .11,
                        ),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            !widget.desktop || constraints.maxWidth < 650;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (enhancement != null)
                              CreationEnhancementPanel(
                                key: ValueKey(enhancement.requestId),
                                original: enhancement.original,
                                modelName: enhancement.modelName,
                                spans: enhancement.spans,
                                onClose: _dismissEnhancement,
                                onAgain: () => _enhance(again: true),
                                onApply: _applyEnhancement,
                              ),
                            if (!video && references.isNotEmpty)
                              _ReferenceStrip(
                                references: references,
                                limit: limit,
                                model:
                                    model?.spec.displayName ??
                                    l10n.creationSelectModel,
                                onRemove: (ref) => state.setReferences(
                                  widget.topicId,
                                  [...references]..remove(ref),
                                ),
                                onAdd: (anchor) => _pickReferences(anchor),
                              ),
                            if (frames && caps != null)
                              _VideoFrames(
                                desktop: widget.desktop,
                                topicId: widget.topicId,
                                capabilities: caps,
                                onPick: (anchor, role) =>
                                    _pickReferences(anchor, role: role),
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
                                    child: Focus(
                                      canRequestFocus: false,
                                      onKeyEvent: widget.desktop
                                          ? _handleDesktopKey
                                          : null,
                                      child: PlainTextInput(
                                        controller: _prompt,
                                        focusNode: _focus,
                                        enabled: model != null,
                                        minLines: 1,
                                        maxLines: 6,
                                        style: TextStyle(
                                          fontSize: compact ? 16 : 15,
                                          height: 1.5,
                                        ),
                                        placeholder: hint,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        onChanged: (value) {
                                          _dismissEnhancement();
                                          state.updatePrompt(
                                            widget.topicId,
                                            value,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: _prompt,
                                    builder: (context, value, _) =>
                                        IosIconButton(
                                          icon: Lucide.WandSparkles,
                                          tooltip: l10n.creationEnhance,
                                          minSize: 34,
                                          enabled:
                                              model != null &&
                                              value.text.trim().isNotEmpty,
                                          onTap: () => _enhance(),
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
                                  Builder(
                                    builder: (anchor) => IosIconButton(
                                      icon: LucideIcons.imagePlus,
                                      size: 17,
                                      minSize: 30,
                                      tooltip: l10n.creationAddReference,
                                      enabled:
                                          limit > 0 &&
                                          (video
                                              ? caps?.frameRoles.isNotEmpty ==
                                                    true
                                              : references.length < limit),
                                      onTap: () => _pickReferences(
                                        anchor,
                                        role: video
                                            ? MediaReferenceRole.firstFrame
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  SizedBox(
                                    width: compact ? 64 : 132,
                                    child: SlidingSegmentedTabs(
                                      height: 30,
                                      compact: true,
                                      iconOnly: compact,

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
                                      onChanged: (index) => state.setMode(
                                        MediaMode.values[index],
                                      ),
                                    ),
                                  ),
                                  if (!compact)
                                    Container(
                                      height: 16,
                                      width: 1,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      color: cs.onSurface.withValues(
                                        alpha: .11,
                                      ),
                                    ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: _ComposerChip(
                                      label:
                                          model?.spec.displayName ??
                                          l10n.creationNoSelectableModels,
                                      strong: true,
                                      maxWidth: 190,
                                      leading: model == null
                                          ? null
                                          : ProviderAvatar(
                                              providerKey: model.provider.id,
                                              displayName: model.provider.name,
                                              size: 16,
                                            ),
                                      trailing: model == null
                                          ? null
                                          : Lucide.ChevronDown,
                                      onTap: model == null
                                          ? null
                                          : (anchor) => _showPicker(
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
                                      _ComposerChip(
                                        maxWidth: (constraints.maxWidth - 170)
                                            .clamp(80.0, 300.0),
                                        label: [
                                          aspectRatio == 'auto'
                                              ? l10n.creationAuto
                                              : aspectRatio,
                                          if (!video)
                                            l10n.creationImagesCount(
                                              state.count,
                                            ),
                                          if (state.duration
                                              case final int duration
                                              when video)
                                            l10n.creationDurationSeconds(
                                              duration,
                                            ),
                                        ].join(' · '),
                                        leading: const Icon(
                                          Lucide.SlidersHorizontal,
                                          size: 15,
                                        ),
                                        trailing: frames
                                            ? LucideIcons.film
                                            : null,
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
                                      )
                                    else ...[
                                      _ComposerChip(
                                        maxWidth: 84,
                                        label: aspectRatio == 'auto'
                                            ? l10n.creationAuto
                                            : aspectRatio,
                                        leading: const Icon(
                                          Lucide.Square,
                                          size: 15,
                                        ),
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
                                          leading: const Icon(
                                            Lucide.Timer,
                                            size: 15,
                                          ),
                                          onTap: (anchor) => _showPicker(
                                            anchor,
                                            width: 320,
                                            title: l10n.creationDuration,
                                            content: (_) =>
                                                const _ParameterOptions(
                                                  duration: true,
                                                ),
                                          ),
                                        ),
                                      if (state.resolutionFor(widget.topicId)
                                          case final String resolution
                                          when video)
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
                                                const _ParameterOptions(
                                                  count: true,
                                                ),
                                          ),
                                        ),
                                      _ComposerChip(
                                        maxWidth: 109,
                                        label: l10n.creationMoreOptions,
                                        leading: Badge(
                                          isLabelVisible: state
                                              .hasAdvancedOptions(
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
                                                  (MediaQuery.sizeOf(
                                                            context,
                                                          ).height -
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
    return showCreationPicker<void>(
      anchor,
      desktop: widget.desktop,
      width: width,
      title: title,
      builder: (context) => content(() => Navigator.of(context).pop()),
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
  final ValueChanged<BuildContext>? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chip = IosCardPress(
      focusable: true,
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      onTap: onTap == null ? null : () => onTap!(context),
      child: SizedBox(
        height: 30,
        child: LayoutBuilder(
          builder: (context, bounds) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null && bounds.maxWidth >= 35) ...[
                leading!,
                const SizedBox(width: 5),
              ],
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
              if (trailing != null && bounds.maxWidth >= 60) ...[
                const SizedBox(width: 3),
                Icon(trailing, size: 13, color: cs.onSurfaceVariant),
              ],
            ],
          ),
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
        CreationSearchBox(
          hint: l10n.creationSearchModels,
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
          SlidingSegmentedTabs(
            height: 36,
            expand: ratios.length <= 4,

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
        if (count) _ImageCountOptions(topicId: topicId),
        if (duration && caps != null && caps.durations.isNotEmpty) ...[
          if (ratio) const SizedBox(height: 12),
          Text(l10n.creationDuration),
          const SizedBox(height: 6),
          SlidingSegmentedTabs(
            height: 36,
            expand: caps.durations.length <= 4,

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
          SlidingSegmentedTabs(
            height: 36,

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

class _ImageCountOptions extends StatefulWidget {
  const _ImageCountOptions({this.topicId});

  final String? topicId;

  @override
  State<_ImageCountOptions> createState() => _ImageCountOptionsState();
}

class _ImageCountOptionsState extends State<_ImageCountOptions> {
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final count = state.count;
    final custom = _custom || count > 4;
    final model = state.model;
    final max =
        model?.capabilities.outputLimit(
          state.imageReferences(widget.topicId).length,
        ) ??
        1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.creationCountLabel),
        const SizedBox(height: 6),
        SlidingSegmentedTabs(
          height: 36,

          tabs: [
            for (var i = 1; i <= 4; i++) SegmentedTab(label: '$i'),
            SegmentedTab(label: l10n.creationCustomCount),
          ],
          index: custom ? 4 : count - 1,
          onChanged: (index) {
            setState(() => _custom = index == 4);
            if (index != 4) state.selectCount(index + 1);
          },
        ),
        if (custom)
          Row(
            children: [
              IosIconButton(
                icon: Lucide.Minus,
                minSize: 34,
                onTap: count > 1 ? () => state.selectCount(count - 1) : null,
              ),
              Text('$count'),
              IosIconButton(
                icon: Lucide.Plus,
                minSize: 34,
                onTap: count < 16 ? () => state.selectCount(count + 1) : null,
              ),
              const Spacer(),
              Text(
                l10n.creationCustomCountMaximum,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        if (model != null && max > 0 && count > max)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.creationRequestSplit(
                model.spec.displayName,
                max,
                (count / max).ceil(),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ReferenceStrip extends StatelessWidget {
  const _ReferenceStrip({
    required this.references,
    required this.limit,
    required this.model,
    required this.onRemove,
    required this.onAdd,
  });

  final List<MediaReference> references;
  final int limit;
  final String model;
  final ValueChanged<MediaReference> onRemove;
  final ValueChanged<BuildContext> onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final unavailable = limit == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final reference in references)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.square(
                            dimension: 56,
                            child: Opacity(
                              opacity: unavailable ? .45 : 1,
                              child: CreationFileImage(
                                reference.path,
                                cacheWidth: 140,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 1,
                          right: 1,
                          child: IosIconButton(
                            icon: Lucide.X,
                            size: 13,
                            minSize: 21,
                            color: Colors.white,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            onTap: () => onRemove(reference),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (references.length < limit)
                  Builder(
                    builder: (anchor) => SizedBox.square(
                      dimension: 56,
                      child: IosCardPress(
                        onTap: () => onAdd(anchor),
                        borderRadius: BorderRadius.circular(12),
                        baseColor: colors.surfaceContainerHighest.withValues(
                          alpha: .5,
                        ),
                        child: const Icon(Lucide.Plus, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unavailable
                ? l10n.creationReferenceUnsupported(model)
                : l10n.creationReferenceSummary(references.length, limit),
            style: TextStyle(
              fontSize: 11.5,
              color: unavailable
                  ? context.appColors.warning
                  : colors.onSurfaceVariant,
            ),
          ),
          if (unavailable)
            Text(
              l10n.creationReferenceIgnored,
              style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
            ),
        ],
      ),
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
    required this.desktop,
    required this.capabilities,
    required this.onPick,
  });

  final String? topicId;
  final bool desktop;
  final MediaCapabilities capabilities;
  final void Function(BuildContext, MediaReferenceRole) onPick;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final hasLast = capabilities.frameRoles.contains(
      MediaReferenceRole.lastFrame,
    );
    final style = TextStyle(
      fontSize: 11.5,
      height: 1.4,
      color: cs.onSurface.withValues(alpha: .42),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          for (final role in capabilities.frameRoles) ...[
            _FrameSlot(
              desktop: desktop,
              label: role == MediaReferenceRole.firstFrame
                  ? l10n.creationFirstFrame
                  : l10n.creationLastFrame,
              value: state.frame(topicId, role),
              onPick: () => onPick(context, role),
              onRemove: () => state.setFrame(topicId, role, null),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasLast
                      ? l10n.creationFirstFrameRequired
                      : l10n.creationFrameModelFirstOnly(
                          state.model!.spec.displayName,
                        ),
                  style: style,
                ),
                const SizedBox(height: 2),
                Text(l10n.creationFrameSources, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameSlot extends StatefulWidget {
  const _FrameSlot({
    required this.desktop,
    required this.label,
    required this.value,
    required this.onPick,
    required this.onRemove,
  });
  final bool desktop;
  final String label;
  final MediaReference? value;
  final VoidCallback onPick, onRemove;
  @override
  State<_FrameSlot> createState() => _FrameSlotState();
}

class _FrameSlotState extends State<_FrameSlot> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    final value = widget.value;
    final color = _hover || _focus
        ? cs.primary
        : cs.onSurface.withValues(alpha: .42);
    final remove = value != null && (!widget.desktop || _hover || _focus);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (v) => setState(() => _focus = v),
        child: SizedBox.square(
          dimension: 56,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: widget.label,
                  child: IosCardPress(
                    focusable: true,
                    borderRadius: radius,
                    baseColor: Colors.transparent,
                    onTap: widget.onPick,
                    border: Border.all(
                      color: _hover || _focus
                          ? cs.primary
                          : cs.onSurface.withValues(
                              alpha: value == null ? .12 : .06,
                            ),
                      width: value == null ? 1.5 : 1,
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: value == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Lucide.Plus, size: 16, color: color),
                                const SizedBox(height: 3),
                                Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                CreationFileImage(value.path),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.black.withValues(alpha: .45),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      widget.label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (remove)
                PositionedDirectional(
                  top: 3,
                  end: 3,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IosIconButton(
                      icon: Lucide.X,
                      size: 11,
                      minSize: 18,
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onTap: widget.onRemove,
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
