import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:file_picker/file_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:markstream/markstream.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/desktop/html_preview_dialog.dart';
import 'package:Kelivo/features/chat/pages/html_preview_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/utils/clipboard_images.dart';

Widget markdownActionButton(BuildContext context, MarkstreamAction action) {
  if (action.kind == MarkstreamActionKind.showMore) {
    return TextButton(
      onPressed: () => unawaited(Future<void>.sync(action.onInvoke)),
      child: Text(action.label),
    );
  }
  return markdownIconAction(
    context,
    chrome: action.chrome,
    icon: switch (action.kind) {
      MarkstreamActionKind.expand => Lucide.ChevronDown,
      MarkstreamActionKind.collapse => Lucide.ChevronUp,
      MarkstreamActionKind.copyCsv => Lucide.FileSpreadsheet,
      _ => Lucide.Copy,
    },
    label: action.label,
    invoke: () async {
      await Future<void>.sync(action.onInvoke);
      if (!context.mounted) return;
      if (action.kind == MarkstreamActionKind.copyCode ||
          action.kind == MarkstreamActionKind.copyMarkdown ||
          action.kind == MarkstreamActionKind.copyCsv) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: action.kind == MarkstreamActionKind.copyMarkdown
              ? l10n.markdownTableCopiedMarkdownSnackbar
              : l10n.chatMessageWidgetCopiedToClipboard,
          type: NotificationType.success,
        );
      }
    },
  );
}

Widget markdownIconAction(
  BuildContext context, {
  required MarkstreamChromeTheme chrome,
  required IconData icon,
  required String label,
  required FutureOr<void> Function() invoke,
}) => IosIconButton(
  icon: icon,
  tooltip: label,
  semanticLabel: label,
  size: chrome.actionIconSize,
  minSize: chrome.actionSize,
  borderRadius: chrome.actionRadius,
  padding: const EdgeInsets.all(6.5),
  color: chrome.actionColor,
  onTap: () => unawaited(Future<void>.sync(invoke)),
);

List<Widget> markdownCodeActions(
  BuildContext context,
  CodeActionContext action,
) {
  final l10n = AppLocalizations.of(context)!;
  final language = action.code.info
      .trim()
      .split(RegExp(r'\s+'))
      .first
      .toLowerCase();
  return [
    markdownIconAction(
      context,
      chrome: action.theme.chrome,
      icon: Lucide.Download,
      label: l10n.codeBlockSaveAsButton,
      invoke: () => _save(
        context,
        utf8.encode(action.code.code),
        codeFileExtension(language),
        l10n.codeBlockDefaultFileNameStem,
      ),
    ),
    if (isHtmlLanguage(language))
      markdownIconAction(
        context,
        chrome: action.theme.chrome,
        icon: Lucide.Eye,
        label: l10n.codeBlockPreviewButton,
        invoke: () => previewMarkdownHtml(context, action.code.code),
      ),
  ];
}

List<Widget> markdownTableActions(
  BuildContext context,
  TableActionContext action,
) {
  final l10n = AppLocalizations.of(context)!;
  final desktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
  return [
    markdownIconAction(
      context,
      chrome: action.theme.chrome,
      icon: Lucide.Download,
      label: l10n.markdownTableExportCsvTooltip,
      invoke: () => _save(
        context,
        utf8.encode(tableToCsv(action.table)),
        '.csv',
        l10n.markdownTableDefaultFileNameStem,
      ),
    ),
    markdownIconAction(
      context,
      chrome: action.theme.chrome,
      icon: Lucide.ImageDown,
      label: desktop
          ? l10n.messageExportSheetExportImage
          : l10n.imageViewerPageSaveButton,
      invoke: () =>
          _tableImage(context, action, copy: false, gallery: !desktop),
    ),
    markdownIconAction(
      context,
      chrome: action.theme.chrome,
      icon: Lucide.Clipboard,
      label: l10n.markdownCopyImageAction,
      invoke: () => _tableImage(context, action, copy: true, gallery: false),
    ),
  ];
}

Widget markdownMobileTableToolbar(
  BuildContext context,
  TableActionContext action,
) {
  final l10n = AppLocalizations.of(context)!;
  final chrome = action.theme.chrome;
  Future<void> copy({bool csv = false}) async {
    await Clipboard.setData(
      ClipboardData(
        text: csv ? tableToCsv(action.table) : toMarkdown(action.table),
      ),
    );
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: csv
            ? l10n.chatMessageWidgetCopiedToClipboard
            : l10n.markdownTableCopiedMarkdownSnackbar,
        type: NotificationType.success,
      );
    }
  }

  Widget button(
    IconData icon,
    String label,
    Future<void> Function() tap, {
    Future<void> Function()? longPress,
  }) => IosIconButton(
    icon: icon,
    tooltip: label,
    semanticLabel: label,
    size: chrome.actionIconSize,
    minSize: chrome.actionSize,
    borderRadius: chrome.actionRadius,
    padding: const EdgeInsets.all(6.5),
    color: chrome.actionColor,
    onTap: () => unawaited(tap()),
    onLongPress: longPress == null ? null : () => unawaited(longPress()),
  );
  return Container(
    key: const ValueKey('markdown-mobile-table-toolbar'),
    height: chrome.height,
    padding: chrome.padding,
    decoration: BoxDecoration(
      color: chrome.background,
      border: Border(
        bottom: BorderSide(
          color: chrome.divider,
          width: MarkstreamTheme.stroke,
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l10n.markdownTableLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: chrome.label,
          ),
        ),
        button(
          Lucide.Copy,
          l10n.markdownCopyMarkdownAction,
          copy,
          longPress: () =>
              _tableImage(context, action, copy: true, gallery: false),
        ),
        button(
          Lucide.ImageDown,
          l10n.imageViewerPageSaveButton,
          () => _tableImage(context, action, copy: false, gallery: true),
          longPress: () =>
              _tableImage(context, action, copy: false, gallery: false),
        ),
        button(
          Lucide.Download,
          l10n.markdownTableExportCsvTooltip,
          () => _save(
            context,
            utf8.encode(tableToCsv(action.table)),
            '.csv',
            l10n.markdownTableDefaultFileNameStem,
          ),
          longPress: () => copy(csv: true),
        ),
      ],
    ),
  );
}

String _stamp() =>
    DateTime.now().toLocal().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
Future<void> _save(
  BuildContext context,
  Uint8List bytes,
  String extension,
  String stem,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.backupPageExportToFile,
      fileName: '${stem}_${_stamp()}$extension',
      type: FileType.custom,
      allowedExtensions: [extension.substring(1)],
      bytes: desktop ? null : bytes,
    );
    if (path == null) return;
    if (desktop) {
      await File(path).parent.create(recursive: true);
      await File(path).writeAsBytes(bytes, flush: true);
    }
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportedAs(p.basename(path)),
        type: NotificationType.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$error'),
        type: NotificationType.error,
      );
    }
  }
}

Future<void> _tableImage(
  BuildContext context,
  TableActionContext action, {
  required bool copy,
  required bool gallery,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final bytes = await action.capturePng(3);
    if (!context.mounted) return;
    if (!copy && !gallery) {
      await _save(
        context,
        bytes,
        '.png',
        l10n.markdownTableDefaultFileNameStem,
      );
      return;
    }
    var ok = false;
    if (gallery) {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'kelivo-table-${_stamp()}',
      );
      if (result is Map) {
        ok =
            result['isSuccess'] == true ||
            result['isSuccess'] == 1 ||
            (result['filePath'] is String &&
                (result['filePath'] as String).isNotEmpty);
      }
    } else {
      try {
        final clipboard = SystemClipboard.instance;
        if (clipboard != null) {
          final item = DataWriterItem(suggestedName: 'kelivo-table.png')
            ..add(Formats.png(bytes));
          await clipboard.write([item]);
          ok = true;
        }
      } catch (_) {
        /* The platform image bridge also supports older desktops. */
      }
      if (!ok) {
        final file = File(
          p.join(Directory.systemTemp.path, 'kelivo-table-${_stamp()}.png'),
        );
        await file.writeAsBytes(bytes, flush: true);
        ok = await ClipboardImages.setImagePath(file.path);
      }
    }
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: ok
            ? (copy
                  ? l10n.chatMessageWidgetCopiedToClipboard
                  : l10n.imagePreviewSheetSaveSuccess)
            : l10n.messageExportSheetExportFailed('image'),
        type: ok ? NotificationType.success : NotificationType.error,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$error'),
        type: NotificationType.error,
      );
    }
  }
}

void previewMarkdownHtml(BuildContext context, String source) {
  if (Platform.isAndroid || Platform.isIOS) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => HtmlPreviewPage(html: source)),
    );
  } else if (Platform.isLinux) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.htmlPreviewNotSupportedOnLinux,
      type: NotificationType.warning,
    );
  } else {
    showHtmlPreviewDesktopDialog(context, html: source);
  }
}

bool isHtmlLanguage(String language) =>
    const {'html', 'htm', 'rawhtml', 'raw_html'}.contains(language);
String codeFileExtension(String? language) {
  switch ((language ?? '').trim().toLowerCase()) {
    case 'kotlin':
    case 'kt':
      return '.kt';
    case 'java':
      return '.java';
    case 'python':
    case 'py':
      return '.py';
    case 'javascript':
    case 'js':
      return '.js';
    case 'typescript':
    case 'ts':
      return '.ts';
    case 'dart':
      return '.dart';
    case 'cpp':
    case 'c++':
      return '.cpp';
    case 'c':
      return '.c';
    case 'csharp':
    case 'cs':
    case 'c#':
      return '.cs';
    case 'go':
    case 'golang':
      return '.go';
    case 'rust':
    case 'rs':
      return '.rs';
    case 'swift':
      return '.swift';
    case 'html':
    case 'htm':
    case 'rawhtml':
    case 'raw_html':
      return '.html';
    case 'css':
      return '.css';
    case 'xml':
      return '.xml';
    case 'json':
      return '.json';
    case 'yaml':
    case 'yml':
      return '.yml';
    case 'markdown':
    case 'md':
      return '.md';
    case 'sql':
      return '.sql';
    case 'shell':
    case 'bash':
    case 'sh':
    case 'zsh':
      return '.sh';
    case 'svg':
      return '.svg';
    default:
      return '.txt';
  }
}
