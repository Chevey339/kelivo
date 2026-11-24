import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../core/models/message_part.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/tools/generate_image_tool.dart';
import 'timeline_projection.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/media/chat_image_generation_service.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../media/widgets/creation_controls.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../../media/providers/media_creation_controller.dart';
import '../../media/widgets/creation_lightbox.dart';
import '../../media/widgets/creation_timeline.dart';
import '../../media/widgets/creation_waiting_card.dart';
import '../pages/image_viewer_page.dart';

typedef ChatImageSlot = ({
  String id,
  GenerationBatchRow? batch,
  GenerationItemRow? item,
  ImagePart? attachment,
});

List<ChatImageSlot> _imageSlots(
  BuildContext context,
  String messageId,
  List<ImagePart> attachments, {
  bool listen = true,
}) {
  List<(GenerationBatchRow, GenerationItemRow?)> rowsFor(
    MediaCreationController? media,
  ) => [
    if (media != null)
      for (final batch in media.chatBatchesFor(messageId))
        (
          batch,
          media
              .itemsFor(batch.id)
              .where((item) => item.status == GenerationItemStatus.ready)
              .firstOrNull,
        ),
  ];
  final rows = listen
      ? context.select<
          MediaCreationController?,
          List<(GenerationBatchRow, GenerationItemRow?)>
        >(rowsFor)
      : rowsFor(context.read<MediaCreationController?>());
  final byItem = {
    for (final part in attachments)
      if (part.generationItemId case final id?) id: part,
  };
  return <ChatImageSlot>[
    for (final (batch, item) in rows)
      if (batch.status.isActive ||
          item != null ||
          batch.status != GenerationStatus.succeeded)
        (
          id: batch.id,
          batch: batch,
          item: item,
          attachment: byItem.remove(item?.id),
        ),
    for (final part in byItem.values)
      (id: part.generationItemId!, batch: null, item: null, attachment: part),
  ];
}

/// Matches only this reply's results. An older or unlinked image stays in the footer.
class ChatImagePlacement {
  ChatImagePlacement._(this.atCall, this.footer);

  final Map<int, List<ChatImageSlot>> atCall;
  final List<ChatImageSlot> footer;

  static ChatImagePlacement? resolve(
    BuildContext context,
    String messageId,
    List<ImagePart> attachments,
    TimelineProjection projection, {
    bool listen = true,
  }) {
    final steps = [
      for (final block in projection.blocks)
        for (final step in block.steps)
          if (step.tool?.toolName == GenerateImageTool.name) step,
    ];
    if (steps.isEmpty) return null;
    final byBatch = <String, int>{};
    final byCall = <String, int>{};
    final byItem = <String, int>{};
    for (final step in steps) {
      final tool = step.tool!;
      if (tool.providerId.isNotEmpty) {
        byCall[tool.providerId] = step.sourceOrdinal;
      }
      if (tool.metadata?[GenerateImageTool.batchKey] case final String id) {
        byBatch[id] = step.sourceOrdinal;
      }
      if (GenerateImageTool.attachment(tool.metadata)?.generationItemId
          case final id?) {
        byItem[id] = step.sourceOrdinal;
      }
    }
    final atCall = <int, List<ChatImageSlot>>{};
    final footer = <ChatImageSlot>[];
    for (final slot in _imageSlots(
      context,
      messageId,
      attachments,
      listen: listen,
    )) {
      var ordinal =
          byBatch[slot.batch?.id] ??
          byItem[slot.item?.id ?? slot.attachment?.generationItemId];
      // Active calls can precede the tool-result metadata in the chat stream.
      final batch = slot.batch;
      if (ordinal == null && batch != null) {
        try {
          if (jsonDecode(batch.paramsJson) case {
            GenerateImageTool.callIdParameter: final String id,
          }) {
            ordinal = byCall[id];
          }
        } on FormatException {
          // The saved chat attachment can still be displayed in the footer.
        }
      }
      if (ordinal == null) {
        footer.add(slot);
      } else {
        (atCall[ordinal] ??= []).add(slot);
      }
    }
    return ChatImagePlacement._(atCall, footer);
  }
}

class ChatCreationImages extends StatefulWidget {
  const ChatCreationImages({
    super.key,
    required this.messageId,
    required this.attachments,
    required this.streaming,
  }) : slots = null;

  const ChatCreationImages.forSlots({
    super.key,
    required this.messageId,
    required List<ChatImageSlot> this.slots,
    required this.streaming,
  }) : attachments = const [];

  final String messageId;
  final List<ChatImageSlot>? slots;
  final List<ImagePart> attachments;
  final bool streaming;

  @override
  State<ChatCreationImages> createState() => _ChatCreationImagesState();
}

class _ChatCreationImagesState extends State<ChatCreationImages> {
  String? _selected;
  String? _holding;
  final _thumbFocus = <String, FocusNode>{};
  @override
  void dispose() {
    for (final n in _thumbFocus.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _choose(String id, {bool keyboard = false}) {
    setState(() {
      if (_selected != id) _holding = null;
      _selected = id;
    });
    final node = _thumbFocus[id];
    if (keyboard) node?.requestFocus();
    final ctx = node?.context;
    if (ctx != null) {
      final object = ctx.findRenderObject();
      if (object == null) return;
      Scrollable.maybeOf(ctx)?.position.ensureVisible(
        object,
        alignment: .5,
        duration: handoffDuration(ctx, 160),
        curve: handoffCurve,
      );
    }
  }

  void _hold(String id, bool value) {
    if (!mounted || (value ? _holding == id : _holding != id)) return;
    setState(() => _holding = value ? id : null);
  }

  bool _hovered = false;
  bool _imageFocused = false;
  String? _retrying;

  Future<void> _retry(
    GenerationBatchRow batch,
    MediaCreationController media,
  ) async {
    if (_retrying != null || widget.streaming) return;
    final chat = context.read<ChatService?>();
    if (chat == null) return;
    setState(() => _retrying = batch.id);
    try {
      if (await ChatImageGenerationService(
        runner: media.runner,
        chat: chat,
        settings: media.settings,
      ).retry(batch)) {
        return;
      }
    } catch (_) {
      // Report the rejected action in the conversation.
    } finally {
      if (mounted) setState(() => _retrying = null);
    }
    if (mounted) {
      showAppSnackBar(
        context,
        type: NotificationType.error,
        message: AppLocalizations.of(context)!.creationActionFailed,
      );
    }
  }

  double _ratio(ChatImageSlot slot) {
    final width = slot.item?.width;
    final height = slot.item?.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return (width / height).clamp(.25, 5);
    }
    try {
      if (slot.batch case final batch?) {
        final values = MediaRequest.fromBatch(batch).aspectRatio.split(':');
        if (values.length == 2) {
          final horizontal = double.tryParse(values.first);
          final vertical = double.tryParse(values.last);
          if (horizontal != null &&
              vertical != null &&
              horizontal > 0 &&
              vertical > 0) {
            return (horizontal / vertical).clamp(.25, 5);
          }
        }
      }
    } on FormatException {
      // A batch with unavailable parameters uses the waiting card's square.
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final media = context.read<MediaCreationController?>();
    final slots =
        widget.slots ??
        _imageSlots(context, widget.messageId, widget.attachments);
    if (slots.isEmpty) return const SizedBox.shrink();
    final (showInfo, showLink) = context
        .select<SettingsProvider?, (bool, bool)>(
          (settings) => (
            settings?.showChatImageInfo ?? true,
            settings?.showChatImageLink ?? true,
          ),
        );
    final slot =
        slots.where((value) => value.id == _selected).firstOrNull ?? slots.last;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = PlatformUtils.isDesktopTarget;
    final ratio = _ratio(slot);
    final batch = slot.batch;
    final active = batch?.status.isActive == true;
    final held = _holding == slot.id && !active && slot.item != null;
    final ids = slots.map((v) => v.id).toSet();
    for (final id
        in _thumbFocus.keys.where((id) => !ids.contains(id)).toList()) {
      _thumbFocus.remove(id)!.dispose();
    }
    final showRail = slots.length > 1;
    final maxWidth = active || held
        ? (desktop ? 400.0 : 300.0)
        : desktop
        ? ratio >= 2
              ? double.infinity
              : ratio > 1.01
              ? 480.0
              : 400.0
        : 300.0;
    final readyCount = slots
        .where(
          (value) =>
              value.batch?.status.isActive != true &&
              (value.item != null || value.attachment != null),
        )
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final width = math.min(
            bounds.maxWidth,
            maxWidth + (showRail ? 64 : 0),
          );
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 7,
                children: [
                  if ((active || held) && batch != null && media != null)
                    Row(
                      children: [
                        Expanded(
                          child: ThinkingSheen(
                            enabled:
                                active &&
                                !MediaQuery.disableAnimationsOf(context),
                            child: Text(
                              active
                                  ? l10n.creationWaitingImage
                                  : l10n.creationChatImageReady,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        if (active)
                          _link(
                            MaterialLocalizations.of(context).cancelButtonLabel,
                            () => media.runner.cancel(batch.id),
                          ),
                      ],
                    )
                  else if (batch != null &&
                      batch.status == GenerationStatus.cancelled &&
                      media != null)
                    Row(
                      children: [
                        Expanded(child: Text(l10n.creationChatCancelled)),
                        _link(
                          l10n.creationChatRegenerate,
                          widget.streaming || _retrying != null
                              ? null
                              : () => _retry(batch, media),
                        ),
                      ],
                    ),
                  Row(
                    key: const ValueKey('creation-image'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _main(slot, slots, media, ratio, desktop),
                      ),
                      if (showRail) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: SingleChildScrollView(
                            child: Column(
                              spacing: 8,
                              children: [
                                for (final candidate in slots)
                                  _thumbnail(
                                    candidate,
                                    slot.id == candidate.id,
                                    slots,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (slot.item case final item?
                      when (showInfo || showLink) &&
                          !active &&
                          !held &&
                          batch != null &&
                          media != null)
                    _caption(
                      item,
                      batch,
                      media,
                      readyCount,
                      showInfo: showInfo,
                      showLink: showLink,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _main(
    ChatImageSlot slot,
    List<ChatImageSlot> slots,
    MediaCreationController? media,
    double ratio,
    bool desktop,
  ) {
    final batch = slot.batch;
    if (batch != null &&
        media != null &&
        (batch.status.isActive || slot.item != null)) {
      final busy = batch.status.isActive;
      final item = slot.item;
      return AspectRatio(
        aspectRatio: ratio,
        child: AnimatedBuilder(
          animation: busy ? media.runner : const AlwaysStoppedAnimation(0),
          child: !busy && item != null
              ? _finishedImage(slot, item, slots, desktop)
              : null,
          builder: (_, result) {
            final progress = busy ? media.runner.progressFor(batch.id) : null;
            return CreationWaitingCard(
              key: ValueKey(batch.id),
              batch: batch,
              progress: progress?.fraction,
              preview: progress?.preview,
              queueAhead: busy ? media.runner.queueAhead(batch.id) : 0,
              showStatusLabel: false,
              onGameHoldingChanged: (value) => _hold(slot.id, value),
              gameSeed: widget.messageId,
              result: result,
            );
          },
        ),
      );
    }
    if (slot.attachment case final part?) {
      return IosCardPress(
        onTap: part.unavailable
            ? null
            : () => ImageViewerPage(
                images: [part.uri],
                dismissOnTap: true,
              ).open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: ratio,
            child: CreationFileImage(part.uri),
          ),
        ),
      );
    }
    if (batch == null ||
        media == null ||
        batch.status == GenerationStatus.cancelled) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    Object? message;
    try {
      final diagnostics = jsonDecode(batch.errorJson ?? '{}');
      if (diagnostics is Map) message = diagnostics['message'];
    } on FormatException {
      // The batch may have been interrupted before collecting diagnostics.
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.onSurface.withValues(alpha: .06),
          context.appColors.surfaceCard,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(Lucide.ImageOff, size: 22, color: cs.onSurfaceVariant),
            Text(
              l10n.creationChatImageUnavailable,
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            Text(
              message is String && message.isNotEmpty
                  ? message
                  : batch.status == GenerationStatus.interrupted
                  ? l10n.creationInterrupted
                  : l10n.creationFailed,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                CreationAction(
                  small: true,
                  tone: CreationActionTone.tonal,
                  icon: const Icon(Lucide.RotateCcw, size: 13),
                  onPressed: widget.streaming || _retrying != null
                      ? null
                      : () => _retry(batch, media),
                  child: Text(l10n.creationRetry),
                ),
                if (batch.errorJson != null)
                  CreationAction(
                    small: true,
                    onPressed: () => showCreationRequestDetails(
                      context,
                      batch,
                      desktop: desktop,
                      retry: () => _retry(batch, media),
                    ),
                    child: Text(l10n.creationRequestDetails),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _finishedImage(
    ChatImageSlot slot,
    GenerationItemRow item,
    List<ChatImageSlot> slots,
    bool desktop,
  ) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _imageFocused = v),
      child: MouseRegion(
        onEnter: desktop ? (_) => setState(() => _hovered = true) : null,
        onExit: desktop ? (_) => setState(() => _hovered = false) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IosCardPress(
                focusable: true,
                baseColor: Colors.transparent,
                onTap: () => showCreationLightbox(
                  context,
                  item,
                  desktop: desktop,
                  fromChat: true,
                  gallery: [
                    for (final value in slots)
                      if (value.item case final artwork?) artwork,
                  ],
                ),
                child: CreationFileImage(slot.attachment?.uri ?? item.path),
              ),
              if (desktop)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _ChatImageActions(
                    visible: _hovered || _imageFocused,
                    onSave: () =>
                        saveCreationArtwork(context, item, desktop: true),
                    onShare: () => shareCreationArtwork(context, item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(
    ChatImageSlot slot,
    bool selected,
    List<ChatImageSlot> slots,
  ) {
    final cs = Theme.of(context).colorScheme;
    final path =
        slot.item?.thumbnailPath ?? slot.attachment?.uri ?? slot.item?.path;
    final index = slots.indexWhere((s) => s.id == slot.id);
    final node = _thumbFocus.putIfAbsent(
      slot.id,
      () => FocusNode(debugLabel: 'Chat image thumbnail'),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: MaterialLocalizations.of(
        context,
      ).tabLabel(tabIndex: index + 1, tabCount: slots.length),
      child: Focus(
        focusNode: node,
        skipTraversal: !selected,
        onKeyEvent: (_, event) {
          if (event is KeyUpEvent) return KeyEventResult.ignored;
          final dest = switch (event.logicalKey) {
            LogicalKeyboardKey.arrowUp => index - 1,
            LogicalKeyboardKey.arrowDown => index + 1,
            LogicalKeyboardKey.home => 0,
            LogicalKeyboardKey.end => slots.length - 1,
            LogicalKeyboardKey.enter || LogicalKeyboardKey.space => index,
            _ => null,
          };
          if (dest == null) return KeyEventResult.ignored;
          _choose(slots[dest.clamp(0, slots.length - 1)].id, keyboard: true);
          return KeyEventResult.handled;
        },
        child: IosCardPress(
          onTap: () => _choose(slot.id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            padding: EdgeInsets.all(selected ? 2 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected ? cs.primary : context.appColors.surfaceFill,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Opacity(
                opacity: selected ? 1 : .7,
                child: slot.batch?.status.isActive == true
                    ? const CreationDotField(progress: .4, thumbnail: true)
                    : path == null
                    ? const Icon(Lucide.ImageOff, size: 19)
                    : CreationFileImage(path, cacheWidth: 144),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(
    GenerationItemRow item,
    GenerationBatchRow batch,
    MediaCreationController media,
    int count, {
    required bool showInfo,
    required bool showLink,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final provider = media.settings.getProviderConfig(batch.providerId);
    final model = ModelSpecResolver.instance.spec(provider, batch.modelId);
    var ratio = l10n.creationAuto;
    try {
      final requested = MediaRequest.fromBatch(batch).aspectRatio;
      if (requested != 'auto') ratio = requested;
    } on FormatException {
      // Keep the default caption if the parameters cannot be read.
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (showInfo)
          Text(
            l10n.creationChatResultCaption(count, model.displayName, ratio),
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .42),
            ),
          ),
        if (showLink)
          _link(
            l10n.creationShowInCreation,
            () => ChatActionBus.instance.fireCreation(
              OpenCreationArtwork(item.id),
            ),
            external: true,
          ),
      ],
    );
  }

  Widget _link(String label, VoidCallback? onTap, {bool external = false}) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      enabled: onTap != null,
      child: IosCardPress(
        focusable: true,
        onTap: onTap,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        duration: handoffDuration(context, 140),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(
                    alpha: onTap == null ? .32 : .64,
                  ),
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dashed,
                  decorationColor: cs.onSurface.withValues(alpha: .38),
                ),
              ),
            ),
            if (external)
              Icon(
                LucideIcons.arrowUpRight,
                size: 12,
                color: cs.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatImageActions extends StatelessWidget {
  const _ChatImageActions({
    required this.visible,
    required this.onSave,
    required this.onShare,
  });

  final bool visible;
  final VoidCallback onSave, onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget button(IconData icon, String label, VoidCallback tap) => ColoredBox(
      color: Colors.white.withValues(alpha: .16),
      child: IosIconButton(
        shape: BoxShape.circle,
        icon: icon,
        size: 15,
        minSize: 30,
        padding: EdgeInsets.zero,
        color: Colors.white,
        tooltip: label,
        onTap: tap,
      ),
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        button(Lucide.Download, l10n.creationSaveImage, onSave),
        button(Lucide.Share, l10n.creationShare, onShare),
      ],
    );
    return ExcludeFocus(
      excluding: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: visible ? 1 : 0),
            duration: handoffDuration(context, 160),
            curve: Curves.easeInOut,
            child: buttons,
            builder: (_, t, controls) => Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                if (t > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: .32 * t),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                  child: Align(
                    heightFactor: 1,
                    alignment: AlignmentDirectional.bottomEnd,
                    child: ClipPath(
                      clipper: const _ActionButtonCircles(),
                      child: CreationGlassReveal(
                        progress: t,
                        sigma: 8,
                        child: controls!,
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

/// The two circular buttons share one small blur pass. Their gap and the
/// corners of the bounding box remain part of the tappable artwork.
class _ActionButtonCircles extends CustomClipper<Path> {
  const _ActionButtonCircles();
  @override
  Path getClip(Size size) {
    final circle = Rect.fromLTWH(0, 0, size.height, size.height);
    return Path()
      ..addOval(circle)
      ..addOval(circle.shift(Offset(size.width - size.height, 0)));
  }

  @override
  bool shouldReclip(_ActionButtonCircles oldClipper) => false;
}
