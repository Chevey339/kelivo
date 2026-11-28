import '../../../side_panel/desktop_side_panel_controller.dart';
import '../../../../utils/platform_utils.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:Kelivo/core/models/workspace_file_owner.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/preview/code_file_preview.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import 'binary_file_preview.dart';
import 'csv_file_preview.dart';
import 'html_file_preview.dart';
import 'image_file_preview.dart';
import 'markdown_file_preview.dart';
import 'file_preview_frame.dart';
import 'preview_file_type.dart';
import 'workspace_text_editing.dart';
import 'workspace_text_preview.dart';

export 'binary_file_preview.dart';
export 'csv_file_preview.dart';
export 'html_file_preview.dart';
export 'image_file_preview.dart';
export 'markdown_file_preview.dart';
export 'preview_actions.dart';
export 'file_preview_frame.dart';
export 'preview_file_type.dart'
    show
        FilePreviewKind,
        highlightLanguageFor,
        languageForExtension,
        languageForPath;

const int kFilePreviewSniffBytes = 8 * 1024;

const Set<String> _markdownExtensions = {'.md', '.markdown'};

const Set<String> _htmlExtensions = {'.html', '.htm', '.svg'};

const Set<String> _csvExtensions = {'.csv', '.tsv'};

bool isWorkspaceTextKind(FilePreviewKind kind) =>
    kind == FilePreviewKind.markdown || kind == FilePreviewKind.code;

bool isNewWorkspaceTextFile(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext.isEmpty ||
      _markdownExtensions.contains(ext) ||
      kPreviewCodeExtensions.contains(ext);
}

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
    if (length <= bytes.length) {
      utf8.decode(bytes);
    } else {
      // A UTF-8 sequence can continue beyond the sniff window. Validate the
      // sampled stream without treating the end of this chunk as end-of-file.
      utf8.decoder
          .startChunkedConversion(
            StringConversionSink.fromStringSink(StringBuffer()),
          )
          .add(bytes);
    }
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
  WorkspaceFileOwner? owner,
  String source = 'workspace',
  bool startEditing = false,
  bool readOnly = false,
}) async {
  final panel = DesktopSidePanelController.instance;
  if (PlatformUtils.isDesktopTarget && panel.isAvailable) {
    panel.openPreview(
      file.path,
      source: source,
      owner: readOnly ? null : owner,
      startEditing: startEditing,
    );
    return;
  }
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

  if (!readOnly && owner != null && isWorkspaceTextKind(resolvedKind)) {
    final preview = WorkspaceTextPreview(
      session: WorkspaceTextEditing(file, owner),
      surface: desktop
          ? WorkspacePreviewSurface.dialog
          : WorkspacePreviewSurface.page,
      markdown: resolvedKind == FilePreviewKind.markdown,
      startEditing: startEditing,
      title: resolvedTitle,
    );
    if (desktop) {
      await showAppDialog<void>(
        context,
        maxWidth: 960,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: preview,
        ),
      );
    } else {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => preview));
    }
    return;
  }

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

  Widget body = buildFilePreviewBody(
    kind: resolvedKind,
    file: file,
    autoLoad: autoLoad,
  );
  if (readOnly && isWorkspaceTextKind(resolvedKind)) {
    body = Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 2),
            child: Text(
              AppLocalizations.of(context)!.workspaceEditorReadOnly,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
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

Widget buildFilePreviewBody({
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
