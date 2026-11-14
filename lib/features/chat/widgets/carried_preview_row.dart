import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/carried_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/markdown/link_image_handlers.dart'
    show markdownImageProvider;
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/safe_resize_image.dart';
import '../pages/image_viewer_page.dart';
import 'context_dialog.dart';

class CarriedPreviewRow extends StatefulWidget {
  const CarriedPreviewRow({
    super.key,
    required this.row,
    required this.selected,
    required this.includeReply,
    required this.newConversation,
    required this.onSelect,
    required this.onReply,
  });
  final CarryRow row;
  final bool selected, includeReply, newConversation;
  final ValueChanged<bool> onSelect, onReply;
  @override
  State<CarriedPreviewRow> createState() => _CarriedPreviewRowState();
}

class _CarriedPreviewRowState extends State<CarriedPreviewRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;
    final small = TextStyle(fontSize: 12, height: 1.4, color: muted);
    final raw = (row.messageText ?? row.item.effectiveText).trim();
    final imageItems = row.imageUris;
    final files = row.fileNames;
    final count = row.attachmentCount;
    final attachmentLabel = count == 0
        ? ''
        : imageItems.length == count
        ? l.compressionCarryImageCount(count)
        : l.compressionCarryAttachmentCount(count);
    final title = raw.isNotEmpty
        ? raw
        : files.length == 1 && files.single.isNotEmpty && count == 1
        ? files.single
        : attachmentLabel.isNotEmpty
        ? attachmentLabel
        : l.compressionCarryNoText;
    final clipped = title.characters.take(161).toString();
    final long =
        title.length > clipped.length ||
        title.contains('\n') ||
        clipped.characters.length > 65;
    final compact = clipped.replaceAll(RegExp(r'\s+'), ' ');
    final reply = row.availableReply;
    final fileText = files.isNotEmpty && row.item.effectiveText.trim() != raw
        ? row.item.effectiveText.trim()
        : '';
    final toggle =
        long ||
        count > 4 ||
        files.length > 1 ||
        fileText.isNotEmpty ||
        (widget.includeReply && (reply?.effectiveText.length ?? 0) > 150);
    final gallery = imageItems.whereType<String>().toList();
    final visibleImages = _expanded ? imageItems : imageItems.take(4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IosCheckbox(
            value: widget.selected,
            hitTestSize: 44,
            size: 20,
            semanticLabel: compact,
            onChanged: widget.onSelect,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  expanded: toggle ? _expanded : null,
                  child: IosCardPress(
                    onTap: toggle
                        ? () => setState(() => _expanded = !_expanded)
                        : () => widget.onSelect(!widget.selected),
                    focusable: true,
                    haptics: false,
                    pressedBlendStrength: 0,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _expanded ? title : compact,
                            maxLines: _expanded ? 6 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: AppFontWeights.medium,
                              color: widget.selected ? cs.onSurface : muted,
                            ),
                          ),
                        ),
                        if (toggle) ...[
                          const SizedBox(width: 6),
                          Icon(
                            _expanded
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                            color: muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (imageItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final (i, image) in visibleImages.indexed)
                          _ImageThumbnail(
                            key: ValueKey((i, image)),
                            uri: image ?? '',
                            label: l.imageContextImageNumber(i + 1),
                            onOpen: image == null
                                ? null
                                : () => ImageViewerPage(
                                    images: gallery,
                                    initialIndex: imageItems
                                        .take(i)
                                        .whereType<String>()
                                        .length,
                                  ).open(context),
                          ),
                        if (!_expanded && imageItems.length > 4)
                          IosCardPress(
                            onTap: () => setState(() => _expanded = true),
                            focusable: true,
                            child: SizedBox.square(
                              dimension: 44,
                              child: Center(
                                child: Text(
                                  '+${imageItems.length - 4}',
                                  style: small,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (files.isNotEmpty && (raw.isNotEmpty || count != 1))
                  for (final file in (_expanded ? files : files.take(1)))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(LucideIcons.fileText, size: 14, color: muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              file.trim().isNotEmpty
                                  ? file
                                  : l.storageSpaceCategoryFiles,
                              style: small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                if (_expanded && fileText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      fileText,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (attachmentLabel.isNotEmpty && raw.isNotEmpty)
                      Text(attachmentLabel, style: small),
                    Text(
                      l.compressApproxTokens(contextTokenValue(row.tokens)),
                      style: small,
                    ),
                  ],
                ),
                if (row.item.truncated)
                  Text(l.compressionCarryTruncated, style: small),
                if (widget.newConversation &&
                    (row.hadAttachments || row.item.hasAttachments))
                  Text(l.compressionCarryNewChatText, style: small),
                if (widget.selected && reply != null) ...[
                  Row(
                    children: [
                      Icon(LucideIcons.cornerDownRight, size: 14, color: muted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          l.compressionCarryReply,
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        ),
                      ),
                      if (widget.includeReply && !row.replyInRetained)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            l.compressionCarryReplyTokens(
                              contextTokenValue(reply.estimatedTokens),
                            ),
                            style: small,
                          ),
                        ),
                      IosSwitch(
                        value: widget.includeReply && !row.replyInRetained,
                        width: 34,
                        height: 21,
                        semanticLabel: l.compressionCarryReply,
                        onChanged: row.replyInRetained ? null : widget.onReply,
                      ),
                    ],
                  ),
                  if (row.replyInRetained)
                    Text(l.compressionCarryReplyInKept, style: small),
                  if (row.replyDoesNotFit && widget.includeReply)
                    Text(
                      l.compressionCarryOverBudget,
                      style: small.copyWith(color: context.appColors.warning),
                    ),
                  if (widget.includeReply && !row.replyInRetained)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            start: BorderSide(
                              width: 2,
                              color: cs.primary.withValues(alpha: .4),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 9),
                          child: Text(
                            reply.effectiveText.trim(),
                            maxLines: _expanded ? 6 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: small,
                          ),
                        ),
                      ),
                    ),
                ] else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Retain the image provider while selection and token estimates refresh.
class _ImageThumbnail extends StatefulWidget {
  const _ImageThumbnail({
    super.key,
    required this.uri,
    required this.label,
    required this.onOpen,
  });
  final String uri, label;
  final VoidCallback? onOpen;
  @override
  State<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<_ImageThumbnail> {
  late final _image = widget.uri.isEmpty
      ? null
      : markdownImageProvider(widget.uri);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final edge = (44 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
      1,
      160,
    );
    final fallback = Icon(
      LucideIcons.image,
      size: 18,
      color: cs.onSurfaceVariant,
    );
    return Semantics(
      label: widget.label,
      button: widget.onOpen != null,
      child: IosCardPress(
        onTap: widget.onOpen,
        focusable: true,
        borderRadius: BorderRadius.circular(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ColoredBox(
            color: context.appColors.surfaceFill,
            child: SizedBox.square(
              dimension: 44,
              child: _image == null
                  ? fallback
                  : Image(
                      excludeFromSemantics: true,
                      image: SafeResizeImage.display(
                        _image,
                        width: edge,
                        height: edge,
                        fit: SafeResizeFit.cover,
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
