import 'dart:convert';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'balance request settings round trip and clear independently of chat',
    () {
      final config = ProviderConfig.defaultsFor('OpenAI').copyWith(
        balanceEnabled: true,
        balanceApiPath: 'https://balance.example.test/account',
        balanceResultPath: 'usd_balance',
        balanceMethod: 'POST',
        balanceHeaders: const [
          {'name': 'x-api-key', 'value': '{{apiKey}}'},
        ],
        balanceBody: '{"api_key":"{{apiKey}}"}',
        customHeaders: const [
          {'name': 'X-Chat', 'value': 'chat'},
        ],
      );
      final restored = ProviderConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())),
      );
      expect(restored.toJson(), config.toJson());
      final renamed = restored.copyWith(name: 'Renamed');
      expect(renamed.balanceMethod, 'POST');
      expect(renamed.balanceHeaders, config.balanceHeaders);
      expect(renamed.balanceBody, config.balanceBody);

      final reset = renamed.copyWith(
        balanceMethod: 'GET',
        balanceHeaders: [],
        balanceBody: '',
      );
      expect(reset.balanceMethod, 'GET');
      expect(reset.balanceHeaders, isEmpty);
      expect(reset.balanceBody, isEmpty);
      expect(reset.customHeaders, config.customHeaders);
    },
  );

  test('unset request settings use GET with no overrides', () {
    final json = ProviderConfig.defaultsFor('OpenAI').toJson()
      ..remove('balanceMethod')
      ..remove('balanceHeaders')
      ..remove('balanceBody');
    final config = ProviderConfig.fromJson(json);
    expect(config.balanceMethod, 'GET');
    expect(config.balanceHeaders, isEmpty);
    expect(config.balanceBody, isEmpty);
  });

  test('balance request settings survive backup snapshot validation', () {
    final config = ProviderConfig.defaultsFor('OpenAI').copyWith(
      balanceMethod: 'POST',
      balanceHeaders: const [
        {'name': 'x-api-key', 'value': '{{apiKey}}'},
        {'name': 'Authorization', 'value': ''},
        {'name': '', 'value': ''},
      ],
      balanceBody: '{"account":"main"}',
    );
    final snapshot = BusinessSettingsRouter.normalizeAndRoute({
      'provider_configs_v1': jsonEncode({'OpenAI': config.toJson()}),
    });
    final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
    final providers =
        jsonDecode(exported['provider_configs_v1']! as String) as Map;
    expect(
      ProviderConfig.fromJson(providers['OpenAI']).toJson(),
      config.toJson(),
    );
  });

  test('rejects malformed balance settings before restoring a snapshot', () {
    for (final invalid in <Map<String, Object?>>[
      {'balanceMethod': 1},
      {'balanceMethod': 'DELETE'},
      {'balanceBody': <String, Object>{}},
      {'balanceHeaders': <String, Object>{}},
      {
        'balanceHeaders': ['not-a-row'],
      },
      {
        'balanceHeaders': [null],
      },
      {
        'balanceHeaders': [
          {'name': 'X-Account', 'value': 123},
        ],
      },
      {
        'balanceHeaders': [
          {'name': 123, 'value': 'main'},
        ],
      },
      {
        'balanceHeaders': [
          {'name': 'X-Account', 'value': null},
        ],
      },
    ]) {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'provider_configs_v1': jsonEncode({
            'OpenAI': {
              ...ProviderConfig.defaultsFor('OpenAI').toJson(),
              ...invalid,
            },
          }),
        }),
        throwsFormatException,
        reason: invalid.toString(),
      );
    }
  });

  test('balance request settings persist in business preferences', () async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    final config = ProviderConfig.defaultsFor('OpenAI').copyWith(
      balanceMethod: 'POST',
      balanceHeaders: const [
        {'name': 'x-api-key', 'value': '{{apiKey}}'},
      ],
      balanceBody: '{"account":"main"}',
    );
    await settings.setProviderConfig('OpenAI', config);
    final reloaded = SettingsProvider(BusinessPreferences(harness.repository));
    addTearDown(reloaded.dispose);
    await reloaded.loaded;
    expect(reloaded.getProviderConfig('OpenAI').toJson(), config.toJson());
  });
}
