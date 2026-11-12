import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/provider_balance_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

class ProviderBalanceBadge extends StatefulWidget {
  const ProviderBalanceBadge({
    super.key,
    required this.providerKey,
    required this.displayName,
    this.style,
    this.color,
    this.iconSize,
  });

  final String providerKey;
  final String displayName;
  final TextStyle? style;
  final Color? color;
  final double? iconSize;

  static void clearCacheFor(String providerKey) {
    _ProviderBalanceBadgeState._cache.removeWhere(
      (key, _) => key.startsWith('$providerKey|'),
    );
  }

  @override
  State<ProviderBalanceBadge> createState() => _ProviderBalanceBadgeState();
}

class _ProviderBalanceBadgeState extends State<ProviderBalanceBadge> {
  static final Map<String, String> _cache = <String, String>{};

  String? _cacheKey;
  Timer? _queryTimer;
  String _value = '~';
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncQuery(notify: false);
  }

  @override
  void didUpdateWidget(covariant ProviderBalanceBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncQuery();
  }

  @override
  void dispose() {
    _queryTimer?.cancel();
    super.dispose();
  }

  void _syncQuery({bool notify = true}) {
    final settings = context.read<SettingsProvider>();
    final config = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    if (!config.enabled || config.balanceEnabled != true) {
      _queryTimer?.cancel();
      _cacheKey = null;
      return;
    }

    final key = [
      config.id,
      config.baseUrl,
      config.balanceApiPath ?? '',
      config.balanceResultPath ?? '',
      config.balanceMethod,
      Object.hashAll(
        config.balanceHeaders.map(
          (row) => Object.hash(row['name'], row['value']),
        ),
      ),
      config.balanceBody.hashCode,
      config.apiKey.hashCode,
      config.multiKeyEnabled,
      Object.hashAll(
        config.apiKeys?.map(
              (key) =>
                  Object.hash(key.key, key.isEnabled, key.status, key.priority),
            ) ??
            const [],
      ),
      config.keyManagement?.strategy,
    ].join('|');
    if (_cacheKey == key) return;
    _queryTimer?.cancel();
    _cacheKey = key;

    final cached = _cache[key];
    if (cached != null) {
      if (mounted && notify) {
        setState(() {
          _value = cached;
          _error = null;
        });
      } else {
        _value = cached;
        _error = null;
      }
      return;
    }

    void reset() {
      _value = '~';
      _error = null;
    }

    if (notify) {
      setState(reset);
    } else {
      reset();
    }
    // Settings save on each keystroke; wait for an editing pause before querying.
    _queryTimer = Timer(const Duration(milliseconds: 500), () {
      _queryTimer = null;
      if (mounted && _cacheKey == key) _fetch(config, key);
    });
  }

  Future<void> _fetch(ProviderConfig config, String key) async {
    try {
      final value = await ProviderBalanceService.fetchBalance(config);
      _cache[key] = value;
      if (!mounted || _cacheKey != key) return;
      setState(() {
        _value = value;
        _error = null;
      });
    } catch (e) {
      if (!mounted || _cacheKey != key) return;
      setState(() {
        _value = '!';
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    if (!config.enabled || config.balanceEnabled != true) {
      return const SizedBox.shrink();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncQuery();
    });

    final cs = Theme.of(context).colorScheme;
    final style = widget.style ?? Theme.of(context).textTheme.labelSmall;
    final color = widget.color ?? cs.onSurface.withValues(alpha: 0.62);
    final iconSize = widget.iconSize ?? ((style?.fontSize ?? 12) + 2);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Lucide.Coins, size: iconSize, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(color: color),
          ),
        ),
      ],
    );

    if (_error == null) return child;
    return Tooltip(
      message: AppLocalizations.of(
        context,
      )!.providerDetailPageBalanceError(_error!),
      child: child,
    );
  }
}
