import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../theme/surface_ladder.dart';
import '../../browser/widgets/browser_controls.dart';
import '../../workspace/widgets/preview/file_preview.dart';
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
    if (oldWidget.tab.path != widget.tab.path) _kind = _read();
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
    final cs = Theme.of(context).colorScheme;
    final file = File(widget.tab.path);
    final source = switch (widget.tab.source) {
      'attachments' => l.workspaceFilesTabAttachments,
      'outputs' => l.workspaceFilesTabOutputs,
      _ => l.workspaceFilesTabWorkspace,
    };
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: .5,
                color: SurfaceLadder.fromScheme(cs).hairline,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: file.path,
                  child: Text(
                    '$source › ${p.basename(file.path)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
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
        ),
        Expanded(
          child: FutureBuilder<FilePreviewKind?>(
            future: _kind,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final kind = snapshot.data;
              if (kind == null || snapshot.hasError) {
                return BrowserEmptyState(
                  icon: LucideIcons.fileQuestion,
                  title: l.sidePanelFileMissing,
                  subtitle: l.sidePanelFileMissingBody(widget.tab.path),
                  action: IosTileButton(
                    label: l.sidePanelRelocate,
                    icon: LucideIcons.folderOpen,
                    backgroundColor: cs.primary,
                    onTap: _relocate,
                  ),
                );
              }
              return buildFilePreviewBody(kind: kind, file: file);
            },
          ),
        ),
      ],
    );
  }
}
