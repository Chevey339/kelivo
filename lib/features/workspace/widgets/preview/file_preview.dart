import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/preview/code_file_preview.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import 'binary_file_preview.dart';
import 'csv_file_preview.dart';
import 'html_file_preview.dart';
import 'image_file_preview.dart';
import 'markdown_file_preview.dart';
import 'preview_actions.dart';
import 'preview_file_type.dart';

export 'binary_file_preview.dart';
export 'csv_file_preview.dart';
export 'html_file_preview.dart';
export 'image_file_preview.dart';
export 'markdown_file_preview.dart';
export 'preview_actions.dart';
export 'preview_file_type.dart'
    show highlightLanguageFor, languageForExtension, languageForPath;

const int kFilePreviewSniffBytes = 8 * 1024;

const Set<String> _markdownExtensions = {'.md', '.markdown'};

const Set<String> _htmlExtensions = {'.html', '.htm', '.svg'};

const Set<String> _csvExtensions = {'.csv', '.tsv'};

enum FilePreviewKind { image, markdown, html, csv, code, binary }

Future<FilePreviewKind> classifyFilePreview(File file) async {
  final ext = p.extension(file.path).toLowerCase();
  if (kPreviewImageExtensions.contains(ext)) return FilePreviewKind.image;
  if (_markdownExtensions.contains(ext)) return FilePreviewKind.markdown;
  if (_htmlExtensions.contains(ext)) return FilePreviewKind.html;
  if (_csvExtensions.contains(ext)) return FilePreviewKind.csv;
  if (kPreviewCodeExtensions.contains(ext)) return FilePreviewKind.code;
  if (await fileSniffsAsUtf8Text(file)) return FilePreviewKind.code;
  return FilePreviewKind.binary;
}

Future<bool> fileSniffsAsUtf8Text(File file) async {
  RandomAccessFile? raf;
  try {
    final length = await file.length();
    if (length == 0) return true;
    raf = await file.open();
    final n = length < kFilePreviewSniffBytes ? length : kFilePreviewSniffBytes;
    final bytes = await raf.read(n);
    if (bytes.contains(0)) return false;
    utf8.decode(bytes);
    return true;
  } catch (_) {
    return false;
  } finally {
    await raf?.close();
  }
}

bool get htmlPreviewSupported {
  if (kIsWeb) return false;
  if (Platform.isLinux) return false;
  return WebViewPlatform.instance != null;
}

Future<void> showFilePreview(
  BuildContext context,
  File file, {
  String? title,
  FilePreviewKind? kind,
  bool autoLoad = true,
}) async {
  if (!file.existsSync()) {
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: l10n.workspaceFileNotAvailable,
      type: NotificationType.info,
    );
    return;
  }

  final resolvedKind = kind ?? await classifyFilePreview(file);
  if (!context.mounted) return;

  final resolvedTitle = title ?? p.basename(file.path);
  final desktop = useDesktopWorkspaceLayout(context);

  if (resolvedKind == FilePreviewKind.image) {
    await _showImagePreview(
      context,
      file: file,
      title: resolvedTitle,
      desktop: desktop,
      autoLoad: autoLoad,
    );
    return;
  }

  final body = _previewBody(kind: resolvedKind, file: file, autoLoad: autoLoad);
  if (desktop) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    await showAppDialog<void>(
      context,
      maxWidth: 960,
      child: SizedBox(
        height: height,
        child: FilePreviewFrame(
          file: file,
          title: resolvedTitle,
          kind: resolvedKind,
          dialog: true,
          child: body,
        ),
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FilePreviewPage(
        file: file,
        title: resolvedTitle,
        kind: resolvedKind,
        child: body,
      ),
    ),
  );
}

Widget _previewBody({
  required FilePreviewKind kind,
  required File file,
  bool autoLoad = true,
}) {
  switch (kind) {
    case FilePreviewKind.image:
      return ImageFilePreview(file: file, autoLoad: autoLoad);
    case FilePreviewKind.markdown:
      return MarkdownFilePreview(file: file, autoLoad: autoLoad);
    case FilePreviewKind.html:
      if (htmlPreviewSupported) {
        return HtmlFilePreview(file: file, autoLoad: autoLoad);
      }
      return CodeFilePreview(file: file, autoLoad: autoLoad);
    case FilePreviewKind.csv:
      return CsvFilePreview(file: file, autoLoad: autoLoad);
    case FilePreviewKind.code:
      return CodeFilePreview(file: file, autoLoad: autoLoad);
    case FilePreviewKind.binary:
      return BinaryFilePreview(file: file);
  }
}

Future<void> _showImagePreview(
  BuildContext context, {
  required File file,
  required String title,
  required bool desktop,
  bool autoLoad = true,
}) async {
  if (desktop) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    await showAppDialog<void>(
      context,
      maxWidth: 960,
      child: SizedBox(
        height: height,
        child: FilePreviewFrame(
          file: file,
          title: title,
          kind: FilePreviewKind.image,
          dialog: true,
          child: ImageFilePreview(file: file, autoLoad: autoLoad),
        ),
      ),
    );
    return;
  }
  final page = ImageViewerPage(images: [file.path]);
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, anim, sec, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class FilePreviewPage extends StatelessWidget {
  const FilePreviewPage({
    super.key,
    required this.file,
    required this.title,
    required this.kind,
    required this.child,
  });

  final File file;
  final String title;
  final FilePreviewKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FilePreviewFrame(
      file: file,
      title: title,
      kind: kind,
      dialog: false,
      child: child,
    );
  }
}

class FilePreviewFrame extends StatelessWidget {
  const FilePreviewFrame({
    super.key,
    required this.file,
    required this.title,
    required this.kind,
    required this.dialog,
    required this.child,
  });

  final File file;
  final String title;
  final FilePreviewKind kind;
  final bool dialog;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final desktop = dialog || useDesktopWorkspaceLayout(context);
    final actions = _headerActions(context, desktop: desktop);
    if (dialog) {
      return Column(
        children: [
          AppDialogHeader(title: title, actions: actions),
          Expanded(child: child),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Tooltip(
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
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [...actions, const SizedBox(width: 12)],
      ),
      body: child,
    );
  }

  List<Widget> _headerActions(BuildContext context, {required bool desktop}) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final size = dialog ? 18.0 : 22.0;
    final minSize = dialog ? 36.0 : 44.0;

    Widget action({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: label,
        child: IosIconButton(
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
        label: l10n.workspacePreviewCopyPath,
        icon: Lucide.Copy,
        onTap: () => unawaited(copyFilePath(context, file)),
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
    if (desktop) {
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
          label: l10n.workspacePreviewOpenInBrowser,
          icon: Lucide.Globe,
          onTap: () => unawaited(openPreviewFileInBrowser(context, file)),
        ),
      );
    }
    return items;
  }
}
