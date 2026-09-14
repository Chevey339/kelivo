import 'oauth_callback_stub.dart'
    if (dart.library.io) 'oauth_callback_io.dart'
    as implementation;
import 'oauth_callback_types.dart';

export 'oauth_callback_types.dart';

Future<OAuthCallback> openOAuthCallback(
  Uri authorizationServer, {
  Uri? loopbackRedirect,
}) => implementation.openOAuthCallback(
  authorizationServer,
  loopbackRedirect: loopbackRedirect,
);
