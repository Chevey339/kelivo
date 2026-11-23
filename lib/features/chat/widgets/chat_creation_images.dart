import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../core/models/message_part.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/media/chat_image_generation_service.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../../media/providers/media_creation_controller.dart';
import '../../media/widgets/creation_lightbox.dart';
import '../../media/widgets/creation_timeline.dart';
import '../../media/widgets/creation_waiting_card.dart';
import '../pages/image_viewer_page.dart';

typedef _ImageSlot = ({
  String id,
  GenerationBatchRow? batch,
  GenerationItemRow? item,
  ImagePart? attachment,
});

class ChatCreationImages extends StatefulWidget {
  const ChatCreationImages({
    super.key,
    required this.messageId,
    required this.attachments,
    required this.streaming,
  });

  final String messageId;
  final List<ImagePart> attachments;
  final bool streaming;

  @override
  State<ChatCreationImages> createState() => _ChatCreationImagesState();
}

class _ChatCreationImagesState extends State<ChatCreationImages> {
  String? _selected;
  bool _hovered = false;
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
        message: AppLocalizations.of(context)!.creationActionFailed,
      );
    }
  }

  double _ratio(_ImageSlot slot) {
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
    final rows = context
        .select<
          MediaCreationController?,
          List<(GenerationBatchRow, GenerationItemRow?)>
        >(
          (media) => [
            for (final batch
                in media?.chatBatchesFor(widget.messageId) ??
                    const <GenerationBatchRow>[])
              (
                batch,
                media
                    ?.itemsFor(batch.id)
                    .where((item) => item.status == GenerationItemStatus.ready)
                    .firstOrNull,
              ),
          ],
        );
    final byItem = {
      for (final part in widget.attachments)
        if (part.generationItemId case final id?) id: part,
    };
    final slots = <_ImageSlot>[
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
    if (slots.isEmpty) return const SizedBox.shrink();
    final slot =
        slots.where((value) => value.id == _selected).firstOrNull ?? slots.last;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = PlatformUtils.isDesktopTarget;
    final ratio = _ratio(slot);
    final batch = slot.batch;
    final active = batch?.status.isActive == true;
    final showRail = slots.length > 1;
    final maxWidth = desktop
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
          return SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 7,
              children: [
                if (active && batch != null && media != null)
                  Row(
                    children: [
                      Expanded(
                        child: ThinkingSheen(
                          enabled: !MediaQuery.disableAnimationsOf(context),
                          child: Text(
                            l10n.creationWaitingImage,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _main(slot, slots, media, ratio, desktop)),
                    if (showRail) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          child: Column(
                            spacing: 8,
                            children: [
                              for (final candidate in slots)
                                _thumbnail(candidate, slot.id == candidate.id),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (slot.item case final item?
                    when !active && batch != null && media != null)
                  _caption(item, batch, media, readyCount),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _main(
    _ImageSlot slot,
    List<_ImageSlot> slots,
    MediaCreationController? media,
    double ratio,
    bool desktop,
  ) {
    final batch = slot.batch;
    if (batch != null && batch.status.isActive && media != null) {
      return AspectRatio(
        aspectRatio: ratio,
        child: ListenableBuilder(
          listenable: media.runner,
          builder: (_, _) => CreationWaitingCard(
            key: ValueKey(batch.id),
            batch: batch,
            progress: media.runner.progressFor(batch.id)?.fraction,
            preview: media.runner.progressFor(batch.id)?.preview,
            queueAhead: media.runner.queueAhead(batch.id),
            showStatusLabel: false,
          ),
        ),
      );
    }
    if (slot.item case final item?) {
      final l10n = AppLocalizations.of(context)!;
      return MouseRegion(
        onEnter: desktop ? (_) => setState(() => _hovered = true) : null,
        onExit: desktop ? (_) => setState(() => _hovered = false) : null,
        child: AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IosCardPress(
                  onTap: () => showCreationLightbox(
                    context,
                    item,
                    desktop: desktop,
                    gallery: [
                      for (final value in slots)
                        if (value.item case final artwork?) artwork,
                    ],
                  ),
                  child: CreationFileImage(slot.attachment?.uri ?? item.path),
                ),
                if (_hovered && desktop)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IosIconButton(
                            icon: Lucide.Download,
                            color: Colors.white,
                            minSize: 32,
                            tooltip: l10n.creationSaveImage,
                            onTap: () => saveCreationArtwork(
                              context,
                              item,
                              desktop: desktop,
                            ),
                          ),
                          IosIconButton(
                            icon: Lucide.Share,
                            color: Colors.white,
                            minSize: 32,
                            tooltip: l10n.creationShare,
                            onTap: () => shareCreationArtwork(context, item),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (slot.attachment case final part?) {
      return IosCardPress(
        onTap: part.unavailable
            ? null
            : () => ImageViewerPage(
                images: [part.uri],
                initialIndex: 0,
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
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Icon(Lucide.ImageOff, size: 22),
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
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: widget.streaming || _retrying != null
                      ? null
                      : () => _retry(batch, media),
                  child: Text(l10n.creationRetry),
                ),
                if (batch.errorJson != null)
                  TextButton(
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

  Widget _thumbnail(_ImageSlot slot, bool selected) {
    final cs = Theme.of(context).colorScheme;
    final path =
        slot.item?.thumbnailPath ?? slot.attachment?.uri ?? slot.item?.path;
    return IosCardPress(
      onTap: () => setState(() => _selected = slot.id),
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
    );
  }

  Widget _caption(
    GenerationItemRow item,
    GenerationBatchRow batch,
    MediaCreationController media,
    int count,
  ) {
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
        Text(
          l10n.creationChatResultCaption(count, model.displayName, ratio),
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _link(
          l10n.creationShowInCreation,
          () =>
              ChatActionBus.instance.fireCreation(OpenCreationArtwork(item.id)),
        ),
      ],
    );
  }

  Widget _link(String label, VoidCallback? onTap) => TextButton(
    style: TextButton.styleFrom(
      textStyle: const TextStyle(fontSize: 12.5),
      minimumSize: const Size(28, 30),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: onTap,
    child: Text(label),
  );
}
