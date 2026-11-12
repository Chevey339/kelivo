import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/provider/pages/provider_detail_page.dart';
import 'package:Kelivo/features/provider/pages/providers_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../../../support/business_test_harness.dart';

Future<void> _openSelection(WidgetTester tester, {required bool models}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = SettingsProvider(createBusinessTestPreferences());
  await tester.pump(const Duration(milliseconds: 300));
  await settings.setProviderConfig(
    'TestProvider',
    ProviderConfig(
      id: 'TestProvider',
      enabled: true,
      name: 'Test Provider',
      apiKey: 'test-key',
      baseUrl: 'https://example.test',
      providerType: ProviderKind.openai,
      models: const ['model-a', 'model-b'],
    ),
  );
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => models
                      ? const ProviderDetailPage(
                          keyName: 'TestProvider',
                          displayName: 'Test Provider',
                        )
                      : const ProvidersPage(),
                ),
              ),
              child: const Text('Parent page'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Parent page'));
  await tester.pumpAndSettle();
  if (models) {
    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byTooltip('Multi-select'));
  await tester.pumpAndSettle();
  expect(find.byTooltip(models ? 'Cancel' : 'Done'), findsOneWidget);
}

void main() {
  testWidgets('deleting a provider still dismisses its selected models page', (
    tester,
  ) async {
    await _openSelection(tester, models: true);
    await tester.tap(find.byTooltip('Delete Provider'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byType(ProviderDetailPage).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    AppSnackBarManager().dismissAll();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Parent page'), findsOneWidget);
    expect(find.byType(ProviderDetailPage), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final models in [false, true]) {
    final name = models ? 'models' : 'providers';

    testWidgets('Android back exits $name selection before leaving the page', (
      tester,
    ) async {
      await _openSelection(tester, models: models);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Multi-select'), findsOneWidget);
      expect(find.text('Parent page'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Parent page'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS edge swipe returns from $name selection', (tester) async {
      await _openSelection(tester, models: models);
      final page = find.byType(models ? ProviderDetailPage : ProvidersPage);
      final route = ModalRoute.of(tester.element(page))!;
      expect(route.popGestureEnabled, isTrue);

      await tester.dragFrom(const Offset(1, 300), const Offset(350, 0));
      await tester.pumpAndSettle();
      expect(find.text('Parent page'), findsOneWidget);
      expect(page, findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
