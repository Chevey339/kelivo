part of 'provider_oauth_adapter.dart';

const _claudeAccountBetas = [
  'claude-code-20250219',
  'oauth-2025-04-20',
  'interleaved-thinking-2025-05-14',
  'redact-thinking-2026-02-12',
  'context-management-2025-06-27',
  'prompt-caching-scope-2026-01-05',
  'mid-conversation-system-2026-04-07',
  'advanced-tool-use-2025-11-20',
  'effort-2025-11-24',
  'extended-cache-ttl-2025-04-11',
];

/// OMP 6f2c14b3: rules/auth/anthropic.kdl and registry/oauth/anthropic.ts.
class ClaudeOAuthAdapter extends ProviderOAuthAdapter {
  @override
  OAuthProvider get provider => OAuthProvider.claude;

  @override
  Map<String, String> headers(ProviderOAuthCredentials credentials) =>
      claudeOAuthHeaders(credentials);

  @override
  Future<ProviderOAuthCredentials> login(
    OAuthWire wire,
    OAuthCancellation cancellation,
    OAuthPromptHandler onPrompt, {
    bool deviceCode = true,
    OAuthUrlLauncher? launcher,
  }) async {
    final authority = Uri.parse('https://claude.ai');
    final preferred = Uri.parse('http://localhost:54545/callback');
    final state = oauthRandomString(24);
    OAuthCallback callback;
    try {
      callback = await openOAuthCallback(
        authority,
        loopbackRedirect: preferred,
        expectedState: state,
      );
    } on SocketException {
      callback = await openOAuthCallback(
        authority,
        loopbackRedirect: preferred.replace(port: 0),
        expectedState: state,
      );
    }
    final redirect = callback.redirectUri;
    final verifier = oauthRandomString(32);
    final received = Completer<String>();
    final url = Uri.https('claude.ai', '/oauth/authorize', {
      'client_id': provider.clientId,
      'response_type': 'code',
      'redirect_uri': redirect.toString(),
      'scope': provider.scope,
      'code_challenge': oauthPkceChallenge(verifier),
      'code_challenge_method': 'S256',
      'state': state,
      'code': 'true',
    });
    bool submit(String input) {
      if (cancellation.isCancelled || received.isCompleted) return false;
      String? parsed;
      try {
        parsed = _claudeAuthorizationCode(input, state);
      } on FormatException {
        return false;
      }
      if (parsed == null) return false;
      received.complete(parsed);
      return true;
    }

    unawaited(cancellation.whenCancelled.then((_) => callback.close()));
    try {
      cancellation.check();
      await onPrompt(
        OAuthLoginPrompt(
          url: url,
          browserAuthorization: true,
          submitAuthorizationCode: submit,
        ),
      );
      cancellation.check();
      if (!received.isCompleted) {
        unawaited(() async {
          try {
            final result = await callback.authorize(
              url,
              const Duration(minutes: 5),
              launcher ??
                  (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
            );
            if (cancellation.isCancelled || received.isCompleted) return;
            if (result.queryParameters['state'] != state) {
              received.completeError(
                const ProviderOAuthException(
                  ProviderOAuthFailure.invalidResponse,
                ),
              );
            } else if (result.queryParameters.containsKey('error')) {
              received.completeError(
                const ProviderOAuthException(ProviderOAuthFailure.denied),
              );
            } else if (!submit(result.toString())) {
              received.completeError(
                const ProviderOAuthException(
                  ProviderOAuthFailure.invalidResponse,
                ),
              );
            }
          } on OAuthCallbackException {
            // Closing the browser leaves OMP's manual code entry available.
          } on TimeoutException {
            // The shared deadline below also covers the manual-input path.
          } catch (error, stack) {
            if (!received.isCompleted) received.completeError(error, stack);
          }
        }());
      }
      final code = await Future.any<String>([
        received.future,
        cancellation.whenCancelled.then(
          (_) => throw const ProviderOAuthException(
            ProviderOAuthFailure.cancelled,
          ),
        ),
      ]).timeout(const Duration(minutes: 5));
      cancellation.check();
      final response = await wire.request(
        provider.tokenEndpoint,
        json: {
          'grant_type': 'authorization_code',
          'client_id': provider.clientId,
          'code': code,
          'state': state,
          'redirect_uri': redirect.toString(),
          'code_verifier': verifier,
        },
      );
      if (!response.ok) {
        throw _requestFailure(response, null, secrets: [code, verifier]);
      }
      cancellation.check();
      final identity = await _identity(
        wire,
        credentials(response.data),
        includeOrganization: true,
      );
      cancellation.check();
      return identity;
    } on TimeoutException {
      throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
    } finally {
      await callback.close();
    }
  }

  @override
  ProviderOAuthCredentials credentials(
    Map<String, dynamic> data, {
    ProviderOAuthCredentials? stored,
    String? deviceId,
  }) {
    final access = oauthString(data['access_token']);
    final refresh = oauthString(data['refresh_token']) ?? stored?.refreshToken;
    final expires = oauthNumber(data['expires_in']);
    if (access == null || refresh == null || expires == null || expires <= 0) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    final account = oauthMap(data['account']);
    final organization = oauthMap(data['organization']);
    return ProviderOAuthCredentials(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(Duration(seconds: expires.toInt())),
      sessionId: stored?.sessionId ?? const Uuid().v4(),
      accountId: oauthString(account['uuid']) ?? stored?.accountId,
      email: oauthString(account['email_address']) ?? stored?.email,
      organizationId: stored == null
          ? oauthString(organization['uuid'])
          : stored.organizationId,
      organizationName: stored == null
          ? oauthString(organization['name'])
          : stored.organizationName,
      deviceId:
          stored?.deviceId ??
          deviceId ??
          claudeOAuthDeviceId(
            oauthRandomString(32),
            oauthString(account['uuid']),
          ),
      plan: stored?.plan,
    );
  }

  Future<ProviderOAuthCredentials> _identity(
    OAuthWire wire,
    ProviderOAuthCredentials value, {
    required bool includeOrganization,
  }) async {
    if (value.accountId != null &&
        value.email != null &&
        (!includeOrganization || value.organizationId != null)) {
      return value;
    }
    try {
      final result = await wire.request(
        'https://api.anthropic.com/api/claude_cli/bootstrap?entrypoint=cli&model=claude-opus-4-8',
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Authorization': 'Bearer ${value.accessToken}',
          'Content-Type': 'application/json',
          'User-Agent': 'claude-code/$claudeCodeVersion',
          'anthropic-beta': 'oauth-2025-04-20',
        },
      );
      if (!result.ok) return value;
      final account = oauthMap(result.data['oauth_account']);
      return value.copyWith(
        accountId: value.accountId ?? oauthString(account['account_uuid']),
        email: value.email ?? oauthString(account['account_email']),
        organizationId: includeOrganization
            ? value.organizationId ?? oauthString(account['organization_uuid'])
            : null,
        organizationName: includeOrganization
            ? value.organizationName ??
                  oauthString(account['organization_name'])
            : null,
      );
    } on ProviderOAuthException {
      return value;
    }
  }

  @override
  Future<ProviderOAuthCredentials> refresh(
    OAuthWire wire,
    ProviderOAuthCredentials stored,
  ) async {
    final response = await wire.request(
      provider.tokenEndpoint,
      json: {
        'grant_type': 'refresh_token',
        'client_id': provider.clientId,
        'refresh_token': stored.refreshToken,
      },
      headers: {
        'anthropic-beta': 'oauth-2025-04-20',
        'User-Agent':
            'anthropic-sdk-typescript/$claudeCodeSdkVersion userOAuthProvider',
      },
    );
    if (!response.ok) {
      final failure = _requestFailure(response, stored);
      throw ProviderOAuthException(
        response.status == 401 || response.data['error'] == 'invalid_grant'
            ? ProviderOAuthFailure.loginRequired
            : failure.kind,
        statusCode: response.status,
        code: failure.code,
        message: failure.message,
      );
    }
    return _identity(
      wire,
      credentials(response.data, stored: stored),
      includeOrganization: false,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> models(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async {
    final rows = <Map<String, dynamic>>[];
    final cursors = <String>{};
    String? cursor;
    do {
      final url = Uri.parse('${provider.baseUrl}/models').replace(
        queryParameters: {
          'limit': '1000',
          if (cursor != null) 'after_id': cursor,
        },
      );
      final response = await wire.request(
        url.toString(),
        headers: {
          'Authorization': 'Bearer ${credentials.accessToken}',
          'anthropic-version': '2023-06-01',
          'anthropic-beta': _claudeAccountBetas.join(','),
          'anthropic-dangerous-direct-browser-access': 'true',
        },
      );
      if (!response.ok) throw _requestFailure(response, credentials);
      final result = response.data;
      if (result['data'] is! List) {
        throw const ProviderOAuthException(
          ProviderOAuthFailure.invalidResponse,
        );
      }
      rows.addAll(
        (result['data'] as List).whereType<Map>().map(
          (row) => row.cast<String, dynamic>(),
        ),
      );
      if (result['has_more'] != true) break;
      cursor = oauthString(result['last_id']);
      if (cursor == null || !cursors.add(cursor)) {
        throw const ProviderOAuthException(
          ProviderOAuthFailure.invalidResponse,
        );
      }
    } while (true);
    return rows;
  }

  @override
  Future<ProviderUsageSnapshot> usage(
    OAuthWire wire,
    ProviderOAuthCredentials credentials,
  ) async {
    for (var attempt = 0; ; attempt++) {
      String? retryAfter;
      try {
        final response = await wire.request(
          'https://api.anthropic.com/api/oauth/usage',
          headers: {
            'Authorization': 'Bearer ${credentials.accessToken}',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Encoding': 'gzip',
            'Content-Type': 'application/json',
            'User-Agent': 'claude-cli/$claudeCodeVersion (external, cli)',
            'anthropic-beta': _claudeAccountBetas.join(','),
          },
        );
        if (!response.ok) {
          final retryable =
              response.status == 408 ||
              response.status >= 500 && response.status != 501;
          if (!retryable || attempt == 2) {
            throw _requestFailure(response, credentials);
          }
          retryAfter = response.headers['retry-after'];
        } else {
          final usage = parseClaudeOAuthUsage(response.data);
          if (usage.hasData || attempt == 2) return usage;
        }
      } on ProviderOAuthException catch (error) {
        if (attempt == 2 ||
            !const {
              ProviderOAuthFailure.network,
              ProviderOAuthFailure.invalidResponse,
            }.contains(error.kind)) {
          rethrow;
        }
      }
      // OMP retries transient failures three times, but never 429. Respect
      // Retry-After so repeated manual refreshes do not deepen a throttle.
      var delay = Duration(milliseconds: 500 * (1 << attempt));
      if (retryAfter != null) {
        final seconds = double.tryParse(retryAfter);
        Duration? requested;
        if (seconds != null && seconds.isFinite) {
          requested = Duration(milliseconds: (seconds * 1000).round());
        } else {
          try {
            requested = HttpDate.parse(retryAfter).difference(DateTime.now());
          } on FormatException {
            // An invalid Retry-After keeps the exponential backoff.
          }
        }
        if (requested != null && requested > delay) delay = requested;
      }
      await Future<void>.delayed(delay);
    }
  }
}

String? _claudeAuthorizationCode(String input, String expectedState) {
  var value = input.trim();
  if (value.isEmpty) return null;
  String? state;
  final uri = Uri.tryParse(value);
  if (uri?.hasScheme == true) {
    state = uri!.queryParameters['state'];
    value = uri.queryParameters['code'] ?? '';
  } else if (value.contains('code=')) {
    final params = Uri.splitQueryString(
      value.replaceFirst(RegExp(r'^[?#]'), ''),
    );
    state = params['state'];
    value = params['code'] ?? '';
  }
  final fragment = value.indexOf('#');
  if (fragment >= 0) {
    state = value.substring(fragment + 1);
    value = value.substring(0, fragment);
  }
  if (value.isEmpty ||
      RegExp(r'\s').hasMatch(value) ||
      (state != null && state.isNotEmpty && state != expectedState)) {
    return null;
  }
  return value;
}

/// Match OMP usage/claude.ts: newer scoped limits remain visible even when
/// is_active is false; only the shared windows describe account-wide limits.
ProviderUsageSnapshot parseClaudeOAuthUsage(Map<String, dynamic> data) {
  final limits = (data['limits'] is List ? data['limits'] as List : const [])
      .whereType<Map>()
      .toList();
  final windows = <ProviderUsageWindow>[];
  final ids = <String>{};
  void add(
    String id,
    Object? raw,
    Duration duration, {
    String? label,
    bool modern = false,
  }) {
    final bucket = oauthMap(raw);
    final percent = oauthNumber(bucket[modern ? 'percent' : 'utilization']);
    if (percent == null || !ids.add(id)) return;
    windows.add(
      ProviderUsageWindow(
        id: id,
        label: label,
        usedPercent: percent.clamp(0, 100),
        resetsAt: DateTime.tryParse('${bucket['resets_at']}'),
        duration: duration,
      ),
    );
  }

  void shared(String id, String key, String kind, Duration duration) {
    final legacy = oauthMap(data[key]);
    if (oauthNumber(legacy['utilization']) != null ||
        DateTime.tryParse('${legacy['resets_at']}') != null) {
      add(id, legacy, duration);
    } else {
      for (final limit in limits) {
        if (limit['kind'] == kind) {
          add(id, limit, duration, modern: true);
          break;
        }
      }
    }
  }

  shared('primary', 'five_hour', 'session', const Duration(hours: 5));
  shared('weekly', 'seven_day', 'weekly_all', const Duration(days: 7));
  add(
    'weekly-opus',
    data['seven_day_opus'],
    const Duration(days: 7),
    label: 'Opus',
  );
  add(
    'weekly-sonnet',
    data['seven_day_sonnet'],
    const Duration(days: 7),
    label: 'Sonnet',
  );
  for (final entry in limits) {
    final label = oauthString(
      oauthMap(oauthMap(entry['scope'])['model'])['display_name'],
    );
    if (entry['kind'] != 'weekly_scoped' || label == null) continue;
    final slug = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isNotEmpty) {
      add(
        'weekly-$slug',
        entry,
        const Duration(days: 7),
        label: label.trim(),
        modern: true,
      );
    }
  }
  double? dollars(
    Object? raw,
    Object? exponentRaw,
    Object? currency, {
    bool requireCurrency = false,
  }) {
    final amount = raw is num ? raw.toDouble() : null;
    final exponent = exponentRaw is num ? exponentRaw.toDouble() : null;
    if (amount == null ||
        !amount.isFinite ||
        amount < 0 ||
        amount > 9007199254740991 ||
        amount != amount.truncateToDouble() ||
        exponent == null ||
        !exponent.isFinite ||
        exponent < 0 ||
        exponent > 308 ||
        exponent != exponent.truncateToDouble() ||
        (currency == null
            ? requireCurrency
            : currency is! String || currency.toUpperCase() != 'USD')) {
      return null;
    }
    return amount / double.parse('1e${exponent.toInt()}');
  }

  final spend = data['spend'];
  final extra = oauthMap(spend ?? data['extra_usage']);
  double? used;
  double? limit;
  var valid = false;
  if (spend != null) {
    if (extra['enabled'] == true && extra.containsKey('limit')) {
      final usedMoney = oauthMap(extra['used']);
      final cap = oauthMap(extra['limit']);
      used = dollars(
        usedMoney['amount_minor'],
        usedMoney['exponent'],
        usedMoney['currency'],
        requireCurrency: true,
      );
      limit = dollars(
        cap['amount_minor'],
        cap['exponent'],
        cap['currency'],
        requireCurrency: true,
      );
      valid =
          used != null &&
          (extra['limit'] == null || limit != null && limit > 0);
    }
  } else if (extra['is_enabled'] == true &&
      extra.containsKey('monthly_limit')) {
    final exponent = extra.containsKey('decimal_places')
        ? extra['decimal_places']
        : 2;
    used = dollars(
      extra['used_credits'],
      exponent,
      extra['currency'],
      requireCurrency: extra.containsKey('currency'),
    );
    limit = dollars(
      extra['monthly_limit'],
      exponent,
      extra['currency'],
      requireCurrency: extra.containsKey('currency'),
    );
    valid =
        used != null &&
        (extra['monthly_limit'] == null || limit != null && limit > 0);
  }
  if (valid && (limit == null || (used! / limit).isFinite)) {
    windows.add(
      ProviderUsageWindow(
        id: 'extra',
        unit: 'usd',
        used: used,
        limit: limit,
        usedPercent: limit == null ? null : (used! / limit * 100).clamp(0, 100),
      ),
    );
  }
  return ProviderUsageSnapshot(windows: windows, fetchedAt: DateTime.now());
}
