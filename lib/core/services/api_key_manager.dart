import 'dart:math';
import '../models/api_keys.dart';
import '../providers/settings_provider.dart';

class KeySelectionResult {
  final ApiKeyConfig? key;
  final String reason;
  const KeySelectionResult(this.key, this.reason);
}

class ApiKeyManager {
  static final ApiKeyManager _instance = ApiKeyManager._internal();
  factory ApiKeyManager() => _instance;
  ApiKeyManager._internal();

  final Map<String, int> _roundRobinIndexMap = {}; // providerId -> index
  final Map<String, int> _keyUsageMap = {}; // keyId -> total uses (ephemeral)

  KeySelectionResult selectForProvider(ProviderConfig provider) {
    final keys = List<ApiKeyConfig>.from(
      (provider.apiKeys ?? const <ApiKeyConfig>[]).where((k) => k.isEnabled),
    );
    if (keys.isEmpty) return const KeySelectionResult(null, 'no_keys');

    // Filter by status and cooldown
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownMs =
        (provider.keyManagement?.failureRecoveryTimeMinutes ?? 5) * 60 * 1000;
    final available = keys.where((k) {
      if (k.status == ApiKeyStatus.disabled) return false;
      if (k.status == ApiKeyStatus.error) {
        final since = now - (k.updatedAt);
        if (since < cooldownMs) return false;
      }
      // Only select keys marked active; error keys are filtered by cooldown above and disabled are skipped.
      return k.status == ApiKeyStatus.active;
    }).toList();

    if (available.isEmpty) {
      return const KeySelectionResult(null, 'no_available_keys');
    }

    final strategy =
        provider.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
    ApiKeyConfig chosen;
    switch (strategy) {
      case LoadBalanceStrategy.priority:
        available.sort((a, b) => a.priority.compareTo(b.priority));
        chosen = available.first;
        break;
      case LoadBalanceStrategy.leastUsed:
        available.sort(
          (a, b) => (a.usage.totalRequests).compareTo(b.usage.totalRequests),
        );
        chosen = available.first;
        break;
      case LoadBalanceStrategy.random:
        chosen = available[Random().nextInt(available.length)];
        break;
      case LoadBalanceStrategy.roundRobin:
        // Stable by id
        available.sort((a, b) => a.id.compareTo(b.id));
        final cur =
            _roundRobinIndexMap[provider.id] ??
            (provider.keyManagement?.roundRobinIndex ?? 0);
        final idx = cur % available.length;
        chosen = available[idx];
        final next = (idx + 1) % available.length;
        _roundRobinIndexMap[provider.id] = next;
        break;
    }

    return KeySelectionResult(chosen, 'strategy_${strategy.name}');
  }

  ApiKeyConfig updateKeyStatus(
    ProviderConfig provider,
    ApiKeyConfig key,
    bool success, {
    String? error,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var updated = key.copyWith(
      usage: key.usage.copyWith(
        totalRequests: key.usage.totalRequests + 1,
        successfulRequests: key.usage.successfulRequests + (success ? 1 : 0),
        failedRequests: key.usage.failedRequests + (success ? 0 : 1),
        consecutiveFailures: success ? 0 : (key.usage.consecutiveFailures + 1),
        lastUsed: now,
      ),
      status: success
          ? ApiKeyStatus.active
          : (key.usage.consecutiveFailures + 1) >=
                (provider.keyManagement?.maxFailuresBeforeDisable ?? 3)
          ? ApiKeyStatus.error
          : key.status,
      lastError: success ? null : (error ?? key.lastError),
      updatedAt: now,
    );
    _keyUsageMap[updated.id] = (_keyUsageMap[updated.id] ?? 0) + 1;
    return updated;
  }

  void recordKeyUsage(String keyId, bool success) {
    _keyUsageMap[keyId] = (_keyUsageMap[keyId] ?? 0) + 1;
  }
}
