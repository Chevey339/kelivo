import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../providers/media_creation_controller.dart';
import 'creation_menu.dart';
import 'creation_picker.dart';

IconData creationTopicViewIcon(CreationTopicView mode) => switch (mode) {
  CreationTopicView.coverAndTitle => LucideIcons.layoutGrid,
  CreationTopicView.covers => LucideIcons.images,
  CreationTopicView.list => LucideIcons.list,
};

String _topicViewLabel(AppLocalizations l10n, CreationTopicView mode) =>
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
        label: _topicViewLabel(l10n, mode),
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
    for (final game in CreationWaitGame.values)
      ActionSheetItem(
        icon: _gameIcon(game),
        label: _gameLabel(l10n, game),
        checked: media.waitGame == game,
        startsGroup: game == CreationWaitGame.random,
        groupLabel: game == CreationWaitGame.random
            ? l10n.creationWaitGame
            : null,
        onTap: () => media.setWaitGame(game),
      ),
  ];
  if (!desktop) {
    await showCreationActions(
      context,
      title: l10n.creationDisplayAndGames,
      items: items,
    );
    return;
  }
  await showCreationMenu(
    context,
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
