import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/safe_resize_image.dart';
import '../pages/image_viewer_page.dart';
import '../../../core/models/message_part.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/platform_utils.dart';

/// A compact history link, never an executable composer message.
class ForwardedMessagesCard extends StatelessWidget {
  const ForwardedMessagesCard({super.key, required this.record});
  final ForwardedMessagesPart record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: IosCardPress(
        onTap: () => showForwardedMessagesDetails(context, record),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.forwardMessagesRecord, style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final entry in record.messages.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${entry.author}: ${_previewText(context, entry)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 18),
            Row(
              children: [
                Icon(
                  Lucide.MessagesSquare,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.forwardMessagesRecord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Icon(Lucide.ChevronRight, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showForwardedMessagesDetails(
  BuildContext context,
  ForwardedMessagesPart record,
) {
  final page = ForwardedMessagesDetails(record: record);
  if (PlatformUtils.isDesktopTarget || !ResponsiveHelper.isMobile(context)) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 680,
          height: MediaQuery.sizeOf(context).height * .85,
          child: page,
        ),
      ),
    );
  }
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => page));
}

String _previewText(BuildContext context, ForwardedMessageSnapshot entry) {
  final l10n = AppLocalizations.of(context)!;
  return [
    for (final part in entry.parts)
      if (part is TextPart)
        part.text.replaceAll('\n', ' ')
      else if (part is ImagePart)
        '[${l10n.chatSelectionExportImage}]'
      else if (part is FilePart)
        part.name.split(RegExp(r'[/\\]')).last
      else if (part is ForwardedMessagesPart)
        '[${l10n.forwardMessagesRecord}]',
  ].join(' ');
}

class _ForwardedImage extends StatelessWidget {
  const _ForwardedImage({required this.part});
  final ImagePart part;
  @override
  Widget build(BuildContext context) {
    final uri = part.uri;
    final remote = uri.startsWith('https://') || uri.startsWith('http://');
    final data = uri.startsWith('data:');
    final path = remote || data ? uri : SandboxPathResolver.resolveForIo(uri);
    final available =
        !part.unavailable &&
        path != null &&
        (remote || data || File(path).existsSync());
    Widget unavailable() => Tooltip(
      message: AppLocalizations.of(
        context,
      )!.chatMessageWidgetAttachmentUnavailable,
      child: Container(
        width: 160,
        height: 120,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Lucide.ImageOff),
      ),
    );
    if (!available) return unavailable();
    final ImageProvider provider;
    try {
      provider = remote
          ? NetworkImage(path)
          : data
          ? MemoryImage(UriData.parse(path).contentAsBytes())
          : FileImage(File(path));
    } on FormatException {
      return unavailable();
    }
    return IosCardPress(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerPage(images: [path], initialIndex: 0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image(
          image: SafeResizeImage.display(
            provider,
            width: (240 * MediaQuery.devicePixelRatioOf(context)).round(),
            height: (180 * MediaQuery.devicePixelRatioOf(context)).round(),
            allowUpscaling: false,
          ),
          width: 240,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => unavailable(),
        ),
      ),
    );
  }
}

class _ForwardedFile extends StatelessWidget {
  const _ForwardedFile({required this.part, this.openFile});
  final FilePart part;
  final Future<bool> Function(String path, String? mime)? openFile;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final remote =
        part.uri.startsWith('https://') || part.uri.startsWith('http://');
    final path = remote ? part.uri : SandboxPathResolver.resolveForIo(part.uri);
    final available =
        !part.unavailable &&
        path != null &&
        (remote || File(path).existsSync());
    return IosCardPress(
      padding: const EdgeInsets.all(12),
      onTap: !available
          ? null
          : () async {
              try {
                final success = openFile != null
                    ? await openFile!(path, part.mime)
                    : remote
                    ? await launchUrl(
                        Uri.parse(path),
                        mode: LaunchMode.externalApplication,
                      )
                    : (await OpenFilex.open(path, type: part.mime)).type ==
                          ResultType.done;
                if (!success && context.mounted) {
                  showAppSnackBar(
                    context,
                    message: l10n.chatMessageWidgetAttachmentUnavailable,
                    type: NotificationType.error,
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    message: l10n.chatMessageWidgetAttachmentUnavailable,
                    type: NotificationType.error,
                  );
                }
              }
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Lucide.File),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  part.name.split(RegExp(r'[/\\]')).last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!available)
                  Text(
                    l10n.chatMessageWidgetAttachmentUnavailable,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ForwardedMessagesDetails extends StatelessWidget {
  const ForwardedMessagesDetails({
    super.key,
    required this.record,
    this.openFile,
  });
  final ForwardedMessagesPart record;

  /// Operating-system boundary; omitted in the application.
  final Future<bool> Function(String path, String? mime)? openFile;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Lucide.ArrowLeft),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(AppLocalizations.of(context)!.forwardMessagesRecord),
    ),
    body: ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: record.messages.length,
      itemBuilder: (context, index) {
        final entry = record.messages[index];
        final local = entry.timestamp.toLocal();
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                child: Icon(
                  entry.role == 'user' ? Lucide.User : Lucide.Bot,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.author,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(local)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final part in entry.parts) ...[
                      if (part is TextPart)
                        SelectableText(part.text)
                      else if (part is ForwardedMessagesPart)
                        ForwardedMessagesCard(record: part)
                      else if (part is ImagePart)
                        _ForwardedImage(part: part)
                      else if (part is FilePart)
                        _ForwardedFile(part: part, openFile: openFile),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
