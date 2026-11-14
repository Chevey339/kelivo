import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/carried_original.dart';
import '../../../core/models/carried_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';
import 'compression_controls.dart';
import 'context_dialog.dart';

class CarriedOptionsSection extends StatefulWidget {
  const CarriedOptionsSection({
    super.key,
    required this.setting,
    required this.preview,
    required this.onSetting,
    required this.onExcluded,
    required this.onReply,
    required this.onEarlier,
    this.onValidity,
    this.codex = false,
    this.serverKeeps = false,
    this.hasSummaries = false,
    this.earlier = false,
    this.automatic = false,
    this.newConversation = false,
    this.loading = false,
    this.replies = const {},
  });
  final CarrySetting setting;
  final CarrySelection preview;
  final ValueChanged<CarrySetting> onSetting;
  final void Function(String, bool) onExcluded, onReply;
  final ValueChanged<bool> onEarlier;
  final ValueChanged<bool>? onValidity;
  final bool codex,
      serverKeeps,
      hasSummaries,
      earlier,
      automatic,
      newConversation,
      loading;
  final Set<String> replies;
  @override
  State<CarriedOptionsSection> createState() => _CarriedOptionsSectionState();
}

class _CarriedOptionsSectionState extends State<CarriedOptionsSection> {
  String _displayCount(CarriedOptionsSection section) =>
      (section.codex && section.setting.mode == CarryMode.unset
              ? section.preview.items.length
              : section.setting.count)
          .toString();
  late final _count = TextEditingController(text: _displayCount(widget));
  final _expanded = <String>{};
  int _shown = 50;
  bool get _auto => widget.codex && widget.setting.mode == CarryMode.unset;
  bool get _all => _auto || widget.setting.mode == CarryMode.all;
  bool get _on => _all || widget.setting.mode == CarryMode.count;
  @override
  void didUpdateWidget(covariant CarriedOptionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _displayCount(widget);
    if ((_displayCount(oldWidget) != text ||
            oldWidget.setting.mode != widget.setting.mode) &&
        _count.text != text) {
      _count.text = text;
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _set(CarryMode mode, [int? count]) {
    widget.onValidity?.call(true);
    widget.onSetting(
      CarrySetting(mode: mode, count: count ?? widget.setting.count),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    Widget hint(String text, {bool warning = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: warning ? context.appColors.warning : cs.onSurfaceVariant,
        ),
      ),
    );
    Widget check(
      String label,
      bool value,
      ValueChanged<bool> change, {
      String? subtitle,
    }) => CompressionSettingRow(
      label: label,
      subtitle: subtitle,
      onTap: () => change(!value),
      trailing: IosCheckbox(
        value: value,
        onChanged: change,
        semanticLabel: label,
      ),
    );
    if (widget.serverKeeps) return hint(l.compressionCarryServerKeeps);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompressionSettingRow(
          label: l.compressionCarryTitle,
          subtitle: !_on ? l.compressionCarryHint : null,
          onTap: () => _set(_on ? CarryMode.off : CarryMode.count),
          trailing: IosSwitch(
            value: _on,
            semanticLabel: l.compressionCarryTitle,
            onChanged: (v) => _set(v ? CarryMode.count : CarryMode.off),
          ),
        ),
        if (_on) ...[
          CompressionNumberRow(
            label: l.compressionCarryCountLabel,
            controller: _count,
            unit: l.compressionCarryUnit,
            enabled: !_all,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n == null || n < 1 || n > 10000) {
                widget.onValidity?.call(false);
              } else {
                _set(CarryMode.count, n);
              }
            },
          ),
          check(
            l.compressionCarryAll,
            _all,
            (v) => _set(v ? CarryMode.all : CarryMode.count),
          ),
          if (_all) hint(l.compressionCarryAllHint),
          if (widget.hasSummaries)
            check(
              l.compressionCarryEarlier,
              widget.earlier,
              widget.onEarlier,
              subtitle: l.compressionCarryEarlierHint,
            ),
          hint(
            l.compressionCarryPreview(
              widget.preview.items.length,
              contextTokenValue(widget.preview.totalTokens),
            ),
          ),
          if (widget.loading)
            const Padding(padding: EdgeInsets.all(12), child: Text('…')),
          if (!widget.loading &&
              widget.preview.rows.isEmpty &&
              widget.preview.notFit == 0)
            hint(l.compressionCarryNone),
          for (final row in widget.preview.rows.take(_shown)) ...[
            Opacity(
              opacity: row.selected ? 1 : .45,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IosCheckbox(
                      value: row.selected,
                      semanticLabel: row.item.effectiveText,
                      onChanged: (v) =>
                          widget.onExcluded(row.item.sourceMessageId, !v),
                    ),
                    Expanded(
                      child: IosCardPress(
                        baseColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        padding: const EdgeInsets.all(4),
                        onTap: () => setState(() {
                          if (!_expanded.add(row.item.sourceMessageId)) {
                            _expanded.remove(row.item.sourceMessageId);
                          }
                        }),
                        child: Text(
                          _excerpt(
                            row.item.effectiveText,
                            _expanded.contains(row.item.sourceMessageId)
                                ? 600
                                : 60,
                          ),
                          maxLines: _expanded.contains(row.item.sourceMessageId)
                              ? 6
                              : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (row.hadAttachments || row.item.hasAttachments) ...[
                      const Icon(LucideIcons.paperclip, size: 13),
                      Text(
                        '${row.attachmentCount.clamp(1, 10000)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l.compressApproxTokens(contextTokenValue(row.tokens)),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (row.replyDoesNotFit) hint(l.compressionCarryNotFit(1)),
            if (row.item.truncated) hint(l.compressionCarryTruncated),
            if (widget.newConversation &&
                (row.hadAttachments || row.item.hasAttachments))
              hint(l.compressionCarryNewChatText),
            if (row.selected && row.availableReply != null)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: CompressionSettingRow(
                  label: l.compressionCarryReply,
                  subtitle: row.replyInRetained
                      ? l.compressionCarryReplyInKept
                      : widget.replies.contains(row.item.sourceMessageId)
                      ? l.compressionCarryReplyTokens(
                          contextTokenValue(
                            row.availableReply!.estimatedTokens,
                          ),
                        )
                      : null,
                  trailing: IosSwitch(
                    value:
                        widget.replies.contains(row.item.sourceMessageId) &&
                        !row.replyInRetained,
                    semanticLabel: l.compressionCarryReply,
                    onChanged: row.replyInRetained
                        ? null
                        : (v) => widget.onReply(row.item.sourceMessageId, v),
                  ),
                ),
              ),
          ],
          if (widget.preview.rows.length > _shown)
            IosTextButton(
              label: l.compressionCarryMoreRows(
                widget.preview.rows.length - _shown,
              ),
              onPressed: () => setState(() => _shown += 50),
            ),
          if (widget.preview.notFit > 0)
            hint(l.compressionCarryNotFit(widget.preview.notFit)),
          if (widget.preview.overBudget) ...[
            hint(l.compressionCarryOverBudget, warning: true),
            if (widget.preview.fitCount > 0)
              IosTextButton(
                label: l.compressionCarryFitAction(widget.preview.fitCount),
                onPressed: () => _set(CarryMode.count, widget.preview.fitCount),
              ),
          ],
          if (widget.automatic) hint(l.compressionCarryAutoToo),
        ],
      ],
    );
  }

  String _excerpt(String text, int length) {
    final head = text.characters.take(length + 1).toString();
    return head.characters.length > length
        ? '${head.characters.take(length)}…'
        : head;
  }
}
