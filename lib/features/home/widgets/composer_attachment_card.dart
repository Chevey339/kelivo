import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/chat_input_data.dart';
import '../../../core/services/incoming_share_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format_bytes.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

/// Metadata only: never read an attachment's contents to draw its preview.
class ComposerAttachmentCard extends StatefulWidget {
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 88 +
        (scaler.scale(11) - 11).clamp(0, 100) * 2.4 +
        (scaler.scale(9) - 9).clamp(0, 100);
  }

  const ComposerAttachmentCard({
    super.key,
    required this.file,
    required this.onRemove,
    this.removeKey,
  });
  final DocumentAttachment file;
  final VoidCallback onRemove;
  final Key? removeKey;

  @override
  State<ComposerAttachmentCard> createState() => _ComposerAttachmentCardState();
}

class _ComposerAttachmentCardState extends State<ComposerAttachmentCard> {
  late Future<int?> _size;
  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void didUpdateWidget(ComposerAttachmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _loadSize();
  }

  void _loadSize() {
    _size = File(
      widget.file.path,
    ).length().then<int?>((value) => value, onError: (_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final file = widget.file;
    final extension = p
        .extension(file.fileName)
        .replaceFirst('.', '')
        .toUpperCase();
    final icon = file.mime.startsWith('audio/')
        ? Lucide.FileAudio
        : file.mime.startsWith('video/')
        ? Lucide.FileVideo
        : ['ZIP', 'APK', 'TAR', 'GZ', '7Z', 'RAR'].contains(extension)
        ? Lucide.FileArchive
        : [
            'JSON',
            'DART',
            'JS',
            'TS',
            'PY',
            'HTML',
            'CSS',
            'SH',
          ].contains(extension)
        ? Lucide.FileCode
        : Lucide.FileText;
    return Tooltip(
      message: file.fileName,
      child: Container(
        width: 96,
        height: ComposerAttachmentCard.heightFor(context),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: cs.primary),
                  const SizedBox(height: 5),
                  Text(
                    file.fileName,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  FutureBuilder<int?>(
                    future: _size,
                    builder: (context, snapshot) => Text(
                      snapshot.data == null
                          ? extension
                          : formatBytes(snapshot.data!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IosIconButton(
                key: widget.removeKey,
                icon: Lucide.X,
                size: 12,
                padding: const EdgeInsets.all(7),
                tooltip: AppLocalizations.of(
                  context,
                )!.chatInputBarRemoveAttachment,
                color: cs.onSurfaceVariant,
                onTap: widget.onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComposerImportProgress extends StatelessWidget {
  const ComposerImportProgress({
    super.key,
    required this.progress,
    required this.onCancel,
  });
  final ShareImportProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final detail =
        '${progress.index}/${progress.count} · ${formatBytes(progress.bytes)}${progress.total == null ? '' : ' / ${formatBytes(progress.total!)}'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      child: Row(
        children: [
          Icon(Lucide.Import, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.incomingShareImporting} · ${progress.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: cs.primary.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IosIconButton(
            icon: Lucide.X,
            size: 16,
            padding: const EdgeInsets.all(12),
            tooltip: l10n.homePageCancel,
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}
