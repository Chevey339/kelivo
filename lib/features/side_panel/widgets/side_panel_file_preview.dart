import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import 'side_panel_file_toolbar.dart';
import '../../browser/widgets/browser_controls.dart';
import '../../workspace/widgets/preview/file_preview.dart';
import '../../workspace/widgets/preview/workspace_text_preview.dart';
import '../desktop_side_panel_controller.dart';
import 'side_panel_tab_bar.dart';

class SidePanelFilePreview extends StatefulWidget {
  const SidePanelFilePreview({
    super.key,
    required this.tab,
    required this.controller,
  });
  final PreviewTab tab;
  final DesktopSidePanelController controller;
  @override
  State<SidePanelFilePreview> createState() => _SidePanelFilePreviewState();
}

class _SidePanelFilePreviewState extends State<SidePanelFilePreview> {
  late Future<FilePreviewKind?> _kind = _read();
  Future<FilePreviewKind?> _read() async {
    final file = File(widget.tab.path);
    return await file.exists() ? classifyFilePreview(file) : null;
  }

  @override
  void didUpdateWidget(SidePanelFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) _kind = _read();
  }

  Future<void> _relocate() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.firstOrNull?.path;
    if (path != null && mounted) {
      widget.controller.relocatePreview(widget.tab.id, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final file = File(widget.tab.path);
    final source = switch (widget.tab.source) {
      'attachments' => l.workspaceFilesTabAttachments,
      'outputs' => l.workspaceFilesTabOutputs,
      _ => l.workspaceFilesTabWorkspace,
    };
    return FutureBuilder<FilePreviewKind?>(
      future: _kind,
      builder: (context, snapshot) {
        final kind = snapshot.data;
        final session = widget.tab.editing;
        if (session != null &&
            (session.editing || kind != null && isWorkspaceTextKind(kind))) {
          return WorkspaceTextPreview(
            key: ObjectKey(session),
            session: session,
            surface: WorkspacePreviewSurface.panel,
            markdown:
                kind == FilePreviewKind.markdown ||
                {
                  '.md',
                  '.markdown',
                }.contains(p.extension(file.path).toLowerCase()),
          );
        }
        return Column(
          children: [
            SidePanelFileToolbar(
              label: '$source › ${p.basename(file.path)}',
              path: file.path,
              actions: [
                SidePanelIconButton(
                  icon: LucideIcons.copy,
                  label: l.workspaceFilesCopyPath,
                  onTap: () => copyFilePath(context, file),
                ),
                SidePanelIconButton(
                  icon: LucideIcons.externalLink,
                  label: l.workspacePreviewOpenWith,
                  onTap: () => openPreviewFileExternally(context, file),
                ),
                SidePanelIconButton(
                  icon: LucideIcons.folderOpen,
                  label: revealInFileManagerLabel(l),
                  onTap: () => revealPreviewFileInFileManager(context, file),
                ),
              ],
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (kind == null || snapshot.hasError) {
                    return BrowserEmptyState(
                      icon: LucideIcons.fileQuestion,
                      title: l.sidePanelFileMissing,
                      subtitle: l.sidePanelFileMissingBody(widget.tab.path),
                      action: IosTileButton(
                        label: l.sidePanelRelocate,
                        icon: LucideIcons.folderOpen,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        onTap: _relocate,
                      ),
                    );
                  }
                  final body = buildFilePreviewBody(kind: kind, file: file);
                  if (isWorkspaceTextKind(kind) &&
                      (widget.tab.source == 'attachments' ||
                          widget.tab.source == 'outputs')) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                          child: Text(
                            l.workspaceEditorReadOnly,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        Expanded(child: body),
                      ],
                    );
                  }
                  return body;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
