import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../core/services/troubleshoot/troubleshoot_data.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../theme/app_font_weights.dart';
import '../../desktop/desktop_settings_navigation_bus.dart';
import 'troubleshoot_action.dart';

class TroubleshootContent extends StatefulWidget {
  final String? initialEntryKey;
  final void Function(TroubleshootAction action)? onDesktopAction;

  const TroubleshootContent({
    super.key,
    this.initialEntryKey,
    this.onDesktopAction,
  });

  @override
  State<TroubleshootContent> createState() => _TroubleshootContentState();
}

class _TroubleshootContentState extends State<TroubleshootContent> {
  final Map<String, bool> _expanded = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final ScrollController _scrollController = ScrollController();
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntryKey != null) {
      _expanded[widget.initialEntryKey!] = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEntry(widget.initialEntryKey!);
        setState(() => _highlighted = true);
      });
    }
  }

  void _scrollToEntry(String key) {
    final ctx = _cardKeys[key]?.currentContext;
    if (ctx != null && ctx.findRenderObject() != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<TroubleshootEntry> get _entries =>
      troubleshootEntries.where((e) => !e.isErrorMatch).toList();

  void _handleAction(BuildContext context, TroubleshootAction action) {
    if (widget.onDesktopAction != null) {
      widget.onDesktopAction!(action);
    } else {
      dispatchAction(context, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: _entries
          .map((entry) => _buildEntryCard(context, entry))
          .toList(),
    );
  }

  Widget _buildEntryCard(BuildContext context, TroubleshootEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isExpanded = _expanded[entry.key] ?? false;
    final isHighlighted = _highlighted && widget.initialEntryKey == entry.key;

    _cardKeys.putIfAbsent(entry.key, () => GlobalKey());
    return Padding(
      key: _cardKeys[entry.key],
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isHighlighted
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IosCardPress(
              onTap: () => setState(() {
                _expanded[entry.key] = !isExpanded;
                _highlighted = false;
              }),
              borderRadius: BorderRadius.circular(14),
              baseColor: Colors.transparent,
              pressedBlendStrength: 0.06,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _iconForEntry(entry),
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _localizedTitle(l10n, entry),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localizedSummary(l10n, entry),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    if (entry.actionType != null &&
                        entry.actionLabelKey != null) ...[
                      const SizedBox(height: 12),
                      IosCardPress(
                        onTap: () {
                          final action = TroubleshootAction(
                            type: entry.actionType!,
                            labelKey: entry.actionLabelKey!,
                            params: entry.actionParams,
                          );
                          _handleAction(context, action);
                        },
                        borderRadius: BorderRadius.circular(10),
                        baseColor: cs.primary.withValues(alpha: 0.1),
                        pressedBlendStrength: 0.1,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Lucide.ChevronRight,
                              size: 14,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _localizedActionLabel(l10n, entry),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFontWeights.medium,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForEntry(TroubleshootEntry entry) {
    switch (entry.key) {
      case 'response_api_not_supported':
      case 'gemini_wrong_provider_type':
      case 'empty_api_path':
        return Lucide.Settings;
      case 'insufficient_balance':
        return Lucide.Wallet;
      case 'model_no_vision':
        return Lucide.Image;
      case 'search_quality':
        return Lucide.Search;
      case 'low_cache_hitrate':
        return Lucide.Zap;
      case 'backup_sync':
        return Lucide.Database;
      case 'chat_suggestions':
        return Lucide.MessageCircleQuestionMark;
      case 'multiple_billing':
        return Lucide.Coins;
      default:
        return Lucide.BadgeInfo;
    }
  }

  String _localizedTitle(AppLocalizations l10n, TroubleshootEntry entry) {
    switch (entry.key) {
      case 'response_api_not_supported':
        return l10n.troubleshootEntryResponseApiTitle;
      case 'gemini_wrong_provider_type':
        return l10n.troubleshootEntryGeminiTypeTitle;
      case 'empty_api_path':
        return l10n.troubleshootEntryEmptyPathTitle;
      case 'insufficient_balance':
        return l10n.troubleshootEntryBalanceTitle;
      case 'model_no_vision':
        return l10n.troubleshootEntryNoVisionTitle;
      case 'search_quality':
        return l10n.troubleshootEntrySearchQualityTitle;
      case 'low_cache_hitrate':
        return l10n.troubleshootEntryCacheHitrateTitle;
      case 'backup_sync':
        return l10n.troubleshootEntryBackupSyncTitle;
      case 'chat_suggestions':
        return l10n.troubleshootEntryChatSuggestionsTitle;
      case 'multiple_billing':
        return l10n.troubleshootEntryMultiBillingTitle;
      default:
        return entry.titleKey;
    }
  }

  String _localizedSummary(AppLocalizations l10n, TroubleshootEntry entry) {
    switch (entry.key) {
      case 'response_api_not_supported':
        return l10n.troubleshootEntryResponseApiSummary;
      case 'gemini_wrong_provider_type':
        return l10n.troubleshootEntryGeminiTypeSummary;
      case 'empty_api_path':
        return l10n.troubleshootEntryEmptyPathSummary;
      case 'insufficient_balance':
        return l10n.troubleshootEntryBalanceSummary;
      case 'model_no_vision':
        return l10n.troubleshootEntryNoVisionSummary;
      case 'search_quality':
        return l10n.troubleshootEntrySearchQualitySummary;
      case 'low_cache_hitrate':
        return l10n.troubleshootEntryCacheHitrateSummary;
      case 'backup_sync':
        return l10n.troubleshootEntryBackupSyncSummary;
      case 'chat_suggestions':
        return l10n.troubleshootEntryChatSuggestionsSummary;
      case 'multiple_billing':
        return l10n.troubleshootEntryMultiBillingSummary;
      default:
        return entry.summaryKey;
    }
  }

  String _localizedActionLabel(AppLocalizations l10n, TroubleshootEntry entry) {
    if (entry.actionLabelKey == null) return '';
    switch (entry.actionLabelKey) {
      case 'troubleshootActionProviderSettings':
        return l10n.troubleshootActionProviderSettings;
      case 'troubleshootActionProviderBalance':
        return l10n.troubleshootActionProviderBalance;
      case 'troubleshootActionDefaultModel':
        return l10n.troubleshootActionDefaultModel;
      case 'troubleshootActionSearchServices':
        return l10n.troubleshootActionSearchServices;
      case 'troubleshootActionAssistantSettings':
        return l10n.troubleshootActionAssistantSettings;
      case 'troubleshootActionBackupSettings':
        return l10n.troubleshootActionBackupSettings;
      default:
        return entry.actionLabelKey!;
    }
  }
}

class TroubleshootCard extends StatelessWidget {
  final ErrorAnalysisResult result;
  final VoidCallback? onTapAction;
  final VoidCallback? onDismiss;

  const TroubleshootCard({
    super.key,
    required this.result,
    this.onTapAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Lucide.MessageCircleWarning, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _localizedErrorTitle(l10n, result.faqKey),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.error,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IosIconButton(
                    size: 16,
                    icon: Lucide.CircleX,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    onTap: onDismiss,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _localizedErrorSummary(l10n, result.faqKey),
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (result.action != null) ...[
              const SizedBox(height: 10),
              IosCardPress(
                onTap: onTapAction,
                borderRadius: BorderRadius.circular(10),
                baseColor: cs.error.withValues(alpha: 0.15),
                pressedBlendStrength: 0.1,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Lucide.Search, size: 14, color: cs.error),
                    const SizedBox(width: 6),
                    Text(
                      result.action!.labelKey.isNotEmpty
                          ? _localizedActionLabel(l10n, result.action!.labelKey)
                          : l10n.troubleshootViewGuide,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.medium,
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _localizedErrorTitle(AppLocalizations l10n, String faqKey) {
    switch (faqKey) {
      case 'response_api_not_supported':
        return l10n.troubleshootEntryResponseApiTitle;
      case 'gemini_wrong_provider_type':
        return l10n.troubleshootEntryGeminiTypeTitle;
      case 'empty_api_path':
        return l10n.troubleshootEntryEmptyPathTitle;
      case 'insufficient_balance':
        return l10n.troubleshootEntryBalanceTitle;
      case 'model_no_vision':
        return l10n.troubleshootEntryNoVisionTitle;
      default:
        return l10n.troubleshootUnknownErrorTitle;
    }
  }

  String _localizedErrorSummary(AppLocalizations l10n, String faqKey) {
    switch (faqKey) {
      case 'response_api_not_supported':
        return l10n.troubleshootEntryResponseApiSummary;
      case 'gemini_wrong_provider_type':
        return l10n.troubleshootEntryGeminiTypeSummary;
      case 'empty_api_path':
        return l10n.troubleshootEntryEmptyPathSummary;
      case 'insufficient_balance':
        return l10n.troubleshootEntryBalanceSummary;
      case 'model_no_vision':
        return l10n.troubleshootEntryNoVisionSummary;
      default:
        return l10n.troubleshootUnknownErrorSummary;
    }
  }

  String _localizedActionLabel(AppLocalizations l10n, String labelKey) {
    switch (labelKey) {
      case 'troubleshootActionProviderSettings':
        return l10n.troubleshootActionProviderSettings;
      case 'troubleshootActionProviderBalance':
        return l10n.troubleshootActionProviderBalance;
      case 'troubleshootActionDefaultModel':
        return l10n.troubleshootActionDefaultModel;
      case 'troubleshootActionSearchServices':
        return l10n.troubleshootActionSearchServices;
      case 'troubleshootActionAssistantSettings':
        return l10n.troubleshootActionAssistantSettings;
      case 'troubleshootActionBackupSettings':
        return l10n.troubleshootActionBackupSettings;
      case 'troubleshootActionOpenAbout':
        return l10n.troubleshootActionOpenAbout;
      default:
        return l10n.troubleshootViewGuide;
    }
  }
}

void handleTroubleshootCardTap(
  BuildContext context,
  ErrorAnalysisResult result,
) {
  final action = result.action;
  if (action == null) return;
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (isDesktop) {
    _navigateDesktopAction(action);
  } else {
    dispatchAction(context, action);
  }
}

void _navigateDesktopAction(TroubleshootAction action) {
  switch (action.type) {
    case ActionType.openProviderDetail:
    case ActionType.openProviderBalance:
      DesktopSettingsNavigationBus.instance.openProviders(
        providerId: action.providerId,
      );
      break;
    case ActionType.openDefaultModel:
      DesktopSettingsNavigationBus.instance.openDefaultModel();
      break;
    case ActionType.openSearchServices:
      DesktopSettingsNavigationBus.instance.openSearch();
      break;
    case ActionType.openAssistantSettings:
      DesktopSettingsNavigationBus.instance.openAssistantSettings();
      break;
    case ActionType.openBackupSettings:
      DesktopSettingsNavigationBus.instance.openBackup();
      break;
    case ActionType.openAbout:
      DesktopSettingsNavigationBus.instance.openAbout();
      break;
    case ActionType.openCommunityLinks:
      break;
  }
}
