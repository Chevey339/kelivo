import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/settings_provider.dart';
import '../network/dio_http_client.dart';
import 'catalog_entry.dart';
import 'model_catalog_trim.dart';

const String kModelCatalogAssetPath = 'assets/model_catalog/models_dev.json';
const String kModelCatalogAutoUpdatePrefsKey = 'model_catalog_auto_update_v1';
const String kModelCatalogCacheFileName = 'models_dev.json';

const Duration kModelCatalogStaleAfter = Duration(hours: 24);
const Duration kModelCatalogRefreshTimeout = Duration(seconds: 60);

final Uri kModelCatalogRemoteUri = Uri.parse('https://models.dev/api.json');

/// Exact hosts for catalog providers that omit `api` in models.dev.
const Map<String, List<String>> kCatalogExactHostProviders =
    <String, List<String>>{
      'api.openai.com': <String>['openai'],
      'api.anthropic.com': <String>['anthropic'],
      'generativelanguage.googleapis.com': <String>['google'],
      'api.x.ai': <String>['xai'],
      'api.mistral.ai': <String>['mistral'],
      'api.groq.com': <String>['groq'],
      'api.cerebras.ai': <String>['cerebras'],
      'api.cohere.com': <String>['cohere'],
      'api.cohere.ai': <String>['cohere'],
      'api.deepinfra.com': <String>['deepinfra'],
      'api.together.xyz': <String>['togetherai'],
      'api.perplexity.ai': <String>['perplexity'],
      'aihubmix.com': <String>['aihubmix'],
      'api.venice.ai': <String>['venice'],
      'ai-gateway.vercel.sh': <String>['vercel'],
      'gateway.ai.cloudflare.com': <String>['cloudflare-ai-gateway'],
      'api.v0.dev': <String>['v0'],
      'gitlab.com': <String>['gitlab'],
      'cloud.gitlab.com': <String>['gitlab'],
      'ai.salad.cloud': <String>['salad-cloud'],
    };

/// Slash-prefix on aggregator ids → first-party catalog provider id.
///
/// Only includes mappings whose target id exists in the bundled snapshot.
const Map<String, String> kCatalogVendorPrefixToProviderId = <String, String>{
  'openai': 'openai',
  'anthropic': 'anthropic',
  'google': 'google',
  'deepseek': 'deepseek',
  'moonshotai': 'moonshotai',
  'qwen': 'alibaba',
  'x-ai': 'xai',
  'z-ai': 'zai',
  'mistralai': 'mistral',
  'meta-llama': 'meta',
};

/// First-party ranking for slash-less global fallback.
///
/// All ids exist in the bundled snapshot.
const List<String> kCatalogFirstPartyPriority = <String>[
  'openai',
  'anthropic',
  'google',
  'google-vertex',
  'deepseek',
  'moonshotai',
  'alibaba',
  'alibaba-cn',
  'zhipuai',
  'zai',
  'xai',
  'mistral',
  'minimax',
  'minimax-cn',
  'volcengine',
  'stepfun',
  'meta',
  'cohere',
  'groq',
  'cerebras',
  'togetherai',
  'fireworks-ai',
  'openrouter',
];

enum CatalogMatchKind { providerExact, providerNormalized, global }

class CatalogMatch {
  const CatalogMatch({
    required this.provider,
    required this.model,
    required this.kind,
  });

  final CatalogProvider provider;
  final CatalogModel model;
  final CatalogMatchKind kind;
}

class ModelCatalogService extends ChangeNotifier {
  static final ModelCatalogService instance = ModelCatalogService();

  ModelCatalogService({
    Future<String> Function()? loadBundledJson,
    Future<Directory> Function()? cacheDirectory,
    http.Client Function()? clientFactory,
    Future<SharedPreferences> Function()? prefs,
    Uri? remoteUri,
    DateTime Function()? now,
  }) : _loadBundledJson = loadBundledJson ?? _defaultLoadBundledJson,
       _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
       _clientFactory = clientFactory ?? _defaultClientFactory,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _remoteUri = remoteUri ?? kModelCatalogRemoteUri,
       _now = now ?? DateTime.now;

  final Future<String> Function() _loadBundledJson;
  final Future<Directory> Function() _cacheDirectory;
  final http.Client Function() _clientFactory;
  final Future<SharedPreferences> Function() _prefs;
  final Uri _remoteUri;
  final DateTime Function() _now;

  ModelCatalogData? _data;
  int _version = 0;
  bool _refreshing = false;
  String? _lastError;
  bool _isBundled = true;
  bool _autoUpdate = true;
  bool _prefsLoaded = false;

  Future<void>? _loadInFlight;
  Future<bool>? _refreshInFlight;

  _CatalogIndex? _index;

  ModelCatalogData? get data => _data;
  bool get isLoaded => _data != null;
  int get version => _version;
  bool get refreshing => _refreshing;
  String? get lastError => _lastError;
  DateTime? get generatedAt => _data?.generatedAt;
  bool get isBundled => _isBundled;
  bool get autoUpdate => _autoUpdate;
  int get providerCount => _data?.providers.length ?? 0;
  int get modelCount {
    final providers = _data?.providers;
    if (providers == null) return 0;
    var total = 0;
    for (final provider in providers.values) {
      total += provider.models.length;
    }
    return total;
  }

  bool get isStale {
    final data = _data;
    if (data == null || _isBundled) {
      return true;
    }
    return _now().toUtc().difference(data.generatedAt.toUtc()) >
        kModelCatalogStaleAfter;
  }

  Future<void> setAutoUpdate(bool value) async {
    final changed = _autoUpdate != value;
    _autoUpdate = value;
    if (changed) {
      notifyListeners();
    }
    try {
      final prefs = await _prefs();
      await prefs.setBool(kModelCatalogAutoUpdatePrefsKey, value);
      _prefsLoaded = true;
    } catch (error) {
      _lastError = error.toString();
    }
  }

  Future<void> ensureLoaded() {
    if (_data != null) {
      return Future<void>.value();
    }
    return _loadInFlight ??= _load().whenComplete(() {
      _loadInFlight = null;
    });
  }

  Future<bool> refresh({bool force = false}) {
    return _refreshInFlight ??= _refresh(force: force).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> maybeAutoRefresh() async {
    try {
      await _ensurePrefsLoaded();
      await ensureLoaded();
      if (_autoUpdate && isStale) {
        await refresh();
      }
    } catch (error) {
      _lastError = error.toString();
    }
  }

  List<String> catalogProviderIdsFor(ProviderConfig cfg) {
    if (cfg.vertexAI == true) {
      return const <String>['google-vertex', 'google-vertex-anthropic'];
    }

    final baseUrl = cfg.baseUrl.trim();
    if (baseUrl.isEmpty) {
      return <String>[
        switch (cfg.providerType) {
          ProviderKind.claude => 'anthropic',
          ProviderKind.google => 'google',
          _ => 'openai',
        },
      ];
    }

    final host = hostFromProviderBaseUrl(baseUrl);
    final ids = <String>{};
    if (host != null) {
      ids.addAll(catalogProvidersForHost(host));
      final data = _data;
      if (data != null) {
        for (final provider in data.providers.values) {
          if (provider.apiHost == host) {
            ids.add(provider.id);
          }
        }
      }
    }

    if (ids.isEmpty) {
      if (cfg.providerType == ProviderKind.claude) {
        ids.add('anthropic');
      } else if (cfg.providerType == ProviderKind.google) {
        ids.add('google');
      }
    }

    final list = ids.toList()
      ..sort((a, b) {
        final byLength = a.length.compareTo(b.length);
        return byLength != 0 ? byLength : a.compareTo(b);
      });
    return list;
  }

  /// Models for [providerId] in the currently loaded catalog.
  ///
  /// Uses whatever snapshot is loaded (bundled, cache, or post-refresh).
  /// Returns an empty list when the catalog is not loaded or the provider
  /// is absent. Call [ensureLoaded] first when a load is required.
  List<CatalogModel> modelsOfProvider(String providerId) {
    final provider = _data?.providers[providerId];
    if (provider == null) {
      return const <CatalogModel>[];
    }
    return List<CatalogModel>.of(provider.models.values);
  }

  CatalogMatch? lookup(ProviderConfig cfg, String modelId) {
    if (_data == null) {
      unawaited(ensureLoaded());
      return null;
    }

    final trimmed = modelId.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final index = _ensureIndex();
    final candidates = catalogProviderIdsFor(cfg);

    for (final providerId in candidates) {
      final model = index.exactByProvider[providerId]?[trimmed];
      if (model != null) {
        return CatalogMatch(
          provider: index.providers[providerId]!,
          model: model,
          kind: CatalogMatchKind.providerExact,
        );
      }
    }

    final lower = trimmed.toLowerCase();
    for (final providerId in candidates) {
      final model = index.lowerByProvider[providerId]?[lower];
      if (model != null) {
        return CatalogMatch(
          provider: index.providers[providerId]!,
          model: model,
          kind: CatalogMatchKind.providerNormalized,
        );
      }
    }

    final normalized = normalizeCatalogModelId(trimmed);
    for (final providerId in candidates) {
      final model = index.normalizedByProvider[providerId]?[normalized];
      if (model != null) {
        return CatalogMatch(
          provider: index.providers[providerId]!,
          model: model,
          kind: CatalogMatchKind.providerNormalized,
        );
      }
    }

    return _lookupGlobal(index, trimmed, normalized);
  }

  @visibleForTesting
  void debugSetData(ModelCatalogData data, {bool bundled = false}) {
    _replaceData(data, bundled: bundled);
  }

  CatalogMatch? _lookupGlobal(
    _CatalogIndex index,
    String modelId,
    String normalized,
  ) {
    final slash = modelId.indexOf('/');
    if (slash > 0) {
      final prefix = modelId.substring(0, slash).toLowerCase();
      final suffix = modelId.substring(slash + 1);
      final mapped = kCatalogVendorPrefixToProviderId[prefix];
      if (mapped != null) {
        final provider = index.providers[mapped];
        if (provider != null) {
          final exact = index.exactByProvider[mapped]?[suffix];
          if (exact != null) {
            return CatalogMatch(
              provider: provider,
              model: exact,
              kind: CatalogMatchKind.global,
            );
          }
          final lower = index.lowerByProvider[mapped]?[suffix.toLowerCase()];
          if (lower != null) {
            return CatalogMatch(
              provider: provider,
              model: lower,
              kind: CatalogMatchKind.global,
            );
          }
          final norm = index
              .normalizedByProvider[mapped]?[normalizeCatalogModelId(suffix)];
          if (norm != null) {
            return CatalogMatch(
              provider: provider,
              model: norm,
              kind: CatalogMatchKind.global,
            );
          }
        }
      }
    }

    final matches = index.globalByNormalized[normalized];
    if (matches == null || matches.isEmpty) {
      return null;
    }

    var best = matches.first;
    for (var i = 1; i < matches.length; i++) {
      if (_compareGlobal(best, matches[i], index) > 0) {
        best = matches[i];
      }
    }
    return CatalogMatch(
      provider: best.provider,
      model: best.model,
      kind: CatalogMatchKind.global,
    );
  }

  int _compareGlobal(_IndexedModel a, _IndexedModel b, _CatalogIndex index) {
    final byPriority = _priorityRank(
      a.provider.id,
    ).compareTo(_priorityRank(b.provider.id));
    if (byPriority != 0) {
      return byPriority;
    }
    final byPrefix =
        (_isProviderPrefixMatch(a) ? 0 : 1) -
        (_isProviderPrefixMatch(b) ? 0 : 1);
    if (byPrefix != 0) {
      return byPrefix;
    }
    return (index.insertionOrder[a.provider.id] ?? 1 << 20).compareTo(
      index.insertionOrder[b.provider.id] ?? 1 << 20,
    );
  }

  Future<void> _load() async {
    try {
      await _ensurePrefsLoaded();
      final cacheFile = await _cacheFile();
      if (await cacheFile.exists()) {
        try {
          final parsed = await _parseTrimmedInIsolate(
            await cacheFile.readAsString(),
          );
          _lastError = null;
          _replaceData(parsed, bundled: false);
          return;
        } catch (error) {
          _lastError = error.toString();
          try {
            await cacheFile.delete();
          } catch (_) {}
        }
      }

      final bundled = await _parseTrimmedInIsolate(await _loadBundledJson());
      _lastError = null;
      _replaceData(bundled, bundled: true);
    } catch (error) {
      _lastError = error.toString();
    }
  }

  Future<bool> _refresh({required bool force}) async {
    try {
      await _ensurePrefsLoaded();
      if (!force && !isStale) {
        return false;
      }

      _setRefreshing(true);
      final body = await _downloadRemote();
      final generatedAt = _now().toUtc();
      final result = await Isolate.run(
        () => _trimAndParseRemote(body, generatedAt),
      );
      if (!_isValidCatalog(result.data)) {
        throw const FormatException('catalog has no providers or models');
      }
      await _writeCacheAtomically(result.json);
      _lastError = null;
      _refreshing = false;
      _replaceData(result.data, bundled: false);
      return true;
    } catch (error) {
      _lastError = error.toString();
      _setRefreshing(false);
      return false;
    }
  }

  Future<String> _downloadRemote() async {
    final client = _clientFactory();
    try {
      final response = await client.get(_remoteUri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: _remoteUri);
      }
      return response.body;
    } finally {
      client.close();
    }
  }

  Future<void> _writeCacheAtomically(String json) async {
    final dir = await _cacheDirectory();
    await dir.create(recursive: true);
    final dest = File('${dir.path}/$kModelCatalogCacheFileName');
    final tmp = File('${dest.path}.tmp');
    await tmp.writeAsString(json);
    if (await dest.exists()) {
      await dest.delete();
    }
    await tmp.rename(dest.path);
  }

  Future<File> _cacheFile() async {
    final dir = await _cacheDirectory();
    return File('${dir.path}/$kModelCatalogCacheFileName');
  }

  Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) {
      return;
    }
    try {
      final prefs = await _prefs();
      final value = prefs.getBool(kModelCatalogAutoUpdatePrefsKey) ?? true;
      final changed = _autoUpdate != value;
      _autoUpdate = value;
      if (changed) {
        notifyListeners();
      }
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _prefsLoaded = true;
    }
  }

  void _setRefreshing(bool value) {
    if (_refreshing == value) {
      return;
    }
    _refreshing = value;
    notifyListeners();
  }

  void _replaceData(ModelCatalogData data, {required bool bundled}) {
    _data = data;
    _isBundled = bundled;
    _version += 1;
    _index = null;
    notifyListeners();
  }

  _CatalogIndex _ensureIndex() {
    final data = _data;
    final existing = _index;
    if (data == null) {
      throw StateError('catalog is not loaded');
    }
    if (existing != null && existing.version == _version) {
      return existing;
    }
    final built = _CatalogIndex(version: _version, data: data);
    _index = built;
    return built;
  }
}

class _IndexedModel {
  const _IndexedModel({required this.provider, required this.model});

  final CatalogProvider provider;
  final CatalogModel model;
}

class _CatalogIndex {
  _CatalogIndex({required this.version, required ModelCatalogData data}) {
    var order = 0;
    for (final provider in data.providers.values) {
      providers[provider.id] = provider;
      insertionOrder[provider.id] = order++;
      final exact = <String, CatalogModel>{};
      final lower = <String, CatalogModel>{};
      final normalized = <String, CatalogModel>{};
      for (final model in provider.models.values) {
        exact[model.id] = model;
        lower.putIfAbsent(model.id.toLowerCase(), () => model);
        final norm = normalizeCatalogModelId(model.id);
        normalized.putIfAbsent(norm, () => model);
        globalByNormalized
            .putIfAbsent(norm, () => <_IndexedModel>[])
            .add(_IndexedModel(provider: provider, model: model));
      }
      exactByProvider[provider.id] = exact;
      lowerByProvider[provider.id] = lower;
      normalizedByProvider[provider.id] = normalized;
    }
  }

  final int version;
  final Map<String, CatalogProvider> providers = <String, CatalogProvider>{};
  final Map<String, int> insertionOrder = <String, int>{};
  final Map<String, Map<String, CatalogModel>> exactByProvider =
      <String, Map<String, CatalogModel>>{};
  final Map<String, Map<String, CatalogModel>> lowerByProvider =
      <String, Map<String, CatalogModel>>{};
  final Map<String, Map<String, CatalogModel>> normalizedByProvider =
      <String, Map<String, CatalogModel>>{};
  final Map<String, List<_IndexedModel>> globalByNormalized =
      <String, List<_IndexedModel>>{};
}

class _RemoteCatalogResult {
  const _RemoteCatalogResult({required this.json, required this.data});

  final String json;
  final ModelCatalogData data;
}

_RemoteCatalogResult _trimAndParseRemote(String body, DateTime generatedAt) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('models.dev payload is not an object');
  }
  final trimmed = trimModelsDevJson(
    Map<String, dynamic>.from(decoded),
    generatedAt: generatedAt,
  );
  return _RemoteCatalogResult(
    json: jsonEncode(trimmed),
    data: parseTrimmedCatalog(trimmed),
  );
}

Future<ModelCatalogData> _parseTrimmedInIsolate(String json) {
  return Isolate.run(() {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('catalog is not an object');
    }
    return parseTrimmedCatalog(Map<String, dynamic>.from(decoded));
  });
}

bool _isValidCatalog(ModelCatalogData data) {
  if (data.providers.isEmpty) {
    return false;
  }
  for (final provider in data.providers.values) {
    if (provider.models.isNotEmpty) {
      return true;
    }
  }
  return false;
}

int _priorityRank(String providerId) {
  final index = kCatalogFirstPartyPriority.indexOf(providerId);
  return index < 0 ? kCatalogFirstPartyPriority.length : index;
}

bool _isProviderPrefixMatch(_IndexedModel entry) {
  final providerId = entry.provider.id.toLowerCase();
  if (providerId.isEmpty) {
    return false;
  }
  if (entry.model.id.toLowerCase().startsWith(providerId)) {
    return true;
  }
  final family = entry.model.family;
  return family != null && family.toLowerCase().startsWith(providerId);
}

String normalizeCatalogModelId(String id) {
  var value = id.trim().toLowerCase();
  if (value.endsWith(':free')) {
    value = value.substring(0, value.length - 5);
  }
  final at = value.lastIndexOf('@');
  if (at >= 0) {
    final suffix = value.substring(at + 1);
    if (suffix.isNotEmpty && _isDigits(suffix)) {
      value = value.substring(0, at);
    }
  }
  return value;
}

bool _isDigits(String value) {
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

String? hostFromProviderBaseUrl(String baseUrl) {
  final raw = baseUrl.trim();
  if (raw.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.host.isNotEmpty) {
    return parsed.host.toLowerCase();
  }
  final withScheme = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (withScheme != null && withScheme.host.isNotEmpty) {
    return withScheme.host.toLowerCase();
  }
  return null;
}

List<String> catalogProvidersForHost(String host) {
  final exact = kCatalogExactHostProviders[host];
  if (exact != null) {
    return exact;
  }
  if (host == 'aiplatform.googleapis.com' ||
      host.endsWith('.aiplatform.googleapis.com') ||
      host.endsWith('-aiplatform.googleapis.com')) {
    return const <String>['google-vertex', 'google-vertex-anthropic'];
  }
  if (host.endsWith('.openai.azure.com')) {
    return const <String>['azure'];
  }
  if (host.endsWith('.cognitiveservices.azure.com')) {
    return const <String>['azure-cognitive-services'];
  }
  if (host.startsWith('bedrock-runtime.') && host.endsWith('.amazonaws.com')) {
    return const <String>['amazon-bedrock'];
  }
  if (host.endsWith('.aihubmix.com')) {
    return const <String>['aihubmix'];
  }
  if (host == 'ai.salad.cloud' || host.endsWith('.salad.cloud')) {
    return const <String>['salad-cloud'];
  }
  if (host.endsWith('.gitlab.com')) {
    return const <String>['gitlab'];
  }
  if (host.endsWith('.ml.cloud.ibm.com')) {
    return const <String>['watsonx'];
  }
  return const <String>[];
}

Future<String> _defaultLoadBundledJson() {
  return rootBundle.loadString(kModelCatalogAssetPath);
}

Future<Directory> _defaultCacheDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}/model_catalog');
}

http.Client _defaultClientFactory() {
  return DioHttpClient(
    timeout: kModelCatalogRefreshTimeout,
    logRequests: false,
  );
}
