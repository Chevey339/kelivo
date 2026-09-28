import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../models/provider_oauth.dart';
import '../../models/provider_plugin.dart';
import '../../models/provider_plugin_session.dart';
import '../../providers/settings_provider.dart';
import '../auth/oauth_cancellation.dart';
import '../network/dio_http_client.dart';
import 'plugin_oauth_client.dart';

abstract interface class ProviderPluginStore {
  ProviderConfig? read(String id);
  Future<void> save(ProviderConfig config, {bool prepend = false});
  Future<void> remove(String id);
}

class _SettingsPluginStore implements ProviderPluginStore {
  _SettingsPluginStore(this.settings);

  final SettingsProvider settings;

  @override
  ProviderConfig? read(String id) => settings.providerConfigs[id];

  @override
  Future<void> save(ProviderConfig config, {bool prepend = false}) async {
    await settings.setProviderConfig(config.id, config);
    if (prepend && settings.providerConfigs.containsKey(config.id)) {
      await settings.setProvidersOrder([
        config.id,
        ...settings.providersOrder.where((id) => id != config.id),
      ]);
    }
  }

  @override
  Future<void> remove(String id) => settings.removeProviderConfig(id);
}

/// Coordinates account-bound credentials and rejects stale asynchronous work.
class ProviderPluginService {
  factory ProviderPluginService({
    ProviderPluginStore? store,
    http.Client Function(ProviderConfig)? clientFactory,
    PluginCallbackFactory? callbackFactory,
    DateTime Function()? clock,
  }) => ProviderPluginService._(
    store,
    clientFactory ?? _clientFor,
    callbackFactory,
    clock ?? DateTime.now,
  );

  ProviderPluginService._(
    this._store,
    this._clientFactory,
    this._callbackFactory,
    this._clock,
  );

  static final instance = ProviderPluginService();

  ProviderPluginStore? _store;
  final http.Client Function(ProviderConfig) _clientFactory;
  final PluginCallbackFactory? _callbackFactory;
  final DateTime Function() _clock;

  int _generation = 0;
  OAuthCancellation? _login;
  String? _loginId;
  final _clients = <http.Client>{};
  final _refreshes = <String, Future<ProviderConfig>>{};

  void bind(SettingsProvider settings) {
    final store = _store;
    if (store is _SettingsPluginStore && identical(store.settings, settings)) {
      return;
    }
    _reset();
    _store = _SettingsPluginStore(settings);
  }

  void unbind(SettingsProvider settings) {
    final store = _store;
    if (store is _SettingsPluginStore && identical(store.settings, settings)) {
      _reset();
      _store = null;
    }
  }

  void _reset() {
    _generation++;
    _login?.cancel();
    _login = null;
    _loginId = null;
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
    _refreshes.clear();
  }

  static http.Client _clientFor(ProviderConfig config) {
    final host = config.proxyHost?.trim() ?? '';
    final port = int.tryParse(config.proxyPort ?? '');

    // Bypass providerHttpClient: token requests use the authorization server,
    // not the API origin. Disable request logging for secrets and PKCE values.
    return DioHttpClient(
      logRequests: false,
      timeout: PluginOAuthClient.requestTimeout,
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

  ProviderPluginStore get _requiredStore =>
      _store ??
      (throw const ProviderOAuthException(ProviderOAuthFailure.cancelled));

  static ProviderKind kindFor(ProviderPluginManifest manifest) =>
      switch (manifest.protocol) {
        'anthropic' => ProviderKind.claude,
        'gemini' => ProviderKind.google,
        _ => ProviderKind.openai,
      };

  Future<ProviderConfig> install(ProviderPluginManifest manifest) async {
    final store = _requiredStore;
    final generation = _generation;
    final config = ProviderConfig(
      id: 'plugin_${const Uuid().v4()}',
      name: manifest.name,
      enabled: true,
      apiKey: '',
      baseUrl: manifest.baseUrl.toString(),
      providerType: kindFor(manifest),
      useResponseApi: manifest.protocol == 'openai-responses',
      chatPath: '/chat/completions',
      models: manifest.models,
      providerPlugin: manifest,
      multiKeyEnabled: false,
      balanceEnabled: false,
    );
    await store.save(config, prepend: true);
    return _current(config, store, generation);
  }

  /// Re-imports create independent instances/accounts. Replacing an existing
  /// manifest in-place is deliberately not automatic: it changes trust.
  Future<void> uninstall(String id) async {
    final store = _requiredStore;
    if (store.read(id)?.providerPlugin == null) return;
    if (_loginId == id) _login?.cancel();
    await store.remove(id);
  }

  Future<ProviderConfig> login(
    String id,
    OAuthCancellation cancellation, {
    void Function(Uri)? onAuthorization,
  }) async {
    if (_login != null) {
      throw const ProviderOAuthException(ProviderOAuthFailure.denied);
    }

    final store = _requiredStore;
    final generation = _generation;
    final original = store.read(id);
    if (original == null || original.providerPlugin?.oauth == null) {
      throw const ProviderOAuthException(ProviderOAuthFailure.cancelled);
    }

    _current(original, store, generation);
    cancellation.check();

    final client = _clientFactory(original);
    _login = cancellation;
    _loginId = id;
    _clients.add(client);
    var closed = false;

    void close() {
      if (!closed) {
        closed = true;
        _clients.remove(client);
        client.close();
      }
    }

    unawaited(cancellation.whenCancelled.then((_) => close()));

    try {
      final credentials =
          await PluginOAuthClient(
            client: client,
            callbackFactory: _callbackFactory,
            clock: _clock,
          ).login(
            original.providerPlugin!.oauth!,
            cancellation,
            onAuthorization: onAuthorization,
          );
      cancellation.check();

      final current = _current(original, store, generation);
      final saved = current.copyWith(
        apiKey: '',
        providerPluginSession: ProviderPluginSession(
          manifestFingerprint: current.providerPlugin!.fingerprint,
          credentials: credentials,
        ),
      );
      await store.save(saved);
      cancellation.check();
      return _current(saved, store, generation);
    } finally {
      close();
      if (identical(_login, cancellation)) {
        _login = null;
        _loginId = null;
      }
    }
  }

  Future<void> logout(String id) async {
    final store = _requiredStore;
    final config = store.read(id);
    if (config?.providerPlugin == null) return;
    if (_loginId == id) _login?.cancel();

    // setProviderConfig updates memory before its first await; an in-flight
    // refresh consequently cannot resurrect this cleared session.
    await store.save(config!.copyWith(providerPluginSession: null, apiKey: ''));
  }

  ProviderConfig _current(
    ProviderConfig original,
    ProviderPluginStore store,
    int generation,
  ) {
    final current = store.read(original.id);
    if (!identical(store, _store) ||
        generation != _generation ||
        current == null ||
        !current.enabled ||
        current.providerPlugin == null ||
        original.providerPlugin == null ||
        current.providerPlugin!.fingerprint !=
            original.providerPlugin!.fingerprint ||
        current.providerPluginSession?.credentials.sessionId !=
            original.providerPluginSession?.credentials.sessionId) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.cancelled,
        providerId: original.id,
      );
    }

    final manifest = current.providerPlugin!;
    if (current.oauthProvider != null ||
        current.vertexAI == true ||
        current.baseUrl != manifest.baseUrl.toString() ||
        current.providerType != kindFor(manifest) ||
        (current.useResponseApi == true) !=
            (manifest.protocol == 'openai-responses')) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.requestRejected,
        providerId: original.id,
        code: 'plugin_configuration_changed',
      );
    }
    return current;
  }

  Future<ProviderConfig> resolve(
    ProviderConfig original, {
    String? rejectedAccessToken,
  }) async {
    final store = _requiredStore;
    final generation = _generation;
    final current = _current(original, store, generation);

    if (current.providerPlugin!.oauth == null) return current;

    final session = current.providerPluginSession;
    if (session == null ||
        session.credentials.requiresLogin ||
        session.manifestFingerprint != current.providerPlugin!.fingerprint) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.loginRequired,
        providerId: original.id,
      );
    }

    final credentials = session.credentials;
    final force =
        rejectedAccessToken != null &&
        credentials.accessToken == rejectedAccessToken;
    if (!force &&
        !credentials.shouldRefresh(
          _clock(),
          leeway: const Duration(seconds: 5),
        )) {
      return current;
    }

    final key = '$generation:${current.id}:${credentials.sessionId}';
    final pending = _refreshes[key];
    if (pending != null) return pending;

    final request = _refresh(current, store, generation);
    _refreshes[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_refreshes[key], request)) {
        _refreshes.remove(key);
      }
    }
  }

  Future<ProviderConfig> _refresh(
    ProviderConfig original,
    ProviderPluginStore store,
    int generation,
  ) async {
    final client = _clientFactory(original);
    _clients.add(client);
    try {
      final credentials = await PluginOAuthClient(client: client, clock: _clock)
          .refresh(
            original.providerPlugin!.oauth!,
            original.providerPluginSession!.credentials,
          );
      final current = _current(original, store, generation);
      await store.save(
        current.copyWith(
          providerPluginSession: ProviderPluginSession(
            manifestFingerprint: current.providerPlugin!.fingerprint,
            credentials: credentials,
          ),
        ),
      );
      return _current(original, store, generation);
    } on ProviderOAuthException catch (error) {
      _current(original, store, generation);
      if (error.kind == ProviderOAuthFailure.loginRequired) {
        await markLoginRequired(original);
      }
      rethrow;
    } finally {
      _clients.remove(client);
      client.close();
    }
  }

  Future<void> markLoginRequired(ProviderConfig original) async {
    final store = _requiredStore;
    final current = _current(original, store, _generation);
    final previous = original.providerPluginSession;
    final session = current.providerPluginSession;
    if (previous == null ||
        session == null ||
        session.credentials.accessToken != previous.credentials.accessToken) {
      return;
    }

    await store.save(
      current.copyWith(
        providerPluginSession: ProviderPluginSession(
          manifestFingerprint: session.manifestFingerprint,
          credentials: session.credentials.copyWith(requiresLogin: true),
        ),
      ),
    );
  }
}
