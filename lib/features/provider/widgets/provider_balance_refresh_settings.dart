import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/provider_balance_refresh_interval.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../settings/widgets/custom_theme_widgets.dart';

enum _RefreshScope { provider, global }

enum _ReplySetting { inherit, on, off }

class ProviderBalanceRefreshSettings extends StatefulWidget {
  const ProviderBalanceRefreshSettings({
    super.key,
    required this.providerKey,
    required this.providerDisplayName,
  });

  final String providerKey;
  final String providerDisplayName;

  @override
  State<ProviderBalanceRefreshSettings> createState() =>
      _ProviderBalanceRefreshSettingsState();
}

class _ProviderBalanceRefreshSettingsState
    extends State<ProviderBalanceRefreshSettings> {
  _RefreshScope? _scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = _scope;
    return SectionCard(
      children: [
        Semantics(
          button: true,
          expanded: scope != null,
          child: IosNavRow(
            focusable: true,
            label: l10n.providerBalanceAutoRefresh,
            labelMaxLines: null,
            trailing: Icon(
              scope == null ? Lucide.ChevronDown : Lucide.ChevronUp,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => setState(() {
              _scope = scope == null ? _RefreshScope.provider : null;
            }),
          ),
        ),
        if (scope != null) ...[
          const IosRowDivider(indent: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: SegmentedTabs(
              tabs: [
                SegmentedTab(label: l10n.providerBalanceScopeProvider),
                SegmentedTab(label: l10n.providerBalanceScopeGlobal),
              ],
              index: scope.index,
              height: 36,
              radioGroup: true,
              backgroundColor: context.appColors.surfaceFill,
              onChanged: (index) => setState(() {
                _scope = _RefreshScope.values[index];
              }),
            ),
          ),
          _RefreshOptions(
            providerKey: scope == _RefreshScope.provider
                ? widget.providerKey
                : null,
            providerDisplayName: widget.providerDisplayName,
          ),
        ],
      ],
    );
  }
}

class _RefreshOptions extends StatelessWidget {
  const _RefreshOptions({
    required this.providerKey,
    required this.providerDisplayName,
  });

  final String? providerKey;
  final String providerDisplayName;

  static const _presets = [0, 1, 5, 15, 30, 60];
  static const _inherit = -1;
  static const _custom = -2;

  static String _intervalLabel(AppLocalizations l10n, int minutes) =>
      switch (minutes) {
        0 => l10n.providerBalanceRefreshOff,
        60 => l10n.providerBalanceRefreshHour,
        _ => l10n.providerBalanceRefreshMinutes(minutes),
      };

  static String _replyLabel(AppLocalizations l10n, bool enabled) =>
      enabled ? l10n.providerBalanceRefreshOn : l10n.providerBalanceRefreshOff;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final key = providerKey;
    ProviderConfig configFor(String key) =>
        settings.getProviderConfig(key, defaultName: providerDisplayName);
    final config = key == null ? null : configFor(key);
    final interval = config == null
        ? settings.balanceRefreshInterval
        : config.balanceRefreshInterval;
    final intervalTitle = config == null
        ? l10n.providerBalanceDefaultInterval
        : l10n.providerBalanceInterval;
    final inheritedInterval = l10n.providerBalanceFollowDefault(
      _intervalLabel(l10n, settings.balanceRefreshInterval),
    );
    final inheritedReply = l10n.providerBalanceFollowDefault(
      _replyLabel(l10n, settings.balanceRefreshOnReply),
    );

    return Column(
      children: [
        IosNavRow(
          focusable: true,
          label: intervalTitle,
          labelMaxLines: null,
          subtitle: interval == null
              ? inheritedInterval
              : _intervalLabel(l10n, interval),
          subtitleMaxLines: null,
          onTap: () async {
            final custom = interval != null && !_presets.contains(interval);
            final choice = await showOptionSheet<int>(
              context,
              title: intervalTitle,
              selected: custom ? _custom : interval ?? _inherit,
              items: [
                if (config != null)
                  OptionSheetItem(value: _inherit, label: inheritedInterval),
                for (final minutes in _presets)
                  OptionSheetItem(
                    value: minutes,
                    label: _intervalLabel(l10n, minutes),
                  ),
                OptionSheetItem(
                  value: _custom,
                  label: l10n.providerBalanceCustomInterval,
                  subtitle: custom ? _intervalLabel(l10n, interval) : null,
                ),
              ],
            );
            if (!context.mounted || choice == null) return;

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
            if (key == null) {
              await settings.setBalanceRefreshInterval(minutes!);
            } else {
              final current = configFor(key);
              await settings.setProviderConfig(
                key,
                current.copyWith(balanceRefreshInterval: minutes),
              );
            }
          },
        ),
        const IosRowDivider(indent: 12),
        if (key == null)
          IosSwitchRow(
            focusable: true,
            label: l10n.providerBalanceRefreshOnReply,
            value: settings.balanceRefreshOnReply,
            onChanged: settings.setBalanceRefreshOnReply,
          )
        else
          IosNavRow(
            focusable: true,
            label: l10n.providerBalanceRefreshOnReply,
            labelMaxLines: null,
            subtitle: switch (config!.balanceRefreshOnReply) {
              final bool enabled => _replyLabel(l10n, enabled),
              null => inheritedReply,
            },
            subtitleMaxLines: null,
            onTap: () async {
              final choice = await showOptionSheet<_ReplySetting>(
                context,
                title: l10n.providerBalanceRefreshOnReply,
                selected: switch (config.balanceRefreshOnReply) {
                  true => _ReplySetting.on,
                  false => _ReplySetting.off,
                  null => _ReplySetting.inherit,
                },
                items: [
                  OptionSheetItem(
                    value: _ReplySetting.inherit,
                    label: inheritedReply,
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
              );
              if (choice == null || !context.mounted) return;
              final current = configFor(key);
              await settings.setProviderConfig(
                key,
                current.copyWith(
                  balanceRefreshOnReply: switch (choice) {
                    _ReplySetting.inherit => null,
                    _ReplySetting.on => true,
                    _ReplySetting.off => false,
                  },
                ),
              );
            },
          ),
      ],
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
