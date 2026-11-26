import 'dart:async';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/provider_balance_refresh.dart';
import 'package:Kelivo/core/services/provider_balance_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/business_test_harness.dart';

const _provider = 'BalanceRefresh';

Future<SettingsProvider> _settings(WidgetTester tester) async {
  final settings = (await tester.runAsync(() async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setProviderConfig(
      _provider,
      ProviderConfig(
        id: _provider,
        enabled: true,
        name: _provider,
        apiKey: 'balance-key',
        baseUrl: 'https://example.test',
        balanceEnabled: true,
        balanceRefreshInterval: 1,
        balanceRefreshOnReply: true,
      ),
    );
    return settings;
  }))!;
  addTearDown(settings.dispose);
  return settings;
}

void main() {
  testWidgets(
    'visible badges share queries and replies reset the periodic interval',
    (tester) async {
      final settings = await _settings(tester);
      var requests = 0;
      final refresh = ProviderBalanceRefresh(
        settings,
        hasNetwork: (_) async => true,
        fetch: (_, {cancelToken}) async => (++requests).toString(),
      );
      try {
        final entry = refresh.forProvider(_provider);
        final detachFirst = entry.attachVisibleBadge();
        final detachSecond = entry.attachVisibleBadge();
        await tester.pump(const Duration(milliseconds: 500));
        expect(entry.value.balance, '1');

        await tester.pump(const Duration(seconds: 45));
        refresh.replyFinished(_provider);
        await tester.pump(const Duration(milliseconds: 400));
        refresh.replyFinished(_provider);
        await tester.pump(const Duration(milliseconds: 499));
        expect(requests, 1);
        await tester.pump(const Duration(milliseconds: 1));
        expect(entry.value.balance, '2');

        await tester.pump(const Duration(seconds: 15));
        expect(requests, 2);
        await tester.pump(const Duration(seconds: 45));
        expect(entry.value.balance, '3');

        await tester.pump(const Duration(milliseconds: 59800));
        refresh.replyFinished(_provider);
        await tester.pump(const Duration(milliseconds: 200));
        expect(entry.value.balance, '4');
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests, 4);

        detachFirst();
        detachSecond();
        refresh.replyFinished(_provider);
        await tester.pump(const Duration(minutes: 5));
        expect(requests, 4);
        entry.attachVisibleBadge();
        await tester.pump(Duration.zero);
        expect(entry.value.balance, '5');
      } finally {
        refresh.dispose();
      }
    },
  );

  testWidgets(
    'offline and hidden ticks are skipped and failed refresh keeps balance',
    (tester) async {
      final settings = await _settings(tester);
      var requests = 0;
      var online = true;
      final refresh = ProviderBalanceRefresh(
        settings,
        hasNetwork: (_) async => online,
        fetch: (_, {cancelToken}) async {
          requests++;
          if (requests == 2) throw StateError('temporary failure');
          return requests.toString();
        },
      );
      void lifecycle(AppLifecycleState state) =>
          tester.binding.handleAppLifecycleStateChanged(state);
      try {
        lifecycle(AppLifecycleState.resumed);
        final entry = refresh.forProvider(_provider);
        entry.attachVisibleBadge();
        await tester.pump(const Duration(milliseconds: 500));
        final successful = entry.value;
        expect(successful.balance, '1');

        online = false;
        await tester.pump(const Duration(minutes: 1));
        expect(requests, 1);
        lifecycle(AppLifecycleState.inactive);
        lifecycle(AppLifecycleState.hidden);
        online = true;
        await tester.pump(const Duration(minutes: 3));
        expect(requests, 1);

        lifecycle(AppLifecycleState.inactive);
        lifecycle(AppLifecycleState.resumed);
        await tester.pump(Duration.zero);
        expect(requests, 2);
        expect(entry.value.balance, successful.balance);
        expect(entry.value.updatedAt, successful.updatedAt);
        expect(entry.value.error, contains('temporary failure'));

        await tester.pump(const Duration(minutes: 1));
        expect(entry.value.balance, '3');
        expect(entry.value.error, isNull);
      } finally {
        refresh.dispose();
      }
    },
  );

  testWidgets(
    'manual callers join one query and old credentials cannot publish a result',
    (tester) async {
      final settings = await _settings(tester);
      final oldResponse = Completer<String>();
      final newResponse = Completer<String>();
      final credentials = <String>[];
      final refresh = ProviderBalanceRefresh(
        settings,
        fetch: (config, {cancelToken}) {
          credentials.add(config.apiKey);
          return config.apiKey == 'balance-key'
              ? oldResponse.future
              : newResponse.future;
        },
      );
      try {
        final entry = refresh.forProvider(_provider);
        final previous = entry.query();
        expect(entry.query(), same(previous));
        final cancelled = expectLater(
          previous,
          throwsA(isA<ProviderBalanceException>()),
        );
        await tester.runAsync(
          () => settings.setProviderConfig(
            _provider,
            settings.getProviderConfig(_provider).copyWith(apiKey: 'new-key'),
          ),
        );
        final current = entry.query();
        newResponse.complete('new balance');
        expect(await current, 'new balance');
        oldResponse.complete('old balance');
        await cancelled;
        expect(entry.value.balance, 'new balance');
        expect(credentials, ['balance-key', 'new-key']);
      } finally {
        refresh.dispose();
      }
    },
  );
}
