import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/hermes_gateway_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../shared/widgets/ios_tile_button.dart';

/// Billing and credits sheet for Hermes backend.
///
/// Shows current credits balance, available purchase packages,
/// and auto-reload settings.
class HermesBillingSheet extends StatefulWidget {
  const HermesBillingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HermesBillingSheet(),
    );
  }

  @override
  State<HermesBillingSheet> createState() => _HermesBillingSheetState();
}

class _HermesBillingSheetState extends State<HermesBillingSheet> {
  double _credits = 0.0;
  List<Map<String, dynamic>> _packages = [];
  bool _autoReload = false;
  double? _threshold;
  bool _loading = true;
  String? _chargingPackageId;
  String? _chargeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hp = context.read<HermesGatewayProvider>();
    final results = await Future.wait([
      hp.fetchCredits(),
      hp.fetchBillingPackages(),
    ]);
    if (!mounted) return;
    setState(() {
      _credits = results[0] as double;
      _packages = (results[1] as List<Map<String, dynamic>>)
          .cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _onPurchase(String packageId) async {
    setState(() {
      _chargingPackageId = packageId;
      _chargeError = null;
    });
    final hp = context.read<HermesGatewayProvider>();
    await hp.purchaseCredits(packageId);
    if (!mounted) return;
    setState(() {
      _chargingPackageId = null;
      // Refresh credits after purchase
      _load();
    });
  }

  Future<void> _onToggleAutoReload(bool value) async {
    setState(() => _autoReload = value);
    final hp = context.read<HermesGatewayProvider>();
    await hp.setAutoReload(enabled: value, threshold: _threshold);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.hermesBillingTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IosIconButton(
                  icon: Icons.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Credits balance card
                        _CreditsCard(credits: _credits, l10n: l10n),
                        const SizedBox(height: 20),
                        // Auto-reload toggle
                        _AutoReloadSection(
                          enabled: _autoReload,
                          threshold: _threshold,
                          l10n: l10n,
                          onChanged: _onToggleAutoReload,
                        ),
                        const SizedBox(height: 20),
                        // Packages
                        Text(
                          l10n.hermesBillingPackages,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_packages.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                l10n.hermesBillingEmpty,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._packages.map(
                            (pkg) => _PackageTile(
                              pkg: pkg,
                              isCharging: _chargingPackageId == pkg['id'],
                              error: _chargeError,
                              l10n: l10n,
                              onPurchase: () =>
                                  _onPurchase(pkg['id']?.toString() ?? ''),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  final double credits;
  final AppLocalizations l10n;

  const _CreditsCard({required this.credits, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.8),
            theme.colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hermesBillingCreditsRemaining,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            credits.toStringAsFixed(4),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            l10n.hermesBillingCredits,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoReloadSection extends StatelessWidget {
  final bool enabled;
  final double? threshold;
  final AppLocalizations l10n;
  final ValueChanged<bool> onChanged;

  const _AutoReloadSection({
    required this.enabled,
    this.threshold,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hermesBillingAutoReload,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (threshold != null)
                  Text(
                    '${l10n.hermesBillingThreshold}: $threshold',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              enabled
                  ? l10n.hermesBillingAutoReloadOn
                  : l10n.hermesBillingAutoReloadOff,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: enabled,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final bool isCharging;
  final String? error;
  final AppLocalizations l10n;
  final VoidCallback onPurchase;

  const _PackageTile({
    required this.pkg,
    required this.isCharging,
    this.error,
    required this.l10n,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = pkg['name']?.toString() ?? 'Package';
    final credits_ = pkg['credits']?.toString() ?? '0';
    final price = pkg['price']?.toString() ?? '';
    final description = pkg['description']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$credits_ credits',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          isCharging
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : IosTileButton(
                  label: price.isNotEmpty
                      ? '$price ${l10n.hermesBillingCharge}'
                      : l10n.hermesBillingCharge,
                  icon: Icons.shopping_cart_outlined,
                  onTap: onPurchase,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
        ],
      ),
    );
  }
}
