import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/provider_oauth.dart';
import '../../providers/model_provider.dart';
import '../../providers/settings_provider.dart';
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

  Future<List<ModelInfo>> models(ProviderConfig original) => _authenticated(
    original,
    (wire, config) async {
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
            _OAuthModelInfo(
              row: row,
              base: ModelRegistry.infer(
                ModelInfo(
                  id: row['id'] as String,
                  displayName:
                      oauthString(row['display_name']) ??
                      oauthString(row['name']) ??
                      row['id'] as String,
                  input: [
                    Modality.text,
                    if (row['supports_image_in'] == true ||
                        (row['input_modalities'] as List? ?? const []).contains(
                          'image',
                        ))
                      Modality.image,
                  ],
                  abilities: [
                    ModelAbility.tool,
                    if (row['supports_reasoning'] == true ||
                        {
                          'only',
                          'both',
                        }.contains(row['supports_thinking_type']) ||
                        oauthMap(row['think_efforts'])['support'] == true ||
                        (row['supported_reasoning_levels'] as List? ?? const [])
                            .isNotEmpty)
                      ModelAbility.reasoning,
                  ],
                ),
              ),
            ),
      ];
    },
  );

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
    for (final model in list) {
      overrides[model.id] = {
        ...oauthMap(overrides[model.id]),
        'name': model.displayName,
        'type': model.type.name,
        'input': model.input.map((e) => e.name).toList(),
        'output': model.output.map((e) => e.name).toList(),
        'abilities': model.abilities.map((e) => e.name).toList(),
        if (current.oauthProvider == OAuthProvider.kimi &&
            model is _OAuthModelInfo) ...{
          'oauthThinkingMode':
              oauthMap(model.row['think_efforts'])['support'] == true
              ? 'adaptive'
              : 'enabled',
          'oauthThinkingRequired':
              model.row['supports_thinking_type'] == 'only',
          'oauthThinkingEfforts':
              oauthMap(model.row['think_efforts'])['support'] == true &&
                  oauthMap(model.row['think_efforts'])['valid_efforts'] is List
              ? (oauthMap(model.row['think_efforts'])['valid_efforts'] as List)
                    .whereType<String>()
                    .toList()
              : <String>[],
          'oauthThinkingDefaultEffort': oauthString(
            oauthMap(model.row['think_efforts'])['default_effort'],
          ),
        },
        if (current.oauthProvider == OAuthProvider.kimi &&
            model is _OAuthModelInfo)
          'oauthProtocol':
              model.row['protocol'] == null && model.row.containsKey('protocol')
              ? 'openai'
              : 'anthropic',
      };
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

class _OAuthModelInfo extends ModelInfo {
  _OAuthModelInfo({required this.row, required ModelInfo base})
    : super(
        id: base.id,
        displayName: base.displayName,
        type: base.type,
        input: base.input,
        output: base.output,
        abilities: base.abilities,
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
        result.headers.removeWhere(
          (key, _) => key.toLowerCase() == name.toLowerCase(),
        );
      }
      result.headers.addAll(authHeaders);
      if (isClaude) {
        result.headers.removeWhere(
          (key, _) => key.toLowerCase() == 'x-api-key',
        );
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
            final model = '${payload['model']}';
            if (model == 'grok-build' ||
                model.endsWith('reasoning') ||
                (model.startsWith('grok-4') &&
                    !RegExp(r'grok-4\.(?:[3-9]|20)').hasMatch(model))) {
              value.remove('effort');
            }
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

    var response = await inner.send(build());
    if (response.statusCode != 401) return response;
    await response.stream.drain<void>();
    _checkSession();
    config = await service.resolve(config, force: true);
    response = await inner.send(build());
    if (response.statusCode == 401) {
      await response.stream.drain<void>();
      await service.markLoginRequired(config);
      throw ProviderOAuthException(
        ProviderOAuthFailure.loginRequired,
        providerId: config.id,
        statusCode: 401,
      );
    }
    return response;
  }

  @override
  void close() => inner.close();
}
