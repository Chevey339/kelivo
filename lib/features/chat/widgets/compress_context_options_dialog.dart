import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/compress_context_options.dart';
import '../../../core/models/context_operation.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/utils/token_estimator.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../model/widgets/model_select_sheet.dart';
import 'context_dialog.dart';

class CompressContextOptionsDialog extends StatefulWidget {
  const CompressContextOptionsDialog({
    super.key,
    required this.messages,
    required this.operations,
    this.messageWindow,
    this.initialOptions,
    this.prepareInput,
    this.estimateContext,
  });
  final List<ChatMessage> messages;
  final List<ContextOperation> operations;
  final int? messageWindow;
  final CompressContextOptions? initialOptions;
  final Future<List<ChatMessage>> Function(List<ChatMessage>, bool)?
  prepareInput;
  final Future<CompressionBudget> Function(List<ChatMessage>)? estimateContext;
  @override
  State<CompressContextOptionsDialog> createState() =>
      _CompressContextOptionsDialogState();
}

class _CompressContextOptionsDialogState
    extends State<CompressContextOptionsDialog> {
  late CompressContextLimitMode _mode;
  ContextHistorySource _source = ContextHistorySource.effective;
  bool _includeManual = true;
  bool _includeAttachments = true;
  bool _advanced = false;
  bool _adjusting = false;
  late final TextEditingController _maxChars;
  late final TextEditingController _keep;
  int _estimateRevision = 0;
  int? _inputTokens;
  int? _summaryMin;
  int? _summaryMax;
  int? _nextMin;
  int? _nextMax;
  int? _original;
  bool _saving = false;

  CompressContextOptions _options({
    bool regenerate = false,
    bool? includeManual,
  }) => CompressContextOptions(
    mode: _mode,
    maxChars: int.tryParse(_maxChars.text),
    keepUserMessages: int.tryParse(_keep.text),
    historySource: _source,
    includeEditedSummaries: includeManual ?? _includeManual,
    includeAttachmentsAndTools: _includeAttachments,
    regenerateExisting: regenerate,
  );
  CompressionSelection get _selection =>
      selectCompressionHistory(widget.messages, widget.operations, _options());
  bool get _valid =>
      !_saving &&
      _selection.covered.isNotEmpty &&
      !_selection.needsRegeneration &&
      (_mode != CompressContextLimitMode.keepRecent ||
          (int.tryParse(_keep.text) ?? 0) > 0) &&
      ((_mode != CompressContextLimitMode.start &&
              _mode != CompressContextLimitMode.recent) ||
          (int.tryParse(_maxChars.text) ?? 0) > 0);

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final initial = widget.initialOptions;
    _mode = initial?.mode ?? settings.compressLimitMode;
    _source = initial?.historySource ?? ContextHistorySource.effective;
    _includeManual = initial?.includeEditedSummaries ?? true;
    _includeAttachments = initial?.includeAttachmentsAndTools ?? true;
    _maxChars = TextEditingController(
      text: (initial?.maxChars ?? settings.compressMaxChars).toString(),
    );
    _keep = TextEditingController(
      text:
          (initial?.keepUserMessages ?? settings.compressKeepUserMessages ?? 6)
              .toString(),
    );
    _refreshEstimate();
  }

  @override
  void dispose() {
    _maxChars.dispose();
    _keep.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(change);
    _refreshEstimate();
  }

  Future<void> _refreshEstimate() async {
    final revision = ++_estimateRevision;
    final options = _options();
    final selection = selectCompressionHistory(
      widget.messages,
      widget.operations,
      options,
    );
    try {
      final input =
          await widget.prepareInput?.call(
            selection.input,
            _includeAttachments,
          ) ??
          selection.input;
      final chunks = buildCompressRequestContents(input, options);
      final inputTokens = chunks.fold<int>(
        0,
        (sum, text) => sum + estimateTokens(text),
      );
      final min = (inputTokens * .10).round();
      final max = (inputTokens * .30).round();
      final values = await Future.wait([
        if (widget.estimateContext != null)
          widget.estimateContext!(selection.effective),
        if (widget.estimateContext != null)
          widget.estimateContext!(selection.retained),
      ]);
      if (!mounted || revision != _estimateRevision) return;
      setState(() {
        _inputTokens = inputTokens;
        _summaryMin = min;
        _summaryMax = max;
        _original = values.isEmpty ? null : values.first.usedTokens;
        _nextMin = values.isEmpty ? null : values.last.usedTokens + min;
        _nextMax = values.isEmpty ? null : values.last.usedTokens + max;
      });
    } catch (_) {
      if (mounted && revision == _estimateRevision) {
        setState(() {
          _inputTokens = null;
          _summaryMin = null;
          _summaryMax = null;
          _nextMin = null;
          _nextMax = null;
          _original = null;
        });
      }
    }
  }

  Future<void> _submit({bool regenerate = false}) async {
    if (_saving || (!regenerate && !_valid)) return;
    setState(() => _saving = true);
    final settings = context.read<SettingsProvider>();
    final options = _options(regenerate: regenerate);
    try {
      await settings.setCompressLimitMode(_mode);
      if ((options.keepUserMessages ?? 0) > 0) {
        await settings.setCompressKeepUserMessages(options.keepUserMessages);
      }
      if ((options.maxChars ?? 0) > 0) {
        await settings.setCompressMaxChars(options.maxChars!);
      }
      if (mounted) Navigator.of(context).pop(options);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final selection = _selection;
    final keep = int.tryParse(_keep.text) ?? 0;
    final short = selection.covered.isEmpty;
    final manualCount = selectCompressionHistory(
      widget.messages,
      widget.operations,
      _options(includeManual: true),
    ).input.where((m) => m.id.startsWith('context-note:')).length;
    if (selection.needsRegeneration && !_adjusting) {
      return ContextDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.compressNothingNew,
              style: TextStyle(
                fontSize: 17,
                fontWeight: AppFontWeights.emphasis,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.compressContextKeepAllMessages,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ContextDialogActionButton(
                    label: l10n.statsPageClose,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ContextDialogActionButton(
                    label: l10n.compressAdjust,
                    onTap: () => setState(() => _adjusting = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ContextDialogActionButton(
                    label: l10n.compressRegenerate,
                    primary: true,
                    onTap: _saving ? null : () => _submit(regenerate: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return ContextDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Lucide.package2, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.compressContextOptionsTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.compressContextOptionsDesc,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _CompressModelPickerRow(),
                  const SizedBox(height: 12),
                  _CompressModeSegmented(
                    mode: _mode,
                    onChanged: (mode) => _update(() => _mode = mode),
                  ),
                  const SizedBox(height: 10),
                  if (_mode == CompressContextLimitMode.keepRecent) ...[
                    IosFormTextField(
                      label: l10n.compressContextKeepCountLabel,
                      controller: _keep,
                      keyboardType: TextInputType.number,
                      fieldWidth: 100,
                      selectAllOnFocus: true,
                      onChanged: (_) => _update(() {}),
                    ),
                    _note(
                      keep <= 0
                          ? l10n.contextKeepInvalid
                          : short || selection.needsRegeneration
                          ? l10n.compressContextKeepAllMessages
                          : l10n.compressKeepDescription(keep),
                      color: keep <= 0 || short || selection.needsRegeneration
                          ? cs.error
                          : null,
                    ),
                  ] else if (_mode == CompressContextLimitMode.start ||
                      _mode == CompressContextLimitMode.recent) ...[
                    IosFormTextField(
                      label: l10n.compressContextMaxCharsLabel,
                      controller: _maxChars,
                      keyboardType: TextInputType.number,
                      fieldWidth: 100,
                      selectAllOnFocus: true,
                      onChanged: (_) => _update(() {}),
                    ),
                    _note(
                      l10n.contextSampledInfo(
                        int.tryParse(_maxChars.text) ?? 0,
                      ),
                      color: context.appColors.warning,
                    ),
                  ] else
                    _note(l10n.contextSourceScopeHint),
                  if (_mode != CompressContextLimitMode.unlimited)
                    _note(l10n.contextSourceScopeHint),
                  if (widget.messageWindow != null)
                    _note(l10n.contextHistoryWindowNote(widget.messageWindow!)),
                  if (!short) ...[
                    const SizedBox(height: 12),
                    CompressionUsageCards(
                      inputTokens: _inputTokens,
                      summaryMin: _summaryMin,
                      summaryMax: _summaryMax,
                      nextMin: _nextMin,
                      nextMax: _nextMax,
                      original: _original,
                    ),
                  ],
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _advanced = !_advanced),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _advanced
                                ? Lucide.ChevronDown
                                : Lucide.ChevronRight,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n.compressAdvanced,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _source == ContextHistorySource.effective
                                  ? l10n.compressAdvancedOff
                                  : l10n.compressAdvancedOn,
                              textAlign: TextAlign.end,
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
                  if (_advanced)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _switch(
                            l10n.compressReread,
                            l10n.compressRereadDesc,
                            _source != ContextHistorySource.effective,
                            (value) => _update(
                              () => _source = value
                                  ? ContextHistorySource.previous
                                  : ContextHistorySource.effective,
                            ),
                          ),
                          if (_source != ContextHistorySource.effective) ...[
                            RadioGroup<ContextHistorySource>(
                              groupValue: _source,
                              onChanged: (value) {
                                if (value != null) {
                                  _update(() => _source = value);
                                }
                              },
                              child: Column(
                                children: [
                                  for (final source in [
                                    ContextHistorySource.previous,
                                    ContextHistorySource.original,
                                  ])
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          height: 36,
                                          child: Radio<ContextHistorySource>(
                                            value: source,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                _update(() => _source = source),
                                            child: Text(
                                              source ==
                                                      ContextHistorySource
                                                          .previous
                                                  ? l10n.compressRereadLastLayer
                                                  : l10n.compressRereadAll,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  IosCheckbox(
                                    value: _includeManual,
                                    onChanged: (value) =>
                                        _update(() => _includeManual = value),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.compressIncludeManual(manualCount),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Divider(height: 1, color: context.appColors.hairline),
                          _switch(
                            l10n.compressIncludeAttachments,
                            l10n.compressIncludeAttachmentsDesc,
                            _includeAttachments,
                            (value) =>
                                _update(() => _includeAttachments = value),
                          ),
                        ],
                      ),
                    ),
                  if (selection.needsRegeneration)
                    IosTextButton(
                      label: l10n.compressRegenerate,
                      onPressed: _saving
                          ? null
                          : () => _submit(regenerate: true),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ContextDialogActionButton(
                  label: l10n.homePageCancel,
                  onTap: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ContextDialogActionButton(
                  label: l10n.compressContextStartButton,
                  primary: true,
                  onTap: _valid ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _note(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _switch(
    String label,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IosSwitch(
          value: value,
          width: 40,
          height: 24,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class CompressionUsageCards extends StatelessWidget {
  const CompressionUsageCards({
    super.key,
    this.inputTokens,
    this.summaryMin,
    this.summaryMax,
    this.nextMin,
    this.nextMax,
    this.original,
  });
  final int? inputTokens, summaryMin, summaryMax, nextMin, nextMax, original;
  String _range(int? a, int? b) => a == null || b == null
      ? '—'
      : a == b
      ? contextTokenValue(a)
      : '${contextTokenValue(a)}–${contextTokenValue(b)}';
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _card(
            context,
            l10n.compressUsageInput,
            inputTokens == null ? '—' : contextTokenValue(inputTokens!),
            'tokens',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _card(
            context,
            l10n.compressUsageSummary,
            _range(summaryMin, summaryMax),
            'tokens',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _card(
            context,
            l10n.compressUsageNext,
            _range(nextMin, nextMax),
            original == null
                ? 'tokens'
                : l10n.compressUsageOriginal(contextTokenValue(original!)),
            primary: true,
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    String value,
    String foot, {
    bool primary = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
            child: Text(
              title,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
                color: primary ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String? _compressModelDisplayName(
  SettingsProvider settings, {
  required String? providerKey,
  required String? modelId,
}) {
  if (providerKey == null || modelId == null) return null;
  try {
    final cfg = settings.getProviderConfig(providerKey);
    final ov = cfg.modelOverrides[modelId] as Map?;
    if (ov != null) {
      final overrideName = (ov['name'] as String?)?.trim();
      if (overrideName != null && overrideName.isNotEmpty) {
        return overrideName;
      }
      final apiId = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
      if (apiId != null && apiId.isNotEmpty) return apiId;
    }
    return modelId;
  } catch (_) {
    return modelId;
  }
}

class _CompressModelPickerRow extends StatelessWidget {
  const _CompressModelPickerRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    final resolved = resolveCompressContextModel(
      compressProvider: settings.compressModelProvider,
      compressModelId: settings.compressModelId,
      summaryProvider: settings.summaryModelProvider,
      summaryModelId: settings.summaryModelId,
      titleProvider: settings.titleModelProvider,
      titleModelId: settings.titleModelId,
      assistantProvider: assistant?.chatModelProvider,
      assistantModelId: assistant?.chatModelId,
      currentProvider: settings.currentModelProvider,
      currentModelId: settings.currentModelId,
    );
    final display =
        _compressModelDisplayName(
          settings,
          providerKey: resolved.providerKey,
          modelId: resolved.modelId,
        ) ??
        l10n.compressContextModelUnset;
    return IosCardPress(
      baseColor: context.appColors.surfaceFill,
      borderRadius: BorderRadius.circular(14),
      pressedScale: .98,
      haptics: false,
      onTap: () async {
        final selected = await showModelSelector(
          context,
          initialProviderKey: resolved.providerKey,
          initialModelId: resolved.modelId,
        );
        if (selected != null && context.mounted) {
          await context.read<SettingsProvider>().setCompressModel(
            selected.providerKey,
            selected.modelId,
          );
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Lucide.Sparkles, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.compressContextModelLabel,
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.compressModelGlobal,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Lucide.ChevronRight, size: 15, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _CompressModeSegmented extends StatelessWidget {
  const _CompressModeSegmented({required this.mode, required this.onChanged});
  final CompressContextLimitMode mode;
  final ValueChanged<CompressContextLimitMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modes = {
      CompressContextLimitMode.keepRecent:
          l10n.compressContextKeepRecentMessages,
      CompressContextLimitMode.unlimited: l10n.compressContextUnlimited,
      CompressContextLimitMode.start: l10n.compressContextKeepStart,
      CompressContextLimitMode.recent: l10n.compressContextKeepRecent,
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final entry in modes.entries)
            Expanded(
              child: _SegmentButton(
                label: entry.value,
                selected: mode == entry.key,
                onTap: () => onChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? cs.primary.withValues(alpha: 0.22)
        : cs.primary.withValues(alpha: 0.12);
    final baseBg = context.appColors.surfaceFill;

    return IosCardPress(
      baseColor: selected ? selectedBg : baseBg,
      borderRadius: BorderRadius.circular(10),
      pressedScale: 0.98,
      onTap: onTap,
      haptics: false,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.emphasis,
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}
