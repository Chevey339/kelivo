import 'package:flutter/material.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';

sealed class FaqListItem {}

class FaqSectionHeader extends FaqListItem {
  final String Function(AppLocalizations) title;

  FaqSectionHeader({required this.title});
}

class FaqEntryItem extends FaqListItem {
  final String key;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) summary;
  final IconData icon;

  FaqEntryItem({
    required this.key,
    required this.title,
    required this.summary,
    required this.icon,
  });
}

List<FaqListItem> faqItems(AppLocalizations l10n) => [
  FaqSectionHeader(title: (_) => l10n.faqSectionGeneral),
  FaqEntryItem(
    key: '1_1',
    title: (_) => l10n.faqEntry1GeneralTipsTitle,
    summary: (_) => l10n.faqEntry1GeneralTipsSummary,
    icon: Lucide.Lightbulb,
  ),
  FaqEntryItem(
    key: '1_2',
    title: (_) => l10n.faqEntry1BillingPrivacyTitle,
    summary: (_) => l10n.faqEntry1BillingPrivacySummary,
    icon: Lucide.Shield,
  ),
  FaqEntryItem(
    key: '1_3',
    title: (_) => l10n.faqEntry1AgentSkillsTitle,
    summary: (_) => l10n.faqEntry1AgentSkillsSummary,
    icon: Lucide.Bot,
  ),
  FaqEntryItem(
    key: '1_4',
    title: (_) => l10n.faqEntry1ApiCallsTitle,
    summary: (_) => l10n.faqEntry1ApiCallsSummary,
    icon: Lucide.Coins,
  ),
  FaqEntryItem(
    key: '1_5',
    title: (_) => l10n.faqEntry1FeedbackTitle,
    summary: (_) => l10n.faqEntry1FeedbackSummary,
    icon: Lucide.MessageCircleQuestionMark,
  ),

  FaqSectionHeader(title: (_) => l10n.faqSectionErrors),
  FaqEntryItem(
    key: '2_1',
    title: (_) => l10n.faqEntry2Http404Title,
    summary: (_) => l10n.faqEntry2Http404Summary,
    icon: Lucide.Settings,
  ),
  FaqEntryItem(
    key: '2_2',
    title: (_) => l10n.faqEntry2BalanceTitle,
    summary: (_) => l10n.faqEntry2BalanceSummary,
    icon: Lucide.Wallet,
  ),
  FaqEntryItem(
    key: '2_3',
    title: (_) => l10n.faqEntry2GeminiTitle,
    summary: (_) => l10n.faqEntry2GeminiSummary,
    icon: Lucide.Settings,
  ),
  FaqEntryItem(
    key: '2_4',
    title: (_) => l10n.faqEntry2NoVisionTitle,
    summary: (_) => l10n.faqEntry2NoVisionSummary,
    icon: Lucide.Image,
  ),

  FaqSectionHeader(title: (_) => l10n.faqSectionSearch),
  FaqEntryItem(
    key: '3_1',
    title: (_) => l10n.faqEntry3SearchQualityTitle,
    summary: (_) => l10n.faqEntry3SearchQualitySummary,
    icon: Lucide.Search,
  ),
  FaqEntryItem(
    key: '3_2',
    title: (_) => l10n.faqEntry3ContextExplosionTitle,
    summary: (_) => l10n.faqEntry3ContextExplosionSummary,
    icon: Lucide.Globe,
  ),

  FaqSectionHeader(title: (_) => l10n.faqSectionCache),
  FaqEntryItem(
    key: '4_1',
    title: (_) => l10n.faqEntry4CacheHitrateTitle,
    summary: (_) => l10n.faqEntry4CacheHitrateSummary,
    icon: Lucide.Zap,
  ),
  FaqEntryItem(
    key: '4_2',
    title: (_) => l10n.faqEntry4ClaudeCacheTitle,
    summary: (_) => l10n.faqEntry4ClaudeCacheSummary,
    icon: Lucide.Zap,
  ),

  FaqSectionHeader(title: (_) => l10n.faqSectionBackup),
  FaqEntryItem(
    key: '5_1',
    title: (_) => l10n.faqEntry5BackupRestoreTitle,
    summary: (_) => l10n.faqEntry5BackupRestoreSummary,
    icon: Lucide.Database,
  ),
  FaqEntryItem(
    key: '5_2',
    title: (_) => l10n.faqEntry5CrossDeviceSyncTitle,
    summary: (_) => l10n.faqEntry5CrossDeviceSyncSummary,
    icon: Lucide.Database,
  ),
];
