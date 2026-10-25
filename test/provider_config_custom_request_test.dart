import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

ProviderConfig _config() => ProviderConfig(
  id: 'provider',
  enabled: true,
  name: 'Provider',
  apiKey: 'key',
  baseUrl: 'https://example.test/v1',
  customHeaders: const [
    {'name': 'X-Test', 'value': 'header-value'},
  ],
  customBody: const [
    {'key': 'metadata', 'value': '{"source":"provider"}'},
  ],
);

void main() {
  group('ProviderConfig custom request', () {
    test('conversation cache key setting defaults off and round trips', () {
      final config = _config();
      expect(config.promptCacheKeyEnabled, isFalse);
      final withoutSetting = config.toJson()..remove('promptCacheKeyEnabled');
      expect(
        ProviderConfig.fromJson(withoutSetting).promptCacheKeyEnabled,
        isFalse,
      );
      final enabled = config.copyWith(promptCacheKeyEnabled: true);
      final restored = ProviderConfig.fromJson(enabled.toJson());
      expect(restored.promptCacheKeyEnabled, isTrue);
      expect(restored.copyWith(name: 'Renamed').promptCacheKeyEnabled, isTrue);
      expect(
        restored.copyWith(promptCacheKeyEnabled: false).promptCacheKeyEnabled,
        isFalse,
      );
    });

    test('round trips headers and body', () {
      final restored = ProviderConfig.fromJson(_config().toJson());

      expect(restored.customHeaders, _config().customHeaders);
      expect(restored.customBody, _config().customBody);
    });

    test('legacy JSON defaults to empty request overrides', () {
      final restored = ProviderConfig.fromJson(const {
        'id': 'legacy',
        'enabled': true,
        'name': 'Legacy',
        'apiKey': '',
        'baseUrl': 'https://example.test',
      });

      expect(restored.customHeaders, isEmpty);
      expect(restored.customBody, isEmpty);
    });

    test('normalizes legacy row key aliases and non-string values', () {
      final restored = ProviderConfig.fromJson(const {
        'id': 'legacy',
        'enabled': true,
        'name': 'Legacy',
        'apiKey': '',
        'baseUrl': 'https://example.test',
        'customHeaders': [
          {'key': 'X-Number', 'value': 42},
        ],
        'customBody': [
          {'name': 'enabled', 'value': true},
        ],
      });

      expect(restored.customHeaders, [
        {'name': 'X-Number', 'value': '42'},
      ]);
      expect(restored.customBody, [
        {'key': 'enabled', 'value': 'true'},
      ]);
    });
  });
}
