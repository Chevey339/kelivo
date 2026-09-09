import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'tool_detail_text_section.dart';
import 'unified_diff_view.dart';
import 'workspace_tool_ui.dart';

const ValueKey<String> kWorkspaceToolDetailDesktopKey = ValueKey<String>(
  'workspace-tool-detail-desktop',
);

Future<void> showWorkspaceToolDetail(
  BuildContext context,
  WorkspaceToolPart part, {
  String? conversationId,
}) {
  final l10n = AppLocalizations.of(context)!;
  final title = workspaceToolTitle(l10n, part.toolName);
  if (useDesktopWorkspaceLayout(context)) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return showAppDialog<void>(
      context,
      maxWidth: 760,
      child: SizedBox(
        key: kWorkspaceToolDetailDesktopKey,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(
              title: title,
              actions: [
                _HeaderCopyButton(part: part, conversationId: conversationId),
              ],
            ),
            Expanded(
              child: WorkspaceToolDetailBody(
                part: part,
                conversationId: conversationId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return showCustomBottomSheet<void>(
    context: context,
    title: title,
    closeSemanticLabel: l10n.workspaceToolClose,
    builder: (sheetContext, scrollController) {
      return WorkspaceToolDetailBody(
        part: part,
        scrollController: scrollController,
        conversationId: conversationId,
      );
    },
  );
}

class _HeaderCopyButton extends StatelessWidget {
  const _HeaderCopyButton({required this.part, this.conversationId});

  final String? conversationId;

  final WorkspaceToolPart part;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.workspaceToolCopy,
      child: IosIconButton(
        size: 18,
        semanticLabel: l10n.workspaceToolCopy,
        icon: Lucide.Copy,
        onTap: () async {
          final text = _detailCopyText(context, part, conversationId);
          if (text.isEmpty) return;
          await Clipboard.setData(ClipboardData(text: text));
          if (!context.mounted) return;
          showAppSnackBar(
            context,
            message: l10n.workspaceToolCopied,
            type: NotificationType.success,
          );
        },
      ),
    );
  }
}

String _detailCopyText(
  BuildContext context,
  WorkspaceToolPart part,
  String? conversationId,
) {
  ToolRun? run;
  try {
    run = context.read<ToolRunRegistry>().of(
      part.id,
      conversationId: conversationId,
    );
  } on ProviderNotFoundException {
    run = null;
  }
  final meta = workspaceMetadataFrom(part.metadata);
  final command = workspaceCommandOf(part, meta: meta, run: run);
  final path = workspacePathOf(part, meta: meta);
  final stdout = (run?.stdoutSoFar.isNotEmpty == true)
      ? run!.stdoutSoFar
      : (meta?.stdoutPreview ?? part.content ?? '');
  final error = workspaceErrorMessage(part, meta) ?? '';
  final diff = meta?.diff ?? '';
  final buf = StringBuffer();
  if (command.isNotEmpty) buf.writeln(command);
  if (path.isNotEmpty && path != command) buf.writeln(path);
  if (stdout.isNotEmpty) buf.writeln(stdout);
  if (diff.isNotEmpty) buf.writeln(diff);
  if (error.isNotEmpty) buf.writeln(error);
  return buf.toString().trim();
}

class WorkspaceToolDetailBody extends StatelessWidget {
  const WorkspaceToolDetailBody({
    super.key,
    required this.part,
    this.scrollController,
    this.conversationId,
  });

  final WorkspaceToolPart part;
  final ScrollController? scrollController;
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    ToolRunRegistry? registry;
    try {
      registry = context.watch<ToolRunRegistry>();
    } on ProviderNotFoundException {
      registry = null;
    }
    final run = registry?.of(part.id, conversationId: conversationId);
    final body = run == null
        ? _UnifiedDetail(
            part: part,
            run: run,
            scrollController: scrollController,
            conversationId: conversationId,
          )
        : ListenableBuilder(
            listenable: run,
            builder: (context, _) => _UnifiedDetail(
              part: part,
              run: run,
              scrollController: scrollController,
              conversationId: conversationId,
            ),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: body,
    );
  }
}

class _CopyIcon extends StatelessWidget {
  const _CopyIcon({required this.tooltip, required this.text});

  final String tooltip;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: tooltip,
      child: IosIconButton(
        size: 16,
        semanticLabel: tooltip,
        icon: Lucide.Copy,
        onTap: text.isEmpty
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  message: l10n.workspaceToolCopied,
                  type: NotificationType.success,
                );
              },
      ),
    );
  }
}

class _MutedSectionLabel extends StatelessWidget {
  const _MutedSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _UnifiedDetail extends StatefulWidget {
  const _UnifiedDetail({
    required this.part,
    required this.run,
    this.scrollController,
    this.conversationId,
  });

  final WorkspaceToolPart part;
  final ToolRun? run;
  final ScrollController? scrollController;
  final String? conversationId;

  @override
  State<_UnifiedDetail> createState() => _UnifiedDetailState();
}

class _UnifiedDetailState extends State<_UnifiedDetail> {
  bool _showStderr = false;
  bool _pinnedToBottom = true;
  ScrollController? _ownedController;

  ScrollController get _scroll => widget.scrollController ?? _ownedController!;

  WorkspaceToolMetadata? get _meta =>
      workspaceMetadataFrom(widget.part.metadata);

  bool get _running =>
      widget.run != null && widget.run!.status == ToolRunStatus.running;

  String get _stdout {
    final live = widget.run?.stdoutSoFar ?? '';
    if (live.isNotEmpty) return live;
    return _meta?.stdoutPreview ?? '';
  }

  String get _stderr {
    final live = widget.run?.stderrSoFar ?? '';
    if (live.isNotEmpty) return live;
    return _meta?.stderrPreview ?? '';
  }

  String get _textResult {
    if (widget.part.toolName == 'shell') return '';
    return widget.part.content?.trim() ?? '';
  }

  String get _activeOutput {
    if (widget.part.toolName == 'shell') {
      return _showStderr ? _stderr : _stdout;
    }
    return _textResult;
  }

  String get _commandBlock {
    if (widget.part.toolName == 'shell') {
      return workspaceCommandOf(widget.part, meta: _meta, run: widget.run);
    }
    final pattern = workspacePatternOf(widget.part);
    if ((widget.part.toolName == 'glob' || widget.part.toolName == 'grep') &&
        pattern.isNotEmpty) {
      return pattern;
    }
    return workspacePathOf(widget.part, meta: _meta);
  }

  String _primarySectionLabel(AppLocalizations l10n) {
    return switch (widget.part.toolName) {
      'read_file' ||
      'write_file' ||
      'edit_file' ||
      'list_dir' => l10n.workspaceToolSectionPath,
      'glob' || 'grep' => l10n.workspaceToolSectionPattern,
      _ => l10n.workspaceToolSectionCommand,
    };
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _ownedController = ScrollController();
    }
    _scroll.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpIfFollowing());
  }

  @override
  void didUpdateWidget(covariant _UnifiedDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _detach(oldWidget.scrollController ?? _ownedController);
      if (widget.scrollController == null) {
        _ownedController ??= ScrollController();
      } else if (_ownedController != null) {
        _ownedController!.dispose();
        _ownedController = null;
      }
      _scroll.addListener(_handleScroll);
    }
    final outputChanged =
        oldWidget.run?.stdoutSoFar != widget.run?.stdoutSoFar ||
        oldWidget.run?.stderrSoFar != widget.run?.stderrSoFar ||
        oldWidget.part.content != widget.part.content;
    if (outputChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpIfFollowing());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _ownedController?.dispose();
    super.dispose();
  }

  void _detach(ScrollController? controller) {
    controller?.removeListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 48;
    if (atBottom) {
      _pinnedToBottom = true;
    } else if (pos.userScrollDirection != ScrollDirection.idle) {
      _pinnedToBottom = false;
    }
  }

  void _jumpIfFollowing() {
    if (!_running || !_pinnedToBottom) return;
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final fontFamily = workspaceCodeFontFamily(context);
    final command = _commandBlock;
    final output = _activeOutput;
    final files = _meta?.files ?? const <WorkspaceToolFile>[];
    final logs = files.where((file) => file.role == WorkspaceFileRole.log);
    final referenced = files
        .where((file) => file.role != WorkspaceFileRole.log)
        .toList();
    final diff = _meta?.diff ?? '';
    final error = workspaceErrorMessage(widget.part, _meta);
    final path = workspacePathOf(widget.part, meta: _meta);
    final isShell = widget.part.toolName == 'shell';
    final showOutput =
        isShell ||
        (widget.part.toolName != 'edit_file' &&
            widget.part.toolName != 'write_file' &&
            output.isNotEmpty);
    final outputDisplay = output.isEmpty ? l10n.workspaceToolNoOutput : output;

    final slivers = <Widget>[];
    var hasSection = false;

    void addGap() {
      if (hasSection) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 12)));
      }
      hasSection = true;
    }

    if (command.isNotEmpty) {
      addGap();
      slivers.add(
        ToolDetailTextSection(
          label: _primarySectionLabel(l10n),
          text: command,
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: 0.9),
          ),
          trailing: _CopyIcon(
            tooltip: l10n.workspaceToolCopyCommand,
            text: command,
          ),
        ),
      );
    }
    if (showOutput) {
      addGap();
      slivers.add(
        ToolDetailTextSection(
          label: l10n.workspaceToolSectionOutput,
          text: outputDisplay,
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: output.isEmpty ? 0.45 : 0.82),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_running)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: CupertinoActivityIndicator(radius: 6),
                ),
              _CopyIcon(tooltip: l10n.workspaceToolCopyOutput, text: output),
            ],
          ),
          belowLabel: isShell && (_stdout.isNotEmpty || _stderr.isNotEmpty)
              ? _StreamToggle(
                  showStderr: _showStderr,
                  onChanged: (stderr) => setState(() => _showStderr = stderr),
                )
              : null,
        ),
      );
      for (final log in logs) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
        slivers.add(
          SliverToBoxAdapter(
            child: WorkspaceFileChip(
              path: log.path,
              displayName: l10n.workspaceToolSavedOutput,
              link: log.link,
              conversationId: widget.conversationId,
            ),
          ),
        );
      }
    }
    if (referenced.isNotEmpty) {
      addGap();
      slivers.add(
        SliverToBoxAdapter(
          child: _MutedSectionLabel(
            label: referenced.any((file) => file.isChanged)
                ? l10n.workspaceToolChangedFiles
                : l10n.workspaceToolRelatedFiles,
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final file in referenced)
                WorkspaceFileChip(
                  path: file.path,
                  link: file.link,
                  isDirectory: file.isDirectory,
                  conversationId: widget.conversationId,
                ),
            ],
          ),
        ),
      );
    }
    if (_meta?.filesTruncated == true) {
      addGap();
      slivers.add(
        SliverToBoxAdapter(
          child: Text(
            l10n.workspaceToolFilesTruncated,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }
    if (diff.isNotEmpty) {
      addGap();
      slivers.add(
        SliverToBoxAdapter(
          child: _MutedSectionLabel(label: l10n.workspaceToolSectionDiff),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: UnifiedDiffView(
            diff: diff,
            showHeader: true,
            fileName: path,
            added: _meta?.added,
            removed: _meta?.removed,
          ),
        ),
      );
      if (_meta?.diffTruncated == true) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.workspaceToolDiffTruncated,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      }
    }
    if (error != null && error.isNotEmpty) {
      addGap();
      slivers.add(
        SliverToBoxAdapter(
          child: _MutedSectionLabel(label: l10n.workspaceToolSectionError),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: Text(
            error,
            style: TextStyle(fontSize: 13, height: 1.4, color: cs.error),
          ),
        ),
      );
    }

    final scrollView = SelectionArea(
      child: CustomScrollView(
        controller: _scroll,
        slivers: [SliverMainAxisGroup(slivers: slivers)],
      ),
    );

    final scrolling = _ownedController != null
        ? Scrollbar(controller: _ownedController, child: scrollView)
        : scrollView;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: scrolling),
        if (_running) ...[
          const SizedBox(height: 8),
          IosTileButton(
            icon: Lucide.X,
            label: l10n.workspaceToolCancel,
            backgroundColor: cs.error,
            onTap: () {
              final runtime = maybeRead<WorkspaceRuntimeProvider>(
                context,
              )?.runtime;
              unawaited(runtime?.cancel(widget.run!.runtimeRunId));
            },
          ),
        ],
      ],
    );
  }
}

class _StreamToggle extends StatelessWidget {
  const _StreamToggle({required this.showStderr, required this.onChanged});

  final bool showStderr;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _ToggleChip(
          label: l10n.workspaceToolStdout,
          selected: !showStderr,
          onTap: () => onChanged(false),
          color: cs.primary,
        ),
        const SizedBox(width: 8),
        _ToggleChip(
          label: l10n.workspaceToolStderr,
          selected: showStderr,
          onTap: () => onChanged(true),
          color: cs.error,
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      baseColor: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: AppFontWeights.semibold,
          color: selected
              ? color
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
