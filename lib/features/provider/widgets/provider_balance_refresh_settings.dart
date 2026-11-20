import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/provider_balance_refresh_interval.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../desktop/widgets/desktop_select_dropdown.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../settings/widgets/custom_theme_widgets.dart';

enum _RefreshScope { provider, global }

enum _ReplySetting { inherit, on, off }

class ProviderBalanceRefreshSettings extends StatefulWidget {
  const ProviderBalanceRefreshSettings({
    super.key,
    required this.providerKey,
    required this.providerDisplayName,
    this.desktopRow,
  });

  final String providerKey;
  final String providerDisplayName;
  final Widget Function(String label, Widget control)? desktopRow;

  @override
  State<ProviderBalanceRefreshSettings> createState() =>
      _ProviderBalanceRefreshSettingsState();
}

class _ProviderBalanceRefreshSettingsState
    extends State<ProviderBalanceRefreshSettings> {
  _RefreshScope _scope = _RefreshScope.provider;

  static const _presets = [0, 1, 5, 15, 30, 60];
  static const _inherit = -1;
  static const _custom = -2;

  static String _intervalLabel(AppLocalizations l10n, int minutes) =>
      switch (minutes) {
        0 => l10n.providerBalanceRefreshOff,
        60 => l10n.providerBalanceRefreshHour,
        _ => l10n.providerBalanceRefreshMinutes(minutes),
      };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final global = _scope == _RefreshScope.global;
    final key = widget.providerKey;
    ProviderConfig currentConfig() => settings.getProviderConfig(
      key,
      defaultName: widget.providerDisplayName,
    );
    final config = currentConfig();
    final interval = global
        ? settings.balanceRefreshInterval
        : config.balanceRefreshInterval;
    final replyTitle = l10n.providerBalanceRefreshOnReply;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _choice(
          context,
          label: l10n.providerBalanceAutoRefresh,
          value: _scope,
          options: [
            OptionSheetItem(
              value: _RefreshScope.provider,
              label: l10n.providerBalanceScopeProvider,
            ),
            OptionSheetItem(
              value: _RefreshScope.global,
              label: l10n.providerBalanceScopeGlobal,
            ),
          ],
          onSelected: (value) => setState(() => _scope = value),
        ),
        _choice(
          context,
          label: l10n.providerBalanceInterval,
          value: interval ?? _inherit,
          options: [
            if (!global)
              OptionSheetItem(
                value: _inherit,
                label: l10n.providerBalanceFollowDefault(
                  _intervalLabel(l10n, settings.balanceRefreshInterval),
                ),
              ),
            for (final minutes in _presets)
              OptionSheetItem(
                value: minutes,
                label: _intervalLabel(l10n, minutes),
              ),
            if (interval != null && !_presets.contains(interval))
              OptionSheetItem(
                value: interval,
                label: _intervalLabel(l10n, interval),
              ),
            OptionSheetItem(
              value: _custom,
              label: l10n.providerBalanceCustomInterval,
            ),
          ],
          onSelected: (choice) async {
            int? minutes = choice == _inherit ? null : choice;
            if (choice == _custom) {
              final initial = interval ?? settings.balanceRefreshInterval;
              minutes = await showAppDialog<int>(
                context,
                maxWidth: 360,
                child: _CustomIntervalDialog(
                  initial: initial > 0 ? initial : 5,
                ),
              );
              if (!context.mounted || minutes == null) return;
            }
            if (minutes == interval) return;
            if (global) {
              await settings.setBalanceRefreshInterval(minutes!);
            } else {
              await settings.setProviderConfig(
                key,
                currentConfig().copyWith(balanceRefreshInterval: minutes),
              );
            }
          },
        ),
        if (global)
          IosSwitchRow(
            padding: EdgeInsets.symmetric(
              vertical: widget.desktopRow == null ? 2 : 6,
            ),
            focusable: true,
            label: replyTitle,
            value: settings.balanceRefreshOnReply,
            onChanged: settings.setBalanceRefreshOnReply,
          )
        else
          _choice(
            context,
            label: replyTitle,
            value: switch (config.balanceRefreshOnReply) {
              true => _ReplySetting.on,
              false => _ReplySetting.off,
              null => _ReplySetting.inherit,
            },
            options: [
              OptionSheetItem(
                value: _ReplySetting.inherit,
                label: l10n.providerBalanceFollowDefault(
                  settings.balanceRefreshOnReply
                      ? l10n.providerBalanceRefreshOn
                      : l10n.providerBalanceRefreshOff,
                ),
              ),
              OptionSheetItem(
                value: _ReplySetting.on,
                label: l10n.providerBalanceRefreshOn,
              ),
              OptionSheetItem(
                value: _ReplySetting.off,
                label: l10n.providerBalanceRefreshOff,
              ),
            ],
            onSelected: (choice) => settings.setProviderConfig(
              key,
              currentConfig().copyWith(
                balanceRefreshOnReply: switch (choice) {
                  _ReplySetting.inherit => null,
                  _ReplySetting.on => true,
                  _ReplySetting.off => false,
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _choice<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<OptionSheetItem<T>> options,
    required FutureOr<void> Function(T) onSelected,
  }) {
    final desktopRow = widget.desktopRow;
    if (desktopRow != null) {
      return desktopRow(
        label,
        SizedBox(
          width: double.infinity,
          child: DesktopSelectDropdown<T>(
            value: value,
            options: [
              for (final option in options)
                DesktopSelectOption(value: option.value, label: option.label),
            ],
            semanticLabel: label,
            wrapTriggerLabel: true,
            triggerFillColor: context.appColors.surfaceFill,
            onSelected: onSelected,
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return IosNavRow(
      label: label,
      labelMaxLines: null,
      padding: const EdgeInsets.symmetric(vertical: 12),
      focusable: true,
      trailing: Flexible(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                options.firstWhere((option) => option.value == value).label,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Lucide.ChevronRight, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
      onTap: () async {
        final choice = await showOptionSheet(
          context,
          title: label,
          selected: value,
          items: options,
        );
        if (choice == null || !context.mounted) return;
        await onSelected(choice);
      },
    );
  }
}

class _CustomIntervalDialog extends StatefulWidget {
  const _CustomIntervalDialog({required this.initial});
  final int initial;

  @override
  State<_CustomIntervalDialog> createState() => _CustomIntervalDialogState();
}

class _CustomIntervalDialogState extends State<_CustomIntervalDialog> {
  late final _controller = TextEditingController(
    text: widget.initial.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final minutes = int.tryParse(_controller.text);
    final valid = minutes != 0 && isBalanceRefreshInterval(minutes);
    void submit() {
      if (valid) Navigator.of(context).pop(minutes);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogHeader(title: l10n.providerBalanceCustomInterval),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: IosFormTextField(
              key: const ValueKey('provider-balance-custom-interval'),
              label: l10n.providerBalanceIntervalMinutes,
              controller: _controller,
              autofocus: true,
              selectAllOnFocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => submit(),
            ),
          ),
          IosTextButton(
            label: l10n.providerDetailPageSaveButton,
            onPressed: valid ? submit : null,
          ),
        ],
      ),
    );
  }
}
