import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/auto_retry_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('numeric fields save when the page is disposed without unfocus', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    Widget app({required Widget home}) {
      return ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );
    }

    await tester.pumpWidget(app(home: const AutoRetryPage()));
    await tester.pumpAndSettle();

    final maxRetriesField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    maxRetriesField.controller!.text = '7';

    await tester.pumpWidget(app(home: const SizedBox.shrink()));
    await tester.idle();

    expect(settings.autoRetryOptions.maxRetries, 7);
  });
}
