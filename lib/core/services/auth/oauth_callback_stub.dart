import 'oauth_callback_types.dart';

Future<OAuthCallback> openOAuthCallback(
  Uri authorizationServer, {
  Uri? loopbackRedirect,
  String? expectedState,
}) {
  throw UnsupportedError('OAuth login is not supported on this platform');
}
