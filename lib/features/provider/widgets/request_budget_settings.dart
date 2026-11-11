import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/request_budget.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';

class ProviderRequestBudgetRow extends StatelessWidget {
  const ProviderRequestBudgetRow({super.key, required this.providerId});
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.getProviderConfig(providerId);
    return RequestBudgetRow(
      value: config.requestBudget,
      inherited: config.defaultRequestBudget,
      onChanged: (value) => settings.setProviderConfig(
        providerId,
        settings.getProviderConfig(providerId).copyWith(requestBudget: value),
      ),
    );
  }
}

class RequestBudgetRow extends StatelessWidget {
  const RequestBudgetRow({
    super.key,
    required this.value,
    required this.inherited,
    required this.onChanged,
    this.modelOverride = false,
  });
  final RequestBudgetOverrides value;
  final RequestBudget inherited;
  final Future<void> Function(RequestBudgetOverrides) onChanged;
  final bool modelOverride;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return IosNavRow(
      label: l.requestBudgetTitle,
      detailText: value.isEmpty
          ? l.requestBudgetInherited
          : l.requestBudgetCustom,
      onTap: () async {
        final next = await showDialog<RequestBudgetOverrides>(
          context: context,
          builder: (_) => RequestBudgetEditor(
            value: value,
            inherited: inherited,
            modelOverride: modelOverride,
          ),
        );
        if (next != null && context.mounted) await onChanged(next);
      },
    );
  }
}

class RequestBudgetEditor extends StatefulWidget {
  const RequestBudgetEditor({
    super.key,
    required this.value,
    required this.inherited,
    this.modelOverride = false,
  });
  final RequestBudgetOverrides value;
  final RequestBudget inherited;
  final bool modelOverride;

  @override
  State<RequestBudgetEditor> createState() => _RequestBudgetEditorState();
}

class _RequestBudgetEditorState extends State<RequestBudgetEditor> {
  late final _fields = [
    TextEditingController(text: _mib(widget.value.singleImageBytes)),
    TextEditingController(text: _mib(widget.value.totalImageBytes)),
    TextEditingController(text: widget.value.imageCount?.toString() ?? ''),
    TextEditingController(text: _mib(widget.value.bodyBytes)),
  ];
  String? _error;

  String _mib(int? bytes) {
    if (bytes == null) return '';
    final value = bytes / RequestBudget.mib;
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : '$value';
  }

  void _save() {
    final values = <int?>[];
    for (var i = 0; i < _fields.length; i++) {
      final text = _fields[i].text.trim();
      if (text.isEmpty) {
        values.add(null);
        continue;
      }
      final number = double.tryParse(text);
      final bytes = i == 2
          ? number
          : number == null
          ? null
          : number * RequestBudget.mib;
      if (bytes == null ||
          !bytes.isFinite ||
          bytes < 1 ||
          bytes > 9007199254740991 ||
          (i == 2 && bytes != bytes.truncateToDouble())) {
        setState(
          () => _error = AppLocalizations.of(context)!.requestBudgetInvalid,
        );
        return;
      }
      values.add(bytes.round());
    }
    Navigator.of(context).pop(
      RequestBudgetOverrides(
        singleImageBytes: values[0],
        totalImageBytes: values[1],
        imageCount: values[2],
        bodyBytes: values[3],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _fields) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final labels = [
      l.requestBudgetSingleImage,
      l.requestBudgetTotalImages,
      l.requestBudgetImageCount,
      l.requestBudgetBody,
    ];
    final hints = [
      _mib(widget.inherited.singleImageBytes),
      _mib(widget.inherited.totalImageBytes),
      '${widget.inherited.imageCount}',
      _mib(widget.inherited.bodyBytes),
    ];
    return SafeArea(
      child: Padding(
        padding: MediaQuery.viewInsetsOf(context),
        child: DesktopFormDialog(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesktopFormDialogHeader(
                title: l.requestBudgetTitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${widget.modelOverride ? l.requestBudgetModelHelp : l.requestBudgetProviderHelp}\n\n${l.requestBudgetRetentionHelp}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: .6),
                          ),
                        ),
                      ),
                      for (var i = 0; i < _fields.length; i++)
                        IosFormTextField(
                          key: ValueKey('request-budget-$i'),
                          label: labels[i],
                          controller: _fields[i],
                          hintText: hints[i],
                          fieldWidth: 110,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: i != 2,
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              DesktopFormDialogFooter(
                secondaryLabel: l.requestBudgetReset,
                onSecondary: () => setState(() {
                  for (final controller in _fields) {
                    controller.clear();
                  }
                  _error = null;
                }),
                primaryLabel: l.assistantEditEmojiDialogSave,
                onPrimary: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
