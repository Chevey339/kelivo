import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'preview_actions.dart';
import 'preview_file_type.dart';

class FilePreviewFrame extends StatelessWidget {
  const FilePreviewFrame({
    super.key,
    required this.file,
    required this.title,
    required this.kind,
    required this.dialog,
    required this.child,
    this.actions,
    this.leading,
    this.centerTitle,
    this.modified = false,
  });

  static const Key exportActionKey = ValueKey<String>(
    'file-preview-header-export',
  );
  static const Key openInBrowserActionKey = ValueKey<String>(
    'file-preview-header-open-in-browser',
  );

  final File file;
  final String title;
  final FilePreviewKind kind;
  final bool dialog;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final bool modified;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = this.actions ?? _headerActions(context);
    final cs = Theme.of(context).colorScheme;
    final modifiedMark = Tooltip(
      message: l10n.workspaceEditorUnsaved,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      ),
    );
    if (dialog) {
      return Column(
        children: [
          AppDialogHeader(
            title: title,
            actions: [
              if (modified)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: modifiedMark,
                ),
              ...actions,
            ],
          ),
          Expanded(child: child),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            leading ??
            Tooltip(
              message: l10n.workspacePreviewBack,
              child: IosIconButton(
                icon: Lucide.ArrowLeft,
                semanticLabel: l10n.workspacePreviewBack,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
                minSize: 44,
                onTap: () {
                  Haptics.light();
                  Navigator.of(context).maybePop();
                },
              ),
            ),
        centerTitle: centerTitle,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: centerTitle == true
                    ? const TextStyle(fontSize: 17)
                    : null,
              ),
            ),
            if (modified)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 7),
                child: modifiedMark,
              ),
          ],
        ),
        actions: [...actions, const SizedBox(width: 12)],
      ),
      body: child,
    );
  }

  List<Widget> _headerActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    // 20 is the IosIconButton default every other page's app-bar actions use;
    // only the leading back arrow is 22.
    final size = dialog ? 18.0 : 20.0;
    final minSize = dialog ? 36.0 : 44.0;

    Widget action({
      Key? key,
      required String label,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: label,
        child: IosIconButton(
          key: key,
          icon: icon,
          semanticLabel: label,
          color: cs.onSurface,
          size: size,
          minSize: minSize,
          onTap: () {
            Haptics.light();
            onTap();
          },
        ),
      );
    }

    final items = <Widget>[
      action(
        key: FilePreviewFrame.exportActionKey,
        label: l10n.workspaceFilesExportItem,
        icon: Lucide.Download,
        onTap: () => unawaited(exportPreviewFile(context, file)),
      ),
      action(
        label: l10n.workspacePreviewShare,
        icon: Lucide.Share2,
        onTap: () => unawaited(sharePreviewFile(context, file)),
      ),
      action(
        label: l10n.workspacePreviewOpenWith,
        icon: Lucide.ExternalLink,
        onTap: () => unawaited(openPreviewFileExternally(context, file)),
      ),
    ];
    if (canRevealPreviewFileInFileManager) {
      items.add(
        action(
          label: revealInFileManagerLabel(l10n),
          icon: Lucide.FolderOpen,
          onTap: () => unawaited(revealPreviewFileInFileManager(context, file)),
        ),
      );
    }
    if (kind == FilePreviewKind.html) {
      items.add(
        action(
          key: FilePreviewFrame.openInBrowserActionKey,
          label: l10n.workspacePreviewOpenInBrowser,
          icon: Lucide.Globe,
          onTap: () => unawaited(openPreviewFileInBrowser(context, file)),
        ),
      );
    }
    return items;
  }
}
