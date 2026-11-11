import '../../../core/models/request_budget.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/models/image_context.dart';
import '../../../core/services/api/request_image_context.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../../home/services/context_usage_service.dart';
import '../../workspace/widgets/files/file_browser_ops.dart';
import '../../workspace/widgets/files/workspace_file_thumbnail.dart';

Future<void> showImageContextPanel(
  BuildContext context,
  String conversationId, {
  ValueChanged<String>? onAttach,
}) async {
  final chat = context.read<ChatService>();
  final usage = context.read<ContextUsageService>();
  final title = AppLocalizations.of(context)!.imageContextTitle;
  // Desktop windows can be narrower than the tablet breakpoint. Width controls
  // density, not whether a desktop app opens a mobile bottom sheet.
  final desktop =
      PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context);
  Widget panel(ScrollController? scroll) => ImageContextPanel(
    conversationId: conversationId,
    chat: chat,
    usage: usage,
    onAttach: onAttach,
    scrollController: scroll,
  );
  if (desktop) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DesktopFormDialog(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 700),
        child: SizedBox(
          width: 680,
          height: math.max(
            0,
            math.min(700, MediaQuery.sizeOf(dialogContext).height - 48),
          ),
          child: Column(
            children: [
              DesktopFormDialogHeader(
                title: title,
                closeTooltip: MaterialLocalizations.of(
                  context,
                ).closeButtonLabel,
                onClose: () => Navigator.pop(dialogContext),
              ),
              Expanded(child: panel(null)),
            ],
          ),
        ),
      ),
    );
  } else {
    await showCustomBottomSheet<void>(
      context: context,
      title: title,
      partialHeightFactor: 0.72,
      expandedHeightFactor: 0.92,
      builder: (_, scroll) => panel(scroll),
    );
  }
}

class ImageContextPanel extends StatefulWidget {
  const ImageContextPanel({
    super.key,
    required this.conversationId,
    required this.chat,
    required this.usage,
    this.onAttach,
    this.scrollController,
  });
  final String conversationId;
  final ChatService chat;
  final ContextUsageService usage;
  final ValueChanged<String>? onAttach;
  final ScrollController? scrollController;
  @override
  State<ImageContextPanel> createState() => _ImageContextPanelState();
}

class _ImageContextPanelState extends State<ImageContextPanel> {
  RequestImageContext? _request;
  List<ImageContextPreviewItem> _items = [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final request = await widget.usage.imageContextPreview(
        widget.conversationId,
      );
      final items = await request?.preview() ?? [];
      if (!mounted) return;
      setState(() {
        _request = request;
        _items = items;
        _error = null;
        _busy = false;
      });
    } catch (error) {
      debugPrint('[ImageContext] Preview failed: $error');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.imageContextLoadFailed;
        _busy = false;
      });
    }
  }

  Future<void> _save(ImageContextSettings settings) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.chat.setImageContextSettings(
        widget.conversationId,
        settings,
      );
      await widget.usage.refresh(widget.conversationId, force: true);
      if (mounted) await _load();
    } catch (error) {
      debugPrint('[ImageContext] Update failed: $error');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.imageContextUpdateFailed;
        _busy = false;
      });
    }
  }

  Future<void> _attach(ChatContextImage image) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Revalidate the clear boundary if it changed while the panel was open.
      final current = await widget.usage.imageContextPreview(
        widget.conversationId,
      );
      final path = await current?.attachmentPath(image.handle);
      if (!mounted) return;
      if (path == null) {
        setState(() {
          _error = AppLocalizations.of(context)!.imageContextUnavailable;
          _busy = false;
        });
        return;
      }
      widget.onAttach?.call(path);
      Navigator.pop(context);
    } catch (error) {
      debugPrint('[ImageContext] Reattachment failed: $error');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.imageContextUnavailable;
        _busy = false;
      });
    }
  }

  Widget _settingCard({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IosSwitch(
            value: value,
            semanticLabel: label,
            onChanged: _busy ? null : onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = _request?.settings;
    final included = _items.where((item) => item.included).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= 520 ? 24.0 : 16.0;
        return CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 12, inset, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.imageContextDescription,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    if (settings != null) ...[
                      const SizedBox(height: 18),
                      _settingCard(
                        label: l10n.imageContextAutomatic,
                        description: l10n.imageContextAutomaticDescription,
                        value: settings.automatic,
                        onChanged: (value) => _save(
                          ImageContextSettings(
                            automatic: value,
                            allowRecall: settings.allowRecall,
                            pinned: settings.pinned,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _settingCard(
                        label: l10n.imageContextAllowRecall,
                        description: l10n.imageContextAllowRecallDescription,
                        value: settings.allowRecall,
                        onChanged: (value) => _save(
                          ImageContextSettings(
                            automatic: settings.automatic,
                            allowRecall: value,
                            pinned: settings.pinned,
                          ),
                        ),
                      ),
                    ],
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        l10n.imageContextIncludedCount(included, _items.length),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.imageContextActionsHint,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                    if (_busy && _request != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: cs.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Lucide.CircleAlert, size: 18, color: cs.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(fontSize: 13, color: cs.error),
                            ),
                          ),
                          IosTextButton(
                            label: l10n.retry,
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() => _busy = true);
                                    _load();
                                  },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_busy && _request == null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              )
            else if (_items.isEmpty && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(inset, 48, inset, 36),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceCardFill,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Lucide.Image,
                          size: 28,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.imageContextEmpty,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          l10n.imageContextEmptyDescription,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            for (final source in ContextImageSource.values)
              ..._imageGroup(context, source, inset),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  List<Widget> _imageGroup(
    BuildContext context,
    ContextImageSource source,
    double inset,
  ) {
    final items = _items.where((item) => item.image.source == source).toList();
    if (items.isEmpty) return [];
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final title = switch (source) {
      ContextImageSource.user => l10n.imageContextUserImages,
      ContextImageSource.tool => l10n.imageContextToolImages,
      ContextImageSource.assistant => l10n.imageContextAssistantImages,
    };
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(inset + 2, 22, inset + 2, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final originalIndex = items.length - index - 1;
            final item = items[originalIndex];
            final image = item.image;
            final available = !image.unavailable && item.bytes != null;
            final status = !available
                ? l10n.imageContextMissing
                : item.included
                ? l10n.imageContextIncluded
                : l10n.imageContextOmitted;
            final statusColor = item.included && available
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.45);
            return Padding(
              key: ValueKey(image.key),
              padding: const EdgeInsets.only(bottom: 8),
              child: SectionCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _ImageContextThumbnail(
                      key: ValueKey(image.key),
                      request: _request!,
                      image: image,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _imageTitle(image, originalIndex + 1, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFontWeights.medium,
                            ),
                          ),
                          if ((item.bytes ?? 0) > 0 || item.pinned) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (item.sizeIsEstimate)
                                  l10n.imageContextSizeUnknown
                                else if ((item.bytes ?? 0) > 0)
                                  l10n.imageContextEncodedSize(
                                    (item.bytes! / RequestBudget.mib)
                                        .toStringAsFixed(2),
                                  ),
                                if (item.pinned) l10n.imageContextPinned,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: .55),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IosIconButton(
                      icon: item.pinned ? Lucide.PinOff : Lucide.Pin,
                      size: 17,
                      minSize: 36,
                      color: item.pinned
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                      tooltip: item.pinned
                          ? l10n.imageContextUnpin
                          : l10n.imageContextPin,
                      enabled: !_busy,
                      onTap: () => _save(
                        _request!.settings.pin(image.key, !item.pinned),
                      ),
                    ),
                    if (widget.onAttach != null)
                      IosIconButton(
                        icon: Lucide.Plus,
                        size: 18,
                        minSize: 36,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        tooltip: l10n.imageContextAttachAgain,
                        enabled: !_busy && available,
                        onTap: () => _attach(image),
                      ),
                  ],
                ),
              ),
            );
          }, childCount: items.length),
        ),
      ),
    ];
  }
}

// Uploads and tool snapshots often have generated storage names. The thumbnail
// identifies the picture; storage IDs are not useful titles for this screen.
final _generatedImageName = RegExp(
  r'(^draft-|^mcp_img_|[0-9a-f]{8}-[0-9a-f]{4}-|^[0-9a-f]{24,})',
  caseSensitive: false,
);

String _imageTitle(ChatContextImage image, int index, AppLocalizations l10n) {
  final label = p.basename(image.label);
  if (image.source == ContextImageSource.user &&
      label.isNotEmpty &&
      label != 'Image' &&
      !_generatedImageName.hasMatch(label)) {
    return label;
  }
  return l10n.imageContextImageNumber(index);
}

class _ImageContextThumbnail extends StatefulWidget {
  const _ImageContextThumbnail({
    super.key,
    required this.request,
    required this.image,
  });
  final RequestImageContext request;
  final ChatContextImage image;
  @override
  State<_ImageContextThumbnail> createState() => _ImageContextThumbnailState();
}

class _ImageContextThumbnailState extends State<_ImageContextThumbnail> {
  late Future<FileBrowserEntry?> _file = _localFile();

  @override
  void didUpdateWidget(_ImageContextThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.uri != widget.image.uri ||
        oldWidget.image.unavailable != widget.image.unavailable) {
      _file = _localFile();
    }
  }

  Future<FileBrowserEntry?> _localFile() async {
    try {
      final path = await widget.request.localAttachmentPath(
        widget.image.handle,
      );
      if (path == null) return null;
      final stat = await File(path).stat();
      if (stat.type != FileSystemEntityType.file) return null;
      return FileBrowserEntry(
        name: p.basename(path),
        hostPath: path,
        isDirectory: false,
        size: stat.size,
        modified: stat.modified,
      );
    } on FileSystemException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = cs.onSurface.withValues(alpha: 0.3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: ColoredBox(
        color: cs.onSurface.withValues(alpha: 0.04),
        child: SizedBox.square(
          dimension: 52,
          child: FutureBuilder<FileBrowserEntry?>(
            future: _file,
            builder: (context, snapshot) {
              final entry = snapshot.data;
              return entry == null
                  ? Icon(Lucide.Image, size: 23, color: iconColor)
                  : WorkspaceFileThumbnail(
                      entry: entry,
                      size: 52,
                      iconColor: iconColor,
                    );
            },
          ),
        ),
      ),
    );
  }
}
