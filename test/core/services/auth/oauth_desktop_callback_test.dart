import 'dart:io';

import 'package:Kelivo/core/services/auth/oauth_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'malformed UTF-8 callbacks return 400 and preserve authorization',
    () async {
      final callback = await openOAuthCallback(
        Uri.parse('https://auth.example.com'),
        expectedState: 'expected',
      );
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() async {
        client.close(force: true);
        await callback.close();
      });
      var completed = false;
      final pending = callback
          .authorize(
            Uri.parse('https://auth.example.com/authorize?state=expected'),
            const Duration(seconds: 5),
            (_) async => true,
          )
          .then((value) {
            completed = true;
            return value;
          });
      pending.ignore();

      Future<int> send(String query) async {
        final request = await client.getUrl(
          callback.redirectUri.replace(query: query),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 2),
        );
        await response.drain<void>().timeout(const Duration(seconds: 2));
        return response.statusCode;
      }

      for (final query in [
        'code=%FF&state=expected',
        'code=%C3&state=expected',
        'code=valid&state=%FF',
        'error=%FF&state=expected',
        'code=valid&state=expected&iss=%FF',
        'code=valid&state=expected&%FF=value',
      ]) {
        expect(await send(query), HttpStatus.badRequest, reason: query);
        expect(completed, isFalse);
      }
      expect(await send('code=valid%2Bcode&state=expected'), HttpStatus.ok);
      expect((await pending).queryParameters['code'], 'valid+code');
    },
  );

  test('invalid callbacks leave the desktop authorization pending', () async {
    final callback = await openOAuthCallback(
      Uri.parse('https://auth.example.com'),
      expectedState: 'expected',
    );
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await callback.close();
    });
    var completed = false;
    final pending = callback
        .authorize(
          Uri.parse('https://auth.example.com/authorize?state=expected'),
          const Duration(seconds: 3),
          (_) async => true,
        )
        .then((value) {
          completed = true;
          return value;
        });
    for (final query in [
      'code=unrelated&state=wrong',
      'code=missing-state',
      'code=one&state=expected&state=expected',
      'code=one&code=two&state=expected',
      'code=one&error=denied&state=expected',
      'code=one&iss=issuer&iss=issuer&state=expected',
    ]) {
      final response = await (await client.getUrl(
        callback.redirectUri.replace(query: query),
      )).close();
      expect(response.statusCode, HttpStatus.badRequest);
      await response.drain<void>();
      expect(completed, isFalse);
    }
    final response = await (await client.getUrl(
      callback.redirectUri.replace(
        queryParameters: {'code': 'valid', 'state': 'expected'},
      ),
    )).close();
    await response.drain<void>();
    expect((await pending).queryParameters['code'], 'valid');
  });

  test(
    'authorize installs state for callers without an initial state',
    () async {
      final callback = await openOAuthCallback(
        Uri.parse('https://auth.example.com'),
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await callback.close();
      });
      final result = callback.authorize(
        Uri.parse('https://auth.example.com/authorize?state=expected'),
        const Duration(seconds: 3),
        (_) async {
          final invalid = await (await client.getUrl(
            callback.redirectUri.replace(
              queryParameters: {'code': 'wrong', 'state': 'wrong'},
            ),
          )).close();
          expect(invalid.statusCode, HttpStatus.badRequest);
          await invalid.drain<void>();
          final valid = await (await client.getUrl(
            callback.redirectUri.replace(
              queryParameters: {'code': 'valid', 'state': 'expected'},
            ),
          )).close();
          await valid.drain<void>();
          return true;
        },
      );
      expect((await result).queryParameters['code'], 'valid');
    },
  );

  test(
    'a configured loopback URL without a path accepts the HTTP root path',
    () async {
      final callback = await openOAuthCallback(
        Uri.parse('https://auth.example.com'),
        loopbackRedirect: Uri.parse('http://127.0.0.1:0'),
        expectedState: 'expected',
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await callback.close();
      });
      final response = await (await client.getUrl(
        callback.redirectUri.replace(query: 'code=valid&state=expected'),
      )).close();
      expect(response.statusCode, HttpStatus.ok);
      await response.drain<void>();
      final received = await callback.waitForCallback(
        const Duration(seconds: 1),
      );
      expect(received.path, callback.redirectUri.path);
      expect(received.queryParameters['code'], 'valid');
    },
  );
}
