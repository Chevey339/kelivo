import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/markdown/markdown_with_code_highlight.dart';
import '../../../shared/text_input/message_editing_controller.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/long_message_editor.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../pages/context_summary_editor_page.dart';
import 'context_dialog.dart';
export 'context_node_divider.dart';

/// Shared detail body. Desktop edits stay here; mobile edits use a full page.
class ContextOperationContent extends StatefulWidget {
  const ContextOperationContent({
    super.key,
    required this.operation,
    required this.onClose,
    this.onSave,
    this.onUndo,
    this.onViewOriginal,
    this.onRecompress,
    this.onContinueNewChat,
    this.rangeLabel = '',
    this.initiallyEditing = false,
    this.budget,
    this.undoBudget,
    this.estimateSummary,
    this.statusLabel = '',
    this.showHeader = true,
  });
  final ContextOperation operation;
  final VoidCallback onClose;
  final Future<bool> Function(String summary)? onSave;
  final Future<bool> Function()? onUndo;
  final VoidCallback? onViewOriginal;
  final VoidCallback? onRecompress;
  final VoidCallback? onContinueNewChat;
  final String rangeLabel;
  final bool initiallyEditing;
  final CompressionBudget? budget;
  final CompressionBudget? undoBudget;
  final Future<CompressionBudget?> Function(String)? estimateSummary;
  final String statusLabel;
  final bool showHeader;

  @override
  State<ContextOperationContent> createState() =>
      _ContextOperationContentState();
}

class _ContextOperationContentState extends State<ContextOperationContent> {
  late final MessageEditingController _editor = MessageEditingController(
    text: widget.operation.summary,
  );
  late bool _editing = widget.initiallyEditing;
  bool _saving = false;
  String? _error;
  CompressionBudget? _editBudget;
  Timer? _estimateTimer;
  int _estimateRevision = 0;
  final _moreKey = GlobalKey();

  @override
  void dispose() {
    _estimateTimer?.cancel();
    _editor.dispose();
    super.dispose();
  }

  void _onChanged(String summary) {
    setState(() => _error = null);
    final revision = ++_estimateRevision;
    _estimateTimer?.cancel();
    _estimateTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final budget = await widget.estimateSummary?.call(summary);
        if (mounted && revision == _estimateRevision) {
          setState(() => _editBudget = budget);
        }
      } catch (_) {
        /* Keep the editable draft when model information is unavailable. */
      }
    });
  }

  Future<void> _beginEdit() async {
    if (PlatformUtils.isDesktopTarget) {
      setState(() {
        _editing = true;
        _editBudget = widget.budget;
      });
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContextSummaryEditorPage(
          summary: widget.operation.summary,
          budget: widget.budget,
          estimate: widget.estimateSummary,
          onSave: widget.onSave!,
        ),
      ),
    );
    if (mounted && saved == true) widget.onClose();
  }

  Future<void> _save() async {
    if (_saving) return;
    await _editor.flushMessageInput();
    if (!mounted || _editor.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave?.call(_editor.text) ?? false;
      if (mounted && saved) widget.onClose();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _undo() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (await widget.onUndo?.call() == true && mounted) widget.onClose();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _more() {
    final l10n = AppLocalizations.of(context)!;
    final box = _moreKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    showAdaptiveActionMenu(
      context,
      anchor: box.localToGlobal(Offset(0, box.size.height)),
      title: l10n.contextDetailTitle,
      items: [
        if (widget.onRecompress != null)
          ActionSheetItem(
            icon: LucideIcons.sparkles,
            label: l10n.compressRegenerate,
            onTap: widget.onRecompress!,
          ),
        if (widget.onViewOriginal != null)
          ActionSheetItem(
            icon: LucideIcons.info,
            label: l10n.contextDetailViewOriginals,
            onTap: widget.onViewOriginal!,
          ),
        if (widget.onContinueNewChat != null)
          ActionSheetItem(
            icon: LucideIcons.gitBranch,
            label: l10n.contextDetailContinueNewChat,
            onTap: widget.onContinueNewChat!,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final operation = widget.operation;
    final cs = Theme.of(context).colorScheme;
    final desktop = PlatformUtils.isDesktopTarget;
    final status = operation.revoked
        ? l10n.contextOperationUndone
        : widget.statusLabel.isEmpty
        ? l10n.contextDetailInUse
        : widget.statusLabel;
    final hasMore =
        widget.onViewOriginal != null ||
        widget.onRecompress != null ||
        widget.onContinueNewChat != null;
    final empty = _editor.text.trim().isEmpty;
    final mode = switch (operation.inputMode) {
      'start' => l10n.compressContextKeepStart,
      'recent' => l10n.compressContextKeepRecent,
      'keepRecent' => l10n.compressContextUnlimited,
      _ => l10n.compressContextUnlimited,
    };
    final time = operation.createdAt.toLocal();
    final timestamp =
        '${MaterialLocalizations.of(context).formatShortDate(time)} '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
    final over =
        widget.undoBudget?.contextWindow != null &&
        widget.undoBudget!.usedTokens > widget.undoBudget!.contextWindow!;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!operation.isCompression) ...[
          const SizedBox(height: 8),
          Text(
            l10n.contextClearDetails,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        ContextDetailRow(
          label: operation.isCompression
              ? l10n.contextDetailReplaced
              : l10n.contextDetailExcluded,
          value: widget.rangeLabel.isEmpty
              ? l10n.contextRangeInfo(
                  operation.sourceGroups.length,
                  operation.keepUserMessages,
                )
              : widget.rangeLabel,
        ),
        if (operation.isCompression) ...[
          ContextDetailRow(
            label: l10n.contextDetailRead,
            value: [
              mode,
              if (operation.inputParts > 0)
                l10n.contextDetailParts(operation.inputParts),
              if (operation.includedAttachmentsAndTools)
                l10n.compressIncludeAttachments,
            ].join(' · '),
          ),
          if (operation.inputMode == 'start' || operation.inputMode == 'recent')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.contextSampledInfo(operation.inputMaxChars ?? 6000),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: context.appColors.warning,
                ),
              ),
            ),
          ContextDetailRow(
            label: l10n.contextDetailKept,
            value: l10n.contextDetailKeptCount(operation.keepUserMessages),
          ),
          ContextDetailRow(
            label: l10n.contextDetailModel,
            value: '${operation.model} · $timestamp',
          ),
        ],
        ContextDetailRow(
          label: operation.isCompression
              ? l10n.contextDetailNext
              : l10n.contextDetailCurrent,
          value: widget.budget == null
              ? '—'
              : l10n.compressApproxTokens(
                  contextTokenValue(widget.budget!.usedTokens),
                ),
        ),
        ContextDetailRow(
          label: l10n.contextDetailAfterUndo,
          value: widget.undoBudget == null
              ? '—'
              : l10n.compressApproxTokens(
                  contextTokenValue(widget.undoBudget!.usedTokens),
                ),
        ),
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.contextOverLimitWarning,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.appColors.warning,
              ),
            ),
          ),
        if (operation.isCompression) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.contextDetailSummaryLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
              if (_editing)
                Text(
                  l10n.contextEditCharacters(_editor.text.characters.length),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                )
              else ...[
                IosTextButton(
                  label: l10n.assistantSettingsCopyButton,
                  icon: LucideIcons.copy,
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: operation.summary)),
                ),
                if (widget.onSave != null && !operation.revoked)
                  IosTextButton(
                    label: l10n.assistantSettingsEditButton,
                    icon: LucideIcons.pencil,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    onPressed: _saving ? null : _beginEdit,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: desktop ? (_editing ? 210 : 180) : 235,
            decoration: BoxDecoration(
              color: context.appColors.surfaceFill,
              borderRadius: BorderRadius.circular(14),
              border: _editing
                  ? Border.all(color: cs.primary, width: 1.5)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: _editing
                ? LongMessageEditor(
                    controller: _editor,
                    minLines: null,
                    maxLines: null,
                    expands: true,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      hintText: l10n.contextEditTitle,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: SelectionArea(
                      child: MarkdownWithCodeHighlight(
                        text: operation.summary,
                        baseStyle: TextStyle(
                          fontSize: desktop ? 13.5 : 14,
                          height: 1.6,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            _editing && empty
                ? l10n.contextEditEmpty
                : _editing
                ? (_editBudget ?? widget.budget) == null
                      ? l10n.contextEditUnknownPreview
                      : l10n.contextEditPreview(
                          contextTokenValue(
                            (_editBudget ?? widget.budget)!.usedTokens,
                          ),
                        )
                : l10n.compressIncludeAttachmentsDesc,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: _editing && empty ? cs.error : cs.onSurfaceVariant,
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ),
      ],
    );
    return Padding(
      padding: widget.showHeader
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  alignment: widget.showHeader
                      ? WrapAlignment.start
                      : WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.showHeader)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            operation.isCompression
                                ? LucideIcons.package2
                                : LucideIcons.eraser,
                            size: 20,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              operation.isCompression
                                  ? l10n.contextDetailTitle
                                  : l10n.contextDetailClearTitle,
                              style: TextStyle(
                                fontSize: 17,
                                color: cs.onSurface,
                                fontWeight: AppFontWeights.emphasis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (operation.isCompression)
                      ContextStatusChip(
                        label: status,
                        muted:
                            widget.statusLabel.isNotEmpty || operation.revoked,
                        icon: LucideIcons.circleCheck,
                      ),
                    if (operation.isEdited && operation.isCompression)
                      ContextStatusChip(
                        label: l10n.contextDetailEdited,
                        muted: true,
                      ),
                    if (operation.convertedFromLegacyClear)
                      ContextStatusChip(
                        label: l10n.contextDetailLegacy,
                        muted: true,
                      ),
                  ],
                ),
              ),
              if (hasMore && desktop)
                IconButton(
                  key: _moreKey,
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  onPressed: _saving ? null : _more,
                  icon: Icon(
                    LucideIcons.ellipsis,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              if (widget.showHeader)
                IconButton(
                  tooltip: l10n.statsPageClose,
                  onPressed: _saving ? null : widget.onClose,
                  icon: Icon(
                    LucideIcons.x,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(child: SingleChildScrollView(child: body)),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!_editing && widget.onUndo != null && !operation.revoked)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IosTextButton(
                      label: operation.isCompression
                          ? l10n.contextUndoCompressTooltip
                          : l10n.contextUndoClearTooltip,
                      icon: LucideIcons.undo2,
                      color: cs.error,
                      fontSize: 13,
                      padding: EdgeInsets.zero,
                      onPressed: _saving ? null : _undo,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (_editing) ...[
                SizedBox(
                  width: 88,
                  child: ContextDialogActionButton(
                    label: l10n.homePageCancel,
                    onTap: _saving
                        ? null
                        : () {
                            if (widget.initiallyEditing) {
                              widget.onClose();
                              return;
                            }
                            _editor.text = operation.summary;
                            setState(() {
                              _editing = false;
                              _error = null;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (!desktop && !_editing && hasMore)
                IosTextButton(
                  key: _moreKey,
                  label: l10n.contextMore,
                  icon: LucideIcons.ellipsis,
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  onPressed: _saving ? null : _more,
                ),
              if (desktop || _editing)
                SizedBox(
                  width: 96,
                  child: ContextDialogActionButton(
                    label: _editing
                        ? l10n.messageEditPageSave
                        : l10n.contextDone,
                    primary: true,
                    onTap: _saving || (_editing && empty)
                        ? null
                        : _editing
                        ? _save
                        : widget.onClose,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
