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
  FaqSectionHeader(title: (_) => 'Kelivo — General'),
  FaqEntryItem(
    key: '1_1',
    title: (_) => 'Tips for new Kelivo users',
    summary: (_) =>
        '1. Regular backups are strongly recommended (local or remote), as Hive database files may become corrupted after a crash.\n'
        '2. Do not delete assistants casually — all chat history under that assistant will be permanently lost.\n'
        '3. For long conversations, avoid the built-in Sample Assistant and the assistant memory feature, as they inject dynamic variables into system prompts which hurt cache hit rates.',
    icon: Lucide.Lightbulb,
  ),
];
