import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../core/utils/token_estimator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/text_input/message_editing_controller.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/long_message_editor.dart';

/// A timeline decoration, never a persisted user/assistant message slot.
class ContextOperationDivider extends StatelessWidget {
  const ContextOperationDivider({
    super.key,
    required this.operation,
    required this.onOpen,
    this.onUndo,
    this.superseded = false,
    this.hiddenByClear = false,
  });
  final ContextOperation operation;
  final VoidCallback onOpen;
  final VoidCallback? onUndo;
  final bool superseded;
  final bool hiddenByClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final base = operation.isCompression
        ? l10n.contextCompressMarker
        : l10n.contextClearMarker;
    final status = operation.revoked
        ? l10n.contextOperationUndone
        : hiddenByClear
        ? l10n.contextOperationHidden
        : superseded
        ? l10n.contextOperationSuperseded
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(child: Divider(color: cs.outlineVariant)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - (operation.revoked ? 44 : 88))
                    .clamp(0.0, constraints.maxWidth)
                    .toDouble(),
              ),
              child: Tooltip(
                message: status.isEmpty ? base : '$base · $status',
                child: IosTextButton(
                  onPressed: onOpen,
                  icon: operation.isCompression
                      ? LucideIcons.layers
                      : LucideIcons.eraser,
                  label: status.isEmpty ? base : '$base · $status',
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            if (!operation.revoked)
              IconButton(
                key: ValueKey('undo-context-${operation.id}'),
                tooltip: l10n.contextOperationUndo,
                onPressed: onUndo,
                icon: const Icon(LucideIcons.x, size: 16),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            Expanded(child: Divider(color: cs.outlineVariant)),
          ],
        ),
      ),
    );
  }
}

/// Shared content; the caller uses a desktop dialog or a mobile sheet.
class ContextOperationContent extends StatefulWidget {
  const ContextOperationContent({
    super.key,
    required this.operation,
    required this.onClose,
    this.onSave,
    this.onUndo,
    this.onViewOriginal,
    this.scrollController,
    this.rangeLabel = '',
    this.initiallyEditing = false,
    this.budget,
    this.undoBudget,
    this.statusLabel = '',
  });
  final ContextOperation operation;
  final VoidCallback onClose;
  final Future<bool> Function(String summary)? onSave;
  final Future<bool> Function()? onUndo;
  final VoidCallback? onViewOriginal;
  final ScrollController? scrollController;
  final String rangeLabel;
  final bool initiallyEditing;
  final CompressionBudget? budget;
  final CompressionBudget? undoBudget;
  final String statusLabel;

  @override
  State<ContextOperationContent> createState() =>
      _ContextOperationContentState();
}

class _ContextOperationContentState extends State<ContextOperationContent> {
  late final MessageEditingController _editor;
  late bool _editing;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _editor = MessageEditingController(text: widget.operation.summary);
    _editing = widget.initiallyEditing;
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    await _editor.flushMessageInput();
    if (!mounted) return;
    if (_editor.text.trim().isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context)!.contextSummaryEmpty,
      );
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final operation = widget.operation;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.statusLabel.isNotEmpty)
                    Text(
                      widget.statusLabel,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  if (operation.revoked)
                    Text(
                      l10n.contextOperationUndone,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  Text(
                    operation.isCompression
                        ? l10n.contextSummaryHint
                        : l10n.contextClearDetails,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.contextRangeInfo(
                      operation.sourceGroups.length,
                      operation.keepUserMessages,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (widget.rangeLabel.isNotEmpty)
                    Text(
                      widget.rangeLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (widget.budget case final budget?)
                    Text(
                      l10n.contextBudgetInfo(
                        budget.usedTokens,
                        budget.contextWindow?.toString() ??
                            l10n.contextUnknownLimit,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (widget.undoBudget case final budget?)
                    Text(
                      l10n.contextUndoBudgetInfo(budget.usedTokens),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (operation.isCompression) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.contextInputModeInfo(
                        switch (operation.inputMode) {
                          'start' => l10n.compressContextKeepStart,
                          'recent' => l10n.compressContextKeepRecent,
                          'keepRecent' =>
                            l10n.compressContextKeepRecentMessages,
                          _ => l10n.compressContextUnlimited,
                        },
                        switch (operation.historySource) {
                          ContextHistorySource.effective =>
                            l10n.contextEffectiveHistory,
                          ContextHistorySource.previous =>
                            l10n.contextPreviousHistory,
                          ContextHistorySource.original =>
                            l10n.contextOriginalHistory,
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (operation.inputMode == 'start' ||
                        operation.inputMode == 'recent')
                      Text(
                        l10n.contextSampledInfo(
                          operation.inputMaxChars ?? 6000,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      l10n.contextSourceScopeHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      l10n.contextTokenInfo(
                        operation.inputTokens,
                        estimateTokens(_editor.text),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (operation.model.isNotEmpty)
                      Text(
                        operation.model,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 16),
                    if (_editing)
                      LongMessageEditor(
                        controller: _editor,
                        minLines: 8,
                        maxLines: 16,
                        onChanged: (_) => setState(() => _error = null),
                        decoration: InputDecoration(
                          labelText: l10n.contextSummaryTitle,
                          border: const OutlineInputBorder(),
                        ),
                      )
                    else
                      SelectableText(operation.summary),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: cs.error)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              if (widget.onViewOriginal != null && !_editing)
                IosTextButton(
                  label: l10n.contextOriginalMessages,
                  onPressed: _saving ? null : widget.onViewOriginal,
                ),
              if (operation.isCompression && !_editing) ...[
                IosTextButton(
                  label: l10n.assistantSettingsCopyButton,
                  icon: LucideIcons.copy,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: operation.summary)),
                ),
                if (widget.onSave != null && !operation.revoked)
                  IosTextButton(
                    label: l10n.assistantSettingsEditButton,
                    icon: LucideIcons.pencil,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editing = true),
                  ),
              ],
              if (!_editing && widget.onUndo != null && !operation.revoked)
                IosTextButton(
                  label: l10n.contextOperationUndo,
                  color: cs.error,
                  onPressed: _saving ? null : _undo,
                ),
              IosTextButton(
                label: _editing ? l10n.homePageCancel : l10n.statsPageClose,
                onPressed: _saving
                    ? null
                    : () {
                        if (_editing && !widget.initiallyEditing) {
                          _editor.text = operation.summary;
                          setState(() {
                            _editing = false;
                            _error = null;
                          });
                        } else {
                          widget.onClose();
                        }
                      },
              ),
              if (_editing)
                IosTextButton(
                  label: l10n.messageEditPageSave,
                  icon: LucideIcons.check,
                  onPressed: _saving ? null : _save,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
