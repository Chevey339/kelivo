import 'package:Kelivo/core/services/auth/oauth_callback_io.dart'
    show createAndroidOAuthCallbackForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android OAuth uses a native custom-scheme callback', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('app.oauth');
    MethodCall? authenticationCall;
    var cancelCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        cancelCalls++;
        return null;
      }
      authenticationCall = call;
      final arguments = call.arguments as Map<Object?, Object?>;
      return Uri.parse(arguments['redirectUri']! as String)
          .replace(queryParameters: const {'code': 'code', 'state': 'state'})
          .toString();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final callback = createAndroidOAuthCallbackForTesting(
      Uri.parse('https://auth.example.com'),
    );
    var fallbackLauncherCalled = false;
    final callbackUri = await callback.authorize(
      Uri.parse('https://auth.example.com/authorize?state=state'),
      const Duration(seconds: 2),
      (uri) async {
        fallbackLauncherCalled = true;
        return true;
      },
    );
    await callback.close();

    expect(callback.redirectUri.scheme, 'psyche.kelivo');
    expect(callback.redirectUri.host, 'mcp-oauth-callback');
    expect(callback.redirectUri.pathSegments, hasLength(1));
    expect(callback.redirectUri.hasQuery, isFalse);
    expect(callbackUri.queryParameters['code'], 'code');
    expect(authenticationCall?.method, 'authenticate');
    expect(
      (authenticationCall?.arguments as Map<Object?, Object?>)['url'],
      'https://auth.example.com/authorize?state=state',
    );
    expect(fallbackLauncherCalled, isFalse);
    expect(cancelCalls, 1);
  });
}
