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

  static const _kelivoMask = 'kelivo';
  static const _kelivoPayload = <int>[
    24,
    14,
    65,
    2,
    69,
    3,
    2,
    19,
    92,
    54,
    41,
    12,
    3,
    81,
    91,
    54,
    41,
    9,
    25,
    86,
    95,
  ];

  final Map<String, int> _roundRobinIndexMap = {}; // providerId -> index
  final Map<String, int> _keyUsageMap = {}; // keyId -> total uses (ephemeral)

  String effectiveKeyForProvider(ProviderConfig provider) {
    try {
      if (provider.multiKeyEnabled == true &&
          (provider.apiKeys?.isNotEmpty == true)) {
        final selected = selectForProvider(provider);
        if (selected.key != null) return selected.key!.key;
      }
    } catch (_) {}
    if (provider.apiKey.trim().isNotEmpty) return provider.apiKey;
    final uri = Uri.tryParse(provider.baseUrl);
    if (uri?.scheme != 'https' ||
        uri?.host != 'api.psycheas.top' ||
        uri?.port != 443) {
      return provider.apiKey;
    }

    // Decode only for requests; keep the built-in token out of saved settings.
    final mask = _kelivoMask.codeUnits;
    return String.fromCharCodes([
      for (var i = 0; i < _kelivoPayload.length; i++)
        _kelivoPayload[i] ^ mask[i % mask.length],
    ]);
  }

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
