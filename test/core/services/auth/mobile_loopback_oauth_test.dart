import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/services/auth/oauth_callback_io.dart';
import 'package:Kelivo/core/services/auth/oauth_callback_types.dart';
import 'package:flutter_test/flutter_test.dart';

class _BrowserCallback implements OAuthCallback {
  @override
  final redirectUri = Uri.parse('psyche.kelivo:/oauth/callback/test');
  late Future<Uri> Function(Uri) open;
  final cancelled = Completer<Uri>();
  int closes = 0;

  @override
  Future<Uri> authorize(Uri url, Duration timeout, OAuthUrlLauncher launch) =>
      Future.any([open(url), cancelled.future]);

  @override
  Future<Uri> waitForCallback(Duration timeout) => throw UnimplementedError();

  @override
  Future<void> close() async {
    closes++;
    if (!cancelled.isCompleted) {
      cancelled.completeError(
        const OAuthCallbackException('cancelled', cancelled: true),
      );
    }
  }
}

void main() {
  test(
    'mobile loopback validates callbacks and returns through the system browser',
    () async {
      final browser = _BrowserCallback();
      final callback = await createMobileLoopbackOAuthCallbackForTesting(
        browser,
      );
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));
      addTearDown(callback.close);
      Future<HttpClientResponse> request(Uri uri) async {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        return request.close();
      }

      browser.open = (url) async {
        expect(
          url.queryParameters['redirect_uri'],
          callback.redirectUri.toString(),
        );
        for (final uri in [
          callback.redirectUri.replace(query: 'code=secret&state=wrong'),
          callback.redirectUri.replace(
            query: 'code=secret&state=state&state=state',
          ),
          callback.redirectUri.replace(query: 'code=one&code=two&state=state'),
          callback.redirectUri.replace(
            query: 'code=one&error=denied&state=state',
          ),
        ]) {
          final response = await request(uri);
          expect(response.statusCode, HttpStatus.badRequest);
          await response.drain<void>();
        }
        final uri = callback.redirectUri.replace(
          query: 'code=secret&state=state',
        );
        final response = await request(uri);
        expect(response.statusCode, HttpStatus.found);
        expect(response.headers.value('cache-control'), 'no-store');
        final finish = Uri.parse(response.headers.value('location')!);
        expect(finish, browser.redirectUri.replace(query: 'state=state'));
        expect(finish.queryParameters.containsKey('code'), false);
        await response.drain<void>();
        final duplicate = await request(uri);
        expect(duplicate.statusCode, HttpStatus.gone);
        await duplicate.drain<void>();
        return finish;
      };
      final received = await callback.authorize(
        Uri.https('auth.openai.com', '/oauth/authorize', {
          'state': 'state',
          'redirect_uri': callback.redirectUri.toString(),
        }),
        const Duration(seconds: 3),
        (_) async => fail('must use the native browser session'),
      );
      expect(received.queryParameters, {'code': 'secret', 'state': 'state'});
      await callback.close();
      await callback.close();
      expect(browser.closes, 1);
      final rebound = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        callback.redirectUri.port,
      );
      await rebound.close(force: true);
    },
  );

  test(
    'mobile loopback closes on cancellation and can immediately start again',
    () async {
      final browser = _BrowserCallback()..open = (_) => Completer<Uri>().future;
      final callback = await createMobileLoopbackOAuthCallbackForTesting(
        browser,
      );
      final pending = callback.authorize(
        Uri.parse('https://auth.openai.com/oauth/authorize?state=state'),
        const Duration(seconds: 3),
        (_) async => true,
      );
      final expectation = expectLater(
        pending,
        throwsA(
          isA<OAuthCallbackException>().having(
            (e) => e.cancelled,
            'cancelled',
            true,
          ),
        ),
      );
      await callback.close();
      await expectation;
      final rebound = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        callback.redirectUri.port,
      );
      await rebound.close(force: true);
    },
  );

  test(
    'mobile loopback does not wait for the timeout after the user closes the browser',
    () async {
      final browser = _BrowserCallback()
        ..open = (_) async =>
            throw const OAuthCallbackException('cancelled', cancelled: true);
      final callback = await createMobileLoopbackOAuthCallbackForTesting(
        browser,
      );
      addTearDown(callback.close);
      await expectLater(
        callback
            .authorize(
              Uri.parse('https://auth.openai.com/oauth/authorize?state=state'),
              const Duration(seconds: 3),
              (_) async => true,
            )
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<OAuthCallbackException>()),
      );
    },
  );

  test('mobile loopback times out when the browser never returns', () async {
    final browser = _BrowserCallback()..open = (_) => Completer<Uri>().future;
    final callback = await createMobileLoopbackOAuthCallbackForTesting(browser);
    addTearDown(callback.close);
    await expectLater(
      callback.authorize(
        Uri.parse('https://auth.openai.com/oauth/authorize?state=state'),
        const Duration(milliseconds: 20),
        (_) async => true,
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
