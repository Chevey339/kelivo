import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/sidebar_layout.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/sidebar_entry_labels.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../settings/pages/sidebar_settings_page.dart';

const sidebarExpandCurve = Cubic(.32, .72, 0, 1);

Offset _menuAnchor(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

void _showEntryActions(
  BuildContext context,
  SidebarEntry entry, {
  VoidCallback? openSettings,
}) {
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  showDesktopContextMenuAt(
    context,
    globalPosition: _menuAnchor(context),
    compact: true,
    borderRadius: 14,
    items: [
      for (final value in SidebarVisibility.values)
        DesktopContextMenuItem(
          label: value.menuLabel(l10n),
          checked: value == settings.mobileSidebarEntries[entry],
          onTap: () => settings.setMobileSidebarEntries({
            ...settings.mobileSidebarEntries,
            entry: value,
          }),
        ),
      DesktopContextMenuItem(
        label: l10n.sidebarCustomize,
        startsGroup: true,
        onTap:
            openSettings ??
            () {
              if (context.mounted) openSidebarSettings(context);
            },
      ),
    ],
  );
}

enum _Customize { open }

void _showCustomizeActions(BuildContext context, {VoidCallback? openSettings}) {
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  showDesktopContextMenuAt(
    context,
    globalPosition: _menuAnchor(context),
    compact: true,
    borderRadius: 14,
    items: [
      DesktopContextMenuItem(
        label: l10n.sidebarHideCustomize,
        onTap: () => settings.setShowSidebarCustomizeInMore(false),
      ),
      DesktopContextMenuItem(
        label: l10n.sidebarOpenSettings,
        onTap:
            openSettings ??
            () {
              if (context.mounted) openSidebarSettings(context);
            },
      ),
    ],
  );
}

class MobileSidebarEntries extends StatefulWidget {
  const MobileSidebarEntries({super.key, required this.onOpen});

  final ValueChanged<SidebarEntry> onOpen;

  @override
  State<MobileSidebarEntries> createState() => _MobileSidebarEntriesState();
}

class _MobileSidebarEntriesState extends State<MobileSidebarEntries> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final entries = settings.mobileSidebarEntries;
    final visible = sidebarEntriesWithVisibility(
      entries,
      SidebarVisibility.show,
    );
    final more = sidebarEntriesWithVisibility(entries, SidebarVisibility.more);
    final customize = settings.showSidebarCustomizeInMore;
    final hasMore = more.isNotEmpty || customize;
    if (visible.isEmpty && !hasMore) return const SizedBox.shrink();

    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 340);
    Widget row(SidebarEntry entry, {bool nested = false}) => _EntryRow(
      icon: entry.icon,
      label: entry.label(l10n),
      muted: nested,
      onTap: () => widget.onOpen(entry),
      onLongPress: (context) => _showEntryActions(context, entry),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final entry in visible) row(entry),
          if (hasMore) ...[
            Semantics(
              expanded: _expanded,
              child: _EntryRow(
                icon: Lucide.Ellipsis,
                label: l10n.sidebarMore,
                trailing: AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: duration,
                  curve: sidebarExpandCurve,
                  child: Icon(
                    Lucide.ChevronDown,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: sidebarExpandCurve,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Column(
                        children: [
                          for (final entry in more) row(entry, nested: true),
                          if (customize)
                            _EntryRow(
                              icon: Lucide.panelLeft,
                              label: l10n.sidebarCustomize,
                              muted: true,
                              onTap: () => openSidebarSettings(context),
                              onLongPress: _showCustomizeActions,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.onSurface.withValues(alpha: .06),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ValueChanged<BuildContext>? onLongPress;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = muted ? cs.onSurfaceVariant : cs.onSurface;
    return SizedBox(
      height: 46,
      child: IosCardPress(
        focusable: true,
        baseColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress == null ? null : () => onLongPress!(context),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: color),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class MobileSidebarEntryIcon extends StatelessWidget {
  const MobileSidebarEntryIcon({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final SidebarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final history = entry == SidebarEntry.history;
    return IosIconButton(
      key: ValueKey(entry),
      icon: entry.icon,
      size: history ? 20 : 22,
      minSize: history ? 44 : 45,
      padding: EdgeInsets.all(history ? 8 : 10),
      semanticLabel: entry.label(AppLocalizations.of(context)!),
      onTap: onTap,
      onLongPress: () => _showEntryActions(context, entry),
    );
  }
}

List<SidebarEntry> mobileSidebarOverflow(
  Map<SidebarEntry, SidebarVisibility> entries, {
  required int iconLimit,
}) {
  final overflow = sidebarEntriesWithVisibility(
    entries,
    SidebarVisibility.show,
  ).where((entry) => entry != SidebarEntry.history).skip(iconLimit).toSet();
  return [
    for (final entry in entries.entries)
      if (entry.value == SidebarVisibility.more || overflow.contains(entry.key))
        entry.key,
  ];
}

Future<void> showMobileSidebarMore(
  BuildContext context,
  ValueChanged<SidebarEntry> onOpen, {
  required int iconLimit,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final selection = await showFormSheet<Object>(
    context,
    builder: (context) {
      final settings = context.watch<SettingsProvider>();
      final entries = mobileSidebarOverflow(
        settings.mobileSidebarEntries,
        iconLimit: iconLimit,
      );
      final cs = Theme.of(context).colorScheme;
      return FormSheet(
        title: l10n.sidebarMore,
        children: [
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (final entry in entries)
                      Builder(
                        builder: (context) => SizedBox(
                          width: (constraints.maxWidth - 18) / 4,
                          child: IosCardPress(
                            focusable: true,
                            baseColor: Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                            onTap: () => Navigator.of(context).pop(entry),
                            onLongPress: () => _showEntryActions(
                              context,
                              entry,
                              openSettings: () {
                                if (context.mounted) {
                                  Navigator.of(context).pop(_Customize.open);
                                }
                              },
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.appColors.surfaceFill,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(entry.icon, size: 22),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.label(l10n),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (settings.showSidebarCustomizeInMore)
            SectionCard(
              children: [
                Builder(
                  builder: (context) => IosNavRow(
                    label: l10n.sidebarCustomize,
                    icon: Lucide.panelLeft,
                    onTap: () => Navigator.of(context).pop(_Customize.open),
                    onLongPress: () => _showCustomizeActions(
                      context,
                      openSettings: () {
                        if (context.mounted) {
                          Navigator.of(context).pop(_Customize.open);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    },
  );
  if (!context.mounted) return;
  if (selection is SidebarEntry) {
    onOpen(selection);
  } else if (selection == _Customize.open) {
    openSidebarSettings(context);
  }
}
