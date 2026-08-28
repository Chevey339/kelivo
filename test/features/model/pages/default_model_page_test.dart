import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/pages/default_model_page.dart';
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

  testWidgets('title summary follows the current chat model by default', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultModelPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Title Summary Model'), findsOneWidget);
    expect(
      find.text(
        'Summarizes conversation titles using the current chat model by default, or a selected model.',
      ),
      findsOneWidget,
    );
    expect(settings.isTitleGenerationEnabled, isTrue);
    expect(find.text('Use current chat model'), findsWidgets);
    expect(find.byTooltip('Disable'), findsOneWidget);

    await tester.tap(find.byTooltip('Disable'));
    await tester.pumpAndSettle();

    expect(settings.isTitleGenerationEnabled, isFalse);
    expect(find.text('Not enabled'), findsWidgets);
    expect(find.byTooltip('Use current chat model'), findsWidgets);
  });
}
