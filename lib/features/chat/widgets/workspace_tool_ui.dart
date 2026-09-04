import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/preview/file_preview.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import 'chat_surface.dart';

/// Snapshot of a tool call used by workspace cards and the detail sheet.
class WorkspaceToolPart {
  const WorkspaceToolPart({
    required this.id,
    required this.toolName,
    this.arguments = const <String, dynamic>{},
    this.content,
    this.metadata,
    this.loading = false,
  });

  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? content;
  final Map<String, dynamic>? metadata;
  final bool loading;
}

bool isWorkspaceToolName(String name) =>
    WorkspaceToolsService.toolNames.contains(name);

/// True when this part should use workspace tool chrome. Routed by tool
/// name in every state (pending, running, done, error, and after reload)
/// so a missing `metadata['workspace']` wrapper cannot fall back to
/// "调用工具: …".
bool shouldUseWorkspaceToolUi(WorkspaceToolPart part) =>
    isWorkspaceToolName(part.toolName);

WorkspaceToolMetadata? workspaceMetadataFrom(Map<String, dynamic>? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  return WorkspaceToolMetadata.fromJson(metadata);
}

const Set<String> kWorkspaceImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
};

const Set<String> _kCodeExtensions = {
  '.dart',
  '.js',
  '.ts',
  '.tsx',
  '.jsx',
  '.py',
  '.rs',
  '.go',
  '.java',
  '.kt',
  '.c',
  '.h',
  '.cpp',
  '.cc',
  '.cs',
  '.swift',
  '.rb',
  '.php',
  '.json',
  '.yaml',
  '.yml',
  '.xml',
  '.html',
  '.css',
  '.sh',
  '.sql',
  '.toml',
};

const Set<String> _kTextExtensions = {
  '.md',
  '.txt',
  '.rst',
  '.rtf',
  '.log',
  '.markdown',
};

const Set<String> _kSpreadsheetExtensions = {'.csv', '.tsv', '.xls', '.xlsx'};

bool isWorkspaceImagePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  final noQuery = trimmed.split('?').first;
  return kWorkspaceImageExtensions.contains(p.extension(noQuery).toLowerCase());
}

IconData workspaceFileTypeIcon(String path) {
  final ext = p.extension(path.split('?').first).toLowerCase();
  if (kWorkspaceImageExtensions.contains(ext) ||
      ext == '.svg' ||
      ext == '.bmp' ||
      ext == '.heic') {
    return Lucide.FileImage;
  }
  if (_kCodeExtensions.contains(ext)) return Lucide.FileCode;
  if (_kTextExtensions.contains(ext)) return Lucide.FileText;
  if (_kSpreadsheetExtensions.contains(ext)) return Lucide.FileSpreadsheet;
  return Lucide.File;
}

bool workspaceReadWasImage({
  required WorkspaceToolPart part,
  WorkspaceToolMetadata? meta,
}) {
  final raw = part.metadata;
  if (raw != null && raw[kMcpResultMetadataKey] != null) return true;
  final content = part.content ?? '';
  if (content.contains('![](') || content.contains('![')) return true;
  final path = meta?.path ?? (part.arguments['path'] ?? '').toString();
  return isWorkspaceImagePath(path);
}

String workspaceToolTitle(AppLocalizations l10n, String toolName) {
  return switch (toolName) {
    'shell' => l10n.workspaceToolTitleShell,
    'read_file' => l10n.workspaceToolTitleReadFile,
    'write_file' => l10n.workspaceToolTitleWriteFile,
    'edit_file' => l10n.workspaceToolTitleEditFile,
    'list_dir' => l10n.workspaceToolTitleListDir,
    'glob' => l10n.workspaceToolTitleGlob,
    'grep' => l10n.workspaceToolTitleGrep,
    _ => toolName,
  };
}

IconData workspaceToolIcon(String toolName) {
  return switch (toolName) {
    'shell' => Lucide.Terminal,
    'read_file' => Lucide.FileText,
    'write_file' => Lucide.FilePlus,
    'edit_file' => Lucide.FilePen,
    'list_dir' => Lucide.FolderOpen,
    'glob' => Lucide.FileSearch,
    'grep' => Lucide.TextSearch,
    _ => Lucide.Wrench,
  };
}

String workspaceCommandOf(
  WorkspaceToolPart part, {
  WorkspaceToolMetadata? meta,
  ToolRun? run,
}) {
  final fromMeta = meta?.command?.trim() ?? '';
  if (fromMeta.isNotEmpty) return fromMeta;
  final fromRun = run?.command?.trim() ?? '';
  if (fromRun.isNotEmpty) return fromRun;
  return (part.arguments['command'] ?? '').toString();
}

String workspacePathOf(WorkspaceToolPart part, {WorkspaceToolMetadata? meta}) {
  final fromMeta = meta?.path?.trim() ?? '';
  if (fromMeta.isNotEmpty) return fromMeta;
  final args = part.arguments;
  final path = (args['path'] ?? '').toString().trim();
  if (path.isNotEmpty) return path;
  return (args['pattern'] ?? '').toString();
}

String workspacePatternOf(WorkspaceToolPart part) {
  return (part.arguments['pattern'] ?? '').toString();
}

int? workspaceWriteLineCount(WorkspaceToolPart part) {
  if (!part.arguments.containsKey('content')) return null;
  final content = part.arguments['content']?.toString() ?? '';
  if (content.isEmpty) return 0;
  return const LineSplitter().convert(content).length;
}

String formatWorkspaceDuration(AppLocalizations l10n, int? durationMs) {
  if (durationMs == null) return '';
  if (durationMs < 1000) {
    return l10n.workspaceToolDurationMs(durationMs);
  }
  final sec = durationMs / 1000;
  final label = sec == sec.roundToDouble()
      ? sec.toStringAsFixed(0)
      : sec.toStringAsFixed(1);
  return l10n.workspaceToolDurationSec(label);
}

int? workspaceDurationMs(WorkspaceToolMetadata? meta, ToolRun? run) {
  if (meta?.durationMs != null) return meta!.durationMs;
  if (run != null && run.status != ToolRunStatus.running) {
    return DateTime.now().difference(run.startedAt).inMilliseconds;
  }
  return null;
}

String? workspaceErrorMessage(
  WorkspaceToolPart part,
  WorkspaceToolMetadata? meta,
) {
  final content = part.content?.trim() ?? '';
  if (content.isNotEmpty) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final message = decoded['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}
  }
  if (meta?.status == 'error') {
    final code = meta?.code?.trim() ?? '';
    if (code.isNotEmpty) return code;
    if (content.isNotEmpty) return content;
  }
  return null;
}

List<String> workspaceTouchedPaths(
  WorkspaceToolPart part, {
  WorkspaceToolMetadata? meta,
}) {
  switch (part.toolName) {
    case 'read_file':
    case 'write_file':
    case 'edit_file':
      final path = workspacePathOf(part, meta: meta);
      return path.isEmpty ? const <String>[] : <String>[path];
    case 'list_dir':
    case 'glob':
    case 'grep':
      final fromMeta = meta?.changedFiles;
      if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
      final content = part.content ?? '';
      final out = <String>[];
      for (final line in const LineSplitter().convert(content)) {
        if (line.isEmpty || line.startsWith('...')) continue;
        out.add(_pathFromResultLine(part.toolName, line));
      }
      if (out.isEmpty) {
        final path = workspacePathOf(part, meta: meta);
        if (path.isNotEmpty && part.toolName == 'list_dir') {
          return <String>[path];
        }
      }
      return out;
    default:
      return const <String>[];
  }
}

String _pathFromResultLine(String tool, String line) {
  if (tool == 'grep') {
    final idx = line.indexOf(':');
    return idx > 0 ? line.substring(0, idx) : line;
  }
  if (tool == 'list_dir') {
    final trimmed = line.trimRight();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    final parts = trimmed.split(RegExp(r'\s{2,}'));
    return parts.first;
  }
  return line;
}

List<String> workspaceOutputTailLines({
  required WorkspaceToolPart part,
  WorkspaceToolMetadata? meta,
  ToolRun? run,
}) {
  if (run != null && run.tailLines.isNotEmpty) {
    return run.tailLines;
  }
  final preview = meta?.stdoutPreview ?? '';
  if (preview.isNotEmpty) return const LineSplitter().convert(preview);
  return const <String>[];
}

Color _workspaceQuietFill(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Theme.of(
    context,
  ).colorScheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04);
}

String workspaceCodeFontFamily(BuildContext context) {
  try {
    final fam = context.watch<SettingsProvider>().codeFontFamily;
    if (fam == null || fam.isEmpty) return 'monospace';
    return fam;
  } on ProviderNotFoundException {
    return 'monospace';
  }
}

T? maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

Future<File?> resolveWorkspaceLinkedFile(
  BuildContext context,
  String? link, {
  String? conversationId,
}) async {
  if (link == null || link.trim().isEmpty) return null;
  final parsed = KelivoLink.tryParse(link);
  if (parsed == null || parsed.kind == KelivoLinkKind.terminal) return null;

  FileLinkResolver? resolver = maybeRead<FileLinkResolver>(context);
  if (resolver == null) {
    final workspaces = maybeRead<WorkspaceProvider>(context);
    if (workspaces == null) return null;
    resolver = FileLinkResolver(workspaces: workspaces);
  }

  final chat = maybeRead<ChatService>(context);
  if (chat == null) return null;
  final id = (conversationId != null && conversationId.isNotEmpty)
      ? conversationId
      : chat.currentConversationId;
  if (id == null || id.isEmpty) return null;
  final conversation = chat.getConversation(id);
  if (conversation == null) return null;
  final binding = WorkspaceBinding.fromExtras(conversation.extras);
  try {
    return await resolver.resolveToHostFile(
      parsed,
      conversationId: conversation.id,
      binding: binding,
    );
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
  final l10n = AppLocalizations.of(context);
  if (link == null || link.trim().isEmpty) {
    if (l10n != null) {
      showAppSnackBar(
        context,
        message: l10n.workspaceFileNotAvailable,
        type: NotificationType.info,
      );
    }
    return;
  }
  final parsed = KelivoLink.tryParse(link);
  if (parsed == null) {
    if (l10n != null) {
      showAppSnackBar(
        context,
        message: l10n.workspaceFileNotAvailable,
        type: NotificationType.info,
      );
    }
    return;
  }
  if (parsed.kind == KelivoLinkKind.terminal) {
    WorkspaceNavigation.openTerminal(context, command: parsed.terminalCommand);
    return;
  }
  final file = await resolveWorkspaceLinkedFile(
    context,
    link,
    conversationId: conversationId,
  );
  if (!context.mounted) return;
  if (file == null) {
    showAppSnackBar(
      context,
      message:
          (l10n ?? AppLocalizations.of(context))!.workspaceFileNotAvailable,
      type: NotificationType.info,
    );
    return;
  }
  await showFilePreview(context, file, title: title);
}

/// Tactile button for tool approval actions (approve / deny).
///
/// Shared by the generic (non-timeline) approval card.
class ToolApprovalButton extends StatelessWidget {
  const ToolApprovalButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: filled ? 0.5 : 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: enabled ? color : color.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

void showToolApprovalDenyDialog(
  BuildContext context,
  ToolApprovalService approvalService,
  String toolCallId, {
  String? conversationId,
}) {
  final l10n = AppLocalizations.of(context)!;
  unawaited(
    showAppDialog<void>(
      context,
      child: _ToolApprovalDenyDialog(
        title: l10n.toolApprovalDenyTitle,
        hint: l10n.toolApprovalDenyHint,
        cancelLabel: l10n.workspaceToolCancel,
        denyLabel: l10n.workspaceToolDeny,
        onDeny: (reason) {
          approvalService.deny(
            toolCallId,
            reason: reason,
            conversationId: conversationId,
          );
        },
      ),
    ),
  );
}

class _ToolApprovalDenyDialog extends StatefulWidget {
  const _ToolApprovalDenyDialog({
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.denyLabel,
    required this.onDeny,
  });

  final String title;
  final String hint;
  final String cancelLabel;
  final String denyLabel;
  final ValueChanged<String?> onDeny;

  @override
  State<_ToolApprovalDenyDialog> createState() =>
      _ToolApprovalDenyDialogState();
}

class _ToolApprovalDenyDialogState extends State<_ToolApprovalDenyDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    widget.onDeny(reason.isEmpty ? null : reason);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
            const SizedBox(height: 12),
            IosFormTextField(
              label: widget.hint,
              hintText: widget.hint,
              controller: _controller,
              autofocus: true,
              inlineLabel: false,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: IosTileButton(
                    icon: Lucide.X,
                    label: widget.cancelLabel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IosTileButton(
                    icon: Lucide.Check,
                    label: widget.denyLabel,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkspaceFileChip extends StatelessWidget {
  const WorkspaceFileChip({
    super.key,
    required this.path,
    this.link,
    this.conversationId,
    this.displayName,
    this.tags = const <Widget>[],
    this.onTap,
  });

  static const ValueKey<String> chipKey = ValueKey<String>(
    'workspace-tool-file-chip',
  );

  final String path;
  final String? link;
  final String? conversationId;
  final String? displayName;
  final List<Widget> tags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = chatSurfaceForegroundPalette(context);
    final name =
        displayName ?? (p.basename(path).isEmpty ? path : p.basename(path));
    final open =
        onTap ??
        ((link == null || link!.isEmpty)
            ? null
            : () {
                unawaited(
                  openWorkspaceLinkedFile(
                    context,
                    link,
                    conversationId: conversationId,
                    title: name,
                  ),
                );
              });
    return Tooltip(
      message: path,
      child: IosCardPress(
        key: chipKey,
        borderRadius: BorderRadius.circular(8),
        baseColor: _workspaceQuietFill(context),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onTap: open,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(workspaceFileTypeIcon(path), size: 14, color: fg.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: workspaceCodeFontFamily(context),
                  color: fg.body,
                ),
              ),
            ),
            for (final tag in tags) ...[const SizedBox(width: 6), tag],
          ],
        ),
      ),
    );
  }
}

/// Keys for workspace tool status text. The former capsule widget was removed.
abstract final class WorkspaceStatusBadge {
  static const ValueKey<String> exitZeroKey = ValueKey<String>(
    'workspace-tool-badge-exit-zero',
  );
  static const ValueKey<String> exitErrorKey = ValueKey<String>(
    'workspace-tool-badge-exit-error',
  );
  static const ValueKey<String> timeoutKey = ValueKey<String>(
    'workspace-tool-badge-timeout',
  );
  static const ValueKey<String> cancelledKey = ValueKey<String>(
    'workspace-tool-badge-cancelled',
  );
  static const ValueKey<String> interruptedKey = ValueKey<String>(
    'workspace-tool-badge-interrupted',
  );
  static const ValueKey<String> deniedKey = ValueKey<String>(
    'workspace-tool-badge-denied',
  );
  static const ValueKey<String> runningKey = ValueKey<String>(
    'workspace-tool-badge-running',
  );
  static const ValueKey<String> approvalKey = ValueKey<String>(
    'workspace-tool-badge-approval',
  );
  static const ValueKey<String> completedKey = ValueKey<String>(
    'workspace-tool-badge-completed',
  );
}

class WorkspaceAddedRemovedCounts extends StatelessWidget {
  const WorkspaceAddedRemovedCounts({
    super.key,
    required this.added,
    required this.removed,
  });

  final int added;
  final int removed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          key: const ValueKey<String>('workspace-tool-added'),
          '+$added',
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.semibold,
            color: colors.success,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          key: const ValueKey<String>('workspace-tool-removed'),
          '−$removed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.semibold,
            color: cs.error,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceToolSummary extends StatelessWidget {
  const _WorkspaceToolSummary({
    required this.part,
    required this.meta,
    required this.run,
  });

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = chatSurfaceForegroundPalette(context);
    final fontFamily = workspaceCodeFontFamily(context);
    final base = TextStyle(
      fontSize: 12,
      fontWeight: AppFontWeights.regular,
      fontFamily: fontFamily,
      color: fg.body,
    );
    final path = workspacePathOf(part, meta: meta);
    final pattern = workspacePatternOf(part);

    final Widget child;
    switch (part.toolName) {
      case 'shell':
        final command = workspaceCommandOf(part, meta: meta, run: run);
        if (command.isEmpty) return const SizedBox.shrink();
        child = Text(
          command,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'write_file':
        final lines = workspaceWriteLineCount(part);
        final text = lines == null
            ? path
            : '$path · ${l10n.workspaceToolLines(lines)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'edit_file':
        final added = meta?.added;
        final removed = meta?.removed;
        if (path.isEmpty && added == null && removed == null) {
          return const SizedBox.shrink();
        }
        child = Text.rich(
          TextSpan(
            style: base,
            children: [
              if (path.isNotEmpty) TextSpan(text: path),
              if (path.isNotEmpty && (added != null || removed != null))
                const TextSpan(text: ' · '),
              if (added != null) TextSpan(text: '+$added'),
              if (added != null && removed != null) const TextSpan(text: ' '),
              if (removed != null) TextSpan(text: '−$removed'),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'list_dir':
        final count = meta?.count;
        final text = count == null
            ? path
            : '$path · ${l10n.workspaceToolItems(count)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'glob':
        final count = meta?.count;
        final text = count == null
            ? pattern
            : '$pattern · ${l10n.workspaceToolFileMatches(count)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'grep':
        final count = meta?.count;
        final text = count == null
            ? pattern
            : '$pattern · ${l10n.workspaceToolContentMatches(count)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      default:
        if (path.isEmpty) return const SizedBox.shrink();
        child = Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
    }
    return child;
  }
}

/// Header extra: exit / denied / timeout plus duration, joined with ` · `.
class WorkspaceToolStatusText extends StatelessWidget {
  const WorkspaceToolStatusText({
    super.key,
    required this.part,
    this.conversationId,
    this.run,
  });

  final WorkspaceToolPart part;
  final String? conversationId;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    ToolRun? liveRun = run;
    if (liveRun == null) {
      try {
        liveRun = context.watch<ToolRunRegistry>().of(part.id);
      } on ProviderNotFoundException {
        liveRun = null;
      }
    }
    final resolved = liveRun;
    if (resolved != null && run == null) {
      return ListenableBuilder(
        listenable: resolved,
        builder: (context, _) => _buildStatus(context, resolved),
      );
    }
    return _buildStatus(context, resolved);
  }

  Widget _buildStatus(BuildContext context, ToolRun? liveRun) {
    final approval = maybeRead<ToolApprovalService>(context);
    ToolApprovalRequest? pending;
    if (approval != null) {
      try {
        pending = context.select<ToolApprovalService, ToolApprovalRequest?>(
          (service) => service.pendingFor(
            toolCallId: part.id,
            conversationId: conversationId,
          ),
        );
      } on ProviderNotFoundException {
        pending = approval.pendingFor(
          toolCallId: part.id,
          conversationId: conversationId,
        );
      }
    }
    final meta = workspaceMetadataFrom(part.metadata);
    final liveRunning =
        liveRun != null && liveRun.status == ToolRunStatus.running;
    final finishedStatus = meta?.status;
    final isRunning =
        liveRunning ||
        (part.loading &&
            pending == null &&
            (finishedStatus == null || finishedStatus.isEmpty));
    if (pending != null || isRunning) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final fg = chatSurfaceForegroundPalette(context);

    final denied = meta?.status == 'denied';
    final timedOut =
        meta?.timedOut == true ||
        meta?.status == 'timeout' ||
        liveRun?.status == ToolRunStatus.timedOut;
    final cancelled =
        meta?.cancelled == true ||
        meta?.status == 'cancelled' ||
        liveRun?.status == ToolRunStatus.cancelled;
    final interrupted =
        meta?.interrupted == true || meta?.status == 'interrupted';
    final exitCode = meta?.exitCode ?? liveRun?.exitCode;

    String? label;
    Color color = fg.muted;
    Key? key;
    if (denied) {
      label = l10n.workspaceToolDenied;
      color = cs.error;
      key = WorkspaceStatusBadge.deniedKey;
    } else if (timedOut) {
      label = l10n.workspaceToolTimeout;
      color = colors.warning;
      key = WorkspaceStatusBadge.timeoutKey;
    } else if (cancelled) {
      label = l10n.workspaceToolCancelled;
      color = cs.error;
      key = WorkspaceStatusBadge.cancelledKey;
    } else if (interrupted) {
      label = l10n.workspaceToolInterrupted;
      color = colors.warning;
      key = WorkspaceStatusBadge.interruptedKey;
    } else if (part.toolName == 'shell' && exitCode != null) {
      label = l10n.workspaceToolExitCode(exitCode);
      final ok = exitCode == 0;
      color = ok ? fg.muted : cs.error;
      key = ok
          ? WorkspaceStatusBadge.exitZeroKey
          : WorkspaceStatusBadge.exitErrorKey;
    } else if (meta?.status == 'error') {
      label = l10n.workspaceToolSectionError;
      color = cs.error;
    }

    final duration = formatWorkspaceDuration(
      l10n,
      workspaceDurationMs(meta, liveRun),
    );
    final pieces = <String>[
      if (label != null) label,
      if (duration.isNotEmpty) duration,
    ];
    if (pieces.isEmpty) return const SizedBox.shrink();
    return Text(
      key: key,
      pieces.join(' · '),
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}

/// Inline workspace tool body under the timeline (or flat-card) title.
class WorkspaceToolCardBody extends StatelessWidget {
  const WorkspaceToolCardBody({
    super.key,
    required this.part,
    required this.conversationId,
    this.run,
  });

  static const ValueKey<String> installButtonKey = ValueKey<String>(
    'workspace-tool-install',
  );
  static const ValueKey<String> allowAllKey = ValueKey<String>(
    'workspace-tool-allow-all',
  );

  final WorkspaceToolPart part;
  final String conversationId;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    ToolRun? liveRun = run;
    if (liveRun == null) {
      try {
        liveRun = context.watch<ToolRunRegistry>().of(part.id);
      } on ProviderNotFoundException {
        liveRun = null;
      }
    }
    final resolvedRun = liveRun;
    if (resolvedRun != null) {
      return ListenableBuilder(
        listenable: resolvedRun,
        builder: (context, _) => _buildBody(context, resolvedRun),
      );
    }
    return _buildBody(context, resolvedRun);
  }

  Widget _buildBody(BuildContext context, ToolRun? liveRun) {
    final meta = workspaceMetadataFrom(part.metadata);
    final approval = maybeRead<ToolApprovalService>(context);
    ToolApprovalRequest? pending;
    if (approval != null) {
      try {
        pending = context.select<ToolApprovalService, ToolApprovalRequest?>(
          (service) => service.pendingFor(
            toolCallId: part.id,
            conversationId: conversationId,
          ),
        );
      } on ProviderNotFoundException {
        pending = approval.pendingFor(
          toolCallId: part.id,
          conversationId: conversationId,
        );
      }
    }
    final extra = pending == null ? _extra(context, liveRun, meta) : null;
    final showEnv =
        meta?.status == 'error' && meta?.code == 'environment_not_ready';
    final summary = pending == null
        ? _WorkspaceToolSummary(part: part, meta: meta, run: liveRun)
        : null;
    final pendingBlock = pending == null
        ? null
        : _WorkspacePendingBody(
            part: part,
            meta: meta,
            run: liveRun,
            request: pending,
            conversationId: conversationId,
          );
    if (summary == null && pendingBlock == null && extra == null && !showEnv) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingBlock != null) pendingBlock,
        if (summary != null) summary,
        if (extra != null) ...[const SizedBox(height: 6), extra],
        if (showEnv) ...[
          const SizedBox(height: 6),
          _EnvironmentNotice(
            onInstall: () => WorkspaceNavigation.openEnvironmentPage(context),
          ).animate().fadeIn(duration: 200.ms),
        ],
      ],
    );
  }

  Widget? _extra(
    BuildContext context,
    ToolRun? liveRun,
    WorkspaceToolMetadata? meta,
  ) {
    switch (part.toolName) {
      case 'shell':
        return _ShellTail(part: part, meta: meta, run: liveRun);
      case 'write_file':
      case 'read_file':
      case 'glob':
      case 'grep':
        return _TouchedPathChips(
          part: part,
          meta: meta,
          conversationId: conversationId,
        );
      default:
        return null;
    }
  }
}

class _EnvironmentNotice extends StatelessWidget {
  const _EnvironmentNotice({required this.onInstall});

  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = chatSurfaceForegroundPalette(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.workspaceToolEnvironmentNotReady,
            style: TextStyle(fontSize: 12, height: 1.35, color: fg.body),
          ),
        ),
        const SizedBox(width: 8),
        IosTileButton(
          key: WorkspaceToolCardBody.installButtonKey,
          icon: Lucide.Download,
          label: l10n.workspaceToolInstall,
          backgroundColor: fg.accent,
          onTap: onInstall,
        ),
      ],
    );
  }
}

class _WorkspacePendingBody extends StatelessWidget {
  const _WorkspacePendingBody({
    required this.part,
    required this.meta,
    required this.run,
    required this.request,
    required this.conversationId,
  });

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final ToolRun? run;
  final ToolApprovalRequest request;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = chatSurfaceForegroundPalette(context);
    final approval = maybeRead<ToolApprovalService>(context);
    final preview = part.toolName == 'shell'
        ? workspaceCommandOf(part, meta: meta, run: run)
        : workspacePathOf(part, meta: meta);
    return Column(
      key: WorkspaceStatusBadge.approvalKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isNotEmpty)
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontFamily: workspaceCodeFontFamily(context),
              color: fg.body,
            ),
          ),
        IosCardPress(
          key: WorkspaceToolCardBody.allowAllKey,
          baseColor: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          onTap: approval == null
              ? null
              : () => unawaited(
                  allowAllWorkspaceToolsInChat(
                    context,
                    approval: approval,
                    request: request,
                    conversationId: conversationId,
                  ),
                ),
          child: Text(
            l10n.workspaceToolAllowAll,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: AppFontWeights.medium,
              color: fg.accent,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> allowAllWorkspaceToolsInChat(
  BuildContext context, {
  required ToolApprovalService approval,
  required ToolApprovalRequest request,
  required String conversationId,
}) async {
  final chat = maybeRead<ChatService>(context);
  final id = conversationId.isNotEmpty
      ? conversationId
      : (request.conversationId ?? '');
  if (chat != null && id.isNotEmpty) {
    try {
      final conversation = chat.getConversation(id);
      if (conversation != null) {
        final binding = WorkspaceBinding.fromExtras(conversation.extras);
        if (binding.isBound) {
          await chat.updateConversationExtras(id, (extras) {
            return WorkspaceBinding(
              workspaceId: binding.workspaceId,
              cwd: binding.cwd,
              toolsUsed: binding.toolsUsed,
              allowAll: true,
            ).applyTo(extras);
          });
        }
      }
    } catch (_) {}
  }
  approval.approve(request.toolCallId, conversationId: request.conversationId);
}

class _ShellTail extends StatelessWidget {
  const _ShellTail({required this.part, required this.meta, required this.run});

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    final lines = workspaceOutputTailLines(part: part, meta: meta, run: run);
    if (lines.isEmpty) return const SizedBox.shrink();
    final last = lines.length <= 4 ? lines : lines.sublist(lines.length - 4);
    final fg = chatSurfaceForegroundPalette(context);
    return Text(
      last.join('\n'),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontFamily: workspaceCodeFontFamily(context),
        color: fg.body,
      ),
    );
  }
}

class _TouchedPathChips extends StatelessWidget {
  const _TouchedPathChips({
    required this.part,
    required this.meta,
    required this.conversationId,
  });

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final paths = workspaceTouchedPaths(part, meta: meta);
    if (paths.isEmpty) return const SizedBox.shrink();
    const limit = 3;
    final visible = paths.length <= limit ? paths : paths.sublist(0, limit);
    final overflow = paths.length - visible.length;
    final links = meta?.changedLinks ?? const <String>[];
    final singleLink = meta?.link;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < visible.length; i++)
          WorkspaceFileChip(
            path: visible[i],
            link: i < links.length
                ? links[i]
                : (visible.length == 1 ? singleLink : null),
            conversationId: conversationId,
          ),
        if (overflow > 0)
          Text(
            l10n.workspaceToolMoreFiles(overflow),
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFontWeights.medium,
              color: chatSurfaceForegroundPalette(context).muted,
            ),
          ),
      ],
    );
  }
}
