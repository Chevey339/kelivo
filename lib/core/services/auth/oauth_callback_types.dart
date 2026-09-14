typedef OAuthUrlLauncher = Future<bool> Function(Uri uri);

final class OAuthCallbackException implements Exception {
  const OAuthCallbackException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

abstract interface class OAuthCallback {
  Uri get redirectUri;

  Future<Uri> authorize(
    Uri authorizationUrl,
    Duration timeout,
    OAuthUrlLauncher launchAuthorizationUrl,
  );

  Future<Uri> waitForCallback(Duration timeout);

  Future<void> close();
}

typedef OAuthCallbackFactory =
    Future<OAuthCallback> Function(Uri authorizationServer);
