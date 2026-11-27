import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/model_spec.dart';
import '../../models/provider_oauth.dart';
import '../../providers/model_provider.dart';
import '../../providers/settings_provider.dart';
import '../model_spec/model_spec_resolver.dart';
import '../api/request_image_context.dart';
import '../network/dio_http_client.dart';
import '../network/media_http_log.dart';
import '../network/provider_http_exception.dart';
import 'codex_client_version.dart';
import 'codex_request.dart';
import 'codex_turn_state.dart';
import 'claude_oauth_request.dart';
import 'oauth_cancellation.dart';
import 'provider_oauth_adapter.dart';

export '../../models/provider_oauth.dart';
export 'oauth_cancellation.dart';
export 'provider_oauth_adapter.dart' show OAuthLoginPrompt;

class ProviderOAuthService extends ChangeNotifier {
  ProviderOAuthService({
    http.Client Function(ProviderConfig)? clientFactory,
    this._codexVersion,
  }) : _clientFactory = clientFactory ?? _clientFor;

  static final instance = ProviderOAuthService(
    codexVersion: CodexClientVersion(),
  );
  final http.Client Function(ProviderConfig) _clientFactory;
  final CodexClientVersion? _codexVersion;
  SettingsProvider? _settings;
  final _refreshes =
      <
        ({SettingsProvider settings, String id, String session}),
        ({String accessToken, Future<ProviderConfig> result})
      >{};
  final _claudeRenewals = <String, _ClaudeRenewal>{};
  final _modelSyncs =
      <(SettingsProvider, String, CodexVersionSnapshot?), Future<void>>{};
  final _usage = <String, ProviderUsageSnapshot>{};
  final _usageRequests = <String, Future<ProviderUsageSnapshot>>{};
  OAuthCancellation? _login;

  void bind(SettingsProvider settings) {
    if (!identical(settings, _settings)) _claudeRenewals.clear();
    _settings = settings;
  }

  void unbind(SettingsProvider settings) {
    if (identical(settings, _settings)) {
      _login?.cancel();
      _settings = null;
      _usage.clear();
      _claudeRenewals.clear();
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

  bool isRefreshing(String id) => _refreshes.keys.any(
    (key) => identical(key.settings, _settings) && key.id == id,
  );
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
      logMode: HttpLogMode.disabled,
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
          .copyWith(
            oauthCredentials: credentials,
            oauthModelsClientVersion: null,
          );
      if (previous != null) _claudeRenewals.remove(_sessionKey(previous));
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
    _claudeRenewals.remove(_sessionKey(config));
    await _settings!.setProviderConfig(
      id,
      config.copyWith(oauthCredentials: null, oauthModelsClientVersion: null),
    );
    notifyListeners();
  }

  Future<ProviderConfig> resolve(
    ProviderConfig config, {
    bool force = false,
    bool usageProbe = false,
  }) async {
    if (!config.isOAuth) return config;
    final current = _requireCurrentSession(config);
    final credentials = current.oauthCredentials;
    if (credentials == null || credentials.requiresLogin) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.loginRequired,
        providerId: config.id,
      );
    }
    final isClaude = current.oauthProvider == OAuthProvider.claude;
    final key = _sessionKey(current);
    final settings = _settings!;
    final refreshKey = (
      settings: settings,
      id: current.id,
      session: credentials.sessionId,
    );
    final pending = _refreshes[refreshKey];
    // Settings exposes the new bearer before its persistence future completes.
    // Finish that rotation before a request can send and then reject the new bearer.
    final publishing =
        isClaude &&
        pending != null &&
        pending.accessToken != credentials.accessToken;
    final renewal = _claudeRenewals[key];
    final now = clock.now();
    if (!force &&
        !publishing &&
        renewal?.rejects(credentials) != true &&
        (!credentials.shouldRefresh(
              now,
              leeway: Duration(minutes: isClaude ? 5 : 1),
            ) ||
            renewal?.canDefer(credentials, now) == true)) {
      return _forRequest(current);
    }
    final request = pending?.result ?? _refresh(current);
    if (pending == null) {
      _refreshes[refreshKey] = (
        accessToken: credentials.accessToken,
        result: request,
      );
      notifyListeners();
    }
    try {
      return await request;
    } on ProviderOAuthException catch (error) {
      // Refreshes are shared with usage probes. Each caller decides whether
      // its failure can invalidate the account; token rotation is still saved
      // once by _refresh regardless of who started it.
      if (!identical(settings, _settings) ||
          error.kind == ProviderOAuthFailure.cancelled) {
        rethrow;
      }
      if (error.kind == ProviderOAuthFailure.loginRequired) {
        if (!usageProbe) await markLoginRequired(current);
        rethrow;
      }
      if (!isClaude || force) rethrow;
      final latest = _requireCurrentSession(current);
      final saved = latest.oauthCredentials!;
      final now = clock.now();
      if (saved.accessToken != credentials.accessToken ||
          saved.requiresLogin ||
          !saved.expiresAt.isAfter(now) ||
          _claudeRenewals[key]?.rejects(saved) == true) {
        rethrow;
      }
      if (!usageProbe) {
        _claudeRenewals[key] = _ClaudeRenewal(
          saved.accessToken,
          retryAt: now.add(const Duration(seconds: 10)),
        );
      }
      return _forRequest(latest);
    } finally {
      if (pending == null) {
        _refreshes.remove(refreshKey);
        notifyListeners();
      }
    }
  }

  // Late refusals of an old bearer should reuse a newer token from the same
  // login. An advisory usage probe cannot invalidate the interactive bearer.
  void _recordBearerRejection(ProviderConfig sent, {bool usageProbe = false}) {
    if (sent.oauthProvider != OAuthProvider.claude || usageProbe) return;
    final credentials = sent.oauthCredentials!;
    final current = _current(sent.id);
    if (current?.oauthProvider == sent.oauthProvider &&
        current?.oauthCredentials?.sessionId == credentials.sessionId &&
        current?.oauthCredentials?.accessToken == credentials.accessToken) {
      _claudeRenewals[_sessionKey(sent)] = _ClaudeRenewal(
        credentials.accessToken,
      );
    }
  }

  Future<ProviderConfig> _recoverBearer(
    ProviderConfig sent, {
    bool usageProbe = false,
  }) {
    final current = _requireCurrentSession(sent);
    final force =
        current.oauthProvider != OAuthProvider.claude ||
        current.oauthCredentials?.accessToken ==
            sent.oauthCredentials!.accessToken;
    return resolve(current, force: force, usageProbe: usageProbe);
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
      _claudeRenewals.remove(_sessionKey(original));
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
      throw ProviderOAuthException(
        error.kind,
        providerId: original.id,
        statusCode: error.statusCode,
        code: error.code,
        message: error.message,
        stage: error.stage,
        transportFailure: error.transportFailure,
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
    Future<T> Function(OAuthWire, ProviderConfig) operation, {
    bool usageProbe = false,
    bool Function()? isCurrent,
  }) async {
    final settings = _settings;
    void checkCurrent() {
      if (!identical(settings, _settings) || isCurrent?.call() == false) {
        throw ProviderOAuthException(
          ProviderOAuthFailure.cancelled,
          providerId: original.id,
        );
      }
      _requireCurrentSession(original);
    }

    try {
      checkCurrent();
      var config = await resolve(original, usageProbe: usageProbe);
      final client = _clientFactory(config);
      try {
        for (var retried = false; ; retried = true) {
          checkCurrent();
          final sent = config;
          final wire = OAuthWire(
            client,
            onUnauthorized:
                !usageProbe && sent.oauthProvider == OAuthProvider.claude
                ? () {
                    if (identical(settings, _settings)) {
                      _recordBearerRejection(sent);
                    }
                  }
                : null,
          );
          try {
            return await operation(wire, sent);
          } on ProviderOAuthException catch (error) {
            checkCurrent();
            final rejected =
                error is ClaudeOAuthBearerRejected ||
                error.kind == ProviderOAuthFailure.loginRequired;
            if (!rejected) rethrow;
            _recordBearerRejection(config, usageProbe: usageProbe);
            if (retried) {
              if (!usageProbe &&
                  error.kind == ProviderOAuthFailure.loginRequired) {
                await markLoginRequired(config);
              }
              rethrow;
            }
            config = await _recoverBearer(config, usageProbe: usageProbe);
          }
        }
      } finally {
        client.close();
      }
    } on ProviderOAuthException catch (error) {
      final resourceUnauthorized =
          error is ClaudeOAuthBearerRejected && error.statusCode == 401;
      if (!usageProbe ||
          (error.kind != ProviderOAuthFailure.loginRequired &&
              !resourceUnauthorized)) {
        rethrow;
      }
      throw ProviderOAuthException(
        ProviderOAuthFailure.usageUnavailable,
        providerId: original.id,
        statusCode: error.statusCode,
        code: error.code,
        message: error.message,
        stage: error.stage,
        transportFailure: error.transportFailure,
      );
    }
  }

  CodexVersionSnapshot get _effectiveCodexVersion =>
      _codexVersion?.snapshot ?? bundledCodexVersion;

  Future<String> _currentCodexVersion() async =>
      await _codexVersion?.current() ?? defaultCodexClientVersion;

  Future<List<ModelSpec>> models(ProviderConfig original) async => _models(
    original,
    original.oauthProvider == OAuthProvider.chatgpt
        ? await _currentCodexVersion()
        : null,
  );

  Future<List<ModelSpec>> _models(
    ProviderConfig original,
    String? codexVersion, {
    bool Function()? isCurrent,
  }) async {
    final settings = _settings;
    final replaceMetadata = await ModelSpecResolver.instance
        .startModelListRefresh(original);
    return _authenticated(original, (wire, config) async {
      final rows = await ProviderOAuthAdapter.forProvider(
        config.oauthProvider!,
        codexVersion: codexVersion,
      ).models(wire, config.oauthCredentials!);
      final current = _current(config.id);
      if (identical(settings, _settings) &&
          current != null &&
          current.oauthProvider == config.oauthProvider &&
          current.oauthCredentials?.sessionId ==
              config.oauthCredentials?.sessionId &&
          // A superseded Codex list can still seed the initial catalog.
          (isCurrent?.call() != false ||
              current.oauthModelsClientVersion == null && rows.isNotEmpty)) {
        await replaceMetadata([
          for (final row in rows)
            if (oauthString(row['id']) case final id?) (id: id, json: row),
        ]);
      }
      final ids = <String>{};
      return [
        for (final row in rows)
          if (oauthString(row['id']) case final id?)
            if (ids.add(id) &&
                (config.oauthProvider != OAuthProvider.grok ||
                    !RegExp(r'grok-(?:stt|voice|tts)').hasMatch(id)))
              _modelFromRow(config, row),
        if (config.oauthProvider == OAuthProvider.chatgpt &&
            ids.add(codexImageModelId))
          _modelFromRow(config, {'id': codexImageModelId}),
      ];
    }, isCurrent: isCurrent);
  }

  _OAuthModelSpec _modelFromRow(
    ProviderConfig config,
    Map<String, dynamic> row,
  ) {
    final id = row['id'] as String;
    final resolved = ModelSpecResolver.instance.resolve(
      config,
      id,
      displayName:
          oauthString(row['display_name']) ?? oauthString(row['name']) ?? id,
    );
    var spec = resolved.override.applyTo(
      _oauthDiscoveredSpec(resolved.base, row),
      applyDisplayName: true,
    );
    if (_usesGrokComposerMetadata(config.oauthProvider, spec)) {
      spec = spec.copyWith(
        input: const [Modality.text],
        abilities: {...spec.abilities, ModelAbility.reasoning}.toList(),
        reasoning: _grokComposerReasoning.applyTo(spec.reasoning),
      );
    }
    return _OAuthModelSpec(row: row, base: spec);
  }

  /// Like OMP's versioned Codex cache, refresh each account after a client
  /// version change. Keep its saved models usable if discovery is unavailable.
  Future<void> syncOutdatedModels(SettingsProvider settings) async {
    await settings.loaded;
    if (!identical(settings, _settings) ||
        !settings.providerConfigs.values.any(_canSyncCodexModels)) {
      return;
    }
    settings.applyGlobalProxyOverridesIfNeeded();
    await _currentCodexVersion();
    if (!identical(settings, _settings)) return;
    await Future.wait([
      _syncOutdatedCodexAccounts(settings),
      _checkForCodexUpdate(settings),
    ]);
  }

  static bool _canSyncCodexModels(ProviderConfig config) =>
      config.enabled &&
      config.oauthProvider == OAuthProvider.chatgpt &&
      config.oauthCredentials?.requiresLogin == false;

  static bool _hasCurrentCodexModels(ProviderConfig config, String version) =>
      config.oauthModelsClientVersion == version &&
      config.models.contains(codexImageModelId) &&
      config.models.every((model) {
        final override = config.modelOverrides[model];
        return override is Map &&
            override['oauthServiceTierSessionId'] ==
                config.oauthCredentials?.sessionId;
      });

  Future<void> _checkForCodexUpdate(SettingsProvider settings) async {
    final before = _effectiveCodexVersion;
    await _codexVersion?.refresh();
    if (before != _effectiveCodexVersion) {
      await _syncOutdatedCodexAccounts(settings);
    }
  }

  Future<void> _syncOutdatedCodexAccounts(SettingsProvider settings) async {
    for (final id in settings.providerConfigs.keys.toList()) {
      if (!identical(settings, _settings)) return;
      final config = _current(id);
      if (config == null ||
          !_canSyncCodexModels(config) ||
          _hasCurrentCodexModels(config, _effectiveCodexVersion.version)) {
        continue;
      }
      try {
        await _syncAccountModels(settings, config);
      } catch (_) {
        // Leave the version unchanged so the next launch or manual sync retries.
      }
    }
  }

  Future<void> syncModels(
    String id, {
    bool checkLatestCodexVersion = false,
  }) async {
    final settings = _settings;
    final before = _current(id);
    if (settings == null || before == null) return;
    if (before.oauthProvider != OAuthProvider.chatgpt) {
      return _syncAccountModels(settings, before);
    }
    await _currentCodexVersion();
    if (!identical(settings, _settings)) return;
    settings.applyGlobalProxyOverridesIfNeeded();
    final initialVersion = _effectiveCodexVersion;
    if (checkLatestCodexVersion) {
      await _codexVersion?.refresh(force: true);
    }
    if (!identical(settings, _settings)) return;
    final versionChanged = initialVersion != _effectiveCodexVersion;
    final sync = _syncAccountModels(
      settings,
      before,
      allowFallback: !checkLatestCodexVersion,
    );
    if (versionChanged) {
      unawaited(_syncOutdatedCodexAccounts(settings));
    } else if (!checkLatestCodexVersion && _codexVersion != null) {
      unawaited(_checkForCodexUpdate(settings));
    }
    return sync;
  }

  Future<void> _syncAccountModels(
    SettingsProvider settings,
    ProviderConfig before, {
    bool allowFallback = true,
  }) async {
    if (before.oauthProvider != OAuthProvider.chatgpt) {
      return _syncAccountModelsForVersion(settings, before, null);
    }
    Future<void>? previousSync;
    while (identical(settings, _settings)) {
      final version = _effectiveCodexVersion;
      final changed = Completer<void>();
      void onVersionChanged() {
        if (!changed.isCompleted) changed.complete();
      }

      final fallback = previousSync;
      final sync = _syncAccountModelsForVersion(settings, before, version);
      previousSync = sync;
      _codexVersion?.addListener(onVersionChanged);
      try {
        await Future.any([sync, changed.future]);
      } catch (_) {
        if (!identical(settings, _settings)) rethrow;
        if (version == _effectiveCodexVersion) {
          final needsCatalog =
              before.oauthModelsClientVersion == null || before.models.isEmpty;
          if (!allowFallback || !needsCatalog || fallback == null) {
            rethrow;
          }
          try {
            await Future.any([fallback, changed.future]);
          } catch (_) {}
          if (version == _effectiveCodexVersion) {
            if (!identical(settings, _settings)) rethrow;
            final current = _requireCurrentSession(before);
            if (current.oauthModelsClientVersion == null ||
                current.models.isEmpty) {
              rethrow;
            }
          }
        }
      } finally {
        _codexVersion?.removeListener(onVersionChanged);
      }
      if (version == _effectiveCodexVersion ||
          !identical(settings, _settings)) {
        return;
      }
      before = _requireCurrentSession(before);
    }
  }

  Future<void> _syncAccountModelsForVersion(
    SettingsProvider settings,
    ProviderConfig before,
    CodexVersionSnapshot? codexVersion,
  ) async {
    if (!identical(settings, _settings)) return;
    final key = (settings, _sessionKey(before), codexVersion);
    final pending = _modelSyncs[key];
    if (pending != null) return pending;
    final request = _syncModelsForVersion(settings, before, codexVersion);
    _modelSyncs[key] = request;
    try {
      await request;
    } finally {
      _modelSyncs.remove(key);
    }
  }

  Future<void> _syncModelsForVersion(
    SettingsProvider settings,
    ProviderConfig before,
    CodexVersionSnapshot? codexVersion,
  ) async {
    final list = await _models(
      before,
      codexVersion?.version,
      isCurrent: codexVersion == null
          ? null
          : () =>
                identical(settings, _settings) &&
                codexVersion == _effectiveCodexVersion,
    );
    final current = _current(before.id);
    if (!identical(settings, _settings) ||
        current == null ||
        current.oauthProvider != before.oauthProvider ||
        current.oauthCredentials?.sessionId !=
            before.oauthCredentials?.sessionId) {
      return;
    }
    if (codexVersion != null &&
        codexVersion != _effectiveCodexVersion &&
        (current.oauthModelsClientVersion != null || list.isEmpty)) {
      return;
    }
    final overrides = Map<String, dynamic>.from(current.modelOverrides);
    final provider = current.oauthProvider!;
    for (final model in list) {
      final row = model is _OAuthModelSpec
          ? model.row
          : const <String, dynamic>{};
      // Model edits can land while discovery is in flight.
      final discovered = model is _OAuthModelSpec
          ? _modelFromRow(current, row)
          : model;
      final composer = _usesGrokComposerMetadata(provider, discovered);
      overrides[model.id] = mergeOAuthModelOverride(
        existing: overrides[model.id],
        model: discovered,
        reasoning: composer
            ? _grokComposerReasoning
            : oauthDiscoveredReasoning(provider, row),
        refreshCapabilities: composer,
        extra: {
          if (provider == OAuthProvider.chatgpt) ...{
            'oauthServiceTiers': [
              if (row['service_tiers'] is List)
                for (final tier
                    in (row['service_tiers'] as List).whereType<Map>())
                  if (tier['id'] is String) tier['id'] as String,
            ],
            'oauthServiceTierSessionId': current.oauthCredentials!.sessionId,
          },
          if (provider == OAuthProvider.kimi)
            'oauthProtocol': kimiOAuthProtocol(row),
        },
      );
    }
    await settings.setProviderConfig(
      current.id,
      current.copyWith(
        models: list.map((e) => e.id).toList(),
        modelOverrides: overrides,
        oauthModelsSyncedAt: DateTime.now(),
        oauthModelsClientVersion: codexVersion?.version,
      ),
    );
  }

  Future<ProviderUsageSnapshot> fetchUsage(ProviderConfig original) async {
    final key = _sessionKey(original);
    if (_usageRequests[key] case final pending?) return pending;
    final request = _authenticated(
      original,
      (wire, config) async => ProviderOAuthAdapter.forProvider(
        config.oauthProvider!,
        codexVersion: config.oauthProvider == OAuthProvider.chatgpt
            ? await _currentCodexVersion()
            : null,
      ).usage(wire, config.oauthCredentials!),
      usageProbe: true,
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

  http.Client authenticatedClient(
    http.Client client,
    ProviderConfig config, {
    CodexTurnState? codexTurnState,
    CancelToken? cancelToken,
  }) => config.isOAuth
      ? _ProviderOAuthHttpClient(
          client,
          config,
          this,
          codexTurnState,
          cancelToken,
        )
      : client;
}

/// A failed proactive exchange defers the next attempt for this bearer. A
/// resource rejection leaves no retry time: the bearer must be replaced.
class _ClaudeRenewal {
  const _ClaudeRenewal(this.accessToken, {this.retryAt});
  final String accessToken;
  final DateTime? retryAt;

  bool rejects(ProviderOAuthCredentials credentials) =>
      accessToken == credentials.accessToken && retryAt == null;

  bool canDefer(ProviderOAuthCredentials credentials, DateTime now) =>
      accessToken == credentials.accessToken &&
      retryAt?.isAfter(now) == true &&
      credentials.expiresAt.isAfter(now);
}

bool _claudeBodyRevokesBearer(String body) {
  try {
    return ClaudeOAuthAdapter.isRevokedBearer(jsonDecode(body));
  } on FormatException {
    return ClaudeOAuthAdapter.isRevokedBearer(body);
  }
}

const _deletedOAuthThinkingKeys = {
  'oauthThinkingMode',
  'oauthThinkingRequired',
  'oauthThinkingEfforts',
  'oauthThinkingDefaultEffort',
};

String kimiOAuthProtocol(Map<String, dynamic> row) {
  return row['protocol'] == null && row.containsKey('protocol')
      ? 'openai'
      : 'anthropic';
}

/// True/false when the catalog row states reasoning support; null if omitted.
bool? oauthRowReasoningSupport(Map<String, dynamic> row) {
  switch (row['supports_thinking_type']) {
    case 'only':
    case 'both':
      return true;
    case 'no':
      return false;
  }
  if (row.containsKey('supports_reasoning')) {
    return row['supports_reasoning'] == true;
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

bool _usesGrokComposerMetadata(OAuthProvider? provider, ModelSpec model) =>
    provider == OAuthProvider.grok &&
    model.id == grokComposerFastModelId &&
    model.upstreamId == grokComposerFastModelId;

const _grokComposerReasoning = ReasoningSpecOverride(
  dialect: ReasoningDialect.openaiResponsesReasoning,
  levels: [
    ReasoningLevel.minimal,
    ReasoningLevel.low,
    ReasoningLevel.medium,
    ReasoningLevel.high,
    ReasoningLevel.xhigh,
  ],
  canDisable: false,
);

/// Maps an OAuth catalog row onto [ReasoningSpecOverride].
ReasoningSpecOverride? oauthDiscoveredReasoning(
  OAuthProvider provider,
  Map<String, dynamic> row,
) {
  if (oauthRowReasoningSupport(row) != true) return null;
  final required = row['supports_thinking_type'] == 'only';
  switch (provider) {
    case OAuthProvider.kimi:
      final levels = oauthMap(row['think_efforts'])['support'] == true
          ? _oauthLevelNames(row)
          : <String>[];
      final defaultLevel = _oauthDefaultLevel(row);
      return ReasoningSpecOverride.fromJson({
        'dialect': kimiOAuthProtocol(row) == 'anthropic'
            ? (levels.isNotEmpty
                  ? ReasoningDialect.anthropicAdaptiveEffort.name
                  : ReasoningDialect.anthropicBudget.name)
            : ReasoningDialect.kimiThinking.name,
        'levels': levels,
        'canDisable': !required,
        'defaultLevel': levels.contains(defaultLevel) ? defaultLevel : 'auto',
        // A fresh roster must retire controls saved by an older discovery.
        'budgets': <String, int>{},
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
  bool refreshCapabilities = false,
  Map<String, dynamic> extra = const {},
}) {
  final current = existing is Map
      ? ModelSpecOverride.fromJson(existing)
      : const ModelSpecOverride();
  final nextExtra = <String, dynamic>{...current.extra, ...extra};
  nextExtra.removeWhere((key, _) => _deletedOAuthThinkingKeys.contains(key));
  return current
      .copyWith(
        displayName: current.displayName ?? model.displayName,
        type: current.type ?? model.type,
        input: refreshCapabilities ? model.input : current.input ?? model.input,
        output: current.output ?? model.output,
        abilities: refreshCapabilities
            ? model.abilities
            : current.abilities ?? model.abilities,
        reasoning: _mergeReasoningOverride(current.reasoning, reasoning),
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

ModelSpec _oauthDiscoveredSpec(ModelSpec resolved, Map<String, dynamic> row) {
  final inputModalities = row['input_modalities'];
  final imageIn =
      row['supports_image_in'] == true ||
      inputModalities is List && inputModalities.contains('image');
  final support = oauthRowReasoningSupport(row);
  return resolved.copyWith(
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
bool _isGrokMediaPath(String method, String path) => switch (method) {
  'POST' => const {
    '/v1/images/generations',
    '/v1/images/edits',
    '/v1/videos/generations',
  }.contains(path),
  'GET' => RegExp(r'^/v1/(?:images|videos)/[a-zA-Z0-9_-]+$').hasMatch(path),
  _ => false,
};

class _ProviderOAuthHttpClient extends http.BaseClient {
  _ProviderOAuthHttpClient(
    this.inner,
    this.config,
    this.service,
    CodexTurnState? codexTurnState,
    this._cancelToken,
  ) : _sessionId = config.oauthCredentials?.sessionId,
      _codexTurnState = codexTurnState ?? CodexTurnState();
  final http.Client inner;
  ProviderConfig config;
  final ProviderOAuthService service;
  final CancelToken? _cancelToken;
  final String? _sessionId;
  final CodexTurnState _codexTurnState;
  final String _claudeConversationId = const Uuid().v4();

  void _checkSession() {
    final cancellation = _cancelToken?.cancelError;
    if (cancellation != null) throw cancellation;
    if (config.oauthCredentials?.sessionId != _sessionId) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.cancelled,
        providerId: config.id,
      );
    }
    service._requireCurrentSession(config);
  }

  Future<void> _resolve({ProviderConfig? rejected}) async {
    _checkSession();
    final pending = rejected == null
        ? service.resolve(config)
        : service._recoverBearer(rejected);
    final cancellation = _cancelToken;
    // Refresh is shared with other requests. Stop only this caller's wait;
    // token rotation must still finish and be persisted for the other callers.
    config = await (cancellation == null
        ? pending
        : Future.any<ProviderConfig>([
            pending,
            cancellation.whenCancel.then((error) => throw error),
          ]));
    _checkSession();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _resolve();
    final base = Uri.parse(config.oauthProvider!.baseUrl);
    final grokMedia =
        config.oauthProvider == OAuthProvider.grok &&
        _isGrokMediaPath(request.method, request.url.path);
    final grokMediaOrigin =
        grokMedia &&
        request.url.origin == Uri.parse(grokMediaBaseUrl).origin &&
        request.url.userInfo.isEmpty;
    final regularOrigin =
        request.url.origin == base.origin &&
        request.url.path.startsWith('${base.path}/');
    if (!(regularOrigin || grokMediaOrigin) ||
        request is! http.Request &&
            config.oauthProvider != OAuthProvider.claude) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    final codexResponses =
        config.oauthProvider == OAuthProvider.chatgpt &&
        (request.url.path == '${base.path}/responses' ||
            request.url.path.startsWith('${base.path}/responses/'));
    final body = request is http.Request
        ? request.bodyBytes
        : await request.finalize().toBytes();
    final isClaude = config.oauthProvider == OAuthProvider.claude;
    final claudeMessages = isClaude && request.url.path.endsWith('/messages');
    final codexVersion = config.oauthProvider == OAuthProvider.chatgpt
        ? await service._currentCodexVersion()
        : null;
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
        codexVersion: codexVersion,
      ).headers(config.oauthCredentials!);
      final existingBeta = result.headers['anthropic-beta'];
      final existingContentType = result.headers['content-type'];
      for (final name in authHeaders.keys) {
        result.headers.remove(name);
      }
      result.headers.addAll(authHeaders);
      if (codexResponses) {
        _codexTurnState.apply(result.headers, config);
      }
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
      final rewriteBody =
          codexResponses ||
          claudeMessages ||
          config.oauthProvider == OAuthProvider.kimi &&
              request.url.path.endsWith('/messages') ||
          config.oauthProvider == OAuthProvider.grok && !grokMedia;
      if (request.method == 'POST' && rewriteBody) {
        final payload = (jsonDecode(utf8.decode(body)) as Map)
            .cast<String, dynamic>();
        if (codexResponses) {
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
        RequestImageContext.current?.validateBodyBytes(result.bodyBytes.length);
      }
      if (identical(result.bodyBytes, body)) {
        MediaHttpLog.copyDescription(request, result);
      }
      return result;
    }

    var refreshed = false;
    var retriedClaudeVersion = false;
    while (true) {
      final requestVersion = claudeCodeVersion;
      final requestConfig = config;
      http.StreamedResponse response;
      try {
        response = await inner.send(build());
      } on ProviderHttpException catch (error) {
        // Request logging may read a failed response before send returns.
        if (isClaude && error.statusCode == 401) {
          _checkSession();
          service._recordBearerRejection(requestConfig);
        }
        rethrow;
      }
      if (codexResponses &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        _codexTurnState.capture(response.headers, requestConfig);
      }
      var rejected = response.statusCode == 401;
      final checkVersion =
          claudeMessages &&
          request.method == 'POST' &&
          response.statusCode == 400 &&
          !retriedClaudeVersion;
      if (checkVersion || isClaude && response.statusCode == 403) {
        final bytes = await response.stream.toBytes();
        final text = utf8.decode(bytes, allowMalformed: true);
        _checkSession();
        if (checkVersion &&
            adoptRequiredClaudeCodeVersion(
              text,
              requestVersion: requestVersion,
            )) {
          retriedClaudeVersion = true;
          // Rebuild from the original body so version, billing and cch agree,
          // without duplicating system blocks or tool prefixes.
          continue;
        }
        rejected = response.statusCode == 403 && _claudeBodyRevokesBearer(text);
        response = http.StreamedResponse(
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
      if (!rejected) return response;
      try {
        _checkSession();
        service._recordBearerRejection(requestConfig);
      } catch (_) {
        // The caller cannot consume this response after its session ends.
        await response.stream.listen(null).cancel();
        rethrow;
      }
      if (refreshed && isClaude) return response;
      await response.stream.drain<void>();
      _checkSession();
      if (refreshed) {
        await service.markLoginRequired(requestConfig);
        throw ProviderOAuthException(
          ProviderOAuthFailure.loginRequired,
          providerId: requestConfig.id,
          statusCode: 401,
        );
      }
      await _resolve(rejected: requestConfig);
      refreshed = true;
    }
  }

  @override
  void close() => inner.close();
}
