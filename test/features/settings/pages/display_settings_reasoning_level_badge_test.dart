import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat item display page toggles reasoning level badge', (
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
          home: ChatItemDisplaySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reasoningBadge = find.text('Show reasoning level on the button');
    await tester.scrollUntilVisible(
      reasoningBadge,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(reasoningBadge, findsOneWidget);
    expect(settings.showReasoningLevelBadge, isFalse);

    await tester.tap(reasoningBadge);
    await tester.pumpAndSettle();
    expect(settings.showReasoningLevelBadge, isTrue);

    final totalTokens = find.text('Show tokens for the entire turn');
    await tester.scrollUntilVisible(
      totalTokens,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(settings.showTotalTokens, isFalse);
    await tester.tap(totalTokens);
    await tester.pumpAndSettle();
    expect(settings.showTotalTokens, isTrue);
  });
}
