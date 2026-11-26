import '../../core/models/sidebar_layout.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

extension SidebarEntryLabels on SidebarEntry {
  String label(AppLocalizations l10n) => switch (this) {
    SidebarEntry.search => l10n.desktopNavGlobalSearchTooltip,
    SidebarEntry.media => l10n.creationTitle,
    SidebarEntry.history => l10n.sideDrawerHistory,
    SidebarEntry.translate => l10n.desktopNavTranslateTooltip,
    SidebarEntry.storage => l10n.desktopNavStorageTooltip,
  };

  IconData get icon => switch (this) {
    SidebarEntry.search => Lucide.Search,
    SidebarEntry.media => Lucide.Palette,
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

class SidebarEntryGlyph extends StatelessWidget {
  const SidebarEntryGlyph({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    this.unread = false,
  });

  final IconData icon;
  final double size;
  final Color color;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: size, color: color),
        if (unread)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary,
                border: Border.all(color: cs.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
