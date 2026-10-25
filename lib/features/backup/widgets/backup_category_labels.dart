import 'package:flutter/widgets.dart';

import '../../../core/models/backup_scope.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

extension BackupCategoryLabels on BackupCategory {
  String label(AppLocalizations l10n) => switch (this) {
    BackupCategory.chats => l10n.backupPageChatsLabel,
    BackupCategory.files => l10n.backupPageFilesLabel,
    BackupCategory.assistants => l10n.backupPageAssistantsLabel,
    BackupCategory.providers => l10n.backupPageProvidersLabel,
    BackupCategory.mcp => l10n.backupPageMcpLabel,
    BackupCategory.environmentVariables =>
      l10n.backupPageEnvironmentVariablesLabel,
    BackupCategory.skills => l10n.backupPageSkillsLabel,
    BackupCategory.worldBooks => l10n.backupPageWorldBooksLabel,
    BackupCategory.memories => l10n.backupPageMemoriesLabel,
    BackupCategory.quickPhrases => l10n.backupPageQuickPhrasesLabel,
    BackupCategory.instructions => l10n.backupPageInstructionsLabel,
    BackupCategory.workspaces => l10n.backupPageWorkspacesLabel,
    BackupCategory.searchServices => l10n.backupPageSearchServicesLabel,
    BackupCategory.speechServices => l10n.backupPageSpeechServicesLabel,
    BackupCategory.settings => l10n.backupPageSettingsLabel,
  };

  IconData get icon => switch (this) {
    BackupCategory.chats => Lucide.MessageSquare,
    BackupCategory.files => Lucide.FileText,
    BackupCategory.assistants => Lucide.Bot,
    BackupCategory.providers => Lucide.Network,
    BackupCategory.mcp => Lucide.Cable,
    BackupCategory.environmentVariables => Lucide.Terminal,
    BackupCategory.skills => Lucide.Zap,
    BackupCategory.worldBooks => Lucide.BookOpen,
    BackupCategory.memories => Lucide.Brain,
    BackupCategory.quickPhrases => Lucide.MessageCircle,
    BackupCategory.instructions => Lucide.FileText,
    BackupCategory.workspaces => Lucide.Folder,
    BackupCategory.searchServices => Lucide.Search,
    BackupCategory.speechServices => Lucide.Volume2,
    BackupCategory.settings => Lucide.Settings,
  };
}
