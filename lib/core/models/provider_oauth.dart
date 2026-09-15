import 'dart:convert';

enum OAuthProvider { chatgpt, grok, kimi, claude }

extension OAuthProviderInfo on OAuthProvider {
  String get displayName => switch (this) {
    OAuthProvider.chatgpt => 'ChatGPT',
    OAuthProvider.grok => 'Grok',
    OAuthProvider.kimi => 'Kimi Code',
    OAuthProvider.claude => 'Claude',
  };

  String get baseUrl => switch (this) {
    OAuthProvider.chatgpt => 'https://chatgpt.com/backend-api/codex',
    OAuthProvider.grok => 'https://api.x.ai/v1',
    OAuthProvider.kimi => 'https://api.kimi.com/coding/v1',
    OAuthProvider.claude => 'https://api.anthropic.com/v1',
  };

  String get clientId => switch (this) {
    OAuthProvider.chatgpt => 'app_EMoamEEZ73f0CkXaXp7hrann',
    OAuthProvider.grok => 'b1a00492-073a-47ea-816f-4c329264a828',
    OAuthProvider.kimi => '17e5f671-d194-4dfb-9706-5516cb48c098',
    OAuthProvider.claude => '9d1c250a-e61b-44d9-88ed-5944d1962f5e',
  };

  String get tokenEndpoint => switch (this) {
    OAuthProvider.chatgpt => 'https://auth.openai.com/oauth/token',
    OAuthProvider.grok => 'https://auth.x.ai/oauth2/token',
    OAuthProvider.kimi => 'https://auth.kimi.com/api/oauth/token',
    OAuthProvider.claude => 'https://api.anthropic.com/v1/oauth/token',
  };

  String get scope => switch (this) {
    OAuthProvider.chatgpt =>
      'openid profile email offline_access api.connectors.read api.connectors.invoke',
    OAuthProvider.grok =>
      'openid profile email offline_access grok-cli:access api:access',
    OAuthProvider.kimi => '',
    OAuthProvider.claude =>
      'org:create_api_key user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload',
  };

  String get icon => switch (this) {
    OAuthProvider.chatgpt => 'assets/icons/openai.svg',
    OAuthProvider.grok => 'assets/icons/grok.svg',
    OAuthProvider.kimi => 'assets/icons/kimi-color.svg',
    OAuthProvider.claude => 'assets/icons/claude-color.svg',
  };

  bool get usesResponsesApi =>
      this == OAuthProvider.chatgpt || this == OAuthProvider.grok;
}

/// Stored with the provider configuration, including in portable backups.
class ProviderOAuthCredentials {
  const ProviderOAuthCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.sessionId,
    this.accountId,
    this.email,
    this.plan,
    this.deviceId,
    this.organizationId,
    this.organizationName,
    this.requiresLogin = false,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String sessionId;
  final String? accountId;
  final String? email;
  final String? plan;
  final String? deviceId;
  final String? organizationId;
  final String? organizationName;
  final bool requiresLogin;

  bool shouldRefresh(
    DateTime now, {
    Duration leeway = const Duration(minutes: 1),
  }) => !now.add(leeway).isBefore(expiresAt);

  ProviderOAuthCredentials copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? accountId,
    String? email,
    String? plan,
    String? deviceId,
    String? organizationId,
    String? organizationName,
    bool? requiresLogin,
  }) => ProviderOAuthCredentials(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
    sessionId: sessionId,
    accountId: accountId ?? this.accountId,
    email: email ?? this.email,
    plan: plan ?? this.plan,
    deviceId: deviceId ?? this.deviceId,
    organizationId: organizationId ?? this.organizationId,
    organizationName: organizationName ?? this.organizationName,
    requiresLogin: requiresLogin ?? this.requiresLogin,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'sessionId': sessionId,
    if (accountId != null) 'accountId': accountId,
    if (email != null) 'email': email,
    if (plan != null) 'plan': plan,
    if (deviceId != null) 'deviceId': deviceId,
    if (organizationId != null) 'organizationId': organizationId,
    if (organizationName != null) 'organizationName': organizationName,
    'requiresLogin': requiresLogin,
  };

  factory ProviderOAuthCredentials.fromJson(Map<String, dynamic> json) =>
      ProviderOAuthCredentials(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        sessionId: json['sessionId'] as String,
        accountId: json['accountId'] as String?,
        email: json['email'] as String?,
        plan: json['plan'] as String?,
        deviceId: json['deviceId'] as String?,
        organizationId: json['organizationId'] as String?,
        organizationName: json['organizationName'] as String?,
        requiresLogin: json['requiresLogin'] == true,
      );
}

/// JWT claims are display/routing metadata, never proof of authentication.
Map<String, dynamic> oauthTokenClaims(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    final value = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return value is Map ? value.cast<String, dynamic>() : const {};
  } catch (_) {
    return const {};
  }
}

class ProviderUsageWindow {
  const ProviderUsageWindow({
    required this.id,
    this.label,
    this.usedPercent,
    this.used,
    this.limit,
    this.resetsAt,
    this.duration,
    this.unit,
  });
  final String id;
  final String? label;
  final double? usedPercent;
  final double? used;
  final double? limit;
  final DateTime? resetsAt;
  final Duration? duration;
  final String? unit;
}

class ProviderUsageSnapshot {
  const ProviderUsageSnapshot({
    required this.windows,
    required this.fetchedAt,
    this.plan,
    this.allowed,
    this.limitReached,
    this.resetCredits,
  });
  final List<ProviderUsageWindow> windows;
  final DateTime fetchedAt;
  final String? plan;
  final bool? allowed;
  final bool? limitReached;
  final int? resetCredits;

  bool get hasData =>
      windows.isNotEmpty ||
      allowed != null ||
      limitReached != null ||
      resetCredits != null;
}

enum ProviderOAuthFailure {
  loginRequired,
  cancelled,
  timeout,
  network,
  invalidResponse,
  denied,
  quotaExceeded,
  requestRejected,
  usageUnavailable,
}

class ProviderOAuthException implements Exception {
  const ProviderOAuthException(
    this.kind, {
    this.providerId,
    this.statusCode,
    this.code,
    this.message,
  });
  final ProviderOAuthFailure kind;
  final String? providerId;
  final int? statusCode;
  final String? code;

  /// Sanitized server explanation; token responses are never copied here.
  final String? message;

  @override
  String toString() =>
      'OAuth: ${kind.name}${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}
