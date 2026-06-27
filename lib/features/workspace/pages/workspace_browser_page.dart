import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/services/workspace/workspace_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/platform_utils.dart';

/// Browser page for a conversation workspace.
///
/// Lists files and directories under the workspace root recursively with
/// expand/collapse support. Tapping a file opens [WorkspaceFilePreviewPage].
/// Directories are loaded lazily via [WorkspaceService.listFiles] and cached
/// in the page state.
class WorkspaceBrowserPage extends StatefulWidget {
  const WorkspaceBrowserPage({
    super.key,
    required this.conversationId,
    required this.conversationTitle,
  });

  final String conversationId;
  final String conversationTitle;

  @override
  State<WorkspaceBrowserPage> createState() => _WorkspaceBrowserPageState();
}

class _WorkspaceBrowserPageState extends State<WorkspaceBrowserPage> {
  // Cache of directory listings: key is subPath (or '' for root).
  final Map<String, Future<List<WorkspaceEntry>>> _dirFutures = {};
  // Set of expanded directory relative paths.
  final Set<String> _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _ensureLoaded('');
  }

  Future<List<WorkspaceEntry>> _ensureLoaded(String subPath) {
    final key = subPath;
    return _dirFutures.putIfAbsent(
      key,
      () => WorkspaceService.listFiles(
        widget.conversationId,
        subPath.isEmpty ? null : subPath,
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dirFutures.clear();
      _expanded.clear();
      _ensureLoaded('');
    });
  }

  Future<void> _confirmCloseWorkspace() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.workspaceDisableConfirmTitle),
        content: Text(l10n.workspaceDisableConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.workspaceDisableConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.workspaceDisableConfirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await WorkspaceService.deleteWorkspace(widget.conversationId);
      if (!mounted) return;
      await context.read<ChatService>().setWorkspaceEnabled(
            widget.conversationId,
            false,
          );
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '$e',
        type: NotificationType.error,
      );
    }
  }

  void _toggleDir(String relativePath) {
    setState(() {
      if (_expanded.contains(relativePath)) {
        _expanded.remove(relativePath);
      } else {
        _expanded.add(relativePath);
        _ensureLoaded(relativePath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final titleSuffix = l10n.workspaceBrowserTitleSuffix;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IosIconButton(
          icon: Lucide.ChevronLeft,
          size: 22,
          minSize: 44,
          semanticLabel: l10n.workspaceBrowserBackTooltip,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          '${widget.conversationTitle}$titleSuffix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: AppFontWeights.medium),
        ),
        actions: [
          IosIconButton(
            icon: Lucide.FolderX,
            size: 20,
            minSize: 44,
            semanticLabel: l10n.workspaceDisableTitle,
            onTap: _confirmCloseWorkspace,
          ),
          IosIconButton(
            icon: Lucide.RefreshCw,
            size: 20,
            minSize: 44,
            semanticLabel: l10n.workspaceBrowserRefreshTooltip,
            onTap: _refresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<WorkspaceEntry>>(
        future: _dirFutures[''],
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Lucide.FileQuestion,
              message: l10n.workspaceBrowserLoadFailed('${snapshot.error}'),
            );
          }
          final entries = snapshot.data ?? const <WorkspaceEntry>[];
          if (entries.isEmpty) {
            return _CenteredMessage(
              icon: Lucide.FolderOpen,
              message: l10n.workspaceBrowserEmpty,
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: entries
                .map((e) => _buildEntryTile(e, 0))
                .expand((w) => [w, const SizedBox.shrink()])
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildEntryTile(WorkspaceEntry entry, int depth) {
    final indent = 12.0 + depth * 16.0;
    final isExpanded = _expanded.contains(entry.relativePath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosCardPress(
          baseColor: Colors.transparent,
          pressedBlendStrength: 0.10,
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          onTap: () {
            if (entry.isDir) {
              _toggleDir(entry.relativePath);
            } else {
              _openFilePreview(entry);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: indent,
              right: 12,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                Icon(
                  entry.isDir
                      ? (isExpanded ? Lucide.FolderOpen : Lucide.Folder)
                      : Lucide.FileText,
                  size: 18,
                  color: entry.isDir
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                      if (!entry.isDir)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            _formatBytes(entry.size),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (entry.isDir)
                  Icon(
                    isExpanded ? Lucide.ChevronDown : Lucide.ChevronRight,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
              ],
            ),
          ),
        ),
        if (entry.isDir && isExpanded)
          FutureBuilder<List<WorkspaceEntry>>(
            future: _dirFutures[entry.relativePath],
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final children = snapshot.data ?? const <WorkspaceEntry>[];
              if (children.isEmpty) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: indent + 28,
                    top: 4,
                    bottom: 4,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.workspaceBrowserEmptyFolder,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children
                    .map((e) => _buildEntryTile(e, depth + 1))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Future<void> _openFilePreview(WorkspaceEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final absolutePath = await WorkspaceService.resolveSafePath(
      widget.conversationId,
      entry.relativePath,
    );
    if (!mounted) return;
    if (absolutePath == null) {
      showAppSnackBar(
        context,
        message: l10n.workspaceFilePreviewInvalidPath,
        type: NotificationType.error,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceFilePreviewPage(
          filePath: absolutePath,
          fileName: entry.name,
          fileSize: entry.size,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  int i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return i == 0
      ? '${size.toInt()} ${units[i]}'
      : '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${units[i]}';
}

/// File preview page for a single workspace file.
///
/// Renders text/markdown via [GptMarkdown], images via [Image.file], and
/// shows a placeholder for binary files. Provides a download / share action
/// in the AppBar.
class WorkspaceFilePreviewPage extends StatefulWidget {
  const WorkspaceFilePreviewPage({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  });

  final String filePath;
  final String fileName;
  final int fileSize;

  @override
  State<WorkspaceFilePreviewPage> createState() =>
      _WorkspaceFilePreviewPageState();
}

class _WorkspaceFilePreviewPageState extends State<WorkspaceFilePreviewPage> {
  bool _downloading = false;

  static const Set<String> _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };

  static const Set<String> _markdownExtensions = {'.md', '.markdown'};

  static const Set<String> _textExtensions = {
    '.txt',
    '.json',
    '.dart',
    '.js',
    '.ts',
    '.jsx',
    '.tsx',
    '.py',
    '.yaml',
    '.yml',
    '.xml',
    '.html',
    '.htm',
    '.css',
    '.scss',
    '.java',
    '.kt',
    '.swift',
    '.go',
    '.rs',
    '.c',
    '.cpp',
    '.h',
    '.hpp',
    '.cs',
    '.rb',
    '.php',
    '.sh',
    '.bash',
    '.zsh',
    '.fish',
    '.ps1',
    '.toml',
    '.ini',
    '.cfg',
    '.conf',
    '.log',
    '.csv',
    '.tsv',
    '.svg',
    '.gradle',
    '.properties',
    '.sql',
    '.vue',
    '.svelte',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = p.extension(widget.fileName).toLowerCase();
    final isImage = _imageExtensions.contains(ext);
    final isMarkdown = _markdownExtensions.contains(ext);
    final isText = _textExtensions.contains(ext) || isMarkdown;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IosIconButton(
          icon: Lucide.ChevronLeft,
          size: 22,
          minSize: 44,
          semanticLabel: l10n.workspaceFilePreviewBackTooltip,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: AppFontWeights.medium),
        ),
        actions: [
          IosIconButton(
            icon: Lucide.Download,
            size: 20,
            minSize: 44,
            semanticLabel: l10n.workspaceFilePreviewDownloadTooltip,
            onTap: _downloading ? null : _downloadOrShare,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(isImage, isMarkdown, isText, ext),
      ),
    );
  }

  Widget _buildBody(bool isImage, bool isMarkdown, bool isText, String ext) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final file = File(widget.filePath);
    if (isImage) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.file(
            file,
            errorBuilder: (_, __, ___) => _CenteredMessage(
              icon: Lucide.FileQuestion,
              message: l10n.workspaceFilePreviewImageLoadFailed,
            ),
          ),
        ),
      );
    }
    if (!isText) {
      return _CenteredMessage(
        icon: Lucide.FileQuestion,
        message: l10n.workspaceFilePreviewUnsupported(
          ext,
          _formatBytes(widget.fileSize),
        ),
      );
    }
    return FutureBuilder<String>(
      future: file.readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _CenteredMessage(
            icon: Lucide.FileQuestion,
            message: l10n.workspaceFilePreviewReadFailed('${snapshot.error}'),
          );
        }
        final content = snapshot.data ?? '';
        if (content.isEmpty) {
          return _CenteredMessage(
            icon: Lucide.FileText,
            message: l10n.workspaceFilePreviewEmpty,
          );
        }
        if (isMarkdown) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GptMarkdown(content),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
              color: cs.onSurface,
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadOrShare() async {
    final l10n = AppLocalizations.of(context)!;
    if (_downloading) return;
    setState(() => _downloading = true);
    final l10nMessage = NotificationType.success;
    String? errorMessage;
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        errorMessage = l10n.workspaceFilePreviewFileNotFound;
      } else if (PlatformUtils.isDesktop) {
        final ext = p.extension(widget.fileName);
        final allowed = ext.isEmpty
            ? null
            : <String>[ext.replaceFirst('.', '').toLowerCase()];
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.workspaceFilePreviewSaveDialogTitle,
          fileName: widget.fileName,
          type: allowed == null ? FileType.any : FileType.custom,
          allowedExtensions: allowed,
        );
        if (savePath == null) {
          // user cancelled; not an error
          return;
        }
        try {
          await File(savePath).parent.create(recursive: true);
          await File(savePath).writeAsBytes(await file.readAsBytes());
        } catch (e) {
          errorMessage = l10n.workspaceFilePreviewSaveFailed('$e');
        }
      } else {
        // Mobile: share via system share sheet
        try {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(widget.filePath)]),
          );
        } catch (e) {
          errorMessage = l10n.workspaceFilePreviewShareFailed('$e');
        }
      }
    } catch (e) {
      errorMessage = '$e';
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
    if (!mounted) return;
    if (errorMessage != null) {
      showAppSnackBar(
        context,
        message: errorMessage,
        type: NotificationType.error,
      );
    } else if (PlatformUtils.isDesktop) {
      showAppSnackBar(
        context,
        message: l10n.workspaceFilePreviewSaveSuccess,
        type: l10nMessage,
      );
    }
  }
}
