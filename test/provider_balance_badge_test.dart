import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/provider/widgets/provider_balance_badge.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/business_test_harness.dart';

class _CountingHttpOverrides extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const HttpException('Balance request intercepted by test');
  }
}

void main() {
  testWidgets('only automatically queries balance while provider is enabled', (
    tester,
  ) async {
    final overrides = _CountingHttpOverrides();
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    ProviderBalanceBadge.clearCacheFor('MaruCode');
    addTearDown(() => ProviderBalanceBadge.clearCacheFor('MaruCode'));

    late SettingsProvider settings;
    await tester.runAsync(() async {
      final harness = await createBusinessTestHarness();
      settings = SettingsProvider(harness.preferences);
      await settings.loaded;
    });
    addTearDown(settings.dispose);

    final config = settings.getProviderConfig('MaruCode');
    expect(config.enabled, isFalse);
    expect(config.balanceEnabled, isTrue);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ProviderBalanceBadge(
              providerKey: 'MaruCode',
              displayName: 'MaruCode',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(overrides.attempts, 0);
    expect(find.byType(Icon), findsNothing);

    await tester.runAsync(
      () => settings.setProviderConfig(
        'MaruCode',
        config.copyWith(enabled: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(overrides.attempts, 1);
    expect(find.text('!'), findsOneWidget);

    await tester.runAsync(
      () => settings.setProviderConfig(
        'MaruCode',
        config.copyWith(enabled: false, apiKey: 'changed-key'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(overrides.attempts, 1);
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
