import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/sidebar_layout.dart';
import '../core/providers/settings_provider.dart';
import '../features/settings/widgets/sidebar_entries_editor.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/ios_settings_rows.dart';
import '../shared/widgets/ios_tactile.dart';
import '../shared/widgets/section_card.dart';
import '../shared/widgets/sidebar_entry_labels.dart';
import '../theme/app_font_weights.dart';
import 'desktop_context_menu.dart';

class DesktopCustomizeSidebarNotification extends Notification {
  const DesktopCustomizeSidebarNotification();
}

void showDesktopSidebarEntryMenu(
  BuildContext context,
  Offset position, {
  SidebarEntry? entry,
}) {
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  showDesktopContextMenuAt(
    context,
    globalPosition: position,
    items: [
      if (entry != null)
        for (final visibility in SidebarVisibility.values)
          DesktopContextMenuItem(
            label: visibility.menuLabel(l10n),
            checked: settings.desktopRailEntries[entry] == visibility,
            onTap: () => settings.setDesktopRailEntries({
              ...settings.desktopRailEntries,
              entry: visibility,
            }),
          ),
      DesktopContextMenuItem(
        icon: Lucide.panelLeft,
        label: l10n.sidebarCustomize,
        startsGroup: entry != null,
        onTap: () {
          if (context.mounted) {
            const DesktopCustomizeSidebarNotification().dispatch(context);
          }
        },
      ),
    ],
  );
}

class DesktopSidebarCustomization extends StatelessWidget {
  const DesktopSidebarCustomization({
    super.key,
    required this.open,
    required this.onClose,
  });

  final bool open;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: duration,
            child: open
                ? _DesktopSidebarPane(onClose: onClose)
                : const SizedBox.expand(),
            transitionBuilder: (child, animation) {
              if (child is! _DesktopSidebarPane) return child;
              return Stack(
                fit: StackFit.expand,
                children: [
                  FadeTransition(
                    opacity: animation,
                    child: ModalBarrier(
                      color: cs.scrim.withValues(alpha: .16),
                      onDismiss: onClose,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SlideTransition(
                      position:
                          Tween(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebarPane extends StatelessWidget {
  const _DesktopSidebarPane({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    return SizedBox(
      width: 360,
      height: double.infinity,
      child: Material(
        elevation: 8,
        color: cs.surface,
        child: FocusScope(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): onClose,
            },
            child: Focus(
              autofocus: true,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.sidebarLocationRail,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      ),
                      IosIconButton(
                        icon: Lucide.X,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onTap: onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    children: [
                      SidebarEntriesEditor(
                        entries: settings.desktopRailEntries,
                        onChanged: settings.setDesktopRailEntries,
                      ),
                      const IosRowDivider(indent: 12),
                      IosNavRow(
                        icon: Lucide.RotateCcw,
                        label: l10n.sidebarRestoreDefaults,
                        focusable: true,
                        onTap: () => settings.setDesktopRailEntries(
                          defaultDesktopSidebarEntries,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
