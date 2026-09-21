import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../auth/oauth_callback.dart';
import '../auth/oauth_pkce.dart';
import 'mcp_oauth_http_client.dart';

enum McpOAuthFailureKind { authorizationRequired, transient, invalidResponse }

enum McpOAuthClientRegistrationSource { preRegistered, cimd, dcr }

final class McpOAuthException implements Exception {
  const McpOAuthException(
    this.message, {
    this.kind = McpOAuthFailureKind.invalidResponse,
    this.statusCode,
    this.oauthError,
  });

  final String message;
  final McpOAuthFailureKind kind;
  final int? statusCode;
  final String? oauthError;

  bool get requiresAuthorization =>
      kind == McpOAuthFailureKind.authorizationRequired;
  bool get isTransient => kind == McpOAuthFailureKind.transient;

  @override
  String toString() => 'MCP OAuth: $message';
}

final class McpOAuthClientRegistration {
  const McpOAuthClientRegistration({
    required this.clientId,
    this.clientSecret,
    this.tokenEndpointAuthMethod = 'none',
    this.authorizationServer,
    this.redirectUri,
    this.registrationSource = McpOAuthClientRegistrationSource.preRegistered,
  });

  final String clientId;
  final String? clientSecret;
  final String tokenEndpointAuthMethod;
  final String? authorizationServer;
  final String? redirectUri;
  final McpOAuthClientRegistrationSource registrationSource;

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    if (clientSecret != null) 'clientSecret': clientSecret,
    'tokenEndpointAuthMethod': tokenEndpointAuthMethod,
    if (authorizationServer != null) 'authorizationServer': authorizationServer,
    if (redirectUri != null) 'redirectUri': redirectUri,
    'registrationSource': registrationSource.name,
  };

  static McpOAuthClientRegistration? tryFromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final json = value.cast<String, dynamic>();
      final clientId = json['clientId'] as String;
      if (clientId.isEmpty) return null;
      return McpOAuthClientRegistration(
        clientId: clientId,
        clientSecret: json['clientSecret'] as String?,
        tokenEndpointAuthMethod:
            json['tokenEndpointAuthMethod'] as String? ?? 'none',
        authorizationServer: json['authorizationServer'] as String?,
        redirectUri: json['redirectUri'] as String?,
        registrationSource: _registrationSource(
          json['registrationSource'],
          fallback: _looksLikeClientMetadataDocumentId(clientId)
              ? McpOAuthClientRegistrationSource.cimd
              : McpOAuthClientRegistrationSource.preRegistered,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

final class McpOAuthState {
  const McpOAuthState({
    required this.clientId,
    required this.authorizationServer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.resource,
    required this.accessToken,
    this.serverUrl,
    this.clientSecret,
    this.registrationEndpoint,
    this.scope,
    this.tokenEndpointAuthMethod = 'none',
    this.registrationSource = McpOAuthClientRegistrationSource.dcr,
    this.redirectUri,
    this.tokenType = 'Bearer',
    this.refreshToken,
    this.expiresAt,
  });

  final String clientId;
  final String? clientSecret;
  final String authorizationServer;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String? registrationEndpoint;
  final String? serverUrl;
  final String resource;
  final String? scope;
  final String tokenEndpointAuthMethod;
  final McpOAuthClientRegistrationSource registrationSource;
  final String? redirectUri;
  final String accessToken;
  final String tokenType;
  final String? refreshToken;
  final DateTime? expiresAt;

  String get authorizationHeader =>
      '${tokenType.toLowerCase() == 'bearer' ? 'Bearer' : tokenType} '
      '$accessToken';

  bool shouldRefresh({Duration leeway = const Duration(minutes: 1)}) =>
      expiresAt != null &&
      !DateTime.now().add(leeway).isBefore(expiresAt!) &&
      refreshToken?.isNotEmpty == true;

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    if (clientSecret != null) 'clientSecret': clientSecret,
    'authorizationServer': authorizationServer,
    'authorizationEndpoint': authorizationEndpoint,
    'tokenEndpoint': tokenEndpoint,
    if (registrationEndpoint != null)
      'registrationEndpoint': registrationEndpoint,
    if (serverUrl != null) 'serverUrl': serverUrl,
    'resource': resource,
    if (scope != null) 'scope': scope,
    'tokenEndpointAuthMethod': tokenEndpointAuthMethod,
    'registrationSource': registrationSource.name,
    if (redirectUri != null) 'redirectUri': redirectUri,
    'accessToken': accessToken,
    'tokenType': tokenType,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
  };

  static McpOAuthState? tryFromJson(
    Object? value, {
    McpOAuthClientRegistrationSource? registrationSourceFallback,
  }) {
    if (value is! Map) return null;
    try {
      final json = value.cast<String, dynamic>();
      final expiresAt = _asInt(json['expiresAt']);
      return McpOAuthState(
        clientId: json['clientId'] as String,
        clientSecret: json['clientSecret'] as String?,
        authorizationServer: json['authorizationServer'] as String,
        authorizationEndpoint: json['authorizationEndpoint'] as String,
        tokenEndpoint: json['tokenEndpoint'] as String,
        registrationEndpoint: json['registrationEndpoint'] as String?,
        serverUrl: json['serverUrl'] as String?,
        resource: json['resource'] as String,
        scope: json['scope'] as String?,
        tokenEndpointAuthMethod:
            json['tokenEndpointAuthMethod'] as String? ?? 'none',
        registrationSource: _registrationSource(
          json['registrationSource'],
          fallback:
              registrationSourceFallback ??
              (_looksLikeClientMetadataDocumentId(json['clientId'] as String)
                  ? McpOAuthClientRegistrationSource.cimd
                  : McpOAuthClientRegistrationSource.dcr),
        ),
        redirectUri: json['redirectUri'] as String?,
        accessToken: json['accessToken'] as String,
        tokenType: json['tokenType'] as String? ?? 'Bearer',
        refreshToken: json['refreshToken'] as String?,
        expiresAt: expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAt),
      );
    } catch (_) {
      return null;
    }
  }
}

final class McpOAuthDiscovery {
  const McpOAuthDiscovery({
    required this.authorizationServer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.resource,
    required this.scopes,
    required this.authorizationResponseIssParameterSupported,
    required this.clientIdMetadataDocumentSupported,
    this.registrationEndpoint,
  });

  final Uri authorizationServer;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri? registrationEndpoint;
  final Uri resource;
  final List<String> scopes;
  final bool authorizationResponseIssParameterSupported;
  final bool clientIdMetadataDocumentSupported;
}

final class McpOAuthService {
  McpOAuthService({
    http.Client? httpClient,
    OAuthCallbackFactory? callbackFactory,
    OAuthUrlLauncher? launchAuthorizationUrl,
    Duration requestTimeout = const Duration(seconds: 20),
    int maximumResponseBytes = 1024 * 1024,
  }) : _httpClient = httpClient ?? http.Client(),
       _discoveryHttpClient = httpClient ?? createMcpOAuthDiscoveryHttpClient(),
       _ownsHttpClients = httpClient == null,
       _validateDiscoveredHosts = httpClient == null,
       _callbackFactory = callbackFactory ?? openOAuthCallback,
       _launchAuthorizationUrl =
           launchAuthorizationUrl ?? _defaultLaunchAuthorizationUrl,
       _requestTimeout = requestTimeout > Duration.zero
           ? requestTimeout
           : const Duration(seconds: 20),
       _maximumResponseBytes = maximumResponseBytes > 0
           ? maximumResponseBytes
           : 1024 * 1024;

  static const _callbackTimeout = Duration(minutes: 5);

  final http.Client _httpClient;
  final http.Client _discoveryHttpClient;
  final bool _ownsHttpClients;
  final bool _validateDiscoveredHosts;
  final OAuthCallbackFactory _callbackFactory;
  final OAuthUrlLauncher _launchAuthorizationUrl;
  final Duration _requestTimeout;
  final int _maximumResponseBytes;
  final Map<String, Future<McpOAuthDiscovery>> _discoveryCache = {};
  final Map<String, Future<McpOAuthClientRegistration>>
  _dynamicRegistrationCache = {};
  final Map<String, Future<void>> _publicTargetValidations = {};

  Future<void> prefetchAuthorization(
    String serverUrl, {
    Map<String, String> headers = const {},
    List<String> wwwAuthenticate = const [],
  }) async {
    try {
      await _cachedDiscovery(
        serverUrl,
        headers: headers,
        wwwAuthenticate: wwwAuthenticate,
      );
    } catch (_) {
      // Authorization remains available so a foreground attempt can report
      // the current discovery error instead of hiding the login action.
    }
  }

  Future<bool> supportsOAuth(
    String serverUrl, {
    Map<String, String> headers = const {},
    List<String> wwwAuthenticate = const [],
  }) async {
    try {
      await _cachedDiscovery(
        serverUrl,
        headers: headers,
        wwwAuthenticate: wwwAuthenticate,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<McpOAuthDiscovery> discover(
    String serverUrl, {
    Map<String, String> headers = const {},
    List<String> wwwAuthenticate = const [],
  }) async {
    final server = _requireServerUri(serverUrl, label: 'MCP server URL');
    final deadline = DateTime.now().add(_requestTimeout);
    var challenges = List<String>.of(wwwAuthenticate);

    if (challenges.isEmpty) {
      try {
        final probe = await _get(
          server,
          headers: {
            ...headers,
            'Accept': 'application/json, text/event-stream',
          },
          operation: 'MCP OAuth probe',
          deadline: deadline,
        );
        if (probe.statusCode == 401) {
          final challenge = probe.headers['www-authenticate'];
          if (challenge != null && challenge.isNotEmpty) {
            challenges = [challenge];
          }
        }
      } catch (_) {
        // Standard protected-resource metadata remains available.
      }
    }

    final discoveryChallenge = _discoveryBearerChallenge(challenges);
    final hasExplicitMetadata =
        discoveryChallenge?.hasParameter('resource_metadata') == true;
    final challengedMetadataUrl = discoveryChallenge?.parameter(
      'resource_metadata',
    );
    if (hasExplicitMetadata &&
        (challengedMetadataUrl == null || challengedMetadataUrl.isEmpty)) {
      throw const McpOAuthException(
        'WWW-Authenticate resource_metadata parameter is invalid',
      );
    }
    final challengedScope = discoveryChallenge?.parameter('scope');
    final targetResource = server;
    final candidates = hasExplicitMetadata
        ? <_ProtectedResourceMetadataCandidate>[
            _ProtectedResourceMetadataCandidate(
              metadataUri: _requireProtectedResourceMetadataUri(
                server.resolve(challengedMetadataUrl!),
                localServer: _isLoopbackHost(server.host),
              ),
              expectedResource: targetResource,
            ),
          ]
        : _protectedResourceMetadataCandidates(server);

    Map<String, dynamic>? protectedResource;
    Uri? protectedResourceUri;
    McpOAuthException? transientFailure;
    var resourceMismatch = false;
    for (final candidate in _distinctMetadataCandidates(candidates)) {
      try {
        final response = await _get(
          candidate.metadataUri,
          headers: {
            ..._sameOrigin(server, candidate.metadataUri) ? headers : const {},
            'Accept': 'application/json',
          },
          operation: 'protected resource metadata request',
          deadline: deadline,
          discoveredTarget: !_sameOrigin(server, candidate.metadataUri),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) continue;
        final value = decoded.cast<String, dynamic>();
        if (value['resource'] != candidate.expectedResource.toString()) {
          resourceMismatch = true;
          continue;
        }
        final authorizationServers = value['authorization_servers'];
        if (authorizationServers is List &&
            authorizationServers.any((item) => item is String)) {
          protectedResource = value;
          protectedResourceUri = candidate.expectedResource;
          break;
        }
      } on McpOAuthException catch (error) {
        if (error.isTransient) transientFailure ??= error;
      } catch (_) {
        // Try the next standard discovery location.
      }
    }
    if (protectedResource == null || protectedResourceUri == null) {
      if (resourceMismatch) {
        throw const McpOAuthException(
          'protected resource metadata resource does not match the requested resource',
        );
      }
      if (transientFailure != null) throw transientFailure;
      throw const McpOAuthException(
        'protected resource metadata could not be discovered',
      );
    }

    final rawAuthorizationServers =
        protectedResource['authorization_servers'] as List;
    Map<String, dynamic>? authorizationMetadata;
    Uri? authorizationServer;
    transientFailure = null;
    var issuerMismatch = false;
    var foundAuthorizationServerWithoutPkce = false;
    for (final rawIssuer in rawAuthorizationServers.whereType<String>()) {
      Uri issuer;
      try {
        issuer = _requireAuthorizationServerUri(
          rawIssuer,
          label: 'authorization server',
        );
      } catch (_) {
        continue;
      }
      for (final candidate in _authorizationMetadataUris(issuer)) {
        try {
          final response = await _get(
            candidate,
            headers: const {'Accept': 'application/json'},
            operation: 'authorization server metadata request',
            deadline: deadline,
            discoveredTarget: true,
          );
          if (response.statusCode < 200 || response.statusCode >= 300) continue;
          final decoded = jsonDecode(response.body);
          if (decoded is! Map) continue;
          final value = decoded.cast<String, dynamic>();
          if (value['issuer'] != issuer.toString()) {
            issuerMismatch = true;
            continue;
          }
          if (value['authorization_endpoint'] is! String ||
              value['token_endpoint'] is! String) {
            continue;
          }
          if (!_stringList(
            value['code_challenge_methods_supported'],
          ).contains('S256')) {
            foundAuthorizationServerWithoutPkce = true;
            continue;
          }
          authorizationMetadata = value;
          authorizationServer = issuer;
          break;
        } on McpOAuthException catch (error) {
          if (error.isTransient) transientFailure ??= error;
        } catch (_) {
          // Try the next RFC 8414 / OIDC discovery location.
        }
      }
      if (authorizationMetadata != null) break;
    }
    if (authorizationMetadata == null || authorizationServer == null) {
      if (issuerMismatch) {
        throw const McpOAuthException(
          'authorization server metadata issuer is missing or does not match discovery',
        );
      }
      if (foundAuthorizationServerWithoutPkce) {
        throw const McpOAuthException(
          'authorization server does not advertise PKCE S256 support',
        );
      }
      if (transientFailure != null) throw transientFailure;
      throw const McpOAuthException(
        'authorization server metadata could not be discovered',
      );
    }

    final challengedScopes = _validScope(challengedScope)
        ? _splitScopes(challengedScope)
        : const <String>[];
    final resourceScopes = _stringList(protectedResource['scopes_supported']);
    final authorizationEndpoint = _requireDiscoveredHttpsUri(
      authorizationMetadata['authorization_endpoint'] as String,
      label: 'authorization endpoint',
    );
    final tokenEndpoint = _requireDiscoveredHttpsUri(
      authorizationMetadata['token_endpoint'] as String,
      label: 'token endpoint',
    );
    final registrationEndpoint =
        authorizationMetadata['registration_endpoint'] is String
        ? _requireDiscoveredHttpsUri(
            authorizationMetadata['registration_endpoint'] as String,
            label: 'registration endpoint',
          )
        : null;
    if (_validateDiscoveredHosts) {
      try {
        await Future.wait<void>([
          _validatePublicTarget(authorizationEndpoint),
          _validatePublicTarget(tokenEndpoint),
          if (registrationEndpoint != null)
            _validatePublicTarget(registrationEndpoint),
        ]);
      } catch (error) {
        throw McpOAuthException(
          'authorization server endpoint resolved to a non-public address: '
          '$error',
        );
      }
    }
    return McpOAuthDiscovery(
      authorizationServer: authorizationServer,
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      registrationEndpoint: registrationEndpoint,
      resource: protectedResourceUri,
      scopes: challengedScopes.isNotEmpty ? challengedScopes : resourceScopes,
      authorizationResponseIssParameterSupported:
          authorizationMetadata['authorization_response_iss_parameter_supported'] ==
          true,
      clientIdMetadataDocumentSupported:
          authorizationMetadata['client_id_metadata_document_supported'] ==
          true,
    );
  }

  Future<McpOAuthState> authorize({
    required String serverUrl,
    required String serverName,
    Map<String, String> headers = const {},
    List<String> wwwAuthenticate = const [],
    List<String> additionalScopes = const [],
    McpOAuthClientRegistration? clientRegistration,
  }) async {
    OAuthCallback? callback;
    final discoveryKey = _discoveryCacheKey(
      serverUrl,
      headers,
      wwwAuthenticate,
    );
    try {
      final discovery = await _cachedDiscovery(
        serverUrl,
        headers: headers,
        wwwAuthenticate: wwwAuthenticate,
      );
      callback = await _callbackFactory(discovery.authorizationServer);
      final scopes = _unionScopes(discovery.scopes, additionalScopes);
      var registration = clientRegistration;
      if (registration?.registrationSource ==
              McpOAuthClientRegistrationSource.dcr &&
          (registration?.authorizationServer !=
                  discovery.authorizationServer.toString() ||
              !_registrationRedirectUriMatches(
                registration?.redirectUri,
                callback.redirectUri,
              ))) {
        registration = null;
      }
      registration ??= await _cachedDynamicRegistration(
        discovery,
        redirectUri: callback.redirectUri,
        clientName: serverName.trim().isEmpty ? 'Kelivo' : serverName.trim(),
        scopes: scopes,
      );
      _validateClientRegistration(registration);
      if (registration.registrationSource !=
              McpOAuthClientRegistrationSource.cimd &&
          registration.authorizationServer != null &&
          registration.authorizationServer !=
              discovery.authorizationServer.toString()) {
        throw const McpOAuthException(
          'configured OAuth client belongs to a different authorization server',
        );
      }

      final verifier = oauthRandomString(32);
      final challenge = oauthPkceChallenge(verifier);
      final state = oauthRandomString(16);
      final authorizationUrl = discovery.authorizationEndpoint.replace(
        queryParameters: {
          ...discovery.authorizationEndpoint.queryParameters,
          'response_type': 'code',
          'client_id': registration.clientId,
          'redirect_uri': callback.redirectUri.toString(),
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
          'resource': discovery.resource.toString(),
          if (scopes.isNotEmpty) 'scope': scopes.join(' '),
        },
      );

      final callbackUri = await callback.authorize(
        authorizationUrl,
        _callbackTimeout,
        _launchAuthorizationUrl,
      );
      if (!_sameRedirectTarget(callbackUri, callback.redirectUri)) {
        throw const McpOAuthException(
          'authorization callback redirect URI mismatch',
        );
      }
      final returnedState = callbackUri.queryParameters['state'];
      if (returnedState != state) {
        throw const McpOAuthException('authorization callback state mismatch');
      }
      final callbackIssuer = callbackUri.queryParameters['iss'];
      if (discovery.authorizationResponseIssParameterSupported &&
          callbackIssuer == null) {
        throw const McpOAuthException(
          'authorization callback did not include the required issuer',
        );
      }
      if (callbackIssuer != null &&
          callbackIssuer != discovery.authorizationServer.toString()) {
        throw const McpOAuthException('authorization callback issuer mismatch');
      }
      final oauthError = callbackUri.queryParameters['error'];
      if (oauthError != null) {
        final description = callbackUri.queryParameters['error_description'];
        throw McpOAuthException(
          description == null ? oauthError : '$oauthError: $description',
          kind: McpOAuthFailureKind.authorizationRequired,
          oauthError: oauthError,
        );
      }
      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const McpOAuthException(
          'authorization callback did not include a code',
        );
      }

      Map<String, dynamic> token;
      try {
        token = await _requestToken(discovery.tokenEndpoint, {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': callback.redirectUri.toString(),
          'code_verifier': verifier,
          'resource': discovery.resource.toString(),
        }, registration: registration);
      } on McpOAuthException catch (error) {
        if (error.oauthError == 'invalid_client' &&
            registration.registrationSource ==
                McpOAuthClientRegistrationSource.dcr) {
          _dynamicRegistrationCache.remove(
            _dynamicRegistrationCacheKey(
              discovery,
              callback.redirectUri,
              scopes,
            ),
          );
        }
        rethrow;
      }
      final result = _stateFromToken(
        token,
        discovery: discovery,
        registration: registration,
        scopes: scopes,
        serverUrl: canonicalResource(
          _requireServerUri(serverUrl, label: 'MCP server URL'),
        ).toString(),
      );
      _discoveryCache.remove(discoveryKey);
      if (registration.registrationSource ==
          McpOAuthClientRegistrationSource.dcr) {
        _dynamicRegistrationCache.remove(
          _dynamicRegistrationCacheKey(discovery, callback.redirectUri, scopes),
        );
      }
      return result;
    } on TimeoutException {
      throw const McpOAuthException(
        'timed out waiting for authorization',
        kind: McpOAuthFailureKind.transient,
      );
    } on OAuthCallbackException catch (error) {
      throw McpOAuthException(
        error.message,
        kind: error.cancelled
            ? McpOAuthFailureKind.authorizationRequired
            : McpOAuthFailureKind.transient,
      );
    } finally {
      await callback?.close();
    }
  }

  Future<McpOAuthState> refresh(McpOAuthState state) async {
    final refreshToken = state.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const McpOAuthException(
        'no refresh token is available',
        kind: McpOAuthFailureKind.authorizationRequired,
      );
    }
    final registration = McpOAuthClientRegistration(
      clientId: state.clientId,
      clientSecret: state.clientSecret,
      tokenEndpointAuthMethod: state.tokenEndpointAuthMethod,
      authorizationServer: state.authorizationServer,
      redirectUri: state.redirectUri,
      registrationSource: state.registrationSource,
    );
    _validateClientRegistration(registration);
    final token = await _requestToken(
      _requireDiscoveredHttpsUri(state.tokenEndpoint, label: 'token endpoint'),
      {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'resource': state.resource,
        if (state.scope?.isNotEmpty == true) 'scope': state.scope!,
      },
      registration: registration,
    );
    return McpOAuthState(
      clientId: state.clientId,
      clientSecret: state.clientSecret,
      authorizationServer: state.authorizationServer,
      authorizationEndpoint: state.authorizationEndpoint,
      tokenEndpoint: state.tokenEndpoint,
      registrationEndpoint: state.registrationEndpoint,
      serverUrl: state.serverUrl,
      resource: state.resource,
      scope: token['scope'] is String ? token['scope'] as String : state.scope,
      tokenEndpointAuthMethod: state.tokenEndpointAuthMethod,
      registrationSource: state.registrationSource,
      redirectUri: state.redirectUri,
      accessToken: token['access_token'] as String,
      tokenType: token['token_type'] as String? ?? 'Bearer',
      refreshToken: token['refresh_token'] as String? ?? state.refreshToken,
      expiresAt: _expiresAt(token['expires_in']),
    );
  }

  Future<McpOAuthClientRegistration> _dynamicallyRegisterClient(
    McpOAuthDiscovery discovery, {
    required Uri redirectUri,
    required String clientName,
    required List<String> scopes,
  }) async {
    final endpoint = discovery.registrationEndpoint;
    if (endpoint == null) {
      final message = discovery.clientIdMetadataDocumentSupported
          ? 'configure a pre-registered client ID or Client ID Metadata Document URL'
          : 'configure a pre-registered client ID; the authorization server does not support dynamic client registration';
      throw McpOAuthException(message);
    }
    final response = await _postJson(endpoint, {
      'client_name': clientName,
      'client_uri': 'https://github.com/Chevey339/kelivo',
      'redirect_uris': [redirectUri.toString()],
      'grant_types': ['authorization_code', 'refresh_token'],
      'response_types': ['code'],
      'token_endpoint_auth_method': 'none',
      'application_type': 'native',
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
    }, operation: 'client registration');
    final registration = _decodeSuccessfulJson(
      response,
      operation: 'client registration',
    );
    final clientId = registration['client_id'];
    if (clientId is! String || clientId.isEmpty) {
      throw const McpOAuthException(
        'dynamic client registration did not return client_id',
      );
    }
    return McpOAuthClientRegistration(
      clientId: clientId,
      clientSecret: registration['client_secret'] as String?,
      tokenEndpointAuthMethod:
          registration['token_endpoint_auth_method'] as String? ?? 'none',
      authorizationServer: discovery.authorizationServer.toString(),
      redirectUri: redirectUri.toString(),
      registrationSource: McpOAuthClientRegistrationSource.dcr,
    );
  }

  Future<McpOAuthDiscovery> _cachedDiscovery(
    String serverUrl, {
    required Map<String, String> headers,
    required List<String> wwwAuthenticate,
  }) {
    final key = _discoveryCacheKey(serverUrl, headers, wwwAuthenticate);
    final existing = _discoveryCache[key];
    if (existing != null) return existing;

    final future = discover(
      serverUrl,
      headers: headers,
      wwwAuthenticate: wwwAuthenticate,
    );
    _discoveryCache[key] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          if (identical(_discoveryCache[key], future)) {
            _discoveryCache.remove(key);
          }
        },
      ),
    );
    return future;
  }

  Future<McpOAuthClientRegistration> _cachedDynamicRegistration(
    McpOAuthDiscovery discovery, {
    required Uri redirectUri,
    required String clientName,
    required List<String> scopes,
  }) {
    final key = _dynamicRegistrationCacheKey(discovery, redirectUri, scopes);
    final existing = _dynamicRegistrationCache[key];
    if (existing != null) return existing;

    final future = _dynamicallyRegisterClient(
      discovery,
      redirectUri: redirectUri,
      clientName: clientName,
      scopes: scopes,
    );
    _dynamicRegistrationCache[key] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          if (identical(_dynamicRegistrationCache[key], future)) {
            _dynamicRegistrationCache.remove(key);
          }
        },
      ),
    );
    return future;
  }

  static String _dynamicRegistrationCacheKey(
    McpOAuthDiscovery discovery,
    Uri redirectUri,
    List<String> scopes,
  ) {
    final normalizedScopes = scopes.toSet().toList()..sort();
    return '${discovery.authorizationServer}\n$redirectUri\n'
        '${normalizedScopes.join(' ')}';
  }

  static String _discoveryCacheKey(
    String serverUrl,
    Map<String, String> headers,
    List<String> wwwAuthenticate,
  ) {
    final sortedHeaders =
        headers.entries
            .map((entry) => [entry.key.toLowerCase(), entry.value])
            .toList()
          ..sort((left, right) {
            final keyOrder = left.first.compareTo(right.first);
            return keyOrder != 0 ? keyOrder : left.last.compareTo(right.last);
          });
    return jsonEncode([serverUrl, sortedHeaders, wwwAuthenticate]);
  }

  Future<Map<String, dynamic>> _requestToken(
    Uri endpoint,
    Map<String, String> form, {
    required McpOAuthClientRegistration registration,
  }) async {
    final body = Map<String, String>.of(form);
    final headers = <String, String>{'Accept': 'application/json'};
    switch (registration.tokenEndpointAuthMethod) {
      case 'none':
        body['client_id'] = registration.clientId;
      case 'client_secret_post':
        body['client_id'] = registration.clientId;
        body['client_secret'] = registration.clientSecret!;
      case 'client_secret_basic':
        final encodedId = Uri.encodeQueryComponent(registration.clientId);
        final encodedSecret = Uri.encodeQueryComponent(
          registration.clientSecret!,
        );
        headers['Authorization'] =
            'Basic ${base64Encode(utf8.encode('$encodedId:$encodedSecret'))}';
    }
    final response = await _postForm(
      endpoint,
      body,
      headers: headers,
      operation: 'token request',
    );
    final token = _decodeSuccessfulJson(response, operation: 'token request');
    if (token['access_token'] is! String ||
        (token['access_token'] as String).isEmpty) {
      throw const McpOAuthException(
        'token response did not include access_token',
      );
    }
    return token;
  }

  McpOAuthState _stateFromToken(
    Map<String, dynamic> token, {
    required McpOAuthDiscovery discovery,
    required McpOAuthClientRegistration registration,
    required List<String> scopes,
    required String serverUrl,
  }) => McpOAuthState(
    clientId: registration.clientId,
    clientSecret: registration.clientSecret,
    authorizationServer: discovery.authorizationServer.toString(),
    authorizationEndpoint: discovery.authorizationEndpoint.toString(),
    tokenEndpoint: discovery.tokenEndpoint.toString(),
    registrationEndpoint: discovery.registrationEndpoint?.toString(),
    serverUrl: serverUrl,
    resource: discovery.resource.toString(),
    scope: token['scope'] is String
        ? token['scope'] as String
        : (scopes.isEmpty ? null : scopes.join(' ')),
    tokenEndpointAuthMethod: registration.tokenEndpointAuthMethod,
    registrationSource: registration.registrationSource,
    redirectUri: registration.redirectUri,
    accessToken: token['access_token'] as String,
    tokenType: token['token_type'] as String? ?? 'Bearer',
    refreshToken: token['refresh_token'] as String?,
    expiresAt: _expiresAt(token['expires_in']),
  );

  void _validateClientRegistration(McpOAuthClientRegistration registration) {
    if (registration.clientId.isEmpty) {
      throw const McpOAuthException('OAuth client ID is empty');
    }
    if (registration.registrationSource ==
            McpOAuthClientRegistrationSource.dcr &&
        registration.authorizationServer == null) {
      throw const McpOAuthException(
        'dynamic OAuth client is not bound to an authorization server',
      );
    }
    switch (registration.tokenEndpointAuthMethod) {
      case 'none':
        return;
      case 'client_secret_basic':
      case 'client_secret_post':
        if (registration.clientSecret?.isNotEmpty == true) return;
        throw McpOAuthException(
          '${registration.tokenEndpointAuthMethod} requires a client secret',
        );
      default:
        throw McpOAuthException(
          'unsupported token endpoint authentication method: '
          '${registration.tokenEndpointAuthMethod}',
        );
    }
  }

  Map<String, dynamic> _decodeSuccessfulJson(
    http.Response response, {
    required String operation,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final oauthError = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : null;
      final description = decoded is Map
          ? decoded['error_description'] ?? oauthError
          : null;
      final kind = oauthError == 'invalid_grant'
          ? McpOAuthFailureKind.authorizationRequired
          : (response.statusCode == 408 ||
                response.statusCode == 429 ||
                response.statusCode >= 500)
          ? McpOAuthFailureKind.transient
          : McpOAuthFailureKind.invalidResponse;
      throw McpOAuthException(
        '$operation failed with HTTP ${response.statusCode}'
        '${description == null ? '' : ': $description'}',
        kind: kind,
        statusCode: response.statusCode,
        oauthError: oauthError,
      );
    }
    if (decoded is! Map) {
      throw McpOAuthException('$operation returned invalid JSON');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<http.Response> _get(
    Uri uri, {
    required Map<String, String> headers,
    required String operation,
    DateTime? deadline,
    bool discoveredTarget = false,
  }) => _send(
    'GET',
    uri,
    headers: headers,
    operation: operation,
    deadline: deadline,
    discoveredTarget: discoveredTarget,
  );

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    required String operation,
  }) => _send(
    'POST',
    uri,
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
    operation: operation,
    discoveredTarget: true,
  );

  Future<http.Response> _postForm(
    Uri uri,
    Map<String, String> body, {
    required Map<String, String> headers,
    required String operation,
  }) => _send(
    'POST',
    uri,
    headers: {...headers, 'Content-Type': 'application/x-www-form-urlencoded'},
    body: body.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&'),
    operation: operation,
    discoveredTarget: true,
    freshConnection: true,
  );

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
    required String operation,
    DateTime? deadline,
    bool discoveredTarget = false,
    bool freshConnection = false,
  }) async {
    if (discoveredTarget && _validateDiscoveredHosts) {
      try {
        await _validatePublicTarget(uri);
      } catch (error) {
        throw McpOAuthException(
          '$operation failed: $error',
          kind: McpOAuthFailureKind.transient,
        );
      }
    }
    final timeout = deadline?.difference(DateTime.now()) ?? _requestTimeout;
    if (timeout <= Duration.zero) {
      throw McpOAuthException(
        '$operation timed out',
        kind: McpOAuthFailureKind.transient,
      );
    }
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..maxRedirects = 0
          ..headers.addAll(headers);
    if (body != null) request.body = body;

    http.Client? oneShotClient;
    Future<http.Response> perform() async {
      final client = freshConnection && _ownsHttpClients
          ? oneShotClient = createMcpOAuthDiscoveryHttpClient()
          : (discoveredTarget ? _discoveryHttpClient : _httpClient);
      try {
        final streamed = await client.send(request);
        final bytes = <int>[];
        await for (final chunk in streamed.stream) {
          if (bytes.length + chunk.length > _maximumResponseBytes) {
            if (!abort.isCompleted) abort.complete();
            throw McpOAuthException(
              '$operation response exceeded $_maximumResponseBytes bytes',
            );
          }
          bytes.addAll(chunk);
        }
        return http.Response.bytes(
          bytes,
          streamed.statusCode,
          headers: streamed.headers,
          reasonPhrase: streamed.reasonPhrase,
          request: streamed.request,
        );
      } finally {
        oneShotClient?.close();
      }
    }

    try {
      return await perform().timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw McpOAuthException(
            '$operation timed out',
            kind: McpOAuthFailureKind.transient,
          );
        },
      );
    } on McpOAuthException {
      rethrow;
    } on http.RequestAbortedException catch (error) {
      throw McpOAuthException(
        '$operation was cancelled: $error',
        kind: McpOAuthFailureKind.transient,
      );
    } catch (error) {
      throw McpOAuthException(
        '$operation failed: $error',
        kind: McpOAuthFailureKind.transient,
      );
    }
  }

  Future<void> _validatePublicTarget(Uri uri) {
    final key =
        '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}:'
        '${_effectivePort(uri)}';
    final existing = _publicTargetValidations[key];
    if (existing != null) return existing;

    final future = validateMcpOAuthPublicUri(uri);
    _publicTargetValidations[key] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          if (identical(_publicTargetValidations[key], future)) {
            _publicTargetValidations.remove(key);
          }
        },
      ),
    );
    return future;
  }

  void dispose() {
    _discoveryCache.clear();
    _dynamicRegistrationCache.clear();
    _publicTargetValidations.clear();
    if (_ownsHttpClients) {
      _httpClient.close();
      _discoveryHttpClient.close();
    }
  }

  static Future<bool> _defaultLaunchAuthorizationUrl(Uri uri) => url_launcher
      .launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);

  static Uri canonicalResource(Uri server) {
    final path = server.path == '/' && !server.hasQuery ? '' : server.path;
    return Uri(
      scheme: server.scheme.toLowerCase(),
      host: server.host.toLowerCase(),
      port: server.hasPort ? server.port : null,
      path: path,
      query: server.hasQuery ? server.query : null,
    );
  }

  static String? bearerChallengeParameter(
    Iterable<String> challenges,
    String name,
  ) {
    for (final challenge in _bearerChallenges(challenges)) {
      final value = challenge.parameter(name);
      if (value != null) return value;
    }
    return null;
  }

  static bool bearerChallengeHasError(
    Iterable<String> challenges,
    String error,
  ) => _bearerChallenges(
    challenges,
  ).any((challenge) => challenge.parameter('error') == error);

  static String? bearerChallengeParameterForError(
    Iterable<String> challenges,
    String error,
    String name,
  ) {
    for (final challenge in _bearerChallenges(challenges)) {
      if (challenge.parameter('error') != error) continue;
      final value = challenge.parameter(name);
      if (name.toLowerCase() == 'scope' && !_validScope(value)) return null;
      return value;
    }
    return null;
  }

  static _BearerChallenge? _discoveryBearerChallenge(Iterable<String> headers) {
    final challenges = _bearerChallenges(headers);
    for (final challenge in challenges) {
      if (challenge.hasParameter('resource_metadata')) return challenge;
    }
    return challenges.isEmpty ? null : challenges.first;
  }

  static List<_BearerChallenge> _bearerChallenges(Iterable<String> headers) => [
    for (final header in headers) ...?_parseBearerChallenges(header),
  ];

  static Uri _requireServerUri(String raw, {required String label}) {
    final uri = _parseAbsoluteUri(raw, label: label);
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && !(scheme == 'http' && _isLoopbackHost(uri.host))) {
      throw McpOAuthException('$label must use HTTPS');
    }
    return uri;
  }

  static Uri _requireProtectedResourceMetadataUri(
    Uri uri, {
    required bool localServer,
  }) {
    if (localServer) {
      return _requireServerUri(
        uri.toString(),
        label: 'protected resource metadata URL',
      );
    }
    return _requireDiscoveredHttpsUri(
      uri.toString(),
      label: 'protected resource metadata URL',
    );
  }

  static Uri _requireAuthorizationServerUri(
    String raw, {
    required String label,
  }) {
    final uri = _requireDiscoveredHttpsUri(raw, label: label);
    if (uri.hasQuery) {
      throw McpOAuthException('$label must not contain a query');
    }
    return uri;
  }

  static Uri _requireDiscoveredHttpsUri(String raw, {required String label}) {
    final uri = _parseAbsoluteUri(raw, label: label);
    if (uri.scheme.toLowerCase() != 'https') {
      throw McpOAuthException('$label must use HTTPS');
    }
    if (_isNonPublicHost(uri.host)) {
      throw McpOAuthException('$label must not target a local or private host');
    }
    return uri;
  }

  static Uri _parseAbsoluteUri(String raw, {required String label}) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw McpOAuthException('$label is invalid');
    }
    if (uri.hasFragment) {
      throw McpOAuthException('$label must not contain a fragment');
    }
    if (uri.userInfo.isNotEmpty) {
      throw McpOAuthException('$label must not contain user information');
    }
    return uri;
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized.endsWith('.localhost') ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static bool _isNonPublicHost(String host) {
    final normalized = host.toLowerCase();
    if (_isLoopbackHost(normalized) ||
        normalized.endsWith('.local') ||
        normalized.endsWith('.internal')) {
      return true;
    }
    final ipv4 = normalized.split('.').map(int.tryParse).toList();
    if (ipv4.length == 4 && ipv4.every((part) => part != null)) {
      final a = ipv4[0]!;
      final b = ipv4[1]!;
      return a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 198 && (b == 18 || b == 19)) ||
          a >= 224;
    }
    if (normalized.contains(':')) {
      return normalized == '::' ||
          normalized.startsWith('fc') ||
          normalized.startsWith('fd') ||
          RegExp(r'^fe[89ab]', caseSensitive: false).hasMatch(normalized) ||
          normalized.startsWith('ff') ||
          normalized.startsWith('::ffff:127.') ||
          normalized.startsWith('::ffff:10.') ||
          normalized.startsWith('::ffff:192.168.');
    }
    return false;
  }

  static List<_ProtectedResourceMetadataCandidate>
  _protectedResourceMetadataCandidates(Uri server) {
    final targetResource = server;
    final path = server.path.isEmpty || server.path == '/'
        ? ''
        : server.path.startsWith('/')
        ? server.path
        : '/${server.path}';
    final metadataPath = '/.well-known/oauth-protected-resource$path';
    final rootMetadata = _originUri(
      server,
      '/.well-known/oauth-protected-resource',
    );
    final rootResource = canonicalResource(_originUri(server, ''));
    return [
      _ProtectedResourceMetadataCandidate(
        metadataUri: _originUri(
          server,
          metadataPath,
          query: server.hasQuery ? server.query : null,
        ),
        expectedResource: targetResource,
      ),
      _ProtectedResourceMetadataCandidate(
        metadataUri: rootMetadata,
        expectedResource: rootResource,
      ),
    ];
  }

  static List<Uri> _authorizationMetadataUris(Uri issuer) {
    final path = issuer.path.isEmpty || issuer.path == '/'
        ? ''
        : issuer.path.startsWith('/')
        ? issuer.path
        : '/${issuer.path}';
    return [
      if (path.isNotEmpty) ...[
        _originUri(issuer, '/.well-known/oauth-authorization-server$path'),
        _originUri(issuer, '/.well-known/openid-configuration$path'),
        _originUri(issuer, '$path/.well-known/openid-configuration'),
      ] else ...[
        _originUri(issuer, '/.well-known/oauth-authorization-server'),
        _originUri(issuer, '/.well-known/openid-configuration'),
      ],
    ];
  }

  static Uri _originUri(Uri source, String path, {String? query}) => Uri(
    scheme: source.scheme,
    host: source.host,
    port: source.hasPort ? source.port : null,
    path: path,
    query: query,
  );

  static Iterable<_ProtectedResourceMetadataCandidate>
  _distinctMetadataCandidates(
    Iterable<_ProtectedResourceMetadataCandidate> values,
  ) sync* {
    final seen = <String>{};
    for (final value in values) {
      final key = '${value.metadataUri}\n${value.expectedResource}';
      if (seen.add(key)) yield value;
    }
  }

  static List<String> _splitScopes(String? value) =>
      value == null || value.trim().isEmpty
      ? const []
      : value.trim().split(RegExp(r'\s+'));

  static bool _validScope(String? scope) =>
      scope != null &&
      scope
          .split(' ')
          .every(
            (token) =>
                token.isNotEmpty &&
                token.codeUnits.every(
                  (codeUnit) =>
                      codeUnit == 0x21 ||
                      (codeUnit >= 0x23 && codeUnit <= 0x5b) ||
                      (codeUnit >= 0x5d && codeUnit <= 0x7e),
                ),
          );

  static List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
      : const [];

  static List<String> _unionScopes(
    Iterable<String> first,
    Iterable<String> second,
  ) {
    final seen = <String>{};
    return [
      for (final scope in [...first, ...second])
        if (scope.isNotEmpty && seen.add(scope)) scope,
    ];
  }

  static bool _sameOrigin(Uri left, Uri right) =>
      left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
      left.host.toLowerCase() == right.host.toLowerCase() &&
      _effectivePort(left) == _effectivePort(right);

  static bool _sameRedirectTarget(Uri received, Uri expected) =>
      received.scheme == expected.scheme &&
      received.hasAuthority == expected.hasAuthority &&
      received.userInfo == expected.userInfo &&
      received.host == expected.host &&
      received.hasPort == expected.hasPort &&
      (!received.hasPort || received.port == expected.port) &&
      received.path == expected.path &&
      received.fragment == expected.fragment;

  static bool _registrationRedirectUriMatches(
    String? registeredRedirectUri,
    Uri currentRedirectUri,
  ) {
    if (registeredRedirectUri == currentRedirectUri.toString()) return true;
    final registered = Uri.tryParse(registeredRedirectUri ?? '');
    if (registered == null ||
        !_isLoopbackRedirect(registered) ||
        !_isLoopbackRedirect(currentRedirectUri)) {
      return false;
    }
    return registered.scheme == currentRedirectUri.scheme &&
        registered.hasAuthority == currentRedirectUri.hasAuthority &&
        registered.userInfo == currentRedirectUri.userInfo &&
        registered.host == currentRedirectUri.host &&
        registered.path == currentRedirectUri.path &&
        registered.query == currentRedirectUri.query &&
        registered.fragment == currentRedirectUri.fragment;
  }

  static bool _isLoopbackRedirect(Uri uri) =>
      uri.scheme == 'http' && (uri.host == '127.0.0.1' || uri.host == '::1');

  static int _effectivePort(Uri uri) => uri.hasPort
      ? uri.port
      : uri.scheme.toLowerCase() == 'https'
      ? 443
      : 80;

  static DateTime? _expiresAt(Object? expiresIn) {
    final seconds = _asInt(expiresIn);
    return seconds == null || seconds <= 0
        ? null
        : DateTime.now().add(Duration(seconds: seconds));
  }
}

final class _ProtectedResourceMetadataCandidate {
  const _ProtectedResourceMetadataCandidate({
    required this.metadataUri,
    required this.expectedResource,
  });

  final Uri metadataUri;
  final Uri expectedResource;
}

final class _BearerChallenge {
  final Map<String, _ChallengeParameter> _parameters = {};

  void addParameter(String name, String? value) {
    final key = name.toLowerCase();
    _parameters[key] = _parameters.containsKey(key)
        ? const _ChallengeParameter.invalid()
        : _ChallengeParameter(value);
  }

  bool hasParameter(String name) => _parameters.containsKey(name.toLowerCase());

  String? parameter(String name) => _parameters[name.toLowerCase()]?.value;
}

final class _ChallengeParameter {
  const _ChallengeParameter(this.value);

  const _ChallengeParameter.invalid() : value = null;

  final String? value;
}

typedef _AuthParameter = ({String name, String? value});
typedef _ChallengeStart = ({String scheme, _AuthParameter? parameter});

List<_BearerChallenge>? _parseBearerChallenges(String header) {
  final segments = _splitUnquotedSegments(header);
  if (segments == null) return null;
  final parsed = <_BearerChallenge>[];
  _BearerChallenge? bearer;

  for (final segment in segments) {
    final parameter = _parseAuthParameter(segment);
    if (parameter != null) {
      bearer?.addParameter(parameter.name, parameter.value);
      continue;
    }

    if (bearer != null) {
      parsed.add(bearer);
      bearer = null;
    }
    final start = _parseChallengeStart(segment);
    if (start == null) return null;
    if (start.scheme.toLowerCase() == 'bearer') {
      bearer = _BearerChallenge();
      final parameter = start.parameter;
      if (parameter != null) {
        bearer.addParameter(parameter.name, parameter.value);
      }
    }
  }

  if (bearer != null) parsed.add(bearer);
  return parsed;
}

_ChallengeStart? _parseChallengeStart(String value) {
  final segment = value.trim();
  if (segment.isEmpty) return null;
  final whitespace = RegExp(r'\s').firstMatch(segment)?.start;
  final scheme = whitespace == null
      ? segment
      : segment.substring(0, whitespace);
  if (!_isHttpToken(scheme)) return null;
  return (
    scheme: scheme,
    parameter: whitespace == null
        ? null
        : _parseAuthParameter(segment.substring(whitespace)),
  );
}

_AuthParameter? _parseAuthParameter(String value) {
  final separator = value.indexOf('=');
  if (separator < 0) return null;
  final name = value.substring(0, separator).trim();
  if (!_isHttpToken(name)) return null;
  return (
    name: name,
    value: _parseAuthParameterValue(value.substring(separator + 1).trim()),
  );
}

String? _parseAuthParameterValue(String value) {
  if (value.startsWith('"')) {
    if (value.length < 2 || !value.endsWith('"')) return null;
    final decoded = StringBuffer();
    final inner = value.substring(1, value.length - 1);
    for (var index = 0; index < inner.length; index++) {
      final character = inner[index];
      if (character == '\\') {
        index++;
        if (index >= inner.length) return null;
        decoded.write(inner[index]);
      } else if (character == '"') {
        return null;
      } else {
        decoded.write(character);
      }
    }
    return decoded.toString();
  }
  return _isHttpToken(value) ? value : null;
}

List<String>? _splitUnquotedSegments(String header) {
  final segments = <String>[];
  var start = 0;
  var inQuotes = false;
  var escaped = false;
  for (var index = 0; index < header.length; index++) {
    final character = header[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character == '\\' && inQuotes) {
      escaped = true;
    } else if (character == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && (character == ',' || character == ';')) {
      segments.add(header.substring(start, index));
      start = index + 1;
    }
  }
  if (inQuotes || escaped) return null;
  segments.add(header.substring(start));
  return segments;
}

bool _isHttpToken(String value) =>
    value.isNotEmpty &&
    value.codeUnits.every(
      (codeUnit) =>
          (codeUnit >= 0x30 && codeUnit <= 0x39) ||
          (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
          (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
          const {
            0x21,
            0x23,
            0x24,
            0x25,
            0x26,
            0x27,
            0x2a,
            0x2b,
            0x2d,
            0x2e,
            0x5e,
            0x5f,
            0x60,
            0x7c,
            0x7e,
          }.contains(codeUnit),
    );

McpOAuthClientRegistrationSource _registrationSource(
  Object? value, {
  required McpOAuthClientRegistrationSource fallback,
}) {
  if (value is String) {
    for (final source in McpOAuthClientRegistrationSource.values) {
      if (source.name == value) return source;
    }
  }
  return fallback;
}

bool _looksLikeClientMetadataDocumentId(String clientId) {
  final uri = Uri.tryParse(clientId);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.path.isNotEmpty &&
      uri.path != '/';
}

int? _asInt(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};
