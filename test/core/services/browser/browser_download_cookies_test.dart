import 'package:Kelivo/core/services/browser/browser_download_cookies.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Cookie cookie({
    String domain = 'example.com',
    String path = '/',
    bool secure = false,
    int? expires,
  }) => Cookie(
    name: 'session',
    value: 'fake-token',
    domain: domain,
    path: path,
    isSecure: secure,
    expiresDate: expires,
  );
  bool matches(Cookie cookie, String url) =>
      browserDownloadCookieMatches(cookie, Uri.parse(url));

  test('host-only credentials never cross a host boundary', () {
    final value = cookie();
    expect(matches(value, 'https://example.com/file'), isTrue);
    expect(matches(value, 'https://evilexample.com/file'), isFalse);
    expect(matches(value, 'https://sub.example.com/file'), isFalse);
    expect(matches(value, 'https://example.com.evil/file'), isFalse);
  });
  test('domain cookies match only exact host or a real subdomain', () {
    final value = cookie(domain: '.example.com');
    expect(matches(value, 'https://example.com/file'), isTrue);
    expect(matches(value, 'https://sub.example.com/file'), isTrue);
    expect(matches(value, 'https://evilexample.com/file'), isFalse);
    expect(
      matches(cookie(domain: 'EXAMPLE.COM'), 'https://example.com'),
      isTrue,
    );
    expect(matches(cookie(domain: '.0.0.1'), 'https://127.0.0.1'), isFalse);
  });
  test('Secure and expiration restrictions survive a fresh redirect query', () {
    expect(matches(cookie(secure: true), 'https://example.com/file'), isTrue);
    expect(matches(cookie(secure: true), 'http://example.com/file'), isFalse);
    expect(matches(cookie(), 'http://example.com/file'), isTrue);
    expect(matches(cookie(expires: 1), 'https://example.com/file'), isFalse);
  });
  test(
    'path matching respects a directory boundary and empty request path',
    () {
      final value = cookie(path: '/account');
      expect(matches(value, 'https://example.com/account'), isTrue);
      expect(matches(value, 'https://example.com/account/file?q=1'), isTrue);
      expect(matches(value, 'https://example.com/accounts/file'), isFalse);
      expect(matches(value, 'https://example.com/file'), isFalse);
      expect(
        matches(cookie(path: '/account/'), 'https://example.com/account/file'),
        isTrue,
      );
      expect(matches(cookie(), 'https://example.com'), isTrue);
      expect(matches(cookie(), 'file://example.com/file'), isFalse);
    },
  );
  test(
    'only Android can supply an already URL-filtered metadata-free cookie',
    () {
      final value = Cookie(name: 'session', value: 'fake-token');
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(matches(value, 'https://example.com/file'), isFalse);
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(matches(value, 'https://example.com/file'), isTrue);
      expect(
        matches(cookie(domain: 'elsewhere.com'), 'https://example.com/file'),
        isFalse,
      );
    },
  );

  test(
    'Windows CDP expiration seconds and session sentinel retain valid login cookies',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final futureSeconds =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      expect(
        matches(cookie(expires: futureSeconds), 'https://example.com/file'),
        isTrue,
      );
      expect(matches(cookie(expires: 1), 'https://example.com/file'), isFalse);
      final session = Cookie(
        name: 'session',
        value: 'fake-token',
        domain: 'example.com',
        path: '/',
        isSecure: true,
        isSessionOnly: true,
        expiresDate: -1,
      );
      expect(matches(session, 'https://example.com/file'), isTrue);
      expect(matches(session, 'http://example.com/file'), isFalse);
      expect(matches(session, 'https://evilexample.com/file'), isFalse);
    },
  );
}
