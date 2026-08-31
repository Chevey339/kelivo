import 'dart:convert';

import '../../support/business_test_harness.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/app_exit_flush.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/desktop/setting/tool_schemas_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    AppExitFlush.debugReset();
  });

  tearDown(AppExitFlush.debugReset);

  testWidgets('editing a field writes through to SettingsProvider', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await _pumpPane(tester, settings);

    expect(find.text(SearchToolService.toolName), findsWidgets);
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(InkWell), findsNothing);

    await tester.enterText(_descriptionField, 'Be conservative about search.');
    await tester.pump();

    expect(
      settings.toolSchemaOverrides[SearchToolService.toolName]?.description,
      'Be conservative about search.',
    );
  });

  testWidgets(
    'restore all remounts the form with defaults and later edits stay fresh',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;

      await _pumpPane(tester, settings);

      await tester.enterText(_descriptionField, 'Stale custom wording');
      await tester.pump();
      expect(
        settings.toolSchemaOverrides[SearchToolService.toolName]?.description,
        'Stale custom wording',
      );

      await tester.tap(find.text('Restore all defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(settings.toolSchemaOverrides, isEmpty);
      expect(
        _descriptionController(tester).text,
        SearchToolService.toolDescription,
      );

      await tester.enterText(_descriptionField, 'After restore');
      await tester.pump();

      expect(
        settings.toolSchemaOverrides[SearchToolService.toolName]?.description,
        'After restore',
      );
      expect(_descriptionController(tester).text, 'After restore');
    },
  );

  testWidgets(
    'typing updates memory immediately but persists once at the end',
    (tester) async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;

      await _pumpPane(tester, settings);

      await tester.enterText(_descriptionField, 'H');
      await tester.pump();
      await tester.enterText(_descriptionField, 'Hi');
      await tester.pump();
      await tester.enterText(_descriptionField, 'Hi there');
      await tester.pump();

      expect(
        settings.toolSchemaOverrides[SearchToolService.toolName]?.description,
        'Hi there',
      );
      expect(harness.preferences.getString('tool_schema_overrides_v1'), isNull);

      await settings.flushPendingToolSchemaOverridePersist();
      expect(
        jsonDecode(harness.preferences.getString('tool_schema_overrides_v1')!),
        {
          SearchToolService.toolName: {'description': 'Hi there'},
        },
      );
    },
  );
}

Finder get _descriptionField => find.descendant(
  of: find.byKey(const ValueKey('tool-schema-desc')),
  matching: find.byType(TextField),
);

TextEditingController _descriptionController(WidgetTester tester) {
  return tester.widget<TextField>(_descriptionField).controller!;
}

Future<void> _pumpPane(WidgetTester tester, SettingsProvider settings) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: DesktopToolSchemasPane()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
