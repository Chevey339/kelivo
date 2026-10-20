import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/services/browser/browser_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/browser_models.dart';
import '../pages/browser_management_page.dart';
import 'browser_glass.dart';
import 'browser_library.dart';
import 'browser_surface_controls.dart';

typedef _BrowserSettingsValues = ({
  BrowserSearchEngine searchEngine,
  bool desktopMode,
  bool restoreTabs,
  bool saveHistory,
  bool agentEnabled,
  BrowserSurfaceStyle surfaceStyle,
  bool supportsWebsiteDataClear,
});

class BrowserSettingsPanel extends StatelessWidget {
  const BrowserSettingsPanel({
    super.key,
    required this.service,
    required this.onError,
    required this.onDataCleared,
    this.scrollController,
  });

  final BrowserService service;
  final ValueChanged<Object> onError;
  final VoidCallback onDataCleared;
  final ScrollController? scrollController;

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      onError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableProvider<BrowserService>.value(
      value: service,
      child: Selector<BrowserService, _BrowserSettingsValues>(
        selector: (_, service) {
          final settings = service.settings;
          return (
            searchEngine: settings.searchEngine,
            desktopMode: settings.desktopMode,
            restoreTabs: settings.restoreTabs,
            saveHistory: settings.saveHistory,
            agentEnabled: settings.agentEnabled,
            surfaceStyle: settings.surfaceStyle,
            supportsWebsiteDataClear: service.supportsWebsiteDataClear,
          );
        },
        builder: (context, s, _) => ListView(
          controller: scrollController,
          padding:
              const EdgeInsets.fromLTRB(18, 4, 18, 28) +
              BrowserManagementPage.contentInsetsOf(context),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                l.browserSurfaceStyle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final style in BrowserSurfaceStyle.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _SurfaceChoice(
                        style: style,
                        selected: s.surfaceStyle == style,
                        label: switch (style) {
                          BrowserSurfaceStyle.liquid => l.browserSurfaceLiquid,
                          BrowserSurfaceStyle.frosted =>
                            l.browserSurfaceFrosted,
                          BrowserSurfaceStyle.solid => l.browserSurfaceSolid,
                        },
                        onSelected: () => _run(
                          () => service.updateSettings(
                            service.settings.copyWith(surfaceStyle: style),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            BrowserSurfaceGroup(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 400 &&
                        MediaQuery.textScalerOf(context).scale(13) > 20;
                    return BrowserSurfaceRow(
                      icon: LucideIcons.search,
                      label: l.browserSearchEngine,
                      subtitle: stacked
                          ? browserSearchEngineName(s.searchEngine)
                          : null,
                      trailing: stacked
                          ? const Icon(LucideIcons.chevronRight, size: 15)
                          : ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * .4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      browserSearchEngineName(s.searchEngine),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                      onTap: () => _chooseSearchEngine(context),
                    );
                  },
                ),
                _switchRow(
                  icon: LucideIcons.monitor,
                  label: l.browserDesktopMode,
                  subtitle: l.browserDesktopModeDescription,
                  value: s.desktopMode,
                  onChanged: (value) => _run(
                    () => service.updateSettings(
                      service.settings.copyWith(desktopMode: value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BrowserSurfaceGroup(
              children: [
                _switchRow(
                  icon: LucideIcons.panelsTopLeft,
                  label: l.browserRestoreTabs,
                  subtitle: l.browserRestoreTabsDescription,
                  value: s.restoreTabs,
                  onChanged: (value) => _run(
                    () => service.updateSettings(
                      service.settings.copyWith(restoreTabs: value),
                    ),
                  ),
                ),
                _switchRow(
                  icon: LucideIcons.history,
                  label: l.browserSaveHistory,
                  subtitle: l.browserSaveHistoryDescription,
                  value: s.saveHistory,
                  onChanged: (value) => _run(
                    () => service.updateSettings(
                      service.settings.copyWith(saveHistory: value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BrowserSurfaceGroup(
              children: [
                _switchRow(
                  icon: LucideIcons.bot,
                  label: l.browserAgentEnabled,
                  subtitle: l.browserAgentEnabledDescription,
                  value: s.agentEnabled,
                  onChanged: (value) => _run(
                    () => service.updateSettings(
                      service.settings.copyWith(agentEnabled: value),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
              child: Text(
                l.browserAgentDescription,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            BrowserSurfaceGroup(
              children: [
                BrowserSurfaceRow(
                  icon: LucideIcons.eraser,
                  label: l.browserClearData,
                  subtitle: s.supportsWebsiteDataClear
                      ? null
                      : l.browserClearDataUnavailable,
                  destructive: s.supportsWebsiteDataClear,
                  onTap: s.supportsWebsiteDataClear
                      ? () => _run(() async {
                          final confirmed = await confirmBrowserAction(
                            context,
                            l.browserClearDataConfirm,
                            l.browserClearData,
                          );
                          if (confirmed) {
                            await service.clearWebsiteData();
                            onDataCleared();
                          }
                        })
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => BrowserSurfaceRow(
    label: label,
    icon: icon,
    subtitle: subtitle,
    onTap: () => onChanged(!value),
    trailing: BrowserSwitch(
      value: value,
      onChanged: onChanged,
      semanticLabel: label,
    ),
  );

  Future<void> _chooseSearchEngine(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final engine = await showBrowserDialog<BrowserSearchEngine>(
      context,
      maxWidth: 380,
      child: Builder(
        builder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrowserDialogHeader(title: l.browserSearchEngine),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: BrowserSurfaceGroup(
                key: const ValueKey('browserSearchEngineOptions'),
                filled: false,
                children: [
                  for (final engine in BrowserSearchEngine.values)
                    BrowserSurfaceRow(
                      label: browserSearchEngineName(engine),
                      trailing: service.settings.searchEngine == engine
                          ? const Icon(LucideIcons.check, size: 20)
                          : null,
                      onTap: () => Navigator.of(dialogContext).pop(engine),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (engine != null) {
      await _run(
        () => service.updateSettings(
          service.settings.copyWith(searchEngine: engine),
        ),
      );
    }
  }
}

class _SurfaceChoice extends StatelessWidget {
  const _SurfaceChoice({
    required this.style,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final BrowserSurfaceStyle style;
  final bool selected;
  final String label;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: BrowserSurfaceButton(
        semanticLabel: label,
        onPressed: onSelected,
        child: Column(
          children: [
            SizedBox(
              height: 66,
              child: BrowserGlassScope(
                style: style,
                child: BrowserGlass(
                  radius: 24,
                  elevated: false,
                  child: Center(
                    child: Icon(
                      switch (style) {
                        BrowserSurfaceStyle.liquid => LucideIcons.droplet,
                        BrowserSurfaceStyle.frosted => LucideIcons.layers,
                        BrowserSurfaceStyle.solid => LucideIcons.square,
                      },
                      size: 25,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 5),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 17,
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String browserSearchEngineName(BrowserSearchEngine engine) => switch (engine) {
  BrowserSearchEngine.bing => 'Bing',
  BrowserSearchEngine.google => 'Google',
  BrowserSearchEngine.duckDuckGo => 'DuckDuckGo',
  BrowserSearchEngine.baidu => 'Baidu',
};
