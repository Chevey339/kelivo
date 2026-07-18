import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/chat_model_selection_provider.dart';
import 'package:Kelivo/core/models/chat_model_target.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('input background opacity sheet shows light and dark controls', (
    tester,
  ) async {
    final settings = SettingsProvider();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DisplaySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('82%'), findsOneWidget);
    expect(find.textContaining('Light 82% / Dark 74%'), findsNothing);

    final opacityRow = find.text('Input Box Background Opacity');
    await tester.scrollUntilVisible(opacityRow, 240);
    await tester.pumpAndSettle();

    await tester.tap(opacityRow);
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byType(SfSlider), findsNWidgets(2));
  });

  testWidgets('behavior page exposes multi-model scope as its first setting', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsProvider();
    final selection = ChatModelSelectionProvider(preferences: preferences);
    addTearDown(settings.dispose);
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ChatModelSelectionProvider>.value(
            value: selection,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BehaviorStartupSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Multi-model selection applies to'), findsOneWidget);
    expect(find.text('Current conversation'), findsOneWidget);

    await tester.tap(find.text('Multi-model selection applies to'));
    await tester.pumpAndSettle();

    expect(
      find.text('Keep separate model combinations for each scope'),
      findsOneWidget,
    );
    await tester.tap(find.text('Next message only'));
    await tester.pumpAndSettle();

    expect(selection.scope, MultiModelSelectionScope.nextMessage);
    expect(find.text('Next message only'), findsOneWidget);
  });
}
