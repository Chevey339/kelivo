import 'provider_oauth.dart';

/// Uses the same local/portable-backup persistence contract as built-in OAuth.
/// Plugin exports contain only manifests; this object is never exported there.
class ProviderPluginSession {
  const ProviderPluginSession({
    required this.manifestFingerprint,
    required this.credentials,
  });

  final String manifestFingerprint;
  final ProviderOAuthCredentials credentials;

  Map<String, dynamic> toJson() => {
    'manifestFingerprint': manifestFingerprint,
    'credentials': credentials.toJson(),
  };

  factory ProviderPluginSession.fromJson(Map<String, dynamic> json) {
    final fingerprint = json['manifestFingerprint'];
    final credentials = json['credentials'];
    if (fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) ||
        credentials is! Map<String, dynamic>) {
      throw const FormatException('Invalid provider plugin session');
    }
    return ProviderPluginSession(
      manifestFingerprint: fingerprint,
      credentials: ProviderOAuthCredentials.fromJson(credentials),
    );
  }
}
