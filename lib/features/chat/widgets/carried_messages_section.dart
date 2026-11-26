import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/carried_original.dart';
import '../../../core/models/context_operation.dart';
import '../../../core/models/native_compaction.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../core/utils/token_estimator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/text_input/message_editing_controller.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/long_message_editor.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../pages/context_summary_editor_page.dart';
import 'context_dialog.dart';

class CarriedMessagesSection extends StatelessWidget {
  const CarriedMessagesSection({
    super.key,
    required this.operation,
    this.onSave,
    this.onSource,
    this.estimate,
    this.sourceIds = const {},
    this.imported = false,
  });
  final ContextOperation operation;
  final Future<bool> Function(CarriedOriginals)? onSave;
  final ValueChanged<String>? onSource;
  final Future<CompressionBudget?> Function(CarriedOriginals)? estimate;
  final Set<String> sourceIds;
  final bool imported;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final carried = operation.carried;
    final legacy = carried == null
        ? operation.nativePayload?.output
                  .where((i) => i['role'] == 'user')
                  .toList() ??
              []
        : [];
    final items =
        carried?.items ??
        [
          for (var i = 0; i < legacy.length; i++)
            CarriedOriginal(
              sourceMessageId: '$i',
              sourceGroupId: '',
              sourceVersion: 0,
              contentHash: '',
              text: carriedWireText(legacy[i]),
            ),
        ];
    if (items.isEmpty && (carried?.notFit ?? 0) == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            operation.nativePayload?.protocol ==
                    NativeCompactionProtocol.compact
                ? l.contextDetailServerKept
                : l.contextDetailCarried,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _CarriedMessageRow(
              key: ValueKey(item.sourceMessageId),
              item: item,
              deleted:
                  carried != null &&
                  !imported &&
                  !sourceIds.contains(item.sourceMessageId),
              sourceLabel: imported
                  ? l.compressionNativeOpenSource
                  : l.quoteJumpToSource,
              onSource:
                  carried == null ||
                      onSource == null ||
                      (!imported && !sourceIds.contains(item.sourceMessageId))
                  ? null
                  : () => onSource!(item.sourceMessageId),
              onSave: carried == null || onSave == null
                  ? null
                  : (value) => onSave!(
                      carried.withItems([
                        for (final entry in carried.items)
                          if (entry.sourceMessageId ==
                              item.sourceMessageId) ...[
                            if (value != null) value,
                          ] else
                            entry,
                      ]),
                    ),
              estimate: carried == null || estimate == null
                  ? null
                  : (value) => estimate!(
                      carried.withItems([
                        for (final entry in carried.items)
                          entry.sourceMessageId == item.sourceMessageId
                              ? value
                              : entry,
                      ]),
                    ),
            ),
          if ((carried?.notFit ?? 0) > 0)
            Text(
              l.compressionCarryNotFit(carried!.notFit),
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _CarriedMessageRow extends StatefulWidget {
  const _CarriedMessageRow({
    super.key,
    required this.item,
    required this.deleted,
    required this.sourceLabel,
    this.onSave,
    this.onSource,
    this.estimate,
  });
  final CarriedOriginal item;
  final bool deleted;
  final String sourceLabel;
  final Future<bool> Function(CarriedOriginal?)? onSave;
  final VoidCallback? onSource;
  final Future<CompressionBudget?> Function(CarriedOriginal)? estimate;
  @override
  State<_CarriedMessageRow> createState() => _CarriedMessageRowState();
}

class _CarriedMessageRowState extends State<_CarriedMessageRow> {
  final _editor = MessageEditingController();
  bool _expanded = false, _editing = false, _reply = false, _saving = false;
  String? _error;
  Timer? _debounce;
  CompressionBudget? _editBudget;
  int _revision = 0;
  @override
  void dispose() {
    _debounce?.cancel();
    _editor.dispose();
    super.dispose();
  }

  CarriedOriginal edited(String text, bool reply) => reply
      ? widget.item.copyWith(
          reply: widget.item.reply!.copyWith(editedText: text),
        )
      : widget.item.copyWith(editedText: text);
  void _changed(String text) {
    setState(() {});
    final revision = ++_revision;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final budget = await widget.estimate?.call(edited(text, _reply));
      if (mounted && revision == _revision) {
        setState(() => _editBudget = budget);
      }
    });
  }

  Future<bool> _save(CarriedOriginal? value) async {
    if (_saving) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      return await widget.onSave!(value);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(bool reply) async {
    final l = AppLocalizations.of(context)!;
    final text = reply
        ? widget.item.reply!.effectiveText
        : widget.item.effectiveText;
    if (PlatformUtils.isDesktopTarget) {
      _editor.text = text;
      setState(() {
        _editing = true;
        _reply = reply;
      });
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContextSummaryEditorPage(
          summary: text,
          hint: l.contextCarriedEditHint,
          emptyHint: l.contextCarriedEmpty,
          title: reply ? l.contextCarriedReplyLabel : l.contextDetailCarried,
          estimate: (value) async =>
              await widget.estimate?.call(edited(value, reply)) ??
              (usedTokens: estimateTokens(value), contextWindow: null),
          onSave: (value) => _save(edited(value, reply)),
        ),
      ),
    );
  }

  Future<void> _remove() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContextDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.contextCarriedRemoveConfirm),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: IosTextButton(
                    label: l.homePageCancel,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                Expanded(
                  child: IosTextButton(
                    label: l.contextCarriedRemove,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) await _save(null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    Widget action(String label, VoidCallback callback) => IosTextButton(
      label: label,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      onPressed: _saving ? null : callback,
    );
    Widget badge(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosCardPress(
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              item.effectiveText,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
          ),
          if (item.isEdited) badge(l.contextDetailEdited),
          if (item.truncated) badge(l.compressionCarryTruncated),
          if (widget.deleted) badge(l.contextCarriedSourceDeleted),
          Wrap(
            children: [
              action(
                l.assistantSettingsCopyButton,
                () =>
                    Clipboard.setData(ClipboardData(text: item.effectiveText)),
              ),
              if (widget.onSave != null)
                action(l.assistantSettingsEditButton, () => _edit(false)),
              if (widget.onSave != null && widget.onSource != null)
                action(widget.sourceLabel, widget.onSource!),
              if (widget.onSave != null)
                action(l.contextCarriedRemove, _remove),
            ],
          ),
          if (item.reply case final reply?)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${l.contextCarriedReplyLabel}：${reply.effectiveText}',
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                  if (reply.editedText != null) badge(l.contextDetailEdited),
                  Wrap(
                    children: [
                      action(
                        l.assistantSettingsCopyButton,
                        () => Clipboard.setData(
                          ClipboardData(text: reply.effectiveText),
                        ),
                      ),
                      if (widget.onSave != null) ...[
                        action(
                          l.assistantSettingsEditButton,
                          () => _edit(true),
                        ),
                        action(
                          l.contextCarriedRemoveReply,
                          () => _save(item.copyWith(removeReply: true)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          if (_editing) ...[
            Text(
              l.contextCarriedEditHint,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            SizedBox(
              height: 200,
              child: LongMessageEditor(
                controller: _editor,
                minLines: null,
                maxLines: null,
                expands: true,
                onChanged: _changed,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
            Text(
              _editor.text.trim().isEmpty
                  ? l.contextCarriedEmpty
                  : l.contextEditPreview(
                      contextTokenValue(
                        _editBudget?.usedTokens ?? estimateTokens(_editor.text),
                      ),
                    ),
              style: TextStyle(
                fontSize: 12,
                color: _editor.text.trim().isEmpty
                    ? cs.error
                    : cs.onSurfaceVariant,
              ),
            ),
            Wrap(
              children: [
                action(
                  l.homePageCancel,
                  () => setState(() => _editing = false),
                ),
                IosTextButton(
                  label: l.messageEditPageSave,
                  onPressed: _saving || _editor.text.trim().isEmpty
                      ? null
                      : () async {
                          await _editor.flushMessageInput();
                          if (_editor.text.trim().isEmpty) return;
                          if (await _save(edited(_editor.text, _reply)) &&
                              mounted) {
                            setState(() => _editing = false);
                          }
                        },
                ),
              ],
            ),
          ],
          if (_error != null)
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
        ],
      ),
    );
  }
}
