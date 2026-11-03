import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/provider_balance_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../widgets/provider_balance_badge.dart';
import '../widgets/provider_balance_request_editor.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class ProviderBalancePage extends StatefulWidget {
  const ProviderBalancePage({
    super.key,
    required this.providerKey,
    required this.providerDisplayName,
  });

  final String providerKey;
  final String providerDisplayName;

  @override
  State<ProviderBalancePage> createState() => _ProviderBalancePageState();
}

class _ProviderBalancePageState extends State<ProviderBalancePage> {
  final _balanceApiPathCtrl = TextEditingController();
  final _balanceResultPathCtrl = TextEditingController();
  final _balanceBodyCtrl = TextEditingController();
  String _balanceMethod = 'GET';
  List<Map<String, String>> _balanceHeaders = [];

  bool _balanceEnabled = false;
  bool _balanceLoading = false;
  String? _balanceValue;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.providerDisplayName,
    );
    final defaults = ProviderConfig.defaultsFor(
      widget.providerKey,
      displayName: widget.providerDisplayName,
    );
    _balanceEnabled = cfg.balanceEnabled ?? false;
    _balanceApiPathCtrl.text =
        cfg.balanceApiPath ?? defaults.balanceApiPath ?? '';
    _balanceResultPathCtrl.text =
        cfg.balanceResultPath ?? defaults.balanceResultPath ?? '';
    _balanceMethod = cfg.balanceMethod;
    _balanceHeaders = cfg.balanceHeaders;
    _balanceBodyCtrl.text = cfg.balanceBody;
  }

  @override
  void dispose() {
    _balanceApiPathCtrl.dispose();
    _balanceResultPathCtrl.dispose();
    _balanceBodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.providerDetailPageBalanceTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _switchRow(
            title: l10n.providerDetailPageBalanceInfo,
            value: _balanceEnabled,
            onChanged: (v) {
              setState(() {
                _balanceEnabled = v;
                _balanceValue = null;
                _balanceError = null;
              });
              _saveBalance();
            },
          ),
          if (_balanceEnabled) ...[
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPageBalanceApiPathLabel,
              child: TextField(
                key: const ValueKey('provider-balance-api-path'),
                controller: _balanceApiPathCtrl,
                onChanged: (_) {
                  setState(() {
                    _balanceValue = null;
                    _balanceError = null;
                  });
                  _saveBalance();
                },
                decoration: _balanceInputDecoration(context),
              ),
            ),
            const SizedBox(height: 12),
            ProviderBalanceRequestEditor(
              method: _balanceMethod,
              headers: _balanceHeaders,
              bodyController: _balanceBodyCtrl,
              onMethodChanged: (value) {
                setState(() {
                  _balanceMethod = value;
                  _balanceValue = null;
                  _balanceError = null;
                });
                _saveBalance();
              },
              onHeadersChanged: (headers) async {
                setState(() {
                  _balanceHeaders = headers;
                  _balanceValue = null;
                  _balanceError = null;
                });
                await _saveBalance();
              },
              onBodyChanged: (_) {
                setState(() {
                  _balanceValue = null;
                  _balanceError = null;
                });
                _saveBalance();
              },
            ),
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPageBalanceResultPathLabel,
              child: TextField(
                key: const ValueKey('provider-balance-result-path'),
                controller: _balanceResultPathCtrl,
                onChanged: (_) {
                  setState(() {
                    _balanceValue = null;
                    _balanceError = null;
                  });
                  _saveBalance();
                },
                decoration: _balanceInputDecoration(context),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _balanceStatus(context),
                  ),
                ),
                Tooltip(
                  message: l10n.providerDetailPageBalanceResetDefaultsTooltip,
                  child: IosIconButton(
                    icon: Lucide.RefreshCw,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.72),
                    minSize: 36,
                    onTap: _resetBalanceDefaults,
                  ),
                ),
                const SizedBox(width: 8),
                _BalanceQueryButton(
                  label: _balanceLoading
                      ? l10n.providerDetailPageBalanceQuerying
                      : l10n.providerDetailPageBalanceQueryButton,
                  enabled: !_balanceLoading,
                  onTap: _queryBalance,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceStatus(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _balanceError ?? _balanceValue;
    if (status == null) {
      return ProviderBalanceBadge(
        key: const ValueKey('balance-badge'),
        providerKey: widget.providerKey,
        displayName: widget.providerDisplayName,
        color: cs.primary,
      );
    }
    return Text(
      status,
      key: ValueKey(status),
      style: TextStyle(
        fontSize: 13,
        fontWeight: AppFontWeights.semibold,
        color: _balanceError != null
            ? cs.error
            : cs.onSurface.withValues(alpha: 0.72),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 15))),
        IosSwitch(
          key: const ValueKey('provider-balance-enabled'),
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _inputRow(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Future<void> _saveBalance() async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.providerDisplayName,
    );
    await settings.setProviderConfig(
      widget.providerKey,
      old.copyWith(
        balanceEnabled: _balanceEnabled,
        balanceApiPath: _balanceApiPathCtrl.text.trim(),
        balanceResultPath: _balanceResultPathCtrl.text.trim(),
        balanceMethod: _balanceMethod,
        balanceHeaders: _balanceHeaders,
        balanceBody: _balanceBodyCtrl.text,
      ),
    );
    ProviderBalanceBadge.clearCacheFor(widget.providerKey);
  }

  Future<void> _queryBalance() async {
    if (_balanceLoading) return;
    final pageContext = context;
    setState(() {
      _balanceLoading = true;
      _balanceValue = null;
      _balanceError = null;
    });
    try {
      await _saveBalance();
      if (!pageContext.mounted) return;
      final settings = pageContext.read<SettingsProvider>();
      final cfg = settings.getProviderConfig(
        widget.providerKey,
        defaultName: widget.providerDisplayName,
      );
      final value = await ProviderBalanceService.fetchBalance(cfg);
      if (!pageContext.mounted) return;
      final l10n = AppLocalizations.of(pageContext)!;
      setState(
        () => _balanceValue = l10n.providerDetailPageBalanceResult(value),
      );
      showAppSnackBar(
        pageContext,
        message: l10n.providerDetailPageBalanceResult(value),
        type: NotificationType.success,
      );
    } catch (e) {
      if (!pageContext.mounted) return;
      final l10n = AppLocalizations.of(pageContext)!;
      setState(
        () => _balanceError = l10n.providerDetailPageBalanceError(e.toString()),
      );
      showAppSnackBar(
        pageContext,
        message: l10n.providerDetailPageBalanceError(e.toString()),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  void _resetBalanceDefaults() {
    final defaults = ProviderConfig.defaultsFor(
      widget.providerKey,
      displayName: widget.providerDisplayName,
    );
    setState(() {
      _balanceEnabled = defaults.balanceEnabled ?? false;
      _balanceApiPathCtrl.text = defaults.balanceApiPath ?? '';
      _balanceResultPathCtrl.text = defaults.balanceResultPath ?? '';
      _balanceMethod = defaults.balanceMethod;
      _balanceHeaders = defaults.balanceHeaders;
      _balanceBodyCtrl.text = defaults.balanceBody;
      _balanceValue = null;
      _balanceError = null;
    });
    _saveBalance();
  }
}

InputDecoration _balanceInputDecoration(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: context.appColors.surfaceFill,
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
      borderSide: BorderSide(
        color: cs.primary.withValues(alpha: 0.35),
        width: 0.8,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _BalanceQueryButton extends StatefulWidget {
  const _BalanceQueryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_BalanceQueryButton> createState() => _BalanceQueryButtonState();
}

class _BalanceQueryButtonState extends State<_BalanceQueryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.enabled
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.38);
    final bg = widget.enabled
        ? cs.primary.withValues(alpha: _pressed ? 0.18 : 0.12)
        : cs.onSurface.withValues(alpha: 0.06);
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.Coins, size: 16, color: base),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFontWeights.emphasis,
                  color: base,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
