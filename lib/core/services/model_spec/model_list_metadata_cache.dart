import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, debugPrint, mapEquals;
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/business_settings_router.dart';
import '../../models/model_spec.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';

typedef ModelListRow = ({String id, Map<dynamic, dynamic> json});
typedef ModelListRefresh = Future<void> Function(Iterable<ModelListRow> rows);
typedef ModelListMetadata = ({
  int? contextWindow,
  int? maxOutput,
  ModelPricing? pricing,
});

/// Numeric metadata reported by a provider's model list, separate from edits.
class ModelListMetadataCache extends ChangeNotifier {
  ModelListMetadataCache({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static final instance = ModelListMetadataCache();
  final Future<SharedPreferences> Function() _preferences;
  final _providers = <String, _ProviderModels>{};
  final _scopes = Expando<String>();
  Future<void>? _loadFuture;
  Future<void>? _writes;
  bool _loaded = false;
  int _version = 0;

  int get version => _version;

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _load().whenComplete(() {
      _loaded = true;
      _loadFuture = null;
    });
  }

  ModelListMetadata? lookup(ProviderConfig cfg, String modelId) {
    final models = _providers[cfg.id];
    if (models == null || models.exact.isEmpty || models.scope != _scope(cfg)) {
      return null;
    }
    final id = modelId.trim();
    return models.exact.containsKey(id)
        ? models.exact[id]
        : models.byLowercase[id.toLowerCase()];
  }

  Future<ModelListRefresh> startRefresh(ProviderConfig cfg) async {
    final provider = _providers.putIfAbsent(cfg.id, _ProviderModels.new);
    final request = ++provider.started;
    final scope = _scope(cfg);
    await ensureLoaded();
    final pricingPerToken =
        Uri.tryParse(cfg.baseUrl.trim())?.host.toLowerCase() ==
        'ai-gateway.vercel.sh';
    return (rows) async {
      if (!identical(_providers[cfg.id], provider) ||
          request <= provider.latestSuccess) {
        return;
      }
      provider.latestSuccess = request;
      final entries = <String, ModelListMetadata?>{};
      for (final row in rows) {
        final id = row.id.trim();
        if (id.isEmpty) continue;
        final metadata = parseModelListMetadata(
          row.json,
          pricingPerToken: pricingPerToken,
        );
        entries.putIfAbsent(id, () => metadata);
      }
      if (provider.replace(scope, entries)) {
        _notifyChanged();
        await _save();
      }
    };
  }

  Future<void> clearProvider(String providerId) {
    if (!_loaded) {
      _providers.remove(providerId);
      return ensureLoaded().then((_) => clearProvider(providerId));
    }
    final removed = _providers.remove(providerId);
    if (removed == null || removed.exact.isEmpty) return Future<void>.value();
    _notifyChanged();
    return _save();
  }

  void _notifyChanged() {
    _version++;
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await _preferences();
      final raw = prefs.getString(
        BusinessKeyRegistry.modelListMetadataCacheKey,
      );
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      var changed = false;
      for (final provider in data.entries) {
        final id = provider.key;
        if (id is! String || provider.value is! Map) continue;
        final stored = provider.value as Map;
        final scope = stored['scope'];
        final models = stored['models'];
        if (scope is! String || models is! Map) continue;
        final entries = <String, ModelListMetadata?>{};
        for (final model in models.entries) {
          if (model.key is! String || model.value is! Map) continue;
          entries[model.key as String] = parseModelListMetadata(
            model.value as Map,
          );
        }
        if (_providers
            .putIfAbsent(id, _ProviderModels.new)
            .replace(scope, entries)) {
          changed = true;
        }
      }
      if (changed) _notifyChanged();
    } catch (error) {
      debugPrint('Failed to load model list metadata (${error.runtimeType})');
    }
  }

  Future<void> _save() {
    final pending = _writes;
    final write = pending == null ? _write() : pending.then((_) => _write());
    _writes = write;
    return write.whenComplete(() {
      if (identical(_writes, write)) _writes = null;
    });
  }

  Future<void> _write() async {
    try {
      final prefs = await _preferences();
      final data = {
        for (final provider in _providers.entries)
          if (provider.value.exact.isNotEmpty)
            provider.key: {
              'scope': provider.value.scope,
              'models': {
                for (final entry in provider.value.exact.entries)
                  entry.key: {
                    if (entry.value?.contextWindow case final context?)
                      'context_window': context,
                    if (entry.value?.maxOutput case final output?)
                      'max_output': output,
                    if (entry.value?.pricing case final pricing?)
                      'cost': pricing.toJson(),
                  },
              },
            },
      };
      if (!await prefs.setString(
        BusinessKeyRegistry.modelListMetadataCacheKey,
        jsonEncode(data),
      )) {
        debugPrint('Failed to save model list metadata');
      }
    } catch (error) {
      debugPrint('Failed to save model list metadata (${error.runtimeType})');
    }
  }

  // A restored config can reuse an ID with a different endpoint or account.
  String _scope(ProviderConfig cfg) => _scopes[cfg] ??= _hashScope(cfg);

  static String _hashScope(ProviderConfig cfg) {
    final oauth = cfg.oauthProvider;
    final vertex = oauth == null && cfg.vertexAI == true;
    final identity = oauth != null
        ? [oauth.name, oauth.baseUrl, cfg.oauthCredentials?.sessionId]
        : [
            ProviderConfig.classify(
              cfg.id,
              explicitType: cfg.providerType,
            ).name,
            cfg.baseUrl.trim(),
            vertex,
            if (vertex) ...[cfg.projectId, cfg.location],
          ];
    return sha256.convert(utf8.encode(jsonEncode(identity))).toString();
  }
}

class _ProviderModels {
  String? scope;
  var exact = <String, ModelListMetadata?>{};
  var byLowercase = <String, ModelListMetadata>{};
  int started = 0;
  int latestSuccess = 0;

  bool replace(String scope, Map<String, ModelListMetadata?> entries) {
    final lower = <String, ModelListMetadata>{};
    for (final entry in entries.entries) {
      final metadata = entry.value;
      if (metadata != null) {
        lower.putIfAbsent(entry.key.toLowerCase(), () => metadata);
      }
    }
    if (lower.isEmpty) entries.clear();
    final nextScope = entries.isEmpty ? null : scope;
    if (this.scope == nextScope &&
        mapEquals(exact, entries) &&
        mapEquals(byLowercase, lower)) {
      return false;
    }
    this.scope = nextScope;
    exact = entries;
    byLowercase = lower;
    return true;
  }
}

ModelListMetadata? parseModelListMetadata(
  Map row, {
  bool pricingPerToken = false,
}) {
  final top = row['top_provider'];
  final limit = row['limit'];
  final pricing = row['pricing'];
  final cost = row['cost'];
  final contextWindow =
      parseModelListTokenLimit(row['context_length']) ??
      parseModelListTokenLimit(row['context_window']) ??
      parseModelListTokenLimit(row['max_context_length']) ??
      parseModelListTokenLimit(row['max_context_window']) ??
      parseModelListTokenLimit(top is Map ? top['context_length'] : null) ??
      parseModelListTokenLimit(limit is Map ? limit['context'] : null) ??
      parseModelListTokenLimit(row['inputTokenLimit']) ??
      parseModelListTokenLimit(row['input_token_limit']);
  final maxOutput =
      parseModelListTokenLimit(row['max_output']) ??
      parseModelListTokenLimit(row['max_output_tokens']) ??
      parseModelListTokenLimit(row['maxOutput']) ??
      parseModelListTokenLimit(row['max_completion_tokens']) ??
      parseModelListTokenLimit(
        top is Map ? top['max_completion_tokens'] : null,
      ) ??
      parseModelListTokenLimit(limit is Map ? limit['output'] : null) ??
      parseModelListTokenLimit(row['outputTokenLimit']) ??
      parseModelListTokenLimit(row['output_token_limit']);

  final inputPrice =
      _price(pricing is Map ? pricing['prompt'] : null, perToken: true) ??
      _price(
        pricing is Map ? pricing['input'] : null,
        perToken: pricingPerToken,
      ) ??
      _price(cost is Map ? cost['input'] : null);
  final outputPrice =
      _price(pricing is Map ? pricing['completion'] : null, perToken: true) ??
      _price(
        pricing is Map ? pricing['output'] : null,
        perToken: pricingPerToken,
      ) ??
      _price(cost is Map ? cost['output'] : null);
  if (contextWindow == null &&
      maxOutput == null &&
      inputPrice == null &&
      outputPrice == null) {
    return null;
  }
  return (
    contextWindow: contextWindow,
    maxOutput: maxOutput,
    pricing: inputPrice != null || outputPrice != null
        ? ModelPricing(input: inputPrice, output: outputPrice)
        : null,
  );
}

int? parseModelListTokenLimit(Object? value) {
  final n = _number(value);
  if (n == null ||
      !n.isFinite ||
      n < 1024 ||
      n > 10000000 ||
      n != n.truncateToDouble()) {
    return null;
  }
  return n.toInt();
}

double? _number(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

double? _price(Object? value, {bool perToken = false}) {
  final n = _number(value);
  if (n == null || n < 0) return null;
  // ModelPricing stores rates per million tokens.
  final price = perToken ? n * 1000000 : n;
  return price.isFinite ? price : null;
}
