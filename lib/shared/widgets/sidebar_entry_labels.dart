import '../../core/models/sidebar_layout.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

extension SidebarEntryLabels on SidebarEntry {
  String label(AppLocalizations l10n) => switch (this) {
    SidebarEntry.search => l10n.desktopNavGlobalSearchTooltip,
    SidebarEntry.history => l10n.sideDrawerHistory,
    SidebarEntry.translate => l10n.desktopNavTranslateTooltip,
    SidebarEntry.storage => l10n.desktopNavStorageTooltip,
  };

  IconData get icon => switch (this) {
    SidebarEntry.search => Lucide.Search,
    SidebarEntry.history => Lucide.History,
    SidebarEntry.translate => Lucide.Languages,
    SidebarEntry.storage => Lucide.Folder,
  };
}

extension SidebarVisibilityLabels on SidebarVisibility {
  String label(AppLocalizations l10n) => switch (this) {
    SidebarVisibility.show => l10n.sidebarVisibilityShow,
    SidebarVisibility.more => l10n.sidebarMore,
    SidebarVisibility.hidden => l10n.sidebarVisibilityHidden,
  };

  String menuLabel(AppLocalizations l10n) => switch (this) {
    SidebarVisibility.show => l10n.sidebarMenuShow,
    SidebarVisibility.more => l10n.sidebarMenuMore,
    SidebarVisibility.hidden => l10n.sidebarMenuHide,
  };
}
