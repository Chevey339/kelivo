import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/api_keys.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api_key_manager.dart';

ApiKeyConfig _key(String id, String value) {
  return ApiKeyConfig(id: id, key: value, createdAt: 1, updatedAt: 1);
}

ApiKeyConfig _usedKey(String id, String value, int totalRequests) {
  return _key(
    id,
    value,
  ).copyWith(usage: ApiKeyUsage(totalRequests: totalRequests));
}

ProviderConfig _provider({
  required String id,
  required List<ApiKeyConfig> keys,
  LoadBalanceStrategy strategy = LoadBalanceStrategy.roundRobin,
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: id,
    apiKey: '',
    baseUrl: 'https://example.test/v1',
    providerType: ProviderKind.openai,
    multiKeyEnabled: true,
    apiKeys: keys,
    keyManagement: KeyManagementConfig(strategy: strategy),
  );
}

void main() {
  group('ApiKeyManager', () {
    test('round robin consumes keys in configured list order', () {
      final provider = _provider(
        id: 'round-robin-list-order',
        keys: [
          _key('key_z', 'first'),
          _key('key_a', 'second'),
          _key('key_m', 'third'),
        ],
      );
      final manager = ApiKeyManager();

      final selected = [
        manager.selectForProvider(provider).key?.key,
        manager.selectForProvider(provider).key?.key,
        manager.selectForProvider(provider).key?.key,
        manager.selectForProvider(provider).key?.key,
      ];

      expect(selected, ['first', 'second', 'third', 'first']);
    });

    test(
      'round robin skips disabled keys without reordering remaining keys',
      () {
        final provider = _provider(
          id: 'round-robin-disabled-skip',
          keys: [
            _key('key_m', 'disabled').copyWith(isEnabled: false),
            _key('key_z', 'second'),
            _key('key_a', 'third'),
          ],
        );
        final manager = ApiKeyManager();

        final selected = [
          manager.selectForProvider(provider).key?.key,
          manager.selectForProvider(provider).key?.key,
          manager.selectForProvider(provider).key?.key,
        ];

        expect(selected, ['second', 'third', 'second']);
      },
    );

    test('returns no available keys when all configured keys are disabled', () {
      final provider = _provider(
        id: 'round-robin-no-available',
        keys: [
          _key('key_a', 'first').copyWith(isEnabled: false),
          _key('key_b', 'second').copyWith(status: ApiKeyStatus.disabled),
        ],
      );

      final result = ApiKeyManager().selectForProvider(provider);

      expect(result.key, isNull);
      expect(result.reason, 'no_available_keys');
    });

    test('priority strategy still selects the lowest priority value', () {
      final provider = _provider(
        id: 'priority-strategy',
        strategy: LoadBalanceStrategy.priority,
        keys: [
          _key('key_a', 'normal').copyWith(priority: 5),
          _key('key_b', 'preferred').copyWith(priority: 1),
        ],
      );

      final result = ApiKeyManager().selectForProvider(provider);

      expect(result.key?.key, 'preferred');
    });

    test('least used strategy still selects the key with fewer requests', () {
      final provider = _provider(
        id: 'least-used-strategy',
        strategy: LoadBalanceStrategy.leastUsed,
        keys: [_usedKey('key_a', 'busy', 5), _usedKey('key_b', 'idle', 1)],
      );

      final result = ApiKeyManager().selectForProvider(provider);

      expect(result.key?.key, 'idle');
    });
  });
}
