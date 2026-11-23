import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/desktop_settings_navigation_bus.dart';
import '../../../desktop/widgets/desktop_select_dropdown.dart';
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

IconData _gameIcon(CreationWaitGame mode) => switch (mode) {
  CreationWaitGame.random => LucideIcons.shuffle,
  CreationWaitGame.snake => LucideIcons.worm,
  CreationWaitGame.brick => LucideIcons.brickWall,
  CreationWaitGame.off => LucideIcons.circleOff,
};

String _gameLabel(AppLocalizations l10n, CreationWaitGame mode) =>
    switch (mode) {
      CreationWaitGame.random => l10n.creationGameRandom,
      CreationWaitGame.snake => l10n.creationGameSnake,
      CreationWaitGame.brick => l10n.creationGameBrick,
      CreationWaitGame.off => l10n.creationGameOff,
    };

List<ActionSheetItem> _gameOptions(
  AppLocalizations l10n,
  MediaCreationController media, {
  bool group = false,
}) => [
  for (final game in CreationWaitGame.values)
    ActionSheetItem(
      icon: _gameIcon(game),
      label: _gameLabel(l10n, game),
      checked: media.waitGame == game,
      startsGroup: group && game == CreationWaitGame.random,
      groupLabel: group && game == CreationWaitGame.random
          ? l10n.creationWaitGame
          : null,
      onTap: () => media.setWaitGame(game),
    ),
];

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
        groupLabel: mode == CreationTopicView.coverAndTitle
            ? l10n.creationTopicDisplay
            : null,
        onTap: () => media.setTopicView(mode),
      ),
    ActionSheetItem(
      icon: LucideIcons.wandSparkles,
      label: l10n.creationAutoTitle,
      checked: media.autoTitle,
      startsGroup: true,
      subtitle: media.autoTitle
          ? l10n.creationAutoTitleHelp
          : l10n.creationAutoTitleOffHelp,
      onTap: () => media.setAutoTitle(!media.autoTitle),
    ),
    ..._gameOptions(l10n, media, group: true),
    ActionSheetItem(
      icon: Lucide.Settings,
      label: l10n.creationEditInPreferences,
      startsGroup: true,
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
      title: l10n.creationDisplayAndGames,
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
      for (final choice in items)
        DesktopContextMenuItem(
          icon: choice.icon,
          label: choice.label,
          checked: choice.checked,
          startsGroup: choice.startsGroup,
          groupLabel: choice.groupLabel,
          subtitle: choice.subtitle,
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
    final waitGame = media.waitGame;
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
              IosSwitch(
                value: media.autoTitle,
                semanticLabel: l10n.creationAutoTitle,
                onChanged: media.setAutoTitle,
              ),
              help: modelHelp,
            ),
            const Divider(height: 1),
            _preferenceRow(
              l10n.creationWaitGame,
              DesktopSelectDropdown<CreationWaitGame>(
                value: waitGame,
                options: [
                  for (final game in CreationWaitGame.values)
                    DesktopSelectOption(
                      value: game,
                      label: _gameLabel(l10n, game),
                      icon: _gameIcon(game),
                    ),
                ],
                onSelected: media.setWaitGame,
                semanticLabel: l10n.creationWaitGame,
                maxLabelWidth: 135,
                minHeight: 30,
              ),
              help: l10n.creationWaitGameHelp,
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
                  _mobileChoice(colors, creationTopicViewLabel(l10n, choice)),
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
              IosCardPress(
                onTap: () => showMobileActionSheet(
                  context,
                  title: l10n.creationWaitGame,
                  items: _gameOptions(l10n, media),
                ),
                child: _preferenceRow(
                  l10n.creationWaitGame,
                  _mobileChoice(colors, _gameLabel(l10n, waitGame)),
                  icon: LucideIcons.gamepad2,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              '$modelHelp\n${l10n.creationWaitGameHelp}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileChoice(ColorScheme colors, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      ),
      Icon(Lucide.ChevronRight, size: 15, color: colors.onSurfaceVariant),
    ],
  );

  Widget _preferenceRow(
    String label,
    Widget control, {
    IconData? icon,
    String? help,
  }) => Padding(
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
            child: Row(
              spacing: 5,
              children: [
                Flexible(
                  child: Text(label, style: const TextStyle(fontSize: 13.5)),
                ),
                if (help != null)
                  Tooltip(
                    message: help,
                    child: const Icon(LucideIcons.info, size: 13),
                  ),
              ],
            ),
          ),
          if (icon == null)
            control
          else
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: control,
              ),
            ),
        ],
      ),
    ),
  );
}
