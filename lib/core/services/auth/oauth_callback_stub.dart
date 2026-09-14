import 'oauth_callback_types.dart';

Future<OAuthCallback> openOAuthCallback(
  Uri authorizationServer, {
  Uri? loopbackRedirect,
}) {
  throw UnsupportedError('OAuth login is not supported on this platform');
}
