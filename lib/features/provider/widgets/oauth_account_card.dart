import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/provider_oauth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

String oauthDisplayTime(BuildContext context, DateTime value) => DateFormat.Md(
  AppLocalizations.of(context)!.localeName,
).add_Hm().format(value.toLocal());

class OAuthAccountCard extends StatelessWidget {
  const OAuthAccountCard({
    super.key,
    required this.avatar,
    required this.name,
    this.email,
    this.plan,
    this.usage,
    this.refreshing = false,
    this.loadingUsage = false,
    this.expired = false,
    this.usageError,
    this.showDetails = false,
    this.onRefresh,
    this.onDetails,
    this.onLogin,
  });
  final Widget avatar;
  final String name;
  final String? email;
  final String? plan;
  final ProviderUsageSnapshot? usage;
  final bool refreshing;
  final bool loadingUsage;
  final bool expired;
  final String? usageError;
  final bool showDetails;
  final VoidCallback? onRefresh;
  final VoidCallback? onDetails;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final subtitle = cs.onSurface.withValues(alpha: .55);
    return SectionCard(
      variant: SectionCardVariant.emphasized,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email ?? name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if ((usage?.plan ?? plan) case final plan?)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              plan,
                              style: TextStyle(fontSize: 11, color: cs.primary),
                            ),
                          ),
                        Text(
                          expired ? l.oauthNeedsLogin : l.oauthConnected,
                          style: TextStyle(
                            fontSize: 12,
                            color: expired
                                ? cs.error
                                : context.appColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IosIconButton(
                  icon: LucideIcons.refreshCw,
                  size: 17,
                  semanticLabel: l.oauthRefreshUsage,
                  onTap: loadingUsage ? null : onRefresh,
                ),
            ],
          ),
          if (expired && onLogin != null) ...[
            const SizedBox(height: 16),
            IosTileButton(
              label: l.oauthRelogin,
              icon: LucideIcons.logIn,
              foregroundColor: cs.error,
              onTap: onLogin!,
            ),
          ],
          if (!expired) ...[
            if (usage != null && usage!.windows.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                height: .5,
                color: cs.outlineVariant.withValues(alpha: .35),
              ),
              for (final window in usage!.windows.take(
                showDetails ? usage!.windows.length : 2,
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _UsageBar(window: window, showDetails: showDetails),
                ),
            ],
            if (usage?.allowed == false || usage?.limitReached == true)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  l.oauthQuotaExceeded,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              )
            else if (usage?.allowed == true && usage!.windows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  l.oauthQuotaAvailable,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.success,
                  ),
                ),
              ),
            if (usage?.resetCredits case final count?)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  l.oauthSavedResets('$count'),
                  style: TextStyle(fontSize: 12, color: subtitle),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    refreshing
                        ? l.oauthRefreshing
                        : loadingUsage
                        ? l.oauthRefreshUsage
                        : usageError ??
                              (usage == null
                                  ? l.oauthUsageUnavailable
                                  : l.oauthLastUpdated(
                                      oauthDisplayTime(
                                        context,
                                        usage!.fetchedAt,
                                      ),
                                    )),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: usageError == null ? subtitle : cs.error,
                    ),
                  ),
                ),
                if (onDetails != null && usage?.windows.isNotEmpty == true)
                  IosCardPress(
                    onTap: onDetails,
                    baseColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                      child: Text(
                        l.oauthUsageDetails,
                        style: TextStyle(fontSize: 12, color: cs.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.window, required this.showDetails});
  final ProviderUsageWindow window;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final duration = window.duration;
    final windowLabel = (window.id == 'extra'
        ? l.oauthExtraUsage
        : window.id == 'monthly'
        ? l.oauthMonthly
        : window.id == 'total'
        ? l.oauthTotal
        : duration?.inDays == 7
        ? l.oauthWeekly
        : duration != null && duration.inDays > 0
        ? l.oauthDays('${duration.inDays}')
        : duration != null && duration.inHours > 0
        ? l.oauthHours('${duration.inHours}')
        : duration != null && duration.inMinutes > 0
        ? l.oauthMinutes('${duration.inMinutes}')
        : window.id.endsWith('primary_window')
        ? l.oauthPrimaryWindow
        : window.id.endsWith('secondary_window')
        ? l.oauthSecondaryWindow
        : l.oauthWindow);
    final label = window.label == null
        ? windowLabel
        : (duration == null ? window.label! : '${window.label} · $windowLabel');
    final percent = window.usedPercent;
    final color = percent != null && percent >= 90
        ? context.appColors.warning
        : cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: .65),
                ),
              ),
            ),
            Text(
              window.unit == 'usd'
                  ? '\$${window.used?.toStringAsFixed(2) ?? '—'}${window.limit == null ? '' : ' / \$${window.limit!.toStringAsFixed(2)}'}'
                  : percent == null
                  ? '—'
                  : '${percent.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: AppFontWeights.medium),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (percent != null)
          Semantics(
            label: '$label ${percent.toStringAsFixed(0)}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: cs.onSurface.withValues(alpha: .07),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (percent / 100).clamp(0, 1),
                      child: ColoredBox(
                        color: color,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (showDetails && window.resetsAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              l.oauthResetsAt(oauthDisplayTime(context, window.resetsAt!)),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: .5),
              ),
            ),
          ),
      ],
    );
  }
}
