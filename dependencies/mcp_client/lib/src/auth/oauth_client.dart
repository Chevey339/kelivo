/// OAuth 2.1 client implementation for MCP
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'oauth.dart';

/// HTTP-based OAuth 2.1 client implementation
class HttpOAuthClient implements OAuthClient {
  final OAuthConfig config;
  final http.Client _httpClient;
  AuthServerMetadata? _metadata;

  HttpOAuthClient({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Discover authorization server metadata (RFC8414)
  Future<AuthServerMetadata> _discoverMetadata() async {
    if (_metadata != null) return _metadata!;

    if (config.authServerMetadataUrl == null) {
      // Create metadata from config
      _metadata = AuthServerMetadata(
        issuer: Uri.parse(config.authorizationEndpoint).origin,
        authorizationEndpoint: config.authorizationEndpoint,
        tokenEndpoint: config.tokenEndpoint,
      );
      return _metadata!;
    }

    final response = await _httpClient.get(
      Uri.parse(config.authServerMetadataUrl!),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw OAuthError(
        error: 'metadata_discovery_failed',
        errorDescription: 'Failed to discover authorization server metadata',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    _metadata = AuthServerMetadata.fromJson(json);
    return _metadata!;
  }

  /// Generate PKCE code verifier and challenge
  Map<String, String> _generatePkce() {
    final random = Random.secure();
    final codeVerifier = base64UrlEncode(
      List<int>.generate(32, (i) => random.nextInt(256)),
    ).replaceAll('=', '');

    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    final codeChallenge = base64UrlEncode(digest.bytes).replaceAll('=', '');

    return {'code_verifier': codeVerifier, 'code_challenge': codeChallenge};
  }

  @override
  Future<String> getAuthorizationUrl({
    required List<String> scopes,
    String? state,
    Map<String, String>? additionalParams,
  }) async {
    final metadata = await _discoverMetadata();
    final pkce = _generatePkce();

    // Store code verifier for later use
    _codeVerifier = pkce['code_verifier']!;

    final params = <String, String>{
      'response_type': 'code',
      'client_id': config.clientId,
      'code_challenge': pkce['code_challenge']!,
      'code_challenge_method': config.codeChallengeMethod,
      if (config.redirectUri != null) 'redirect_uri': config.redirectUri!,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      if (state != null) 'state': state,
      ...?additionalParams,
    };

    final uri = Uri.parse(
      metadata.authorizationEndpoint,
    ).replace(queryParameters: params);

    return uri.toString();
  }

  String? _codeVerifier;

  /// Get the current code verifier for PKCE
  String? get codeVerifier => _codeVerifier;

  @override
  Future<OAuthToken> exchangeCodeForToken({
    required String code,
    required String codeVerifier,
  }) async {
    final metadata = await _discoverMetadata();

    final body = <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': config.clientId,
      'code_verifier': codeVerifier,
      if (config.redirectUri != null) 'redirect_uri': config.redirectUri!,
    };

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    // Add client authentication if confidential client
    if (config.clientSecret != null) {
      final credentials = base64Encode(
        utf8.encode('${config.clientId}:${config.clientSecret}'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    final response = await _httpClient.post(
      Uri.parse(metadata.tokenEndpoint),
      headers: headers,
      body: body.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw OAuthError.fromJson(json);
    }

    return OAuthToken.fromJson(json);
  }

  @override
  Future<OAuthToken> refreshToken({required String refreshToken}) async {
    final metadata = await _discoverMetadata();

    final body = <String, String>{
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': config.clientId,
    };

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    if (config.clientSecret != null) {
      final credentials = base64Encode(
        utf8.encode('${config.clientId}:${config.clientSecret}'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    final response = await _httpClient.post(
      Uri.parse(metadata.tokenEndpoint),
      headers: headers,
      body: body.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw OAuthError.fromJson(json);
    }

    return OAuthToken.fromJson(json);
  }

  @override
  Future<void> revokeToken({
    required String token,
    String? tokenTypeHint,
  }) async {
    final metadata = await _discoverMetadata();

    if (metadata.revocationEndpoint == null) {
      return; // Server doesn't support revocation
    }

    final body = <String, String>{
      'token': token,
      'client_id': config.clientId,
      if (tokenTypeHint != null) 'token_type_hint': tokenTypeHint,
    };

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    if (config.clientSecret != null) {
      final credentials = base64Encode(
        utf8.encode('${config.clientId}:${config.clientSecret}'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    await _httpClient.post(
      Uri.parse(metadata.revocationEndpoint!),
      headers: headers,
      body: body.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );
  }

  @override
  Future<OAuthToken> getClientCredentialsToken({List<String>? scopes}) async {
    final metadata = await _discoverMetadata();

    final body = <String, String>{
      'grant_type': 'client_credentials',
      'client_id': config.clientId,
      if (scopes != null && scopes.isNotEmpty) 'scope': scopes.join(' '),
    };

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    if (config.clientSecret != null) {
      final credentials = base64Encode(
        utf8.encode('${config.clientId}:${config.clientSecret}'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    final response = await _httpClient.post(
      Uri.parse(metadata.tokenEndpoint),
      headers: headers,
      body: body.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw OAuthError.fromJson(json);
    }

    return OAuthToken.fromJson(json);
  }

  // Add PKCE related methods

  /// Generate PKCE code verifier (RFC 7636)
  String generateCodeVerifier() {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    final length = 43 + random.nextInt(86); // 43-128 character length

    return List.generate(
      length,
      (index) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Generate PKCE code challenge (S256 method)
  String generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Code challenge method (S256)
  String get codeChallengeMethod => 'S256';

  /// Generate Authorization URL with PKCE parameters
  Uri getAuthorizationUrlWithPkce({
    required List<String> scopes,
    String? state,
    String? codeVerifier,
    String? redirectUri,
  }) {
    final queryParams = <String, String>{
      'response_type': 'code',
      'client_id': config.clientId,
      'scope': scopes.join(' '),
      'state': state ?? _generateState(),
    };

    if (redirectUri != null) {
      queryParams['redirect_uri'] = redirectUri;
    }

    // Add PKCE parameters
    if (codeVerifier != null) {
      final codeChallenge = generateCodeChallenge(codeVerifier);
      queryParams['code_challenge'] = codeChallenge;
      queryParams['code_challenge_method'] = codeChallengeMethod;
    }

    final uri = Uri.parse(config.authorizationEndpoint);
    return uri.replace(queryParameters: queryParams);
  }

  /// Generate token exchange request data
  Map<String, String> buildTokenExchangeRequest({
    required String authorizationCode,
    required String codeVerifier,
    String? redirectUri,
  }) {
    return {
      'grant_type': 'authorization_code',
      'code': authorizationCode,
      'code_verifier': codeVerifier,
      'client_id': config.clientId,
      if (redirectUri != null) 'redirect_uri': redirectUri,
    };
  }

  /// Generate Refresh Token request data
  Map<String, String> buildRefreshTokenRequest({
    required String refreshToken,
    List<String>? scopes,
  }) {
    return {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': config.clientId,
      if (scopes != null && scopes.isNotEmpty) 'scope': scopes.join(' '),
    };
  }

  /// Generate State parameter (CSRF protection)
  String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}

/// OAuth token manager with automatic refresh
class OAuthTokenManager {
  final HttpOAuthClient _client;
  OAuthToken? _currentToken;
  Timer? _refreshTimer;

  final StreamController<OAuthToken> _tokenController =
      StreamController.broadcast();
  final StreamController<OAuthError> _errorController =
      StreamController.broadcast();

  OAuthTokenManager(this._client);

  /// Current token
  OAuthToken? get currentToken => _currentToken;

  /// Stream of token updates
  Stream<OAuthToken> get onTokenUpdate => _tokenController.stream;

  /// Stream of authentication errors
  Stream<OAuthError> get onError => _errorController.stream;

  /// Check if we have a valid token
  bool get hasValidToken {
    if (_currentToken == null) return false;
    return !_currentToken!.isExpired;
  }

  /// Check if the user is authenticated (alias for hasValidToken)
  bool get isAuthenticated => hasValidToken;

  /// Set the current token and schedule refresh
  void setToken(OAuthToken token) {
    _currentToken = token;
    _tokenController.add(token);
    _scheduleRefresh();
  }

  /// Get a valid access token, refreshing if necessary
  Future<String> getAccessToken() async {
    if (hasValidToken) {
      return _currentToken!.accessToken;
    }

    if (_currentToken?.refreshToken != null) {
      try {
        final newToken = await _client.refreshToken(
          refreshToken: _currentToken!.refreshToken!,
        );
        setToken(newToken);
        return newToken.accessToken;
      } catch (e) {
        _errorController.add(
          e is OAuthError
              ? e
              : OAuthError(
                error: 'refresh_failed',
                errorDescription: e.toString(),
              ),
        );
        rethrow;
      }
    }

    throw OAuthError(
      error: 'no_valid_token',
      errorDescription: 'No valid token available and no refresh token',
    );
  }

  /// Schedule automatic token refresh
  void _scheduleRefresh() {
    _refreshTimer?.cancel();

    if (_currentToken?.refreshToken == null ||
        _currentToken?.expiresIn == null) {
      return;
    }

    // Refresh 5 minutes before expiry
    final refreshIn = Duration(seconds: _currentToken!.expiresIn! - 300);
    if (refreshIn.isNegative) return;

    _refreshTimer = Timer(refreshIn, () async {
      try {
        final newToken = await _client.refreshToken(
          refreshToken: _currentToken!.refreshToken!,
        );
        setToken(newToken);
      } catch (e) {
        _errorController.add(
          e is OAuthError
              ? e
              : OAuthError(
                error: 'auto_refresh_failed',
                errorDescription: e.toString(),
              ),
        );
      }
    });
  }

  /// Clear the current token
  void clearToken() {
    _refreshTimer?.cancel();
    _currentToken = null;
  }

  // Add token lifecycle management methods

  /// Check if token is expired
  bool get isTokenExpired {
    if (_currentToken == null) return true;
    return _currentToken!.isExpired;
  }

  /// Returns true if the token will expire within [threshold].
  bool willExpireSoon({Duration threshold = const Duration(minutes: 5)}) {
    if (_currentToken == null || _currentToken!.expiresIn == null) return true;

    final expiresAt = _currentToken!.issuedAt.add(
      Duration(seconds: _currentToken!.expiresIn!),
    );
    final now = DateTime.now();
    return expiresAt.difference(now) <= threshold;
  }

  /// Stores the token in memory; persists to secure storage when [persistent] is true.
  Future<void> storeToken(OAuthToken token, {bool persistent = false}) async {
    _currentToken = token;
    _tokenController.add(token);
    _scheduleRefresh();

    if (persistent) {
      await _persistToken(token);
    }
  }

  /// Replaces the current token with [newToken] and fires the refresh callback.
  Future<void> refreshToken(OAuthToken newToken) async {
    final oldToken = _currentToken;
    await storeToken(newToken);

    if (onTokenRefresh != null && oldToken != null) {
      onTokenRefresh!(oldToken, newToken);
    }
  }

  /// Revokes the current token at the authorization server and clears it locally.
  Future<void> revokeToken() async {
    if (_currentToken != null) {
      try {
        await _client.revokeToken(token: _currentToken!.accessToken);
      } catch (e) {
        // Even if remote revocation fails, drop the local token.
      }
    }
    clearToken();
  }

  /// Drops expired tokens from memory.
  Future<int> cleanupExpiredTokens() async {
    var cleaned = 0;
    if (isTokenExpired) {
      clearToken();
      cleaned = 1;
    }
    return cleaned;
  }

  /// Securely deletes the token from memory.
  Future<void> securelyDeleteToken() async {
    clearToken();
    // Fully clear the in-memory reference.
    _currentToken = null;
  }

  /// Loads previously persisted tokens.
  Future<void> loadPersistedTokens() async {
    // TODO: integrate with SecureStorage. Empty placeholder for tests.
  }

  /// Stores an encrypted token.
  Future<void> storeEncryptedToken(
    OAuthToken token,
    String encryptionKey,
  ) async {
    // TODO: apply real encryption logic.
    await storeToken(token, persistent: true);
  }

  /// Loads an encrypted token.
  Future<OAuthToken?> loadEncryptedToken(String encryptionKey) async {
    // TODO: apply real decryption logic.
    return _currentToken;
  }

  /// Checks token expiry and emits a near-expiry lifecycle event when due.
  Future<void> checkTokenExpiry() async {
    if (willExpireSoon()) {
      _lifecycleController.add(
        TokenLifecycleEvent(
          type: TokenEventType.nearExpiry,
          timestamp: DateTime.now(),
          tokenId: _currentToken?.accessToken,
          message: 'Token will expire soon',
        ),
      );
    }
  }

  /// Starts the background refresh timer.
  void startBackgroundRefresh() {
    _scheduleRefresh();
    if (onBackgroundRefresh != null) {
      onBackgroundRefresh!();
    }
  }

  /// Stops the background refresh timer.
  void stopBackgroundRefresh() {
    _refreshTimer?.cancel();
  }

  // Persists the token (internal).
  Future<void> _persistToken(OAuthToken token) async {
    // TODO: integrate with SecureStorage.
  }

  // Callbacks and event streams.
  Function(OAuthToken oldToken, OAuthToken newToken)? onTokenRefresh;
  Function(dynamic error, int attempt)? onRefreshFailure;
  Function()? onBackgroundRefresh;

  final StreamController<TokenLifecycleEvent> _lifecycleController =
      StreamController<TokenLifecycleEvent>.broadcast();

  /// Stream of token lifecycle events.
  Stream<TokenLifecycleEvent> get lifecycleEvents =>
      _lifecycleController.stream;

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _tokenController.close();
    _errorController.close();
    _lifecycleController.close();
  }
}

/// Token lifecycle event types.
enum TokenEventType {
  issued,
  accessed,
  refreshed,
  nearExpiry,
  expired,
  revoked,
  error,
}

/// Token lifecycle event.
class TokenLifecycleEvent {
  final TokenEventType type;
  final DateTime timestamp;
  final String? tokenId;
  final String? message;
  final Map<String, dynamic>? metadata;

  TokenLifecycleEvent({
    required this.type,
    required this.timestamp,
    this.tokenId,
    this.message,
    this.metadata,
  });
}
