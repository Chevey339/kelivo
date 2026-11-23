import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/sidebar_layout.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../widgets/sidebar_entries_editor.dart';

void openSidebarSettings(BuildContext context) {
  final duration = handoffDuration(context, 460);
  Navigator.of(context).push<void>(
    PageRouteBuilder(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => const SidebarSettingsPage(),
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: handoffCurve)),
        textDirection: Directionality.of(context),
        child: child,
      ),
    ),
  );
}

class SidebarSettingsPage extends StatelessWidget {
  const SidebarSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final layout = settings.mobileSidebarLayout;
    final currentPreset = layout.preset;
    return ColoredBox(
      color: cs.surface,
      child: SafeArea(
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: cs.onSurface,
            decoration: TextDecoration.none,
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IosIconButton(
                      icon: Lucide.ArrowLeft,
                      size: 22,
                      minSize: 44,
                      tooltip: l10n.settingsPageBackButton,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.settingsPageTitle} › ${l10n.settingsPageDisplay}',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            l10n.sidebarSettingsTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    IosSectionHeader(text: l10n.sidebarLayoutTitle),
                    if (currentPreset == null)
                      IosSectionFooter(text: l10n.sidebarPresetCustom),
                    for (final presets in [
                      SidebarPreset.values.take(2),
                      SidebarPreset.values.skip(2),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final preset in presets) ...[
                              if (preset != presets.first)
                                const SizedBox(width: 8),
                              Expanded(
                                child: _PresetCard(
                                  preset: preset,
                                  selected: currentPreset == preset,
                                  onTap: () => settings.setMobileSidebarLayout(
                                    preset.layout,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    IosSectionHeader(text: l10n.sidebarReorderTitle),
                    IosSectionFooter(text: l10n.sidebarReorderHint),
                    SectionCard(
                      children: [
                        SidebarReorderList<SidebarBlock>(
                          items: layout.visibleOrder.toList(),
                          itemExtent: 52,
                          separator: SidebarBlock.conversations,
                          onMove: (block, target) =>
                              settings.setMobileSidebarLayout(
                                layout.moveBlock(block, target),
                              ),
                          itemBuilder: (context, block, handle) {
                            final separator =
                                block == SidebarBlock.conversations;
                            return Container(
                              height: 52,
                              color: separator
                                  ? context.appColors.surfaceFill
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  handle,
                                  Icon(
                                    _blockIcon(block),
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_blockLabel(block, l10n)),
                                  ),
                                  if (!separator)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        layout.isBelowConversations(block)
                                            ? l10n.sidebarBlockBottom
                                            : l10n.sidebarBlockTop,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    IosSectionHeader(text: l10n.sidebarBlockAssistant),
                    SectionCard(
                      children: [
                        IosSwitchRow(
                          label: l10n
                              .displaySettingsPageKeepSidebarOpenOnAssistantTapTitle,
                          value: settings.keepSidebarOpenOnAssistantTap,
                          onChanged: settings.setKeepSidebarOpenOnAssistantTap,
                        ),
                        const IosRowDivider(),
                        IosSwitchRow(
                          label: l10n
                              .displaySettingsPageNewChatOnAssistantSwitchTitle,
                          value: settings.newChatOnAssistantSwitch,
                          onChanged: settings.setNewChatOnAssistantSwitch,
                        ),
                        const IosRowDivider(),
                        IosSwitchRow(
                          label: l10n.sidebarHideSingleAssistant,
                          subtitle: l10n.sidebarHideSingleAssistantHint,
                          value: settings.hideSidebarSingleAssistant,
                          onChanged: settings.setHideSidebarSingleAssistant,
                        ),
                      ],
                    ),
                    IosSectionHeader(text: l10n.sidebarBlockEntries),
                    SectionCard(
                      children: [
                        IosNavRow(
                          label: l10n.sidebarDisplayAs,
                          trailing: SizedBox(
                            width: 140,
                            child: SlidingSegmentedTabs(
                              height: 36,
                              backgroundColor: context.appColors.surfaceFill,
                              tabs: [
                                SegmentedTab(label: l10n.sidebarStyleList),
                                SegmentedTab(label: l10n.sidebarStyleIcons),
                              ],
                              index: layout.style.index,
                              onChanged: (index) =>
                                  settings.setMobileSidebarLayout(
                                    layout.withStyle(
                                      SidebarStyle.values[index],
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const IosRowDivider(),
                        SidebarEntriesEditor(
                          entries: settings.mobileSidebarEntries,
                          mobileStyle: layout.style,
                          onChanged: settings.setMobileSidebarEntries,
                        ),
                        const IosRowDivider(),
                        IosSwitchRow(
                          label: l10n.sidebarShowCustomizeInMore,
                          subtitle: l10n.sidebarShowCustomizeInMoreHint,
                          value: settings.showSidebarCustomizeInMore,
                          onChanged: settings.setShowSidebarCustomizeInMore,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _blockIcon(SidebarBlock block) => switch (block) {
  SidebarBlock.user => Lucide.User,
  SidebarBlock.search => Lucide.Search,
  SidebarBlock.entries => Lucide.ListTree,
  SidebarBlock.assistant => Lucide.Bot,
  SidebarBlock.conversations => Lucide.MessageCircle,
};

String _blockLabel(SidebarBlock block, AppLocalizations l10n) =>
    switch (block) {
      SidebarBlock.user => l10n.sidebarBlockUser,
      SidebarBlock.search => l10n.sidebarBlockSearch,
      SidebarBlock.entries => l10n.sidebarBlockEntries,
      SidebarBlock.assistant => l10n.sidebarBlockAssistant,
      SidebarBlock.conversations => l10n.sidebarBlockConversations,
    };

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final SidebarPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final title = switch (preset) {
      SidebarPreset.current => l10n.sidebarPresetCurrent,
      SidebarPreset.navigation => l10n.sidebarPresetNavigation,
      SidebarPreset.assistantAtBottom => l10n.sidebarPresetAssistantBottom,
      SidebarPreset.allAtTop => l10n.sidebarPresetAllTop,
    };
    return Semantics(
      selected: selected,
      child: IosCardPress(
        focusable: true,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? cs.primary
              : cs.outlineVariant.withValues(alpha: .3),
          width: selected ? 2 : 1,
        ),
        baseColor: context.appColors.surfaceCard,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                height: 78,
                child: Column(
                  children: [
                    for (final block in preset.layout.visibleOrder)
                      if (block == SidebarBlock.conversations)
                        const Expanded(child: _PresetConversations())
                      else
                        _PresetBlock(
                          block: block,
                          icons: preset.layout.style == SidebarStyle.icons,
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.medium,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                ),
                if (selected) Icon(Lucide.Check, size: 15, color: cs.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetBlock extends StatelessWidget {
  const _PresetBlock({required this.block, required this.icons});

  final SidebarBlock block;
  final bool icons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(_blockIcon(block), size: 10, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: block == SidebarBlock.entries ? 13 : 7,
              decoration: BoxDecoration(
                color: block == SidebarBlock.entries
                    ? cs.primary.withValues(alpha: .12)
                    : context.appColors.surfaceFill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (icons &&
              (block == SidebarBlock.user || block == SidebarBlock.search)) ...[
            const SizedBox(width: 4),
            Icon(
              block == SidebarBlock.search ? Lucide.History : Lucide.Languages,
              size: 8,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetConversations extends StatelessWidget {
  const _PresetConversations();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final fraction in [.8, .65, .75])
          Flexible(
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceFill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
