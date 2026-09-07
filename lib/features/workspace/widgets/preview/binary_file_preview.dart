import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'preview_actions.dart';
import 'preview_file_type.dart';

class BinaryFilePreview extends StatelessWidget {
  const BinaryFilePreview({super.key, required this.file});

  static const Key cardKey = ValueKey<String>('file-preview-binary');
  static const Key typeIconKey = ValueKey<String>('file-preview-binary-type');
  static const Key openWithKey = ValueKey<String>('file-preview-open-with');
  static const Key shareKey = ValueKey<String>('file-preview-share');
  static const Key exportKey = ValueKey<String>('file-preview-export');
  static const Key revealKey = ValueKey<String>('file-preview-reveal');

  static const double desktopCardMaxWidth = 440;

  final File file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = useDesktopWorkspaceLayout(context);
    final stat = file.statSync();
    final modified = stat.modified.toLocal();
    final loc = MaterialLocalizations.of(context);
    final modifiedLabel =
        '${loc.formatMediumDate(modified)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(modified))}';
    final visual = previewFileTypeStyle(file.path);
    final name = p.basename(file.path);

    return Center(
      key: cardKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktop ? desktopCardMaxWidth : double.infinity,
          ),
          child: SectionCard(
            variant: SectionCardVariant.emphasized,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  visual.icon,
                  key: typeIconKey,
                  size: 48,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatBytes(stat.size)} · $modifiedLabel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                IosCardPress(
                  borderRadius: BorderRadius.circular(10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  onTap: () => unawaited(copyFilePath(context, file)),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      file.path,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PreviewActionPair(
                  primary: IosTileButton(
                    key: openWithKey,
                    icon: Lucide.ExternalLink,
                    label: l10n.workspacePreviewOpenWith,
                    expand: true,
                    onTap: () =>
                        unawaited(openPreviewFileExternally(context, file)),
                  ),
                  secondary: IosTileButton(
                    key: shareKey,
                    icon: Lucide.Share2,
                    label: l10n.workspacePreviewShare,
                    expand: true,
                    onTap: () => unawaited(sharePreviewFile(context, file)),
                  ),
                ),
                const SizedBox(height: 8),
                _PreviewActionPair(
                  primary: IosTileButton(
                    key: exportKey,
                    icon: Lucide.Download,
                    label: l10n.workspaceFilesExportItem,
                    expand: true,
                    onTap: () => unawaited(exportPreviewFile(context, file)),
                  ),
                  secondary: desktop
                      ? IosTileButton(
                          key: revealKey,
                          icon: Lucide.FolderOpen,
                          label: revealInFileManagerLabel(l10n),
                          expand: true,
                          onTap: () => unawaited(
                            revealPreviewFileInFileManager(context, file),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewActionPair extends StatelessWidget {
  const _PreviewActionPair({required this.primary, this.secondary});

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final second = secondary;
    if (second == null) {
      return SizedBox(width: double.infinity, child: primary);
    }
    if (!useDesktopWorkspaceLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 8), second],
      );
    }
    return Row(
      children: [
        Expanded(child: primary),
        const SizedBox(width: 8),
        Expanded(child: second),
      ],
    );
  }
}
