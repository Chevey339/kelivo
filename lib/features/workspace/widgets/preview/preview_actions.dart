import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

Future<void> copyFilePath(BuildContext context, File file) async {
  final l10n = AppLocalizations.of(context)!;
  await Clipboard.setData(ClipboardData(text: file.path));
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    message: l10n.workspacePreviewPathCopied,
    type: NotificationType.success,
  );
}

Future<void> sharePreviewFile(BuildContext context, File file) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        sharePositionOrigin: shareAnchorRect(context),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportFailed('$e'),
      type: NotificationType.error,
    );
  }
}

Future<void> openPreviewFileExternally(BuildContext context, File file) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final res = await OpenFilex.open(file.path);
    if (res.type != ResultType.done && context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCannotOpenFile(res.message),
        type: NotificationType.error,
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.chatMessageWidgetOpenFileError(e.toString()),
      type: NotificationType.error,
    );
  }
}

Future<void> revealPreviewFileInFileManager(
  BuildContext context,
  File file,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (kIsWeb) {
    showAppSnackBar(
      context,
      message: l10n.workspacePreviewRevealFailed,
      type: NotificationType.error,
    );
    return;
  }
  try {
    final hostPath = file.absolute.path;
    if (Platform.isMacOS) {
      final result = await Process.run('open', <String>['-R', hostPath]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'open',
          <String>['-R', hostPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    if (Platform.isLinux) {
      final dir = p.dirname(hostPath);
      final result = await Process.run('xdg-open', <String>[dir]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'xdg-open',
          <String>[dir],
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    if (Platform.isWindows) {
      final result = await Process.run('explorer', <String>[
        '/select,$hostPath',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'explorer',
          <String>['/select,$hostPath'],
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    throw UnsupportedError('Reveal is only supported on desktop');
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.workspacePreviewRevealFailed,
      type: NotificationType.error,
    );
  }
}

Future<void> openPreviewFileInBrowser(BuildContext context, File file) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final uri = Uri.file(file.absolute.path);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCannotOpenFile(file.path),
        type: NotificationType.error,
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.chatMessageWidgetOpenFileError(e.toString()),
      type: NotificationType.error,
    );
  }
}

String revealInFileManagerLabel(AppLocalizations l10n) {
  if (!kIsWeb && Platform.isMacOS) {
    return l10n.workspacePreviewRevealInFinder;
  }
  if (!kIsWeb && Platform.isWindows) {
    return l10n.workspacePreviewRevealInExplorer;
  }
  return l10n.workspacePreviewRevealInFileManager;
}

Rect shareAnchorRect(BuildContext context) {
  try {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
  } catch (_) {}
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}
