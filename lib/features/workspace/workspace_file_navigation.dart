import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/models/workspace_binding.dart';
import '../../core/providers/external_mounts_provider.dart';
import '../../core/providers/workspace_provider.dart';
import '../../core/services/chat/chat_service.dart';
import '../../core/services/workspace/file_link_resolver.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../shared/widgets/snackbar.dart';
import '../settings/widgets/custom_theme_widgets.dart';
import 'widgets/files/file_browser.dart';
import 'widgets/files/file_browser_ops.dart';
import 'widgets/preview/file_preview.dart';
import 'workspace_layout.dart';
import 'workspace_navigation.dart';

Future<FileSystemEntity?> _resolveLinkedEntry(
  BuildContext context,
  KelivoLink link, {
  String? conversationId,
}) async {
  final chat = context.read<ChatService?>();
  final id = conversationId ?? chat?.currentConversationId;
  final conversation = id == null ? null : chat?.getConversation(id);
  if (conversation == null) return null;
  var resolver = context.read<FileLinkResolver?>();
  if (resolver == null) {
    final workspaces = context.read<WorkspaceProvider?>();
    if (workspaces == null) return null;
    resolver = FileLinkResolver(
      workspaces: workspaces,
      externalMounts: context.read<ExternalMountsProvider?>(),
    );
  }
  return resolver.resolveToHostEntry(
    link,
    conversationId: conversation.id,
    binding: WorkspaceBinding.fromExtras(conversation.extras),
  );
}

Future<File?> resolveWorkspaceLinkedFile(
  BuildContext context,
  String? link, {
  String? conversationId,
}) async {
  final parsed = link == null ? null : KelivoLink.tryParse(link);
  if (parsed == null || parsed.kind == KelivoLinkKind.terminal) return null;
  try {
    final entry = await _resolveLinkedEntry(
      context,
      parsed,
      conversationId: conversationId,
    );
    return entry is File ? entry : null;
  } catch (_) {
    return null;
  }
}

Future<void> openWorkspaceLinkedFile(
  BuildContext context,
  String? link, {
  String? conversationId,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final parsed = link == null ? null : KelivoLink.tryParse(link);
  if (parsed?.kind == KelivoLinkKind.terminal) {
    WorkspaceNavigation.openTerminal(context, command: parsed!.terminalCommand);
    return;
  }
  FileSystemEntity? entry;
  var error = l10n.workspaceFileNotAvailable;
  try {
    if (parsed != null) {
      entry = await _resolveLinkedEntry(
        context,
        parsed,
        conversationId: conversationId,
      );
    }
  } on FileLinkException catch (e) {
    error = switch (e.reason) {
      FileLinkFailure.missing => l10n.workspaceFileMissing,
      FileLinkFailure.mountUnavailable => l10n.workspaceExternalUnavailable,
    };
  } catch (_) {
    // Directory permissions may have changed since the tool ran.
  }
  if (!context.mounted) return;
  if (entry is File) {
    await showFilePreview(context, entry, title: title);
  } else if (entry is Directory) {
    await _showDirectory(
      context,
      entry,
      link: parsed!,
      conversationId: conversationId,
      title: title,
    );
  } else {
    showAppSnackBar(context, message: error, type: NotificationType.info);
  }
}

Future<void> _showDirectory(
  BuildContext context,
  Directory directory, {
  required KelivoLink link,
  String? conversationId,
  String? title,
}) {
  final currentId =
      conversationId ?? context.read<ChatService?>()?.currentConversationId;
  final guestPath = link.guestPath(
    mountRoot: link.mountId == null
        ? null
        : context
              .read<ExternalMountsProvider?>()
              ?.byId(link.mountId!)
              ?.guestPath,
  );
  final useGuestPaths =
      WorkspaceModelPaths.useGuestPaths &&
      (link.conversationId == null || link.conversationId == currentId);
  final name = title ?? p.basename(directory.path);
  final browser = FileBrowser(
    root: directory,
    rootLabel: name,
    readOnly: true,
    modelPathOf: (host) => useGuestPaths && guestPath != null
        ? p.posix.join(
            guestPath,
            p.relative(host, from: directory.path).replaceAll('\\', '/'),
          )
        : host,
  );
  if (useDesktopWorkspaceLayout(context)) {
    return showAppDialog<void>(
      context,
      maxWidth: 760,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            AppDialogHeader(title: name),
            Expanded(child: browser),
          ],
        ),
      ),
    );
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(name),
          leading: IosIconButton(
            icon: Lucide.ArrowLeft,
            semanticLabel: AppLocalizations.of(context)!.workspacePreviewBack,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        body: browser,
      ),
    ),
  );
}
