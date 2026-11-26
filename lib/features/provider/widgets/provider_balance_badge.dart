import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/provider_balance_refresh.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/snackbar.dart';

class ProviderBalanceBadge extends StatefulWidget {
  const ProviderBalanceBadge({
    super.key,
    required this.providerKey,
    required this.displayName,
    this.style,
    this.color,
    this.iconSize,
    this.showManualResultWhenDisabled = false,
  });

  final String providerKey;
  final String displayName;
  final TextStyle? style;
  final Color? color;
  final double? iconSize;
  final bool showManualResultWhenDisabled;

  @override
  State<ProviderBalanceBadge> createState() => _ProviderBalanceBadgeState();
}

class _ProviderBalanceBadgeState extends State<ProviderBalanceBadge> {
  ProviderBalanceEntry? _entry;
  Key _visibilityKey = UniqueKey();
  bool _painted = false;
  bool _routeCurrent = true;
  VoidCallback? _detachVisibleBadge;

  void _bind(ProviderBalanceEntry? entry) {
    if (identical(_entry, entry)) return;
    VisibilityDetectorController.instance.forget(_visibilityKey);
    _detachVisibleBadge?.call();
    _detachVisibleBadge = null;
    _entry = entry;
    _visibilityKey = UniqueKey();
    _painted = false;
  }

  void _syncVisibility() {
    if (_painted && _routeCurrent && _entry != null) {
      _detachVisibleBadge ??= _entry!.attachVisibleBadge();
    } else {
      _detachVisibleBadge?.call();
      _detachVisibleBadge = null;
    }
  }

  @override
  void dispose() {
    _bind(null);
    super.dispose();
  }

  Future<void> _showMenu(
    Offset anchor,
    ProviderBalanceEntry entry,
    String? status,
  ) {
    return showAdaptiveActionMenu(
      context,
      anchor: anchor,
      title: status,
      items: [
        ActionSheetItem(
          icon: Lucide.RefreshCw,
          label: AppLocalizations.of(context)!.providerBalanceRefreshNow,
          onTap: () async {
            if (!mounted || !identical(_entry, entry)) return;
            try {
              await entry.query();
            } catch (error) {
              if (!mounted || !identical(_entry, entry)) return;
              showAppSnackBar(
                context,
                message: AppLocalizations.of(
                  context,
                )!.providerDetailPageBalanceError(error.toString()),
                type: NotificationType.error,
              );
            }
          },
        ),
      ],
    );
  }

  String? _statusText(BuildContext context, ProviderBalanceSnapshot snapshot) {
    final updatedAt = snapshot.updatedAt;
    final error = snapshot.error;
    if (updatedAt == null && error == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    return [
      if (updatedAt != null)
        l10n.providerBalanceLastUpdated(
          material.formatShortDate(updatedAt),
          material.formatTimeOfDay(
            TimeOfDay.fromDateTime(updatedAt),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
        ),
      if (error != null) l10n.providerDetailPageBalanceError(error),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    final showBadge =
        config.balanceEnabled == true &&
        (config.enabled || widget.showManualResultWhenDisabled);
    final entry = showBadge
        ? settings.balanceRefresh.forProvider(widget.providerKey)
        : null;
    _bind(entry);
    if (entry == null) return const SizedBox.shrink();

    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _syncVisibility();

    final cs = Theme.of(context).colorScheme;
    final style = widget.style ?? Theme.of(context).textTheme.labelSmall;
    final color = widget.color ?? cs.onSurface.withValues(alpha: 0.62);
    final iconSize = widget.iconSize ?? ((style?.fontSize ?? 12) + 2);
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!mounted || info.key != _visibilityKey) return;
        _painted = info.visibleFraction > 0;
        _syncVisibility();
      },
      child: ValueListenableBuilder<ProviderBalanceSnapshot>(
        valueListenable: entry,
        builder: (context, snapshot, _) {
          if (!config.enabled &&
              snapshot.balance == null &&
              snapshot.error == null) {
            return const SizedBox.shrink();
          }
          final status = _statusText(context, snapshot);
          final child = GestureDetector(
            onLongPressStart: (details) =>
                _showMenu(details.globalPosition, entry, status),
            onSecondaryTapUp: (details) =>
                _showMenu(details.globalPosition, entry, status),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Lucide.Coins, size: iconSize, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    snapshot.balance ?? (snapshot.error == null ? '~' : '!'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          );
          return status == null
              ? child
              : Tooltip(
                  message: status,
                  triggerMode: TooltipTriggerMode.manual,
                  child: child,
                );
        },
      ),
    );
  }
}
