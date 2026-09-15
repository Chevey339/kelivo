import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/provider_oauth.dart';
import '../logging/log_redactor.dart';
import 'oauth_callback.dart';
import 'oauth_cancellation.dart';
import 'oauth_pkce.dart';
import 'claude_oauth_request.dart';

part 'claude_oauth_adapter.dart';

const codexClientVersion = '0.153.0';

class OAuthLoginPrompt {
  const OAuthLoginPrompt({
    required this.url,
    this.userCode,
    this.browserAuthorization = false,
    this.submitAuthorizationCode,
  });
  final Uri url;
  final String? userCode;
  final bool browserAuthorization;
  final bool Function(String input)? submitAuthorizationCode;
}

typedef OAuthPromptHandler = Future<void> Function(OAuthLoginPrompt prompt);

class OAuthWireResponse {
  const OAuthWireResponse(this.status, this.data, {this.headers = const {}});
  final int status;
  final Map<String, dynamic> data;
  final Map<String, String> headers;
  bool get ok => status >= 200 && status < 300;
}

/// Form encoding, bounded requests and redirect handling shared by adapters.
class OAuthWire {
  OAuthWire(this.client);
  final http.Client client;

  Future<OAuthWireResponse> request(
    String url, {
    Map<String, String> headers = const {},
    Map<String, String>? form,
    Map<String, dynamic>? json,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request =
        http.Request(
            form == null && json == null ? 'GET' : 'POST',
            Uri.parse(url),
          )
          ..followRedirects = false
          ..headers.addAll({'Accept': 'application/json', ...headers});
    if (form != null) request.bodyFields = form;
    if (json != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(json);
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      Map<String, dynamic> data = const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = decoded.cast<String, dynamic>();
      } catch (_) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw const ProviderOAuthException(
            ProviderOAuthFailure.invalidResponse,
          );
        }
      }
      return OAuthWireResponse(
        response.statusCode,
        data,
        headers: response.headers,
      );
    } on ProviderOAuthException {
      rethrow;
    } on TimeoutException {
      throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
    } catch (_) {
      throw const ProviderOAuthException(ProviderOAuthFailure.network);
    }
  }
}

double? oauthNumber(Object? value) {
  final result = value is num ? value.toDouble() : double.tryParse('$value');
  return result?.isFinite == true ? result : null;
}

Map<String, dynamic> oauthMap(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};
String? oauthString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

ProviderOAuthException _requestFailure(
  OAuthWireResponse response,
  ProviderOAuthCredentials? credentials, {
  List<String> secrets = const [],
}) {
  final data = response.data;
  final error = oauthMap(data['error']);
  final code =
      oauthString(data['code']) ??
      oauthString(error['code']) ??
      oauthString(error['type']) ??
      oauthString(data['error']);
  final messages = <String>{
    if (oauthString(data['message']) case final value?) value,
    if (oauthString(error['message']) case final value?) value,
    if (oauthString(error['error_description']) case final value?) value,
    if (oauthString(data['detail']) case final value?) value,
    if (oauthString(data['error_description']) case final value?) value,
  };
  var quotaExceeded = {
    'insufficient_quota',
    'insufficient_balance',
    'quota_exceeded',
  }.contains(code);
  final details = data['details'];
  for (final detail
      in (details is List ? details : const []).whereType<Map>()) {
    final debug = oauthMap(detail['debug']);
    quotaExceeded |= debug['reason'] == 'REASON_QUOTA_EXCEEDED';
    if (oauthString(oauthMap(debug['localizedMessage'])['message'])
        case final value?) {
      messages.add(value);
    }
  }
  quotaExceeded |= messages.any(
    (text) => {
      'insufficient balance',
      'credits used up.',
    }.contains(text.trim().toLowerCase()),
  );

  String? sanitized(String? text) {
    if (text == null || text.isEmpty) return null;
    var value = text;
    for (final secret in [
      if (credentials != null) ...[
        credentials.accessToken,
        credentials.refreshToken,
      ],
      ...secrets,
      if (oauthString(data['access_token']) case final token?) token,
      if (oauthString(data['refresh_token']) case final token?) token,
      if (oauthString(data['id_token']) case final token?) token,
    ]) {
      if (secret.isNotEmpty) value = value.replaceAll(secret, '[redacted]');
    }
    value = LogRedactor.redactText(value)
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[redacted]',
        )
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
        .trim();
    return value.length > 400 ? '${value.substring(0, 400)}…' : value;
  }

  return ProviderOAuthException(
    response.status == 401
        ? ProviderOAuthFailure.loginRequired
        : quotaExceeded
        ? ProviderOAuthFailure.quotaExceeded
        : ProviderOAuthFailure.requestRejected,
    statusCode: response.status,
    code: sanitized(code),
    message: sanitized(messages.join(' · ')),
  );
}

abstract class ProviderOAuthAdapter {
  OAuthProvider get provider;
  Duration get tokenRequestTimeout => const Duration(seconds: 30);

  static ProviderOAuthAdapter forProvider(OAuthProvider provider) =>
      switch (provider) {
        OAuthProvider.chatgpt => ChatGptOAuthAdapter(),
        OAuthProvider.grok => GrokOAuthAdapter(),
        OAuthProvider.kimi => KimiOAuthAdapter(),
        OAuthProvider.claude => ClaudeOAuthAdapter(),
      };

  Map<String, String> headers(ProviderOAuthCredentials credentials) => {
    'Authorization': 'Bearer ${credentials.accessToken}',
  };

  Future<ProviderOAuthCredentials> login(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt, {
    bool deviceCode = true,
    OAuthUrlLauncher? launcher,
  });

  Future<String> tokenEndpoint(OAuthWire wire) async => provider.tokenEndpoint;

  Future<ProviderOAuthCredentials> refresh(
    OAuthWire wire,
    ProviderOAuthCredentials stored,
  ) async {
    final response = await wire.request(
      await tokenEndpoint(wire),
      form: {
        'grant_type': 'refresh_token',
        'client_id': provider.clientId,
        'refresh_token': stored.refreshToken,
      },
      headers: tokenHeaders(stored.deviceId),
      timeout: tokenRequestTimeout,
    );
    if (!response.ok) {
      final error =
          oauthString(response.data['error']) ??
          oauthString(oauthMap(response.data['error'])['code']);
      final invalid =
          response.status == 401 ||
          {
            'invalid_grant',
            'invalid_token',
            'refresh_token_reused',
            'refresh_token_expired',
            'refresh_token_invalid',
          }.contains(error);
      final failure = _requestFailure(response, stored);
      throw ProviderOAuthException(
        invalid ? ProviderOAuthFailure.loginRequired : failure.kind,
        statusCode: response.status,
        code: failure.code,
        message: failure.message,
      );
    }
    return credentials(response.data, stored: stored);
  }

  Map<String, String> tokenHeaders(String? deviceId) => const {};

  ProviderOAuthCredentials credentials(
    Map<String, dynamic> data, {
    ProviderOAuthCredentials? stored,
    String? deviceId,
  }) {
    final access = oauthString(data['access_token']);
    final refresh = oauthString(data['refresh_token']) ?? stored?.refreshToken;
    final claims = oauthTokenClaims(access ?? '');
    final idClaims = oauthTokenClaims(oauthString(data['id_token']) ?? '');
    final auth = oauthMap(claims['https://api.openai.com/auth']);
    final idAuth = oauthMap(idClaims['https://api.openai.com/auth']);
    final profile = oauthMap(claims['https://api.openai.com/profile']);
    final idProfile = oauthMap(idClaims['https://api.openai.com/profile']);
    final expires = oauthNumber(data['expires_in']);
    final jwtExpiry = oauthNumber(claims['exp']);
    if (access == null ||
        refresh == null ||
        (expires == null &&
            (provider == OAuthProvider.chatgpt || jwtExpiry == null))) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    final accountId =
        oauthString(auth['chatgpt_account_id']) ??
        oauthString(idAuth['chatgpt_account_id']) ??
        (provider == OAuthProvider.chatgpt
            ? null
            : oauthString(claims['user_id']) ?? oauthString(claims['sub'])) ??
        stored?.accountId;
    var email =
        oauthString(profile['email']) ??
        oauthString(idProfile['email']) ??
        oauthString(idClaims['email']) ??
        oauthString(claims['email']) ??
        stored?.email;
    var plan =
        oauthString(auth['chatgpt_plan_type']) ??
        oauthString(idAuth['chatgpt_plan_type']) ??
        stored?.plan;
    if (provider == OAuthProvider.chatgpt) {
      email = email?.trim().toLowerCase();
      plan = plan?.trim().toLowerCase();
    }
    if (provider == OAuthProvider.chatgpt &&
        stored == null &&
        accountId == null &&
        email == null) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    return ProviderOAuthCredentials(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expires != null
          ? DateTime.now().add(Duration(seconds: expires.toInt()))
          : DateTime.fromMillisecondsSinceEpoch((jwtExpiry! * 1000).toInt()),
      sessionId: stored?.sessionId ?? const Uuid().v4(),
      accountId: accountId,
      email: email,
      plan: plan,
      deviceId: deviceId ?? stored?.deviceId,
    );
  }

  Future<ProviderOAuthCredentials> deviceLogin(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt,
    String deviceUrl, {
    String? deviceId,
  }) async {
    final tokenUrl = await tokenEndpoint(wire);
    cancellation.check();
    final init = await wire.request(
      deviceUrl,
      form: {
        'client_id': provider.clientId,
        if (provider.scope.isNotEmpty) 'scope': provider.scope,
      },
      headers: tokenHeaders(deviceId),
    );
    final device = oauthString(init.data['device_code']);
    final userCode = oauthString(init.data['user_code']);
    final url =
        oauthString(init.data['verification_uri_complete']) ??
        oauthString(init.data['verification_uri']);
    if (!init.ok ||
        device == null ||
        userCode == null ||
        url == null ||
        Uri.tryParse(url)?.scheme != 'https') {
      throw ProviderOAuthException(
        ProviderOAuthFailure.invalidResponse,
        statusCode: init.status,
      );
    }
    cancellation.check();
    final deadline = DateTime.now().add(
      Duration(
        seconds: (oauthNumber(init.data['expires_in']) ?? 600)
            .clamp(1, 1800)
            .toInt(),
      ),
    );
    var interval = Duration(
      seconds: (oauthNumber(init.data['interval']) ?? 5).clamp(1, 60).toInt(),
    );
    await onPrompt(OAuthLoginPrompt(url: Uri.parse(url), userCode: userCode));
    while (DateTime.now().isBefore(deadline)) {
      await cancellation.wait(interval);
      if (!DateTime.now().isBefore(deadline)) break;
      final response = await wire.request(
        tokenUrl,
        form: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': provider.clientId,
          'device_code': device,
        },
        headers: tokenHeaders(deviceId),
      );
      cancellation.check();
      if (response.ok && response.data['access_token'] != null) {
        return credentials(response.data, deviceId: deviceId);
      }
      final error = response.data['error'];
      if (error == 'authorization_pending') continue;
      if (error == 'slow_down') {
        interval += const Duration(seconds: 5);
        continue;
      }
      throw ProviderOAuthException(
        error == 'access_denied'
            ? ProviderOAuthFailure.denied
            : error == 'expired_token'
            ? ProviderOAuthFailure.timeout
            : ProviderOAuthFailure.invalidResponse,
        statusCode: response.status,
      );
    }
    throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
  }

  Future<Map<String, dynamic>> get(
    OAuthWire wire,
    String url,
    ProviderOAuthCredentials credentials,
  ) async {
    final result = await wire.request(url, headers: headers(credentials));
    if (!result.ok) {
      throw _requestFailure(result, credentials);
    }
    return result.data;
  }

  Future<List<Map<String, dynamic>>> models(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async {
    final result = await get(wire, '${provider.baseUrl}/models', credentials);
    if (result['data'] is! List) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    return (result['data'] as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<ProviderUsageSnapshot> usage(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  );
}

class ChatGptOAuthAdapter extends ProviderOAuthAdapter {
  @override
  OAuthProvider get provider => OAuthProvider.chatgpt;

  @override
  Duration get tokenRequestTimeout => const Duration(seconds: 15);

  @override
  Map<String, String> headers(ProviderOAuthCredentials credentials) => {
    ...super.headers(credentials),
    if (credentials.accountId case final accountId?)
      'chatgpt-account-id': accountId,
    'originator': 'kelivo',
    'version': codexClientVersion,
    'User-Agent': 'Kelivo',
    'OpenAI-Beta': 'responses=experimental',
  };

  @override
  Future<ProviderOAuthCredentials> login(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt, {
    bool deviceCode = true,
    OAuthUrlLauncher? launcher,
  }) async {
    if (!deviceCode) {
      return _browserLogin(
        wire,
        cancellation,
        onPrompt,
        launcher ??
            (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
      );
    }
    final init = await wire.request(
      'https://auth.openai.com/api/accounts/deviceauth/usercode',
      json: {'client_id': provider.clientId},
      timeout: tokenRequestTimeout,
    );
    if (!init.ok) throw _requestFailure(init, null);
    final id = oauthString(init.data['device_auth_id']);
    final code = oauthString(init.data['user_code']);
    if (!init.ok || id == null || code == null) {
      throw ProviderOAuthException(
        ProviderOAuthFailure.invalidResponse,
        statusCode: init.status,
      );
    }
    cancellation.check();
    await onPrompt(
      OAuthLoginPrompt(
        url: Uri.parse('https://auth.openai.com/codex/device'),
        userCode: code,
      ),
    );
    final interval = Duration(
      seconds:
          (oauthNumber(init.data['interval']) ?? 5).clamp(1, 60).toInt() + 3,
    );
    // Match OMP: a quick first poll, then the advertised interval plus margin.
    for (var poll = 0; poll < 120; poll++) {
      await cancellation.wait(
        poll == 0 && interval > const Duration(seconds: 5)
            ? const Duration(seconds: 5)
            : interval,
      );
      final response = await wire.request(
        'https://auth.openai.com/api/accounts/deviceauth/token',
        json: {'device_auth_id': id, 'user_code': code},
        timeout: tokenRequestTimeout,
      );
      cancellation.check();
      if (response.status == 403 || response.status == 404) continue;
      if (!response.ok) {
        throw _requestFailure(response, null, secrets: [id, code]);
      }
      final authCode = oauthString(response.data['authorization_code']);
      final verifier = oauthString(response.data['code_verifier']);
      if (!response.ok || authCode == null || verifier == null) {
        throw ProviderOAuthException(
          ProviderOAuthFailure.invalidResponse,
          statusCode: response.status,
        );
      }
      return _exchange(
        wire,
        authCode,
        verifier,
        'https://auth.openai.com/deviceauth/callback',
      );
    }
    throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
  }

  Future<ProviderOAuthCredentials> _browserLogin(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt,
    OAuthUrlLauncher launcher,
  ) async {
    final redirect = Uri.parse('http://localhost:1455/auth/callback');
    final callback = await openOAuthCallback(
      Uri.parse('https://auth.openai.com'),
      loopbackRedirect: redirect,
    );
    unawaited(cancellation.whenCancelled.then((_) => callback.close()));
    try {
      final verifier = oauthRandomString(32);
      final state = oauthRandomString(24);
      final url = Uri.https('auth.openai.com', '/oauth/authorize', {
        'response_type': 'code',
        'client_id': provider.clientId,
        'redirect_uri': redirect.toString(),
        'scope': provider.scope,
        'code_challenge': oauthPkceChallenge(verifier),
        'code_challenge_method': 'S256',
        'state': state,
        'id_token_add_organizations': 'true',
        'codex_cli_simplified_flow': 'true',
        'originator': 'kelivo',
      });
      cancellation.check();
      await onPrompt(OAuthLoginPrompt(url: url, browserAuthorization: true));
      cancellation.check();
      final received = await Future.any<Uri>([
        callback.authorize(url, const Duration(minutes: 10), launcher),
        cancellation.whenCancelled.then(
          (_) => throw const ProviderOAuthException(
            ProviderOAuthFailure.cancelled,
          ),
        ),
      ]);
      cancellation.check();
      if (received.queryParameters['state'] != state) {
        throw const ProviderOAuthException(
          ProviderOAuthFailure.invalidResponse,
        );
      }
      final code = oauthString(received.queryParameters['code']);
      if (code == null) {
        throw const ProviderOAuthException(ProviderOAuthFailure.denied);
      }
      return await _exchange(wire, code, verifier, redirect.toString());
    } on OAuthCallbackException catch (error) {
      throw ProviderOAuthException(
        error.cancelled
            ? ProviderOAuthFailure.cancelled
            : ProviderOAuthFailure.invalidResponse,
      );
    } on TimeoutException {
      throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
    } finally {
      await callback.close();
    }
  }

  Future<ProviderOAuthCredentials> _exchange(
    OAuthWire wire,
    String code,
    String verifier,
    String redirect,
  ) async {
    final result = await wire.request(
      provider.tokenEndpoint,
      form: {
        'grant_type': 'authorization_code',
        'client_id': provider.clientId,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirect,
      },
      timeout: tokenRequestTimeout,
    );
    if (!result.ok) {
      throw _requestFailure(result, null, secrets: [code, verifier]);
    }
    return credentials(result.data);
  }

  @override
  Future<List<Map<String, dynamic>>> models(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async {
    final data = await get(
      wire,
      '${provider.baseUrl}/models?client_version=$codexClientVersion',
      credentials,
    );
    final entries = data['models'] ?? data['data'];
    if (entries is! List) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    final models = <Map<String, dynamic>>[];
    for (final row in entries.whereType<Map>()) {
      final id = oauthString(row['slug']) ?? oauthString(row['id']);
      final visibility = oauthString(row['visibility'])?.trim().toLowerCase();
      if (id == null || visibility == 'hide' || visibility == 'hidden') {
        continue;
      }
      // supported_in_api describes API-key availability, not the subscription.
      models.add({...row.cast<String, dynamic>(), 'id': id});
    }
    models.sort((a, b) {
      final priority = (oauthNumber(a['priority']) ?? double.maxFinite)
          .compareTo(oauthNumber(b['priority']) ?? double.maxFinite);
      return priority != 0
          ? priority
          : (a['id'] as String).compareTo(b['id'] as String);
    });
    return models;
  }

  @override
  Future<ProviderUsageSnapshot> usage(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async {
    final data = await get(
      wire,
      'https://chatgpt.com/backend-api/wham/usage',
      credentials,
    );
    final available = oauthNumber(
      oauthMap(data['rate_limit_reset_credits'])['available_count'],
    );
    if (available != null && available > 0) {
      // OMP checks the detail endpoint because /usage can retain a stale count.
      // This is read-only: never redeem a reset while querying usage.
      try {
        final detail = await get(
          wire,
          'https://chatgpt.com/backend-api/wham/rate-limit-reset-credits',
          credentials,
        );
        final reported = oauthNumber(detail['available_count']);
        final credits = detail['credits'];
        final count =
            reported?.clamp(0, double.maxFinite).toInt() ??
            (credits is List
                ? credits
                      .whereType<Map>()
                      .where(
                        (credit) =>
                            oauthString(credit['id']) != null &&
                            (credit['status'] ?? 'available') == 'available',
                      )
                      .length
                : null);
        if (count != null) {
          data['rate_limit_reset_credits'] = {'available_count': count};
        }
      } on ProviderOAuthException {
        // An optional detail failure must not hide the usage windows.
      }
    }
    return parseChatGptUsage(data);
  }
}

class GrokOAuthAdapter extends ProviderOAuthAdapter {
  @override
  OAuthProvider get provider => OAuthProvider.grok;

  @override
  Map<String, String> headers(ProviderOAuthCredentials credentials) => {
    ...super.headers(credentials),
    'X-XAI-Token-Auth': 'xai-grok-cli',
  };

  @override
  Future<String> tokenEndpoint(OAuthWire wire) async {
    final response = await wire.request(
      'https://auth.x.ai/.well-known/openid-configuration',
    );
    final endpoint = Uri.tryParse(
      oauthString(response.data['token_endpoint']) ?? '',
    );
    if (!response.ok ||
        endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host != 'auth.x.ai' ||
        endpoint.userInfo.isNotEmpty) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    return endpoint.toString();
  }

  @override
  Future<ProviderOAuthCredentials> login(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt, {
    bool deviceCode = true,
    OAuthUrlLauncher? launcher,
  }) async {
    var value = await deviceLogin(
      wire,
      cancellation,
      onPrompt,
      'https://auth.x.ai/oauth2/device/code',
    );
    try {
      final profile = await get(
        wire,
        'https://auth.x.ai/oauth2/userinfo',
        value,
      );
      value = value.copyWith(
        email: oauthString(profile['email']),
        accountId: oauthString(profile['sub']),
      );
    } on ProviderOAuthException {
      // Userinfo is optional; a successfully exchanged token remains usable.
    }
    return value;
  }

  @override
  Future<ProviderUsageSnapshot> usage(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async {
    final data = await get(
      wire,
      'https://cli-chat-proxy.grok.com/v1/billing?format=credits',
      credentials,
    );
    final weekly = parseGrokUsage(data);
    if (weekly.windows.isNotEmpty &&
        oauthMap(data['config'])['isUnifiedBillingUser'] != true) {
      return weekly;
    }
    final monthlyData = await get(
      wire,
      'https://cli-chat-proxy.grok.com/v1/billing',
      credentials,
    );
    final monthly = parseGrokUsage(monthlyData);
    if (monthly.windows.isNotEmpty) return monthly;
    // Unified billing does not imply a monthly subscription. A confirmed zero
    // monthly quota can coexist with an active legacy weekly reset cycle.
    if (oauthNumber(
          oauthMap(oauthMap(monthlyData['config'])['monthlyLimit'])['val'],
        ) ==
        0) {
      return parseGrokUsage(data, allowInferredWeekly: true);
    }
    return monthly;
  }
}

class KimiOAuthAdapter extends ProviderOAuthAdapter {
  @override
  OAuthProvider get provider => OAuthProvider.kimi;

  @override
  Map<String, String> tokenHeaders(String? deviceId) => {
    'User-Agent': 'KimiCLI/1.0',
    'X-Msh-Platform': 'kimi_cli',
    'X-Msh-Version': '1.0',
    'X-Msh-Device-Name': 'Kelivo',
    'X-Msh-Device-Model': Platform.operatingSystem,
    if (deviceId != null) 'X-Msh-Device-Id': deviceId,
  };

  @override
  Map<String, String> headers(ProviderOAuthCredentials credentials) => {
    ...super.headers(credentials),
    ...tokenHeaders(credentials.deviceId),
  };

  @override
  Future<ProviderOAuthCredentials> login(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt, {
    bool deviceCode = true,
    OAuthUrlLauncher? launcher,
  }) => deviceLogin(
    wire,
    cancellation,
    onPrompt,
    'https://auth.kimi.com/api/oauth/device_authorization',
    deviceId: const Uuid().v4().replaceAll('-', ''),
  );

  @override
  Future<ProviderUsageSnapshot> usage(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async => parseKimiUsage(
    await get(wire, '${provider.baseUrl}/usages', credentials),
  );
}

DateTime? _reset(Object? value) {
  if (value is String) {
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
  }
  final n = oauthNumber(value);
  return n == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          (n > 1000000000000 ? n : n * 1000).toInt(),
        );
}

ProviderUsageSnapshot parseChatGptUsage(Map<String, dynamic> data) {
  final now = DateTime.now();
  final windows = <ProviderUsageWindow>[];
  void add(Object? raw, String prefix) {
    final limits = oauthMap(raw);
    for (final key in ['primary_window', 'secondary_window']) {
      final row = oauthMap(limits[key]);
      final duration = oauthNumber(row['limit_window_seconds']);
      final usedPercent = oauthNumber(row['used_percent']);
      final resetAt = _reset(row['reset_at']);
      final resetAfter = oauthNumber(row['reset_after_seconds']);
      if (duration == null &&
          usedPercent == null &&
          resetAt == null &&
          resetAfter == null) {
        continue;
      }
      windows.add(
        ProviderUsageWindow(
          id: '$prefix$key',
          label: prefix.isEmpty ? null : prefix,
          usedPercent: usedPercent?.clamp(0, 100),
          duration: duration == null
              ? null
              : Duration(seconds: duration.toInt()),
          resetsAt:
              resetAt ??
              (resetAfter == null
                  ? null
                  : now.add(Duration(seconds: resetAfter.toInt()))),
        ),
      );
    }
  }

  add(data['rate_limit'], '');
  final additional = data['additional_rate_limits'];
  for (final row
      in (additional is List ? additional : const []).whereType<Map>()) {
    add(
      row['rate_limit'],
      oauthString(row['limit_name']) ??
          oauthString(row['metered_feature']) ??
          '',
    );
  }
  final limits = oauthMap(data['rate_limit']);
  final resetCredits = oauthNumber(
    oauthMap(data['rate_limit_reset_credits'])['available_count'],
  );
  return ProviderUsageSnapshot(
    windows: windows,
    fetchedAt: now,
    plan: oauthString(data['plan_type']),
    allowed: limits['allowed'] is bool ? limits['allowed'] as bool : null,
    limitReached: limits['limit_reached'] is bool
        ? limits['limit_reached'] as bool
        : null,
    resetCredits: resetCredits?.clamp(0, double.maxFinite).toInt(),
  );
}

ProviderUsageSnapshot parseGrokUsage(
  Map<String, dynamic> data, {
  bool allowInferredWeekly = false,
}) {
  data = oauthMap(data['config']);
  final windows = <ProviderUsageWindow>[];
  final period = oauthMap(data['currentPeriod']);
  final start = _reset(period['start']);
  final end = _reset(period['end']);
  final percent =
      oauthNumber(data['creditUsagePercent']) ??
      ((data['isUnifiedBillingUser'] != true || allowInferredWeekly) &&
              start != null &&
              end != null &&
              end.isAfter(start) &&
              end.isAfter(DateTime.now()) &&
              '${period['type']}'.toUpperCase().contains('WEEK')
          ? 0.0
          : null);
  if (period.isNotEmpty && percent != null) {
    windows.add(
      ProviderUsageWindow(
        id: 'weekly',
        usedPercent: percent,
        duration: const Duration(days: 7),
        resetsAt: _reset(period['end']),
      ),
    );
    for (final row
        in (data['productUsage'] as List? ?? const []).whereType<Map>()) {
      final p = oauthNumber(row['usagePercent']);
      if (p != null) {
        windows.add(
          ProviderUsageWindow(
            id: '${row['product']}',
            label: oauthString(row['product']),
            usedPercent: p,
            resetsAt: _reset(period['end']),
          ),
        );
      }
    }
  } else {
    final limit = oauthNumber(oauthMap(data['monthlyLimit'])['val']);
    final used = oauthNumber(oauthMap(data['used'])['val']);
    if (limit != null && limit > 0 && used != null) {
      windows.add(
        ProviderUsageWindow(
          id: 'monthly',
          used: used,
          limit: limit,
          usedPercent: limit > 0 ? used / limit * 100 : null,
          resetsAt: _reset(data['billingPeriodEnd']),
        ),
      );
    }
  }
  return ProviderUsageSnapshot(
    windows: windows,
    fetchedAt: DateTime.now(),
    plan: oauthString(data['planName']) ?? oauthString(data['plan']),
  );
}

ProviderUsageSnapshot parseKimiUsage(Map<String, dynamic> data) {
  final windows = <ProviderUsageWindow>[];
  void add(
    Map<String, dynamic> row,
    String id, {
    Duration? duration,
    String? label,
  }) {
    if (row.isEmpty) return;
    final limit = oauthNumber(row['limit']);
    final used =
        oauthNumber(row['used']) ??
        (limit != null && oauthNumber(row['remaining']) != null
            ? limit - oauthNumber(row['remaining'])!
            : null);
    windows.add(
      ProviderUsageWindow(
        id: id,
        label: label,
        used: used,
        limit: limit,
        usedPercent: used != null && limit != null && limit > 0
            ? used / limit * 100
            : null,
        duration: duration,
        resetsAt: _reset(row['resetTime'] ?? row['reset_at']),
      ),
    );
  }

  add(oauthMap(data['usage']), 'weekly', duration: const Duration(days: 7));
  add(oauthMap(data['totalQuota']), 'total');
  var i = 0;
  for (final row in (data['limits'] as List? ?? const []).whereType<Map>()) {
    final window = oauthMap(row['window']);
    final count = oauthNumber(window['duration']);
    final unit = '${window['timeUnit']}'.toUpperCase();
    final multiplier = unit.contains('MINUTE')
        ? 60
        : unit.contains('HOUR')
        ? 3600
        : unit.contains('DAY')
        ? 86400
        : unit.contains('WEEK')
        ? 604800
        : 1;
    add(
      oauthMap(row['detail'] ?? row),
      'limit-${i++}',
      duration: count == null
          ? null
          : Duration(seconds: (count * multiplier).toInt()),
      label: oauthString(row['name']),
    );
  }
  return ProviderUsageSnapshot(windows: windows, fetchedAt: DateTime.now());
}
