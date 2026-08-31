import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/models/health_data_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../theme/theme_factory.dart';
import '../widgets/health_data_settings_view.dart';
import 'health_data_settings_desktop_layout.dart';
import 'health_data_settings_mobile_layout.dart';

class HealthDataSettingsPage extends StatelessWidget {
  const HealthDataSettingsPage({super.key, required this.assistantId});

  final String assistantId;

  static Future<void> open(BuildContext context, String assistantId) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthDataSettingsPage(assistantId: assistantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return HealthDataSettingsDesktopLayout(assistantId: assistantId);
    }
    return HealthDataSettingsMobileLayout(assistantId: assistantId);
  }
}

void healthDataSettingsPreviewToggleMaster(bool value) {}

void healthDataSettingsPreviewToggleType(String typeId, bool enabled) {}

void healthDataSettingsPreviewEnableAll() {}

void healthDataSettingsPreviewDisableAll() {}

void healthDataSettingsPreviewOpenSettings() {}

@Preview(
  name: 'Health data settings · Light',
  group: 'Health data',
  size: Size(390, 844),
  brightness: Brightness.light,
)
@Preview(
  name: 'Health data settings · Dark',
  group: 'Health data',
  size: Size(390, 844),
  brightness: Brightness.dark,
)
Widget healthDataSettingsPagePreview() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLightTheme(null),
    darkTheme: buildDarkTheme(null),
    themeMode: ThemeMode.system,
    home: Scaffold(
      body: HealthDataSettingsView(
        masterEnabled: true,
        selectedIds: HealthDataTypeIds.defaultSelected,
        availableIds: HealthDataTypeIds.all,
        onToggleMaster: healthDataSettingsPreviewToggleMaster,
        onToggleType: healthDataSettingsPreviewToggleType,
        onEnableAll: healthDataSettingsPreviewEnableAll,
        onDisableAll: healthDataSettingsPreviewDisableAll,
        onOpenSystemSettings: healthDataSettingsPreviewOpenSettings,
      ),
    ),
  );
}
