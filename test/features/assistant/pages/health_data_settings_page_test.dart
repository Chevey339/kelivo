import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/health_data_type.dart';
import 'package:Kelivo/features/assistant/widgets/health_data_settings_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

void main() {
  testWidgets('category pills switch the visible type list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLightTheme(null),
        home: Scaffold(
          body: HealthDataSettingsView(
            masterEnabled: true,
            selectedIds: HealthDataTypeIds.defaultSelected,
            availableIds: HealthDataTypeIds.all,
            onToggleMaster: (_) {},
            onToggleType: (_, __) {},
            onEnableAll: () {},
            onDisableAll: () {},
            onOpenSystemSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Sleep'), findsNothing);

    await tester.tap(find.byKey(const Key('health_category_rest')));
    await tester.pumpAndSettle();

    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Resting'), findsOneWidget);
    expect(find.text('Steps'), findsNothing);
  });

  testWidgets('toggling a type reports the id to the callback', (tester) async {
    final toggled = <(String, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLightTheme(null),
        home: Scaffold(
          body: HealthDataSettingsView(
            masterEnabled: true,
            selectedIds: HealthDataTypeIds.defaultSelected,
            availableIds: HealthDataTypeIds.all,
            onToggleMaster: (_) {},
            onToggleType: (id, enabled) => toggled.add((id, enabled)),
            onEnableAll: () {},
            onDisableAll: () {},
            onOpenSystemSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('health_type_steps')));
    await tester.pumpAndSettle();

    expect(toggled, [(HealthDataTypeIds.steps, false)]);
  });

  testWidgets('unsupported types are hidden from counts and pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLightTheme(null),
        home: Scaffold(
          body: HealthDataSettingsView(
            masterEnabled: true,
            selectedIds: HealthDataTypeIds.defaultSelected,
            availableIds: HealthDataTypeIds.withoutOsVersionGate,
            onToggleMaster: (_) {},
            onToggleType: (_, __) {},
            onEnableAll: () {},
            onDisableAll: () {},
            onOpenSystemSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('6/16 on'), findsOneWidget);
    expect(find.text('Sunlight'), findsNothing);
  });

  testWidgets('tapping Enable all reports the callback', (tester) async {
    var enabledAll = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLightTheme(null),
        home: Scaffold(
          body: HealthDataSettingsView(
            masterEnabled: false,
            selectedIds: HealthDataTypeIds.defaultSelected,
            availableIds: HealthDataTypeIds.all,
            onToggleMaster: (_) {},
            onToggleType: (_, __) {},
            onEnableAll: () => enabledAll++,
            onDisableAll: () {},
            onOpenSystemSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('health_enable_all')));
    await tester.pumpAndSettle();

    expect(enabledAll, 1);
  });

  testWidgets('Enable all is disabled when every available type is on', (
    tester,
  ) async {
    var enabledAll = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLightTheme(null),
        home: Scaffold(
          body: HealthDataSettingsView(
            masterEnabled: true,
            selectedIds: HealthDataTypeIds.all,
            availableIds: HealthDataTypeIds.all,
            onToggleMaster: (_) {},
            onToggleType: (_, __) {},
            onEnableAll: () => enabledAll++,
            onDisableAll: () {},
            onOpenSystemSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('health_enable_all')));
    await tester.pumpAndSettle();

    expect(enabledAll, 0);
  });
}
