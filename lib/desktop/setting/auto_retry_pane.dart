import 'dart:async';

import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/auto_retry_options.dart';
import '../../core/providers/settings_provider.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_switch.dart';
import '../../shared/widgets/ios_tactile.dart';

class DesktopAutoRetryPane extends StatefulWidget {
  const DesktopAutoRetryPane({super.key});

  @override
  State<DesktopAutoRetryPane> createState() => _DesktopAutoRetryPaneState();
}

class _DesktopAutoRetryPaneState extends State<DesktopAutoRetryPane> {
  late final SettingsProvider _settingsProvider;
  late final TextEditingController _maxRetriesCtl;
  late final TextEditingController _initialDelayCtl;
  late final TextEditingController _multiplierCtl;
  late final TextEditingController _maxDelayCtl;
  late final TextEditingController _codeInputCtl;
  late final TextEditingController _retryKeywordCtl;
  late final TextEditingController _stopKeywordCtl;
  final FocusNode _maxRetriesFn = FocusNode();
  final FocusNode _initialDelayFn = FocusNode();
  final FocusNode _multiplierFn = FocusNode();
  final FocusNode _maxDelayFn = FocusNode();
  var _disposing = false;

  @override
  void initState() {
    super.initState();
    _settingsProvider = context.read<SettingsProvider>();
    final options = _settingsProvider.autoRetryOptions;
    _maxRetriesCtl = TextEditingController(text: '${options.maxRetries}');
    _initialDelayCtl = TextEditingController(text: '${options.initialDelayMs}');
    _multiplierCtl = TextEditingController(
      text: _formatMultiplier(options.multiplier),
    );
    _maxDelayCtl = TextEditingController(text: '${options.maxDelayMs}');
    _codeInputCtl = TextEditingController();
    _retryKeywordCtl = TextEditingController();
    _stopKeywordCtl = TextEditingController();
    _maxRetriesFn.addListener(() {
      if (!_maxRetriesFn.hasFocus) _commitNumbers();
    });
    _initialDelayFn.addListener(() {
      if (!_initialDelayFn.hasFocus) _commitNumbers();
    });
    _multiplierFn.addListener(() {
      if (!_multiplierFn.hasFocus) _commitNumbers();
    });
    _maxDelayFn.addListener(() {
      if (!_maxDelayFn.hasFocus) _commitNumbers();
    });
  }

  @override
  void dispose() {
    _disposing = true;
    final next = _parsedNumbers();
    final settings = _settingsProvider;
    scheduleMicrotask(() {
      settings.setAutoRetryOptions(next);
    });
    _maxRetriesFn.dispose();
    _initialDelayFn.dispose();
    _multiplierFn.dispose();
    _maxDelayFn.dispose();
    _maxRetriesCtl.dispose();
    _initialDelayCtl.dispose();
    _multiplierCtl.dispose();
    _maxDelayCtl.dispose();
    _codeInputCtl.dispose();
    _retryKeywordCtl.dispose();
    _stopKeywordCtl.dispose();
    super.dispose();
  }

  AutoRetryOptions get _options => _settingsProvider.autoRetryOptions;

  Future<void> _save(AutoRetryOptions next) {
    return _settingsProvider.setAutoRetryOptions(next);
  }

  String _formatMultiplier(double value) {
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toString();
  }

  AutoRetryOptions _parsedNumbers() {
    return _options.copyWith(
      maxRetries:
          int.tryParse(_maxRetriesCtl.text.trim()) ?? _options.maxRetries,
      initialDelayMs:
          int.tryParse(_initialDelayCtl.text.trim()) ?? _options.initialDelayMs,
      multiplier:
          double.tryParse(_multiplierCtl.text.trim()) ?? _options.multiplier,
      maxDelayMs: int.tryParse(_maxDelayCtl.text.trim()) ?? _options.maxDelayMs,
    );
  }

  void _commitNumbers({bool syncField = true}) {
    if (_disposing) return;
    final next = _parsedNumbers();
    if (syncField) {
      _maxRetriesCtl.text = '${next.maxRetries}';
      _initialDelayCtl.text = '${next.initialDelayMs}';
      _multiplierCtl.text = _formatMultiplier(next.multiplier);
      _maxDelayCtl.text = '${next.maxDelayMs}';
    }
    _save(next);
  }

  Widget _numberField({
    required TextEditingController controller,
    required FocusNode focusNode,
    bool decimal = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [if (!decimal) FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 14),
        decoration: _deskInputDecoration(context),
        onChanged: (_) => _commitNumbers(syncField: false),
        onEditingComplete: _commitNumbers,
        onSubmitted: (_) => _commitNumbers(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final options = context.watch<SettingsProvider>().autoRetryOptions;
    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.settingsPageAutoRetry,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.regular,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SectionCard(
                children: [
                  _ItemRow(
                    label: l10n.autoRetryEnableLabel,
                    vpad: 4,
                    trailing: IosSwitch(
                      value: options.enabled,
                      onChanged: (v) => _save(options.copyWith(enabled: v)),
                    ),
                  ),
                  _rowDivider(context),
                  _ItemRow(
                    label: l10n.autoRetryMaxRetries,
                    trailing: _numberField(
                      controller: _maxRetriesCtl,
                      focusNode: _maxRetriesFn,
                    ),
                  ),
                  _rowDivider(context),
                  _ItemRow(
                    label: l10n.autoRetryInitialDelay,
                    trailing: _numberField(
                      controller: _initialDelayCtl,
                      focusNode: _initialDelayFn,
                    ),
                  ),
                  _rowDivider(context),
                  _ItemRow(
                    label: l10n.autoRetryMultiplier,
                    trailing: _numberField(
                      controller: _multiplierCtl,
                      focusNode: _multiplierFn,
                      decimal: true,
                    ),
                  ),
                  _rowDivider(context),
                  _ItemRow(
                    label: l10n.autoRetryMaxDelay,
                    trailing: _numberField(
                      controller: _maxDelayCtl,
                      focusNode: _maxDelayFn,
                    ),
                  ),
                  _rowDivider(context),
                  _ItemRow(
                    label: l10n.autoRetryJitter,
                    trailing: IosSwitch(
                      value: options.jitter,
                      onChanged: (v) => _save(options.copyWith(jitter: v)),
                    ),
                  ),
                  _rowDivider(context),
                  _ItemRow(
                    label: l10n.autoRetryOnNetworkError,
                    trailing: IosSwitch(
                      value: options.retryOnNetworkError,
                      onChanged: (v) =>
                          _save(options.copyWith(retryOnNetworkError: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _chipCard(
                context,
                title: l10n.autoRetryStatusCodes,
                values: [
                  for (final code
                      in (options.retryStatusCodes.toList()..sort()))
                    '$code',
                ],
                controller: _codeInputCtl,
                keyboardType: TextInputType.number,
                onAdd: (raw) {
                  final code = int.tryParse(raw.trim());
                  if (code == null || code < 100 || code > 599) return;
                  _save(
                    options.copyWith(
                      retryStatusCodes: {...options.retryStatusCodes, code},
                    ),
                  );
                },
                onRemove: (raw) {
                  final code = int.tryParse(raw);
                  if (code == null) return;
                  _save(
                    options.copyWith(
                      retryStatusCodes: {...options.retryStatusCodes}
                        ..remove(code),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _chipCard(
                context,
                title: l10n.autoRetryKeywords,
                values: options.retryKeywords,
                controller: _retryKeywordCtl,
                onAdd: (raw) {
                  final keyword = raw.trim();
                  if (keyword.isEmpty ||
                      options.retryKeywords.contains(keyword)) {
                    return;
                  }
                  _save(
                    options.copyWith(
                      retryKeywords: [...options.retryKeywords, keyword],
                    ),
                  );
                },
                onRemove: (raw) {
                  _save(
                    options.copyWith(
                      retryKeywords: [
                        for (final k in options.retryKeywords)
                          if (k != raw) k,
                      ],
                    ),
                  );
                },
                onRestore: () => _save(
                  options.copyWith(
                    retryKeywords: AutoRetryOptions.defaultRetryKeywords,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _chipCard(
                context,
                title: l10n.autoRetryStopKeywords,
                values: options.stopKeywords,
                controller: _stopKeywordCtl,
                onAdd: (raw) {
                  final keyword = raw.trim();
                  if (keyword.isEmpty ||
                      options.stopKeywords.contains(keyword)) {
                    return;
                  }
                  _save(
                    options.copyWith(
                      stopKeywords: [...options.stopKeywords, keyword],
                    ),
                  );
                },
                onRemove: (raw) {
                  _save(
                    options.copyWith(
                      stopKeywords: [
                        for (final k in options.stopKeywords)
                          if (k != raw) k,
                      ],
                    ),
                  );
                },
                onRestore: () => _save(
                  options.copyWith(
                    stopKeywords: AutoRetryOptions.defaultStopKeywords,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  l10n.autoRetryFooter,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _chipCard(
  BuildContext context, {
  required String title,
  required List<String> values,
  required TextEditingController controller,
  required void Function(String raw) onAdd,
  required void Function(String raw) onRemove,
  VoidCallback? onRestore,
  TextInputType? keyboardType,
}) {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  return SectionCard(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
            if (onRestore != null)
              IosCardPress(
                onTap: onRestore,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  l10n.autoRetryRestoreDefaults,
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              _Chip(label: value, onRemove: () => onRemove(value)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 14),
                onSubmitted: (v) {
                  onAdd(v);
                  controller.clear();
                },
                decoration: _deskInputDecoration(
                  context,
                ).copyWith(hintText: l10n.autoRetryAddHint),
              ),
            ),
            const SizedBox(width: 8),
            IosIconButton(
              icon: Lucide.Plus,
              size: 18,
              color: cs.primary,
              onTap: () {
                onAdd(controller.text);
                controller.clear();
              },
            ),
          ],
        ),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.36 : 0.26),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 4,
              top: 6,
              bottom: 6,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
          IosIconButton(
            icon: Lucide.X,
            size: 14,
            padding: const EdgeInsets.all(6),
            color: cs.onSurface.withValues(alpha: 0.65),
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

Widget _rowDivider(BuildContext context) {
  return Container(height: 1, color: context.appColors.hairline);
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.label, required this.trailing, this.vpad = 8});
  final String label;
  final Widget trailing;
  final double vpad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vpad),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.88),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

InputDecoration _deskInputDecoration(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: context.appColors.surfaceCardFill,
    hintStyle: TextStyle(
      fontSize: 14,
      color: cs.onSurface.withValues(alpha: 0.5),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.12),
        width: 0.6,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.12),
        width: 0.6,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
    ),
  );
}
