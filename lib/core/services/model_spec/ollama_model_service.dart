import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../network/provider_http_client.dart';

/// Server-advertised defaults, kept separate from the user's model overrides.
class OllamaModelMetadata {
  const OllamaModelMetadata(
    this.capabilities,
    this.thinkingValues,
    this.defaultThinking,
  );

  final List<String> capabilities;
  final List<Object>? thinkingValues;
  final Object? defaultThinking;

  static OllamaModelMetadata? fromJson(Object? value) {
    if (value is! Map || value['capabilities'] is! List) return null;
    final capabilities = value['capabilities'] as List;
    if (capabilities.any((e) => e is! String) || capabilities.isEmpty) {
      return null;
    }
    final thinking = value['thinking'];
    final values = thinking is Map ? thinking['values'] : null;
    return OllamaModelMetadata(
      capabilities.cast<String>(),
      values is List &&
              values.isNotEmpty &&
              values.every((e) => e is bool || e is String)
          ? values.cast<Object>()
          : null,
      thinking is Map ? thinking['default'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'capabilities': capabilities,
    if (thinkingValues != null)
      'thinking': {'values': thinkingValues, 'default': defaultThinking},
  };

  ModelSpec applyTo(ModelSpec base) {
    final embedding =
        capabilities.contains('embedding') &&
        !capabilities.contains('completion');
    final values = thinkingValues;
    final thinking =
        !embedding &&
        (values == null
            ? capabilities.contains('thinking')
            : values.any((value) => value != false));
    final levels = <ReasoningLevel>[
      if (thinking && values != null)
        for (final level in ReasoningLevel.values)
          if ((level == ReasoningLevel.on && values.contains(true)) ||
              (level.index > ReasoningLevel.on.index &&
                  values.contains(level.name)))
            level,
    ];
    final canDisable = thinking && (values?.contains(false) ?? false);
    final defaultLevel = defaultThinking == false && canDisable
        ? ReasoningLevel.off
        : defaultThinking == true && levels.contains(ReasoningLevel.on)
        ? ReasoningLevel.on
        : levels.where((level) => level.name == defaultThinking).firstOrNull ??
              ReasoningLevel.auto;
    return base.copyWith(
      type: embedding ? ModelType.embedding : ModelType.chat,
      input: [
        Modality.text,
        if (capabilities.contains('vision')) Modality.image,
        if (capabilities.contains('audio')) Modality.audio,
      ],
      output: const [Modality.text],
      abilities: [
        if (!embedding && capabilities.contains('tools')) ModelAbility.tool,
        if (thinking) ModelAbility.reasoning,
      ],
      reasoning: ReasoningSpec(
        dialect: thinking
            ? ReasoningDialect.openaiReasoningEffort
            : ReasoningDialect.none,
        levels: levels,
        canDisable: canDisable,
        defaultLevel: thinking ? defaultLevel : ReasoningLevel.auto,
      ),
      sampling: SamplingPolicy.always,
      dynamicWebSearch: false,
      remoteImageUrls: false,
      promptCacheControl: false,
    );
  }
}

class _CachedModel {
  const _CachedModel(this.digest, this.metadata, this.fetchedAt);
  final String digest;
  final OllamaModelMetadata metadata;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
    'digest': digest,
    'fetchedAt': fetchedAt.toIso8601String(),
    ...metadata.toJson(),
  };
}

/// Discovers local Ollama servers only when the user fetches a model list.
/// Loading the persisted cache never performs network requests.
class OllamaModelService {
  OllamaModelService({
    Future<SharedPreferences> Function()? preferences,
    this.clientFactory,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 2),
    this.discoveryTimeout = const Duration(seconds: 10),
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static final instance = OllamaModelService();
  static const cacheKey = 'ollama_model_metadata_v1';
  final Future<SharedPreferences> Function() _preferences;
  final http.Client Function(ProviderConfig)? clientFactory;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final Duration discoveryTimeout;
  final Map<String, Map<String, _CachedModel>> _cache = {};
  final Map<String, DateTime> _unavailableUntil = {};
  final Map<String, Future<List<String>?>> _inFlight = {};
  Future<void>? _loadFuture;
  bool _loaded = false;
  int version = 0;

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _load().whenComplete(() {
      _loaded = true;
      _loadFuture = null;
    });
  }

  Future<void> _load() async {
    try {
      final prefs = await _preferences();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      for (final endpoint in data.entries) {
        if (endpoint.key is! String || endpoint.value is! Map) continue;
        final models = <String, _CachedModel>{};
        for (final model in (endpoint.value as Map).entries) {
          final entry = model.value;
          final metadata = OllamaModelMetadata.fromJson(entry);
          final fetchedAt = entry is Map && entry['fetchedAt'] is String
              ? DateTime.tryParse(entry['fetchedAt'] as String)
              : null;
          if (model.key is String &&
              entry is Map &&
              entry['digest'] is String &&
              metadata != null &&
              fetchedAt != null) {
            models[model.key as String] = _CachedModel(
              entry['digest'] as String,
              metadata,
              fetchedAt,
            );
          }
        }
        _cache[endpoint.key as String] = models;
      }
      version++;
    } catch (_) {
      // A disposable cache must not prevent settings or model lists loading.
    }
  }

  OllamaModelMetadata? lookup(ProviderConfig config, String modelId) {
    return _cache[cacheScope(config)]?[_modelKey(modelId)]?.metadata;
  }

  String? cacheScope(ProviderConfig config) {
    final root = apiRoot(config);
    return root == null ? null : _endpointKey(config, root);
  }

  Future<List<String>?> fetchModels(
    ProviderConfig config,
    Map<String, String> headers,
  ) async {
    final root = apiRoot(config);
    if (root == null) return null;
    await ensureLoaded();
    final key = _endpointKey(config, root);
    if (_now().isBefore(_unavailableUntil[key] ?? DateTime(1970))) return null;
    return _inFlight[key] ??= _fetch(config, root, key, headers).whenComplete(
      () {
        _inFlight.remove(key);
      },
    );
  }

  Future<List<String>?> _fetch(
    ProviderConfig config,
    Uri root,
    String key,
    Map<String, String> headers,
  ) async {
    try {
      final result = await _discover(
        config,
        root,
        headers,
        _cache[key] ?? const {},
      );
      if (result == null) {
        _unavailableUntil[key] = _now().add(const Duration(minutes: 5));
        return null;
      }
      final old = _cache[key];
      _cache[key] = result.metadata;
      while (_cache.length > 64) {
        _cache.remove(_cache.keys.first);
      }
      if (!mapEquals(old, result.metadata)) {
        version++;
        try {
          final prefs = await _preferences();
          await prefs.setString(
            cacheKey,
            jsonEncode(
              _cache.map(
                (endpoint, models) => MapEntry(
                  endpoint,
                  models.map((id, model) => MapEntry(id, model.toJson())),
                ),
              ),
            ),
          );
        } catch (_) {
          // The current session can still use metadata if cache storage fails.
        }
      }
      return result.ids;
    } catch (_) {
      _unavailableUntil[key] = _now().add(const Duration(minutes: 5));
      return null;
    }
  }

  Future<({List<String> ids, Map<String, _CachedModel> metadata})?> _discover(
    ProviderConfig config,
    Uri root,
    Map<String, String> headers,
    Map<String, _CachedModel> cached,
  ) async {
    final elapsed = Stopwatch()..start();
    final tags = await _request(
      config,
      root.resolve('tags'),
      headers,
      remaining: discoveryTimeout,
    );
    if (tags is! Map || tags['models'] is! List) return null;
    if ((tags['models'] as List).isEmpty) {
      // An empty generic models response alone does not identify Ollama.
      final version = await _request(
        config,
        root.resolve('version'),
        headers,
        remaining: discoveryTimeout - elapsed.elapsed,
      );
      if (version is! Map ||
          version['version'] is! String ||
          !RegExp(r'^\d+\.\d+\.\d+').hasMatch(version['version'] as String)) {
        return null;
      }
    }
    final digests = <String, String>{};
    for (final raw in tags['models'] as List) {
      if (raw is! Map) return null;
      final id = raw['model'] ?? raw['name'];
      final digest = raw['digest'];
      if (id is! String || id.isEmpty || digest is! String || digest.isEmpty) {
        return null;
      }
      digests[id] = digest;
    }
    final metadata = <String, _CachedModel>{};
    final pending = <String>[];
    for (final entry in digests.entries) {
      final existing = cached[_modelKey(entry.key)];
      if (existing != null &&
          existing.digest == entry.value &&
          _now().difference(existing.fetchedAt) < const Duration(days: 1)) {
        metadata[_modelKey(entry.key)] = existing;
      } else {
        pending.add(entry.key);
      }
    }
    // Limit fan-out on small machines with many installed models.
    for (var offset = 0; offset < pending.length; offset += 4) {
      final remaining = discoveryTimeout - elapsed.elapsed;
      if (remaining <= Duration.zero) break;
      await Future.wait(
        pending.skip(offset).take(4).map((id) async {
          try {
            final show = await _request(
              config,
              root.resolve('show'),
              headers,
              modelId: id,
              remaining: remaining,
            );
            final parsed = OllamaModelMetadata.fromJson(show);
            if (parsed != null) {
              metadata[_modelKey(id)] = _CachedModel(
                digests[id]!,
                parsed,
                _now(),
              );
            }
          } catch (_) {
            // A model can disappear between tags and show; retain the list.
          }
        }),
      );
    }
    return (ids: digests.keys.toList(), metadata: metadata);
  }

  Future<Object?> _request(
    ProviderConfig config,
    Uri uri,
    Map<String, String> headers, {
    String? modelId,
    required Duration remaining,
  }) async {
    if (remaining <= Duration.zero) {
      throw TimeoutException('Ollama discovery timed out');
    }
    final timeout = remaining < requestTimeout ? remaining : requestTimeout;
    final cancellation = CancelToken();
    final client =
        clientFactory?.call(config) ??
        providerHttpClient(config, cancelToken: cancellation);
    final request = http.Request(modelId == null ? 'GET' : 'POST', uri)
      ..followRedirects = false
      ..headers.addAll(headers);
    if (modelId != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'model': modelId});
    }
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } finally {
      // Future.timeout alone does not abort Dio's active socket/response stream.
      cancellation.cancel();
      client.close();
    }
  }

  static String _endpointKey(ProviderConfig config, Uri root) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            config.id,
            root.toString(),
            config.apiKey,
            config.customHeaders,
            config.multiKeyEnabled,
            config.apiKeys
                ?.map((key) => [key.id, key.key, key.isEnabled])
                .toList(),
            config.proxyEnabled,
            config.proxyType,
            config.proxyHost,
            config.proxyPort,
            config.proxyUsername,
            config.proxyPassword,
          ]),
        ),
      )
      .toString();

  // Ollama names are case-insensitive and omit the default registry,
  // namespace and tag in user-entered IDs (including apiModelId aliases).
  static String _modelKey(String id) {
    final parts = id
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/');
    if (!parts.last.contains(':')) parts[parts.length - 1] += ':latest';
    return switch (parts.length) {
      1 => 'registry.ollama.ai/library/${parts.single}',
      2 => 'registry.ollama.ai/${parts.join('/')}',
      _ => parts.join('/'),
    };
  }

  /// Private addresses are only candidates; an Ollama API response must still
  /// be recognized. Do not probe arbitrary public OpenAI-compatible services.
  static Uri? apiRoot(ProviderConfig config) {
    if (config.isOAuth ||
        ProviderConfig.classify(config.id, explicitType: config.providerType) !=
            ProviderKind.openai) {
      return null;
    }
    final uri = Uri.tryParse(config.baseUrl.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        !_isLocalHost(uri.host)) {
      return null;
    }
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.endsWith('/v1')) path = path.substring(0, path.length - 3);
    return uri.replace(path: '$path/api/', fragment: '');
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
    if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
      return true;
    }
    final address = InternetAddress.tryParse(normalized);
    if (address == null) return false;
    if (address.isLoopback || address.isLinkLocal) return true;
    var bytes = address.rawAddress;
    // IPv4-mapped IPv6 addresses use the same private-network rules.
    if (bytes.length == 16 &&
        bytes.take(10).every((b) => b == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255) {
      bytes = bytes.sublist(12);
    }
    if (bytes.length == 4) {
      return bytes[0] == 127 ||
          bytes[0] == 10 ||
          (bytes[0] == 169 && bytes[1] == 254) ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168);
    }
    return (bytes[0] & 0xfe) == 0xfc;
  }
}
