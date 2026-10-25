import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/services/auth/oauth_callback.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _issuer = 'https://auth.example.com';
const _endpoint = 'https://mcp.example.com/team/mcp';
const _metadata =
    'https://mcp.example.com/.well-known/oauth-protected-resource';
const _cimd = McpOAuthClientRegistration(
  clientId: 'https://client.example.com/oauth/client.json',
  registrationSource: McpOAuthClientRegistrationSource.cimd,
);

void main() {
  test('cancel during discovery never opens a browser', () async {
    final fixture = _Fixture()..discoveryGate = Completer<void>();
    final session = McpOAuthSession();
    final pending = fixture.authorize(session: session);
    final assertion = expectLater(pending, throwsA(isA<McpOAuthCancelled>()));
    await fixture.discoveryStarted.future;
    await session.cancel();
    await assertion;
    expect(fixture.browsers, isEmpty);
    expect(fixture.registrations, 0);
  });

  test('cancel closes a callback that finishes opening late', () async {
    final fixture = _Fixture()..callbackGate = Completer<void>();
    final session = McpOAuthSession();
    final pending = fixture.authorize(session: session);
    final assertion = expectLater(pending, throwsA(isA<McpOAuthCancelled>()));
    await fixture.callbackStarted.future;
    await session.cancel();
    fixture.callbackGate!.complete();
    await assertion;
    expect(fixture.browsers.single.closes, 1);
    expect(fixture.registrations, 0);
    expect(fixture.browsers.single.authorizationUrl, isNull);
  });

  test(
    'registration survives cancellation and is reusable by a new service',
    () async {
      final fixture = _Fixture();
      McpOAuthClientRegistration? saved;
      final stages = <McpOAuthStage>[];
      final session = McpOAuthSession(onStageChanged: stages.add);
      final pending = fixture.authorize(
        session: session,
        onRegistered: (registration) async {
          saved = registration;
          expect(fixture.browsers.single.authorizationUrl, isNull);
        },
      );
      final assertion = expectLater(pending, throwsA(isA<McpOAuthCancelled>()));
      final url = await fixture.browserOpened.future;
      expect(saved!.clientId, 'registered-client');
      expect(saved!.authorizationServer, _issuer);
      expect(
        saved!.redirectUri,
        fixture.browsers.single.redirectUri.toString(),
      );
      expect(url.queryParameters['resource'], 'https://mcp.example.com');
      expect(fixture.expectedState, url.queryParameters['state']);
      await session.cancel();
      await assertion;
      expect(fixture.browsers.single.closes, 1);
      expect(stages, [
        McpOAuthStage.discovery,
        McpOAuthStage.registration,
        McpOAuthStage.browser,
      ]);

      final restarted = _Fixture(callbackPort: 34567);
      final retry = restarted.authorize(client: saved);
      await restarted.browserOpened.future;
      restarted.browsers.single.succeed();
      final state = await retry;
      expect(restarted.registrations, 0);
      expect(
        state.redirectUri,
        restarted.browsers.single.redirectUri.toString(),
      );
      expect(restarted.tokenForm!['resource'], 'https://mcp.example.com');
    },
  );

  test(
    'native browser cancellation releases the attempt without an error state',
    () async {
      final fixture = _Fixture();
      final pending = fixture.authorize();
      final assertion = expectLater(pending, throwsA(isA<McpOAuthCancelled>()));
      await fixture.browserOpened.future;
      fixture.browsers.single.result.completeError(
        const OAuthCallbackException('user closed browser', cancelled: true),
      );
      await assertion;
      expect(fixture.browsers.single.closes, 1);
      expect(fixture.tokenForm, isNull);
    },
  );

  test('cancel during token exchange discards the late response', () async {
    final fixture = _Fixture()..tokenGate = Completer<void>();
    final session = McpOAuthSession();
    final pending = fixture.authorize(session: session);
    final assertion = expectLater(pending, throwsA(isA<McpOAuthCancelled>()));
    await fixture.browserOpened.future;
    fixture.browsers.single.succeed();
    await fixture.tokenStarted.future;
    expect(session.stage, McpOAuthStage.token);
    await session.cancel();
    await assertion;
    fixture.tokenGate!.complete();
    expect(fixture.browsers.single.closes, 1);
  });

  test('CIMD is used only when advertised and bypasses DCR', () async {
    final fixture = _Fixture(cimdSupported: true);
    final pending = fixture.authorize(client: _cimd);
    final url = await fixture.browserOpened.future;
    expect(url.queryParameters['client_id'], _cimd.clientId);
    fixture.browsers.single.succeed();
    final state = await pending;
    expect(fixture.registrations, 0);
    expect(fixture.tokenForm!['client_id'], _cimd.clientId);
    expect(fixture.tokenForm, isNot(contains('client_secret')));
    expect(state.registrationSource, McpOAuthClientRegistrationSource.cimd);
  });

  test(
    'unsupported CIMD is a registration error before opening the browser',
    () async {
      final fixture = _Fixture();
      await expectLater(
        fixture.authorize(client: _cimd),
        throwsA(
          isA<McpOAuthException>().having(
            (e) => e.stage,
            'stage',
            McpOAuthStage.registration,
          ),
        ),
      );
      expect(fixture.registrations, 0);
      expect(fixture.browsers.single.authorizationUrl, isNull);
      expect(fixture.browsers.single.closes, 1);
    },
  );

  test('configured clients stay bound to their issuer', () async {
    final fixture = _Fixture();
    await expectLater(
      fixture.authorize(
        client: const McpOAuthClientRegistration(
          clientId: 'private-client',
          clientSecret: 'secret',
          tokenEndpointAuthMethod: 'client_secret_post',
          authorizationServer: 'https://another.example.com',
        ),
      ),
      throwsA(
        isA<McpOAuthException>().having(
          (e) => e.message,
          'message',
          contains('different authorization server'),
        ),
      ),
    );
    expect(fixture.browsers.single.authorizationUrl, isNull);
    expect(fixture.tokenForm, isNull);
  });

  for (final query in [
    'code=one&code=two',
    'code=one&error=denied',
    'code=one&iss=$_issuer&iss=$_issuer',
    'code=one&iss=https://wrong.example.com',
  ]) {
    test('rejects ambiguous or wrong issuer callbacks: $query', () async {
      final fixture = _Fixture();
      final pending = fixture.authorize();
      final assertion = expectLater(pending, throwsA(isA<McpOAuthException>()));
      final url = await fixture.browserOpened.future;
      final browser = fixture.browsers.single;
      browser.result.complete(
        browser.redirectUri.replace(
          query: '$query&state=${url.queryParameters['state']}',
        ),
      );
      await assertion;
      expect(fixture.tokenForm, isNull);
    });
  }
}

class _Fixture {
  _Fixture({bool cimdSupported = false, int callbackPort = 23456}) {
    service = McpOAuthService(
      httpClient: MockClient((request) async {
        if (request.url.toString() == _metadata) {
          if (!discoveryStarted.isCompleted) discoveryStarted.complete();
          await discoveryGate?.future;
          return _json({
            'resource': 'https://mcp.example.com',
            'authorization_servers': [_issuer],
          });
        }
        if (request.url.path == '/.well-known/oauth-authorization-server') {
          return _json({
            'issuer': _issuer,
            'authorization_endpoint': '$_issuer/authorize',
            'token_endpoint': '$_issuer/token',
            'registration_endpoint': '$_issuer/register',
            'code_challenge_methods_supported': ['S256'],
            'client_id_metadata_document_supported': cimdSupported,
          });
        }
        if (request.url.path == '/register') {
          registrations++;
          return _json({'client_id': 'registered-client'});
        }
        if (request.url.path == '/token') {
          tokenForm = Uri.splitQueryString(request.body);
          tokenStarted.complete();
          await tokenGate?.future;
          return _json({
            'access_token': 'access-token',
            'token_type': 'Bearer',
          });
        }
        return http.Response('', 404);
      }),
      callbackFactory: (_, {expectedState, loopbackRedirect}) async {
        this.expectedState = expectedState;
        final browser = _Browser(
          Uri.parse('http://127.0.0.1:$callbackPort/callback'),
          browserOpened,
        );
        browsers.add(browser);
        callbackStarted.complete();
        await callbackGate?.future;
        return browser;
      },
      launchAuthorizationUrl: (_) async => true,
    );
    addTearDown(() async {
      for (final gate in [discoveryGate, callbackGate, tokenGate]) {
        if (gate != null && !gate.isCompleted) gate.complete();
      }
      service.dispose();
    });
  }

  late final McpOAuthService service;
  final browsers = <_Browser>[];
  final discoveryStarted = Completer<void>();
  final callbackStarted = Completer<void>();
  final tokenStarted = Completer<void>();
  final browserOpened = Completer<Uri>();
  Completer<void>? discoveryGate;
  Completer<void>? callbackGate;
  Completer<void>? tokenGate;
  String? expectedState;
  Map<String, String>? tokenForm;
  int registrations = 0;

  Future<McpOAuthState> authorize({
    McpOAuthSession? session,
    McpOAuthClientRegistration? client,
    Future<void> Function(McpOAuthClientRegistration)? onRegistered,
  }) => service.authorize(
    serverUrl: _endpoint,
    serverName: 'Test',
    wwwAuthenticate: const ['Bearer resource_metadata="$_metadata"'],
    session: session,
    clientRegistration: client,
    onClientRegistered: onRegistered,
  );

  http.Response _json(Map<String, Object?> value) =>
      http.Response(jsonEncode(value), 200);
}

class _Browser implements OAuthCallback {
  _Browser(this.redirectUri, this.opened) {
    result.future.ignore();
  }

  @override
  final Uri redirectUri;
  final Completer<Uri> opened;
  final result = Completer<Uri>();
  Uri? authorizationUrl;
  int closes = 0;

  @override
  Future<Uri> authorize(Uri url, Duration timeout, OAuthUrlLauncher launch) {
    authorizationUrl = url;
    opened.complete(url);
    return result.future;
  }

  void succeed() => result.complete(
    redirectUri.replace(
      queryParameters: {
        'code': 'code',
        'state': authorizationUrl!.queryParameters['state']!,
      },
    ),
  );

  @override
  Future<void> close() async {
    closes++;
    if (!result.isCompleted) {
      result.completeError(
        const OAuthCallbackException('cancelled', cancelled: true),
      );
    }
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) => result.future;
}
