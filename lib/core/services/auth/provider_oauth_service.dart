import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/model_spec.dart';
import '../../models/provider_oauth.dart';
import '../../providers/model_provider.dart';
import '../../providers/settings_provider.dart';
import '../model_spec/model_spec_resolver.dart';
import '../network/dio_http_client.dart';
import 'codex_request.dart';
import 'claude_oauth_request.dart';
import 'oauth_cancellation.dart';
import 'provider_oauth_adapter.dart';

export '../../models/provider_oauth.dart';
export 'oauth_cancellation.dart';
export 'provider_oauth_adapter.dart' show OAuthLoginPrompt;

class ProviderOAuthService extends ChangeNotifier {
  ProviderOAuthService({http.Client Function(ProviderConfig)? clientFactory})
    : _clientFactory = clientFactory ?? _clientFor;

  static final instance = ProviderOAuthService();
  final http.Client Function(ProviderConfig) _clientFactory;
  SettingsProvider? _settings;
  final _refreshes = <String, Future<ProviderConfig>>{};
  final _usage = <String, ProviderUsageSnapshot>{};
  final _usageRequests = <String, Future<ProviderUsageSnapshot>>{};
  OAuthCancellation? _login;

  void bind(SettingsProvider settings) => _settings = settings;
  void unbind(SettingsProvider settings) {
    if (identical(settings, _settings)) {
      _login?.cancel();
      _settings = null;
      _usage.clear();
    }
  }

  ProviderConfig? _current(String id) => _settings?.providerConfigs[id];

  ProviderConfig _requireCurrentSession(ProviderConfig original) {
    final current = _current(original.id);
    if (current == null ||
        current.oauthProvider != original.oauthProvider ||
        current.oauthCredentials?.sessionId !=
            original.oauthCredentials?.sessionId) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.cancelled,
        providerId: original.id,
      );
    }
    return current;
  }

  bool isRefreshing(String id) =>
      _refreshes.keys.any((key) => key.startsWith('$id:'));
  bool needsLogin(String id) {
    final config = _current(id);
    return config?.isOAuth == true &&
        (config?.oauthCredentials == null ||
            config!.oauthCredentials!.requiresLogin);
  }

  ProviderUsageSnapshot? cachedUsage(ProviderConfig config) =>
      _usage[_sessionKey(config)];
  String _sessionKey(ProviderConfig config) =>
      '${config.id}:${config.oauthCredentials?.sessionId}';

  static http.Client _clientFor(ProviderConfig config) {
    final host = config.proxyHost?.trim() ?? '';
    final port = int.tryParse(config.proxyPort ?? '');
    return DioHttpClient(
      logRequests: false,
      timeout: const Duration(seconds: 30),
      proxy: config.proxyEnabled == true && host.isNotEmpty && port != null
          ? NetworkProxyConfig(
              enabled: true,
              type: ProviderConfig.resolveProxyType(config.proxyType),
              host: host,
              port: port,
              username: config.proxyUsername,
              password: config.proxyPassword,
            )
          : null,
    );
  }

  Future<ProviderConfig> login({
    required OAuthProvider provider,
    required OAuthCancellation cancellation,
    required void Function(OAuthLoginPrompt) onPrompt,
    String? providerId,
    bool deviceCode = true,
    Future<bool> Function(Uri)? launcher,
  }) async {
    if (_login != null) {
      throw const ProviderOAuthException(ProviderOAuthFailure.denied);
    }
    final settings = _settings;
    if (settings == null) throw StateError('OAuth settings are unavailable');
    final previous = providerId == null ? null : _current(providerId);
    if (providerId != null && previous?.oauthProvider != provider) {
      throw const ProviderOAuthException(ProviderOAuthFailure.cancelled);
    }
    final config =
        previous ??
        ProviderConfig(
          id: 'oauth_${provider.name}_${const Uuid().v4()}',
          enabled: true,
          name: provider.displayName,
          apiKey: '',
          baseUrl: provider.baseUrl,
          providerType: provider == OAuthProvider.claude
              ? ProviderKind.claude
              : ProviderKind.openai,
          oauthProvider: provider,
          useResponseApi: provider.usesResponsesApi,
          claudePromptCachingEnabled: provider == OAuthProvider.claude,
          claudePromptCachingTtl: provider == OAuthProvider.claude
              ? ProviderConfig.claudePromptCachingTtl1h
              : ProviderConfig.claudePromptCachingTtl5m,
          avatarType: 'icon',
          avatarValue: provider.icon,
        );
    _login = cancellation;
    final client = _clientFactory(config);
    var closed = false;
    void close() {
      if (!closed) {
        closed = true;
        client.close();
      }
    }

    unawaited(cancellation.whenCancelled.then((_) => close()));
    final launch =
        launcher ??
        (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    try {
      final credentials = await Future.any<ProviderOAuthCredentials>([
        ProviderOAuthAdapter.forProvider(provider).login(
          OAuthWire(client),
          cancellation,
          (prompt) async {
            cancellation.check();
            onPrompt(prompt);
            if (prompt.browserAuthorization) return;
            // The visible link remains available when automatic browser opening fails.
            try {
              await launch(prompt.url);
            } catch (_) {}
          },
          deviceCode: deviceCode,
          launcher: launch,
        ),
        cancellation.whenCancelled.then(
          (_) => throw const ProviderOAuthException(
            ProviderOAuthFailure.cancelled,
          ),
        ),
      ]);
      cancellation.check();
      if (!identical(settings, _settings) ||
          (providerId != null &&
              _current(providerId)?.oauthCredentials?.sessionId !=
                  previous?.oauthCredentials?.sessionId) ||
          (providerId != null && _current(providerId) == null)) {
        throw const ProviderOAuthException(ProviderOAuthFailure.cancelled);
      }
      final saved = (providerId == null ? config : _current(providerId)!)
          .copyWith(oauthCredentials: credentials);
      await settings.setProviderConfig(saved.id, saved);
      if (providerId == null) {
        await settings.setProvidersOrder([
          saved.id,
          ...settings.providersOrder.where((id) => id != saved.id),
        ]);
      }
      notifyListeners();
      return saved;
    } catch (_) {
      cancellation.check();
      rethrow;
    } finally {
      close();
      if (identical(_login, cancellation)) _login = null;
    }
  }

  Future<void> logout(String id) async {
    final config = _current(id);
    if (config == null || !config.isOAuth) return;
    _login?.cancel();
    _usage.remove(_sessionKey(config));
    await _settings!.setProviderConfig(
      id,
      config.copyWith(oauthCredentials: null),
    );
    notifyListeners();
  }

  Future<ProviderConfig> resolve(
    ProviderConfig config, {
    bool force = false,
  }) async {
    if (!config.isOAuth) return config;
    final current = _requireCurrentSession(config);
    if (current.oauthCredentials == null ||
        current.oauthCredentials!.requiresLogin) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.loginRequired,
        providerId: config.id,
      );
    }
    if (!force &&
        !current.oauthCredentials!.shouldRefresh(
          DateTime.now(),
          leeway: current.oauthProvider == OAuthProvider.claude
              ? const Duration(minutes: 5)
              : const Duration(minutes: 1),
        )) {
      return _forRequest(current);
    }
    final key = _sessionKey(current);
    final pending = _refreshes[key];
    if (pending != null) return pending;
    final request = _refresh(current);
    _refreshes[key] = request;
    notifyListeners();
    try {
      return await request;
    } finally {
      _refreshes.remove(key);
      notifyListeners();
    }
  }

  ProviderConfig _forRequest(ProviderConfig config) => config.copyWith(
    apiKey: config.oauthCredentials!.accessToken,
    baseUrl: config.oauthProvider!.baseUrl,
    useResponseApi: config.oauthProvider!.usesResponsesApi,
    providerType: config.oauthProvider == OAuthProvider.claude
        ? ProviderKind.claude
        : config.providerType,
    multiKeyEnabled: false,
  );

  Future<ProviderConfig> _refresh(ProviderConfig original) async {
    final settings = _settings!;
    final client = _clientFactory(original);
    try {
      final refreshed = await ProviderOAuthAdapter.forProvider(
        original.oauthProvider!,
      ).refresh(OAuthWire(client), original.oauthCredentials!);
      final current = _current(original.id);
      if (!identical(settings, _settings) ||
          current?.oauthCredentials?.sessionId !=
              original.oauthCredentials!.sessionId) {
        throw ProviderOAuthException(
          ProviderOAuthFailure.cancelled,
          providerId: original.id,
        );
      }
      // Keep edits made while the refresh was in flight.
      final next = current!.copyWith(oauthCredentials: refreshed);
      await settings.setProviderConfig(next.id, next);
      return _forRequest(next);
    } on ProviderOAuthException catch (error) {
      if (!identical(settings, _settings)) {
        throw ProviderOAuthException(
          ProviderOAuthFailure.cancelled,
          providerId: original.id,
        );
      }
      _requireCurrentSession(original);
      if (error.kind == ProviderOAuthFailure.loginRequired) {
        await markLoginRequired(original);
      }
      throw ProviderOAuthException(
        error.kind,
        providerId: original.id,
        statusCode: error.statusCode,
        code: error.code,
        message: error.message,
      );
    } finally {
      client.close();
    }
  }

  Future<void> markLoginRequired(ProviderConfig original) async {
    final current = _current(original.id);
    if (current?.oauthCredentials == null ||
        current!.oauthCredentials!.sessionId !=
            original.oauthCredentials?.sessionId ||
        current.oauthCredentials!.accessToken !=
            original.oauthCredentials!.accessToken) {
      return;
    }
    await _settings!.setProviderConfig(
      current.id,
      current.copyWith(
        oauthCredentials: current.oauthCredentials!.copyWith(
          requiresLogin: true,
        ),
      ),
    );
    notifyListeners();
  }

  Future<T> _authenticated<T>(
    ProviderConfig original,
    Future<T> Function(OAuthWire, ProviderConfig) operation,
  ) async {
    var config = await resolve(original);
    final client = _clientFactory(config);
    try {
      try {
        return await operation(OAuthWire(client), config);
      } on ProviderOAuthException catch (error) {
        if (error.kind != ProviderOAuthFailure.loginRequired) rethrow;
        config = await resolve(config, force: true);
        try {
          return await operation(OAuthWire(client), config);
        } on ProviderOAuthException catch (error) {
          if (error.kind == ProviderOAuthFailure.loginRequired) {
            await markLoginRequired(config);
          }
          rethrow;
        }
      }
    } finally {
      client.close();
    }
  }

  Future<List<ModelSpec>> models(ProviderConfig original) =>
      _authenticated(original, (wire, config) async {
        final rows = await ProviderOAuthAdapter.forProvider(
          config.oauthProvider!,
        ).models(wire, config.oauthCredentials!);
        final ids = <String>{};
        return [
          for (final row in rows)
            if (oauthString(row['id']) != null &&
                ids.add(row['id'] as String) &&
                (config.oauthProvider != OAuthProvider.grok ||
                    !RegExp(
                      r'grok-(?:imagine|stt|voice|tts)',
                    ).hasMatch(row['id'] as String)))
              _OAuthModelSpec(
                row: row,
                base: _oauthDiscoveredSpec(
                  ModelSpecResolver.instance
                      .resolve(
                        config,
                        row['id'] as String,
                        displayName:
                            oauthString(row['display_name']) ??
                            oauthString(row['name']) ??
                            row['id'] as String,
                      )
                      .spec,
                  row,
                ),
              ),
        ];
      });

  Future<void> syncModels(String id) async {
    final before = _current(id);
    if (before == null) return;
    final list = await models(before);
    final current = _current(id);
    if (current == null ||
        current.oauthCredentials?.sessionId !=
            before.oauthCredentials?.sessionId) {
      return;
    }
    final overrides = Map<String, dynamic>.from(current.modelOverrides);
    final provider = current.oauthProvider!;
    for (final model in list) {
      final row = model is _OAuthModelSpec
          ? model.row
          : const <String, dynamic>{};
      overrides[model.id] = mergeOAuthModelOverride(
        existing: overrides[model.id],
        model: model,
        reasoning: oauthDiscoveredReasoning(provider, row),
        contextWindow: _oauthContextWindow(row),
        extra: {
          if (provider == OAuthProvider.kimi)
            'oauthProtocol': kimiOAuthProtocol(row),
        },
      );
    }
    await _settings!.setProviderConfig(
      id,
      current.copyWith(
        models: list.map((e) => e.id).toList(),
        modelOverrides: overrides,
        oauthModelsSyncedAt: DateTime.now(),
      ),
    );
  }

  Future<ProviderUsageSnapshot> fetchUsage(ProviderConfig original) async {
    final key = _sessionKey(original);
    if (_usageRequests[key] case final pending?) return pending;
    final request = _authenticated(
      original,
      (wire, config) => ProviderOAuthAdapter.forProvider(
        config.oauthProvider!,
      ).usage(wire, config.oauthCredentials!),
    );
    _usageRequests[key] = request;
    try {
      final result = await request;
      if (!result.hasData) {
        throw const ProviderOAuthException(
          ProviderOAuthFailure.usageUnavailable,
        );
      }
      if (_sessionKey(_current(original.id) ?? original) == key &&
          _current(original.id)?.oauthCredentials != null) {
        _usage[key] = result;
      }
      return result;
    } finally {
      _usageRequests.remove(key);
      notifyListeners();
    }
  }

  http.Client authenticatedClient(http.Client client, ProviderConfig config) =>
      config.isOAuth ? _ProviderOAuthHttpClient(client, config, this) : client;
}

const _deletedOAuthThinkingKeys = {
  'oauthThinkingMode',
  'oauthThinkingRequired',
  'oauthThinkingEfforts',
  'oauthThinkingDefaultEffort',
};

const _kimiDefaultLevels = ['low', 'medium', 'high'];

String kimiOAuthProtocol(Map<String, dynamic> row) {
  return row['protocol'] == null && row.containsKey('protocol')
      ? 'openai'
      : 'anthropic';
}

/// True/false when the catalog row states reasoning support; null if omitted.
bool? oauthRowReasoningSupport(Map<String, dynamic> row) {
  if (row.containsKey('supports_reasoning')) {
    return row['supports_reasoning'] == true;
  }
  if (row.containsKey('supports_thinking_type')) {
    return const {'only', 'both'}.contains(row['supports_thinking_type']);
  }
  final efforts = oauthMap(row['think_efforts']);
  if (efforts.containsKey('support')) {
    return efforts['support'] == true;
  }
  if (row.containsKey('supported_reasoning_levels')) {
    return _oauthRawEfforts(row['supported_reasoning_levels']).isNotEmpty;
  }
  if (row.containsKey('supported_reasoning_efforts')) {
    return _oauthRawEfforts(row['supported_reasoning_efforts']).isNotEmpty;
  }
  return null;
}

/// Maps an OAuth catalog row onto [ReasoningSpecOverride].
ReasoningSpecOverride? oauthDiscoveredReasoning(
  OAuthProvider provider,
  Map<String, dynamic> row,
) {
  if (oauthRowReasoningSupport(row) != true) return null;
  final required = row['supports_thinking_type'] == 'only';
  switch (provider) {
    case OAuthProvider.kimi:
      if (kimiOAuthProtocol(row) == 'anthropic') {
        final adaptive = oauthMap(row['think_efforts'])['support'] == true;
        return ReasoningSpecOverride.fromJson({
          'dialect': adaptive
              ? ReasoningDialect.anthropicAdaptiveEffort.name
              : ReasoningDialect.anthropicBudget.name,
          'levels': _kimiDefaultLevels,
          'canDisable': !required,
        });
      }
      final levels = _oauthLevelNames(row);
      return ReasoningSpecOverride.fromJson({
        'dialect': ReasoningDialect.kimiThinking.name,
        'levels': levels.isEmpty ? _kimiDefaultLevels : levels,
        'canDisable': !required,
        if (_oauthDefaultLevel(row) case final defaultLevel?)
          'defaultLevel': defaultLevel,
      });
    case OAuthProvider.chatgpt:
    case OAuthProvider.grok:
      final levels = _oauthLevelNames(row);
      final raw = _oauthEffortNames(row);
      return ReasoningSpecOverride.fromJson({
        'dialect': ReasoningDialect.openaiResponsesReasoning.name,
        if (levels.isNotEmpty) 'levels': levels,
        if (raw.contains('none')) 'canDisable': true,
      });
    case OAuthProvider.claude:
      return ReasoningSpecOverride.fromJson({
        'dialect': ReasoningDialect.anthropicBudget.name,
        'canDisable': !required,
      });
  }
}

Map<String, dynamic> mergeOAuthModelOverride({
  required Object? existing,
  required ModelSpec model,
  ReasoningSpecOverride? reasoning,
  int? contextWindow,
  Map<String, dynamic> extra = const {},
}) {
  final current = existing is Map
      ? ModelSpecOverride.fromJson(existing)
      : const ModelSpecOverride();
  final nextExtra = <String, dynamic>{...current.extra, ...extra};
  nextExtra.removeWhere((key, _) => _deletedOAuthThinkingKeys.contains(key));
  return current
      .copyWith(
        displayName: model.displayName,
        type: model.type,
        input: List<Modality>.from(model.input),
        output: List<Modality>.from(model.output),
        abilities: List<ModelAbility>.from(model.abilities),
        reasoning: _mergeReasoningOverride(current.reasoning, reasoning),
        contextWindow: contextWindow,
        extra: nextExtra,
      )
      .toJson();
}

ReasoningSpecOverride? _mergeReasoningOverride(
  ReasoningSpecOverride? existing,
  ReasoningSpecOverride? discovered,
) {
  if (discovered == null) return existing;
  if (existing == null || existing.isEmpty) return discovered;
  return existing.copyWith(
    levels: discovered.levels,
    canDisable: discovered.canDisable,
    defaultLevel: discovered.defaultLevel,
    dialect: discovered.dialect,
    budgets: discovered.budgets,
    customPatches: discovered.customPatches,
    replay: discovered.replay,
    replayField: discovered.replayField,
  );
}

List<String> _oauthRawEfforts(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim().toLowerCase(),
  ];
}

List<String> _oauthEffortNames(Map<String, dynamic> row) {
  final think = oauthMap(row['think_efforts']);
  if (think['valid_efforts'] is List) {
    return _oauthRawEfforts(think['valid_efforts']);
  }
  if (row['supported_reasoning_levels'] is List) {
    return _oauthRawEfforts(row['supported_reasoning_levels']);
  }
  if (row['supported_reasoning_efforts'] is List) {
    return _oauthRawEfforts(row['supported_reasoning_efforts']);
  }
  return const [];
}

List<String> _oauthLevelNames(Map<String, dynamic> row) {
  final names = <String>[];
  final seen = <String>{};
  for (final effort in _oauthEffortNames(row)) {
    if (effort == 'none' || effort == 'auto' || effort == 'off') continue;
    for (final level in ReasoningLevel.values) {
      if (level.name == effort && seen.add(level.name)) {
        names.add(level.name);
        break;
      }
    }
  }
  return names;
}

String? _oauthDefaultLevel(Map<String, dynamic> row) {
  final raw = oauthString(oauthMap(row['think_efforts'])['default_effort']);
  if (raw == null) return null;
  final name = raw.toLowerCase();
  for (final level in ReasoningLevel.values) {
    if (level.name == name) return level.name;
  }
  return null;
}

int? _oauthContextWindow(Map<String, dynamic> row) {
  final value = oauthNumber(row['context_window']);
  if (value == null || value <= 0 || value != value.truncateToDouble()) {
    return null;
  }
  return value.toInt();
}

ModelSpec _oauthDiscoveredSpec(ModelSpec resolved, Map<String, dynamic> row) {
  final imageIn =
      row['supports_image_in'] == true ||
      (row['input_modalities'] as List? ?? const []).contains('image');
  final support = oauthRowReasoningSupport(row);
  return resolved.copyWith(
    contextWindow: _oauthContextWindow(row),
    input: <Modality>[...resolved.input, if (imageIn) Modality.image],
    abilities: <ModelAbility>[
      ...resolved.abilities.where(
        (ability) => support != false || ability != ModelAbility.reasoning,
      ),
      ModelAbility.tool,
      if (support == true) ModelAbility.reasoning,
    ],
  );
}

class _OAuthModelSpec extends ModelSpec {
  _OAuthModelSpec({required this.row, required ModelSpec base})
    : super(
        id: base.id,
        apiModelId: base.apiModelId,
        displayName: base.displayName,
        type: base.type,
        input: base.input,
        output: base.output,
        abilities: base.abilities,
        reasoning: base.reasoning,
        sampling: base.sampling,
        contextWindow: base.contextWindow,
        maxOutput: base.maxOutput,
        pricing: base.pricing,
        headers: base.headers,
        body: base.body,
        builtInTools: base.builtInTools,
      );
  final Map<String, dynamic> row;
}

/// Attaches current credentials and enforces each subscription wire contract
/// after custom request overrides, for initial requests and tool follow-ups.
class _ProviderOAuthHttpClient extends http.BaseClient {
  _ProviderOAuthHttpClient(this.inner, this.config, this.service)
    : _sessionId = config.oauthCredentials?.sessionId;
  final http.Client inner;
  ProviderConfig config;
  final ProviderOAuthService service;
  final String? _sessionId;
  final String _claudeConversationId = const Uuid().v4();

  void _checkSession() {
    if (config.oauthCredentials?.sessionId != _sessionId) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.cancelled,
        providerId: config.id,
      );
    }
    service._requireCurrentSession(config);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _checkSession();
    config = await service.resolve(config);
    _checkSession();
    final base = Uri.parse(config.oauthProvider!.baseUrl);
    if (request.url.origin != base.origin ||
        !request.url.path.startsWith('${base.path}/') ||
        request is! http.Request &&
            config.oauthProvider != OAuthProvider.claude) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    final body = request is http.Request
        ? request.bodyBytes
        : await request.finalize().toBytes();
    final isClaude = config.oauthProvider == OAuthProvider.claude;
    final claudeMessages = isClaude && request.url.path.endsWith('/messages');
    http.Request build() {
      // Recheck immediately before every send, including after refresh awaits.
      _checkSession();
      final result =
          http.Request(
              request.method,
              claudeMessages
                  ? request.url.replace(
                      queryParameters: {
                        ...request.url.queryParameters,
                        'beta': 'true',
                      },
                    )
                  : request.url,
            )
            ..followRedirects = false
            ..headers.addAll(request.headers)
            ..bodyBytes = body;
      final authHeaders = ProviderOAuthAdapter.forProvider(
        config.oauthProvider!,
      ).headers(config.oauthCredentials!);
      final existingBeta = result.headers['anthropic-beta'];
      final existingContentType = result.headers['content-type'];
      for (final name in authHeaders.keys) {
        result.headers.remove(name);
      }
      result.headers.addAll(authHeaders);
      if (isClaude) {
        result.headers.remove('x-api-key');
        setClaudeOAuthHeader(
          result.headers,
          'anthropic-beta',
          {
            ...claudeOAuthBetas,
            ...?existingBeta
                ?.split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty),
          }.where((value) => value != 'context-1m-2025-08-07').join(','),
        );
        if (existingContentType != null && !claudeMessages) {
          setClaudeOAuthHeader(
            result.headers,
            'Content-Type',
            existingContentType,
          );
        }
      }
      if (config.oauthProvider == OAuthProvider.kimi &&
          request.url.path.endsWith('/messages')) {
        result.headers['x-api-key'] = config.oauthCredentials!.accessToken;
      }
      if (request.method == 'POST' && (!isClaude || claudeMessages)) {
        final payload = (jsonDecode(utf8.decode(body)) as Map)
            .cast<String, dynamic>();
        if (config.oauthProvider == OAuthProvider.chatgpt) {
          applyCodexRequest(
            payload,
            result.headers,
            config.oauthCredentials!.accessToken,
          );
        }
        if (config.oauthProvider == OAuthProvider.kimi &&
            request.url.path.endsWith('/messages')) {
          final thinking = oauthMap(payload['thinking']);
          final budget = oauthNumber(thinking['budget_tokens']);
          final max = oauthNumber(payload['max_tokens']);
          if (budget != null && max != null && budget >= max) {
            payload['thinking'] = {
              ...thinking,
              'budget_tokens': (max - 1).clamp(1, 32000).toInt(),
            };
          }
        }
        if (config.oauthProvider == OAuthProvider.grok) {
          final reasoning = oauthMap(payload['reasoning']);
          if (reasoning.isNotEmpty) {
            final value = Map<String, dynamic>.from(reasoning)
              ..remove('summary');
            if (value.isEmpty) {
              payload.remove('reasoning');
            } else {
              payload['reasoning'] = value;
            }
          }
          payload['store'] = false;
          payload['include'] = {
            ...(payload['include'] as List? ?? const []),
            'reasoning.encrypted_content',
          }.toList();
        }
        result.body = isClaude
            ? encodeClaudeOAuthRequest(
                payload,
                config,
                result.headers,
                _claudeConversationId,
              )
            : jsonEncode(payload);
      }
      return result;
    }

    var refreshed = false;
    var retriedClaudeVersion = false;
    while (true) {
      final requestVersion = claudeCodeVersion;
      final response = await inner.send(build());
      if (response.statusCode == 401) {
        await response.stream.drain<void>();
        _checkSession();
        if (refreshed) {
          await service.markLoginRequired(config);
          throw ProviderOAuthException(
            ProviderOAuthFailure.loginRequired,
            providerId: config.id,
            statusCode: 401,
          );
        }
        config = await service.resolve(config, force: true);
        refreshed = true;
        continue;
      }
      if (claudeMessages &&
          request.method == 'POST' &&
          response.statusCode == 400 &&
          !retriedClaudeVersion) {
        final bytes = await response.stream.toBytes();
        _checkSession();
        if (adoptRequiredClaudeCodeVersion(
          utf8.decode(bytes, allowMalformed: true),
          requestVersion: requestVersion,
        )) {
          retriedClaudeVersion = true;
          // Rebuild from the original body so version, billing and cch agree,
          // without duplicating system blocks or tool prefixes.
          continue;
        }
        return http.StreamedResponse(
          Stream.value(bytes),
          response.statusCode,
          contentLength: response.contentLength,
          request: response.request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }
      return response;
    }
  }

  @override
  void close() => inner.close();
}
