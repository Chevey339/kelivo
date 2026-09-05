import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/utils/save_file_picker.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

HttpServer? _previewBrowserServer;
Timer? _previewBrowserServerTtl;

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

Future<void> exportPreviewFile(BuildContext context, File file) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final savePath = await saveHostFileWithPicker(
      file: file,
      dialogTitle: l10n.workspaceFilesExportItem,
    );
    if (savePath == null || !context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
      type: NotificationType.success,
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
    final uri = await _browserUriForPreviewFile(file);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
    if (!context.mounted) return;
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await openPreviewFileExternally(context, file);
      return;
    }
    if (context.mounted) {
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

/// iOS/Android cannot hand a sandboxed `file://` URL to Safari/Chrome.
/// Serve the file (and siblings) over loopback so the system browser can
/// load it.
Future<Uri> _browserUriForPreviewFile(File file) async {
  if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
    return Uri.file(file.absolute.path);
  }
  return startPreviewFileBrowserServer(file);
}

@visibleForTesting
Future<Uri> startPreviewFileBrowserServer(File file) async {
  await closePreviewFileBrowserServer();
  final root = file.parent.absolute.path;
  final name = p.basename(file.path);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  _previewBrowserServer = server;
  server.listen((request) async {
    try {
      var rel = Uri.decodeComponent(request.uri.path);
      if (rel == '/' || rel.isEmpty) {
        rel = '/$name';
      }
      final requested = p.normalize(p.join(root, rel.replaceFirst('/', '')));
      final allowed =
          p.isWithin(root, requested) ||
          p.equals(requested, p.join(root, name));
      if (!allowed) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final target = File(requested);
      if (!target.existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.parse(
        _mimeForPreviewPath(requested),
      );
      await request.response.addStream(target.openRead());
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  });
  _previewBrowserServerTtl = Timer(const Duration(minutes: 10), () {
    unawaited(closePreviewFileBrowserServer());
  });
  return Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: server.port,
    pathSegments: <String>[name],
  );
}

@visibleForTesting
Future<void> closePreviewFileBrowserServer() async {
  _previewBrowserServerTtl?.cancel();
  _previewBrowserServerTtl = null;
  final server = _previewBrowserServer;
  _previewBrowserServer = null;
  if (server != null) {
    await server.close(force: true);
  }
}

String _mimeForPreviewPath(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.html':
    case '.htm':
      return 'text/html; charset=utf-8';
    case '.css':
      return 'text/css; charset=utf-8';
    case '.js':
    case '.mjs':
      return 'text/javascript; charset=utf-8';
    case '.svg':
      return 'image/svg+xml';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.json':
      return 'application/json';
    default:
      return 'application/octet-stream';
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
