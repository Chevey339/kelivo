import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/api_keys.dart';
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

Future<void> _settleBalance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  for (final kind in ProviderKind.values) {
    testWidgets(
      '${kind.name} only automatically queries balance while provider is enabled',
      (tester) async {
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
          await settings.setProviderConfig(
            'MaruCode',
            settings.getProviderConfig('MaruCode').copyWith(providerType: kind),
          );
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
        await _settleBalance(tester);
        expect(overrides.attempts, 1);
        expect(find.text('!'), findsOneWidget);

        await tester.runAsync(
          () => settings.setProviderConfig(
            'MaruCode',
            config.copyWith(enabled: true, apiKey: 'changed-key'),
          ),
        );
        await tester.pump();
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
      },
    );
  }

  testWidgets(
    'refreshes for request edits, coalesces typing and cancels on dispose',
    (tester) async {
      final overrides = _CountingHttpOverrides();
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = overrides;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      ProviderBalanceBadge.clearCacheFor('BalanceRefresh');
      addTearDown(() => ProviderBalanceBadge.clearCacheFor('BalanceRefresh'));

      late SettingsProvider settings;
      await tester.runAsync(() async {
        final harness = await createBusinessTestHarness();
        settings = SettingsProvider(harness.preferences);
        await settings.loaded;
        await settings.setProviderConfig(
          'BalanceRefresh',
          ProviderConfig(
            id: 'BalanceRefresh',
            name: 'Balance Refresh',
            enabled: true,
            apiKey: 'key',
            baseUrl: 'https://example.test/v1',
            providerType: ProviderKind.openai,
            balanceEnabled: true,
          ),
        );
      });
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ProviderBalanceBadge(
                providerKey: 'BalanceRefresh',
                displayName: 'Balance Refresh',
              ),
            ),
          ),
        ),
      );
      await _settleBalance(tester);
      expect(overrides.attempts, 1);

      final edits = <ProviderConfig Function(ProviderConfig)>[
        (config) => config.copyWith(balanceMethod: 'POST'),
        (config) => config.copyWith(
          balanceHeaders: [
            {'name': 'x-api-key', 'value': '{{apiKey}}'},
          ],
        ),
        (config) => config.copyWith(balanceBody: '{"account":"main"}'),
        (config) => config.copyWith(baseUrl: 'https://other.example.test/v1'),
        (config) => config.copyWith(
          multiKeyEnabled: true,
          apiKeys: const [
            ApiKeyConfig(id: 'key', key: 'first', createdAt: 0, updatedAt: 0),
          ],
        ),
        (config) => config.copyWith(
          apiKeys: [config.apiKeys!.single.copyWith(key: 'replaced')],
        ),
      ];
      for (var i = 0; i < edits.length; i++) {
        await tester.runAsync(
          () => settings.setProviderConfig(
            'BalanceRefresh',
            edits[i](settings.getProviderConfig('BalanceRefresh')),
          ),
        );
        await _settleBalance(tester);
        expect(overrides.attempts, i + 2, reason: 'edit $i must refresh');
      }
      await tester.runAsync(
        () => settings.setProviderConfig(
          'BalanceRefresh',
          settings
              .getProviderConfig('BalanceRefresh')
              .copyWith(name: 'Renamed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(overrides.attempts, edits.length + 1);

      for (final body in ['{', '{"account":', '{"account":"edited"}']) {
        await tester.runAsync(
          () => settings.setProviderConfig(
            'BalanceRefresh',
            settings
                .getProviderConfig('BalanceRefresh')
                .copyWith(balanceBody: body),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(overrides.attempts, edits.length + 1);
      }
      await _settleBalance(tester);
      expect(overrides.attempts, edits.length + 2);

      await tester.runAsync(
        () => settings.setProviderConfig(
          'BalanceRefresh',
          settings
              .getProviderConfig('BalanceRefresh')
              .copyWith(balanceBody: 'pending'),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await _settleBalance(tester);
      expect(overrides.attempts, edits.length + 2);
      expect(tester.takeException(), isNull);
    },
  );
}
