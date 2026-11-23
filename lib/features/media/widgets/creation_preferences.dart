import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/desktop_settings_navigation_bus.dart';
import '../../settings/pages/display_settings_page.dart';
import '../../settings/widgets/settings_search_target.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/media_creation_controller.dart';

IconData creationTopicViewIcon(CreationTopicView mode) => switch (mode) {
  CreationTopicView.coverAndTitle => LucideIcons.layoutGrid,
  CreationTopicView.covers => LucideIcons.images,
  CreationTopicView.list => LucideIcons.list,
};

String creationTopicViewLabel(AppLocalizations l10n, CreationTopicView mode) =>
    switch (mode) {
      CreationTopicView.coverAndTitle => l10n.creationCoversAndTitles,
      CreationTopicView.covers => l10n.creationCoversOnly,
      CreationTopicView.list => l10n.creationTopicList,
    };

Future<void> showCreationDisplayMenu(
  BuildContext context, {
  required bool desktop,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final media = context.read<MediaCreationController>();
  final items = [
    for (final mode in CreationTopicView.values)
      ActionSheetItem(
        icon: creationTopicViewIcon(mode),
        label: creationTopicViewLabel(l10n, mode),
        checked: media.topicView == mode,
        onTap: () => media.setTopicView(mode),
      ),
    ActionSheetItem(
      icon: LucideIcons.wandSparkles,
      label: l10n.creationAutoTitle,
      checked: media.autoTitle,
      onTap: () => media.setAutoTitle(!media.autoTitle),
    ),
    ActionSheetItem(
      icon: Lucide.Settings,
      label: l10n.settingsPageDisplay,
      onTap: () {
        if (desktop) {
          DesktopSettingsNavigationBus.instance.openCreationPreferences();
        } else {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => SettingsSearchTarget(
                label: l10n.creationTopicDisplay,
                child: const DisplaySettingsPage(),
              ),
            ),
          );
        }
      },
    ),
  ];
  if (!desktop) {
    await showMobileActionSheet(
      context,
      title: l10n.creationTopicDisplay,
      items: items,
    );
    return;
  }
  final render = context.findRenderObject() as RenderBox?;
  final anchor = render == null
      ? Offset.zero
      : render.localToGlobal(render.size.bottomCenter(Offset.zero));
  await showDesktopContextMenuAt(
    context,
    globalPosition: anchor,
    compact: true,
    items: [
      for (final (index, choice) in items.indexed)
        DesktopContextMenuItem(
          icon: choice.icon,
          label: choice.label,
          checked: choice.checked,
          startsGroup: index >= items.length - 2,
          subtitle: index == items.length - 2
              ? media.autoTitle
                    ? l10n.creationAutoTitleHelp
                    : l10n.creationAutoTitleOffHelp
              : null,
          onTap: choice.onTap,
        ),
    ],
  );
}

class CreationPreferences extends StatelessWidget {
  const CreationPreferences({super.key, required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController?>();
    if (media == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final choice = media.topicView;
    final modelHelp = media.autoTitle
        ? l10n.creationAutoTitleHelp
        : l10n.creationAutoTitleOffHelp;
    if (desktop) {
      return SettingsSearchTarget.wrap(
        context,
        l10n.creationTopicDisplay,
        Column(
          children: [
            _preferenceRow(
              l10n.creationTopicDisplay,
              SegmentedTabs(
                height: 30,
                compact: true,
                expand: false,
                radioGroup: true,
                index: choice.index,
                tabs: [
                  for (final mode in CreationTopicView.values)
                    SegmentedTab(
                      label: creationTopicViewLabel(l10n, mode),
                      icon: creationTopicViewIcon(mode),
                    ),
                ],
                onChanged: (index) =>
                    media.setTopicView(CreationTopicView.values[index]),
              ),
            ),
            const Divider(height: 1),
            _preferenceRow(
              l10n.creationAutoTitle,
              Tooltip(
                message: modelHelp,
                child: IosSwitch(
                  value: media.autoTitle,
                  semanticLabel: l10n.creationAutoTitle,
                  onChanged: media.setAutoTitle,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SettingsSearchTarget.wrap(
      context,
      l10n.creationTopicDisplay,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 15, 12, 6),
            child: Text(
              l10n.creationTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.semibold,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          SectionCard(
            children: [
              IosCardPress(
                onTap: () => showMobileActionSheet(
                  context,
                  title: l10n.creationTopicDisplay,
                  items: [
                    for (final mode in CreationTopicView.values)
                      ActionSheetItem(
                        icon: creationTopicViewIcon(mode),
                        label: creationTopicViewLabel(l10n, mode),
                        checked: choice == mode,
                        onTap: () => media.setTopicView(mode),
                      ),
                  ],
                ),
                child: _preferenceRow(
                  l10n.creationTopicDisplay,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        creationTopicViewLabel(l10n, choice),
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        Lucide.ChevronRight,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  icon: LucideIcons.layoutGrid,
                ),
              ),
              _preferenceRow(
                l10n.creationAutoTitle,
                IosSwitch(
                  value: media.autoTitle,
                  onChanged: media.setAutoTitle,
                  semanticLabel: l10n.creationAutoTitle,
                ),
                icon: LucideIcons.wandSparkles,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              modelHelp,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferenceRow(String label, Widget control, {IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13.5)),
              ),
              control,
            ],
          ),
        ),
      );
}
