import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import 'package:Cuplivo/theme/app_font_weights.dart';

class ProviderNetworkPage extends StatefulWidget {
  const ProviderNetworkPage({
    super.key,
    required this.providerKey,
    required this.providerDisplayName,
  });
  final String providerKey;
  final String providerDisplayName;

  @override
  State<ProviderNetworkPage> createState() => _ProviderNetworkPageState();
}

class _ProviderNetworkPageState extends State<ProviderNetworkPage> {
  bool _proxyEnabled = false;
  String _proxyType = 'http';
  final _proxyHostCtrl = TextEditingController();
  final _proxyPortCtrl = TextEditingController(text: '8080');
  final _proxyUserCtrl = TextEditingController();
  final _proxyPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.providerDisplayName,
    );
    _proxyEnabled = cfg.proxyEnabled ?? false;
    _proxyType = ProviderConfig.resolveProxyType(cfg.proxyType);
    _proxyHostCtrl.text = cfg.proxyHost ?? '';
    _proxyPortCtrl.text = cfg.proxyPort ?? '8080';
    _proxyUserCtrl.text = cfg.proxyUsername ?? '';
    _proxyPassCtrl.text = cfg.proxyPassword ?? '';
  }

  @override
  void dispose() {
    _proxyHostCtrl.dispose();
    _proxyPortCtrl.dispose();
    _proxyUserCtrl.dispose();
    _proxyPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.providerDetailPageNetworkTab),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _switchRow(
            title: l10n.providerDetailPageEnableProxyTitle,
            value: _proxyEnabled,
            onChanged: (v) {
              setState(() => _proxyEnabled = v);
              _saveNetwork();
            },
          ),
          if (_proxyEnabled) ...[
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.networkProxyType,
              child: _ProxyTypeSheetField(
                value: _proxyType,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _proxyType = value);
                  _saveNetwork();
                },
              ),
            ),
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPageHostLabel,
              child: TextField(
                controller: _proxyHostCtrl,
                onChanged: (_) => _saveNetwork(),
                decoration: _proxyInputDecoration(
                  context,
                ).copyWith(hintText: '127.0.0.1'),
              ),
            ),
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPagePortLabel,
              child: TextField(
                controller: _proxyPortCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => _saveNetwork(),
                decoration: _proxyInputDecoration(
                  context,
                ).copyWith(hintText: '8080'),
              ),
            ),
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPageUsernameOptionalLabel,
              child: TextField(
                controller: _proxyUserCtrl,
                onChanged: (_) => _saveNetwork(),
                decoration: _proxyInputDecoration(context),
              ),
            ),
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPagePasswordOptionalLabel,
              child: TextField(
                controller: _proxyPassCtrl,
                obscureText: true,
                onChanged: (_) => _saveNetwork(),
                decoration: _proxyInputDecoration(context),
              ),
            ),
          ],
        ],
      ),
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
        IosSwitch(value: value, onChanged: onChanged),
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

  Future<void> _saveNetwork() async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.providerDisplayName,
    );
    final cfg = old.copyWith(
      proxyEnabled: _proxyEnabled,
      proxyType: _proxyType,
      proxyHost: _proxyHostCtrl.text.trim(),
      proxyPort: _proxyPortCtrl.text.trim(),
      proxyUsername: _proxyUserCtrl.text.trim(),
      proxyPassword: _proxyPassCtrl.text.trim(),
    );
    await settings.setProviderConfig(widget.providerKey, cfg);
    // Silent auto-save (no snackbar) to match immediate-save UX
    if (!mounted) return;
  }
}

InputDecoration _proxyInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
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

class _ProxyTypeSheetField extends StatelessWidget {
  const _ProxyTypeSheetField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.white10 : const Color(0xFFF7F7F9);

    String labelOf(String currentValue) {
      switch (currentValue) {
        case 'socks5':
          return l10n.networkProxyTypeSocks5;
        case 'http':
        default:
          return l10n.networkProxyTypeHttp;
      }
    }

    Future<void> openSheet() async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetOption(
                    ctx,
                    text: l10n.networkProxyTypeHttp,
                    itemValue: 'http',
                    selected: value == 'http',
                  ),
                  _sheetDivider(ctx),
                  _sheetOption(
                    ctx,
                    text: l10n.networkProxyTypeSocks5,
                    itemValue: 'socks5',
                    selected: value == 'socks5',
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (selected != null) onChanged(selected);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.12),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelOf(value),
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.88),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption(
    BuildContext context, {
    required String text,
    required String itemValue,
    required bool selected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: cs.surface,
          duration: const Duration(milliseconds: 220),
          onTap: () => Navigator.of(context).pop(itemValue),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : cs.primary.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.92),
                      fontWeight: selected
                          ? AppFontWeights.semibold
                          : AppFontWeights.medium,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 18, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetDivider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: cs.outlineVariant.withValues(alpha: 0.12),
      ),
    );
  }
}
