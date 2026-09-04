import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_page.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/utils/app_directories.dart';

/// Resolves mounts/cwd and pushes [TerminalPage].
///
/// Opens a PTY for [workspaceId] when that id is set; otherwise prefers the
/// conversation workspace binding. Reuses a live session for the same target
/// and appends [command] to its input line. Does not assign
/// [WorkspaceNavigation.openTerminal].
Future<void> openTerminal(
  BuildContext context, {
  String? conversationId,
  String? workspaceId,
  String? command,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final runtimeProvider = context.read<WorkspaceRuntimeProvider>();
  final workspaceProvider = context.read<WorkspaceProvider>();
  final chatService = context.read<ChatService>();
  final manager = context.read<TerminalSessionManager>();

  final runtime = runtimeProvider.runtime;
  RuntimeStatus? status;
  try {
    status = await runtimeProvider.refresh();
  } catch (_) {
    status = runtimeProvider.lastStatus;
  }
  if (runtime == null || status == null || !status.ready) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: status?.reason ?? l10n.terminalRuntimeUnavailable,
      type: NotificationType.error,
    );
    return;
  }

  final explicitWorkspaceId = workspaceId?.trim();
  final resolvedConversationId =
      explicitWorkspaceId != null && explicitWorkspaceId.isNotEmpty
      ? null
      : (conversationId ?? chatService.currentConversationId);
  final ctx = resolvedConversationId == null
      ? null
      : await WorkspaceToolsService.resolve(
          conversationId: resolvedConversationId,
          workspaceProvider: workspaceProvider,
          runtimeProvider: runtimeProvider,
          chatService: chatService,
        );

  late final List<Mount> mounts;
  late final String cwd;
  late final String title;
  late final String hostDir;
  late final String? boundWorkspaceId;
  late final String? boundConversationId;

  if (ctx != null && !ctx.skillsOnly) {
    mounts = ctx.paths.mounts;
    cwd = ctx.cwd;
    title = ctx.workspace.name.isNotEmpty
        ? ctx.workspace.name
        : p.basename(cwd);
    hostDir = ctx.paths.workspaceHostRoot;
    boundWorkspaceId = ctx.workspace.id;
    boundConversationId = ctx.conversationId;
  } else {
    final id = workspaceId;
    if (id == null || id.isEmpty) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.terminalBindWorkspaceFirst,
        type: NotificationType.info,
      );
      return;
    }
    try {
      await workspaceProvider.loaded;
    } catch (_) {}
    final workspace = workspaceProvider.byId(id);
    if (workspace == null) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.terminalBindWorkspaceFirst,
        type: NotificationType.info,
      );
      return;
    }
    late final String hostRoot;
    try {
      hostRoot = await workspaceProvider.hostRootFor(workspace);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
      return;
    }
    final sessionsDir = await AppDirectories.getSessionsDirectory();
    final scratch = Directory(p.join(sessionsDir.path, 'terminal-$id'));
    await scratch.create(recursive: true);
    final skillsDir = await AppDirectories.getSkillsDirectory();
    final paths = WorkspacePaths.sandboxed(
      workspaceHostRoot: hostRoot,
      sessionHostDir: scratch.path,
      skillsHostDir: skillsDir.path,
    );
    mounts = paths.mounts;
    cwd = paths.modelRoot;
    title = workspace.name.isNotEmpty ? workspace.name : p.basename(cwd);
    hostDir = hostRoot;
    boundWorkspaceId = workspace.id;
    boundConversationId = null;
  }

  if (!context.mounted) return;

  String? sessionId;
  if (runtime.supportsPty) {
    final existing = manager.findReusable(
      conversationId: boundConversationId,
      workspaceId: boundWorkspaceId,
      cwd: cwd,
    );
    if (existing != null) {
      if (command != null && command.isNotEmpty) {
        existing.appendInput(command);
      }
      sessionId = existing.id;
    } else {
      try {
        final session = await manager.open(
          runtime: runtime,
          mounts: mounts,
          cwd: cwd,
          title: title,
          initialCommand: command,
          hostDir: hostDir,
          conversationId: boundConversationId,
          workspaceId: boundWorkspaceId,
        );
        sessionId = session.id;
      } catch (error) {
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: error.toString(),
          type: NotificationType.error,
        );
        return;
      }
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TerminalPage(
        conversationId: boundConversationId,
        workspaceId: boundWorkspaceId,
        hostDir: hostDir,
        mounts: mounts,
        cwd: cwd,
        title: title,
        initialSessionId: sessionId,
      ),
    ),
  );
}
