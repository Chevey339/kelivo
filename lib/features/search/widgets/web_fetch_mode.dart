import 'package:flutter/widgets.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/services/search/web_fetch_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

/// One choice of the web page reading setting.
typedef WebFetchModeChoice = ({
  String value,
  IconData icon,
  String label,
  String subtitle,
});

/// The stored mode, with a pinned service that no longer exists (or can no
/// longer read pages) shown as following the search selection.
String effectiveWebFetchMode(SettingsProvider settings) {
  return WebFetchService.effectiveMode(
    settings.webFetchMode,
    settings.searchServices,
  );
}

/// Name of whatever currently reads pages when following search.
String _followTargetName(AppLocalizations l10n, SettingsProvider settings) {
  final source = WebFetchService.resolve(
    mode: WebFetchMode.follow,
    services: settings.searchServices,
    selectedIndex: settings.searchServiceSelected,
  );
  return switch (source) {
    ProviderWebFetchSource(:final options) => SearchService.getService(
      options,
    ).name,
    _ => l10n.searchServicesPageWebFetchLocal,
  };
}

List<WebFetchModeChoice> webFetchModeChoices(
  AppLocalizations l10n,
  SettingsProvider settings,
) {
  return [
    (
      value: WebFetchMode.follow,
      icon: Lucide.Link2,
      label: l10n.searchServicesPageWebFetchFollow,
      subtitle: l10n.searchServicesPageWebFetchFollowSubtitle(
        _followTargetName(l10n, settings),
      ),
    ),
    (
      value: WebFetchMode.local,
      icon: Lucide.Smartphone,
      label: l10n.searchServicesPageWebFetchLocal,
      subtitle: l10n.searchServicesPageWebFetchLocalSubtitle,
    ),
    for (final service in settings.searchServices)
      if (WebFetchService.supports(service))
        (
          value: service.id,
          icon: Lucide.Globe,
          label: SearchService.getService(service).name,
          subtitle: l10n.searchServicesPageWebFetchProviderSubtitle,
        ),
    (
      value: WebFetchMode.off,
      icon: Lucide.Ban,
      label: l10n.searchServicesPageWebFetchOff,
      subtitle: l10n.searchServicesPageWebFetchOffSubtitle,
    ),
  ];
}

/// The follow choice with its current target, e.g. "Follow search · Tavily".
String webFetchFollowLabel(AppLocalizations l10n, SettingsProvider settings) =>
    l10n.searchServicesPageWebFetchFollowValue(
      _followTargetName(l10n, settings),
    );

/// Short value shown beside the setting.
String webFetchModeValueLabel(
  AppLocalizations l10n,
  SettingsProvider settings,
) {
  final mode = effectiveWebFetchMode(settings);
  if (mode == WebFetchMode.follow) return webFetchFollowLabel(l10n, settings);
  return webFetchModeChoices(
    l10n,
    settings,
  ).firstWhere((choice) => choice.value == mode).label;
}
