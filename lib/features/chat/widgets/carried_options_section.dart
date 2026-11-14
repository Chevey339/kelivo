import 'package:flutter/material.dart';
import '../../../core/models/carried_original.dart';
import '../../../core/models/carried_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'carried_preview_row.dart';
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
    this.editingSelection = false,
    this.excluded,
    this.replies = const {},
  });
  final CarrySetting setting;
  final CarrySelection? preview;
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
  final bool editingSelection;
  final Set<String>? excluded;
  final Set<String> replies;
  @override
  State<CarriedOptionsSection> createState() => _CarriedOptionsSectionState();
}

class _CarriedOptionsSectionState extends State<CarriedOptionsSection> {
  late final _count = TextEditingController(
    text: widget.setting.count.toString(),
  );
  bool _invalidCount = false;
  int _shown = 50;
  bool get _all =>
      widget.setting.mode == CarryMode.all ||
      (widget.codex && widget.setting.mode == CarryMode.unset);
  bool get _on => _all || widget.setting.mode == CarryMode.count;

  @override
  void didUpdateWidget(covariant CarriedOptionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.count != widget.setting.count ||
        oldWidget.setting.mode != widget.setting.mode) {
      final text = widget.setting.count.toString();
      if (_count.text != text) _count.text = text;
      _invalidCount = false;
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _set(CarryMode mode, [int? count]) {
    if (mode != CarryMode.count) FocusManager.instance.primaryFocus?.unfocus();
    if (_invalidCount) setState(() => _invalidCount = false);
    widget.onValidity?.call(true);
    widget.onSetting(
      CarrySetting(mode: mode, count: count ?? widget.setting.count),
    );
  }

  String _total(AppLocalizations l, CarrySelection preview) {
    if (!widget.loading) {
      return l.compressionCarryPreview(
        preview.items.length,
        contextTokenValue(preview.totalTokens),
      );
    }
    // Count mode has a fixed shortlist. Checkbox and reply changes can be
    // counted immediately without waiting for another snapshot of the chat.
    if (!widget.editingSelection || _all) return l.contextUsageStateComputing;
    var count = 0;
    var tokens = 0;
    for (final row in preview.rows) {
      final id = row.item.sourceMessageId;
      if (widget.excluded?.contains(id) ?? !row.selected) continue;
      count++;
      tokens += row.tokens;
      if (widget.replies.contains(id) && !row.replyInRetained) {
        tokens += row.availableReply?.estimatedTokens ?? 0;
      }
    }
    return l.compressionCarryPreview(count, contextTokenValue(tokens));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final preview = widget.preview;
    final rows = preview?.rows ?? const <CarryRow>[];
    final secondary = TextStyle(
      fontSize: 12,
      height: 1.45,
      color: cs.onSurfaceVariant,
    );
    Widget note(String text, {bool warning = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Text(
        text,
        style: warning
            ? secondary.copyWith(color: context.appColors.warning)
            : secondary,
      ),
    );
    if (widget.serverKeeps) {
      return SectionCard(
        padding: const EdgeInsets.all(14),
        child: Text(l.compressionCarryServerKeeps, style: secondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CompressionSettingRow(
              label: l.compressionCarryTitle,
              subtitle: l.compressionCarryHint,
              onTap: () => _set(_on ? CarryMode.off : CarryMode.count),
              trailing: IosSwitch(
                value: _on,
                semanticLabel: l.compressionCarryTitle,
                onChanged: (v) => _set(v ? CarryMode.count : CarryMode.off),
              ),
            ),
            if (_on) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: SegmentedTabs(
                  radioGroup: true,
                  height: 42,
                  backgroundColor: context.appColors.surfaceFill,
                  tabs: [
                    SegmentedTab(label: l.compressionCarryModeCount),
                    SegmentedTab(label: l.compressionCarryAll),
                  ],
                  index: _all ? 1 : 0,
                  onChanged: (index) =>
                      _set(index == 1 ? CarryMode.all : CarryMode.count),
                ),
              ),
              if (_all)
                note(l.compressionCarryAllHint)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.compressionCarryCountLabel,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 68,
                        child: Semantics(
                          label: l.compressionCarryCountLabel,
                          child: IosFormTextField(
                            label: '',
                            inlineLabel: false,
                            compact: true,
                            outerPadding: EdgeInsets.zero,
                            controller: _count,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            selectAllOnFocus: true,
                            textInputAction: TextInputAction.done,
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n == null || n < 1 || n > 10000) {
                                if (!_invalidCount) {
                                  setState(() => _invalidCount = true);
                                }
                                widget.onValidity?.call(false);
                              } else {
                                _set(CarryMode.count, n);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(l.compressionCarryUnit, style: secondary),
                    ],
                  ),
                ),
              if (_invalidCount)
                note(l.compressionCarryInvalidCount, warning: true),
              if (widget.hasSummaries)
                CompressionSettingRow(
                  label: l.compressionCarryEarlier,
                  subtitle: l.compressionCarryEarlierHint,
                  onTap: () => widget.onEarlier(!widget.earlier),
                  trailing: IosCheckbox(
                    value: widget.earlier,
                    onChanged: widget.onEarlier,
                    semanticLabel: l.compressionCarryEarlier,
                  ),
                ),
              if (widget.automatic) note(l.compressionCarryAutoToo),
            ],
          ],
        ),
        if (_on) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(2, 16, 2, preview == null ? 8 : 3),
            child: Text(
              l.compressionCarryListTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
          ),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(_total(l, preview), style: secondary),
            ),
          if (rows.isNotEmpty)
            SectionCard(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in rows.take(_shown).indexed) ...[
                  if (i > 0)
                    Divider(
                      indent: 14,
                      endIndent: 14,
                      height: 1,
                      color: context.appColors.hairline,
                    ),
                  CarriedPreviewRow(
                    key: ValueKey(row.item.sourceMessageId),
                    row: row,
                    selected: widget.excluded != null
                        ? !widget.excluded!.contains(row.item.sourceMessageId)
                        : row.selected,
                    includeReply: widget.replies.contains(
                      row.item.sourceMessageId,
                    ),
                    newConversation: widget.newConversation,
                    onSelect: (v) =>
                        widget.onExcluded(row.item.sourceMessageId, !v),
                    onReply: (v) => widget.onReply(row.item.sourceMessageId, v),
                  ),
                ],
                if (rows.length > _shown)
                  IosTextButton(
                    label: l.compressionCarryMoreRows(rows.length - _shown),
                    onPressed: () => setState(() => _shown += 50),
                  ),
              ],
            )
          else if (widget.loading || (preview != null && preview.notFit == 0))
            SectionCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                widget.loading ? l.contextLogLoading : l.compressionCarryNone,
                style: secondary,
              ),
            ),
          if (!widget.loading && preview != null) ...[
            if (preview.notFit > 0)
              note(l.compressionCarryNotFit(preview.notFit)),
            if (preview.overBudget) ...[
              note(l.compressionCarryOverBudget, warning: true),
              if (preview.fitCount > 0)
                IosTextButton(
                  label: l.compressionCarryFitAction(preview.fitCount),
                  onPressed: () => _set(CarryMode.count, preview.fitCount),
                ),
            ],
          ],
        ],
      ],
    );
  }
}
