import 'dart:convert';

import 'package:Kelivo/core/services/auth/oauth_callback.dart';
import 'package:Kelivo/core/services/auth/oauth_pkce.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _zomato = 'https://mcp-server.zomato.com';
const _dhan = 'https://mcp.dhan.co';
const _resourcePath = '/.well-known/oauth-protected-resource';
const _authorizationPath = '/.well-known/oauth-authorization-server';

void main() {
  test(
    'Zomato discovery uses authoritative same-origin OAuth metadata',
    () async {
      final responses = _responses(_zomato);
      // The misplaced document is only a signal to try origin discovery. Its
      // endpoints must never replace the authoritative authorization metadata.
      responses['$_zomato$_resourcePath'] = _json({
        ..._authorizationMetadata(_zomato),
        'issuer': 'https://untrusted.example.com',
        'authorization_endpoint': 'https://untrusted.example.com/authorize',
        'token_endpoint': 'https://untrusted.example.com/token',
      });
      final requests = <http.Request>[];
      final service = McpOAuthService(httpClient: _client(responses, requests));
      addTearDown(service.dispose);

      final result = await service.discover(
        '$_zomato/mcp',
        headers: const {'X-Api-Key': 'resource-only-secret'},
      );

      expect(result.authorizationServer.toString(), '$_zomato/');
      expect(result.resource.toString(), '$_zomato/mcp');
      expect(result.authorizationEndpoint.toString(), '$_zomato/authorize');
      expect(result.tokenEndpoint.toString(), '$_zomato/token');
      expect(result.registrationEndpoint.toString(), '$_zomato/register');
      expect(result.scopes, ['mcp:tools', 'mcp:resources', 'mcp:prompts']);
      final authorizationRequest = requests.singleWhere(
        (request) => request.url.path == _authorizationPath,
      );
      expect(authorizationRequest.headers, isNot(contains('x-api-key')));
      expect(
        requests.every((request) => request.url.origin == _zomato),
        isTrue,
      );
    },
  );

  test(
    'Dhan discovery accepts only the same-origin root slash difference',
    () async {
      final service = McpOAuthService(httpClient: _client(_responses(_dhan)));
      addTearDown(service.dispose);

      final result = await service.discover('$_dhan/mcp');

      expect(result.authorizationServer.toString(), _dhan);
      expect(result.resource.toString(), '$_dhan/mcp');
      expect(result.authorizationEndpoint.toString(), '$_dhan/authorize');
      expect(result.tokenEndpoint.toString(), '$_dhan/token');
      expect(result.scopes, isEmpty);
    },
  );

  for (final metadataPath in [
    _authorizationPath,
    '/.well-known/openid-configuration',
  ]) {
    test(
      'Google discovery accepts a delegated root issuer via $metadataPath',
      () async {
        const resource = 'https://developerknowledge.googleapis.com/mcp';
        const metadataUrl =
            'https://developerknowledge.googleapis.com'
            '$_resourcePath/search_documents';
        const issuer = 'https://accounts.google.com';
        const scope =
            'https://www.googleapis.com/auth/devprofiles.full_control';
        final requests = <http.Request>[];
        final service = McpOAuthService(
          httpClient: _client({
            metadataUrl: _json({
              'resource': resource,
              'authorization_servers': ['$issuer/'],
              'scopes_supported': [scope],
            }),
            '$issuer$metadataPath': _json({
              'issuer': issuer,
              'authorization_endpoint': '$issuer/o/oauth2/v2/auth',
              'token_endpoint': 'https://oauth2.googleapis.com/token',
              'code_challenge_methods_supported': ['plain', 'S256'],
            }),
          }, requests),
        );
        addTearDown(service.dispose);

        final result = await service.discover(
          resource,
          headers: const {'X-Api-Key': 'resource-only-secret'},
          wwwAuthenticate: const ['Bearer resource_metadata="$metadataUrl"'],
        );

        expect(result.authorizationServer.toString(), issuer);
        expect(result.resource.toString(), resource);
        expect(
          result.authorizationEndpoint.toString(),
          '$issuer/o/oauth2/v2/auth',
        );
        expect(
          result.tokenEndpoint.toString(),
          'https://oauth2.googleapis.com/token',
        );
        expect(result.registrationEndpoint, isNull);
        expect(result.scopes, [scope]);
        final authorizationRequests = requests.where(
          (request) => request.url.origin == issuer,
        );
        expect(authorizationRequests, isNotEmpty);
        for (final request in authorizationRequests) {
          expect(request.headers, isNot(contains('x-api-key')));
        }
      },
    );
  }

  test(
    'origin discovery preserves resource path, query and challenged scopes',
    () async {
      final responses = _responses(_zomato)..remove('$_zomato$_resourcePath');
      final service = McpOAuthService(httpClient: _client(responses));
      addTearDown(service.dispose);
      const endpoint = '$_zomato/team/mcp?tenant=one';

      final result = await service.discover(
        endpoint,
        wwwAuthenticate: const ['Bearer scope="tools:read"'],
      );

      expect(result.resource.toString(), endpoint);
      expect(result.scopes, ['tools:read']);
    },
  );

  for (final response in [
    http.Response('', 404),
    _json(_authorizationMetadata(_zomato)),
  ]) {
    test(
      'explicit metadata never falls back: ${response.statusCode} ${response.body}',
      () async {
        final responses = _responses(_zomato)
          ..['$_zomato$_resourcePath'] = response;
        final requests = <http.Request>[];
        final service = McpOAuthService(
          httpClient: _client(responses, requests),
        );
        addTearDown(service.dispose);

        await expectLater(
          service.discover(
            '$_zomato/mcp',
            wwwAuthenticate: const [
              'Bearer resource_metadata="$_zomato$_resourcePath"',
            ],
          ),
          throwsA(isA<McpOAuthException>()),
        );
        expect(requests.map((request) => request.url.toString()), [
          '$_zomato$_resourcePath',
        ]);
      },
    );
  }

  final invalidResources = <String, http.Response>{
    'different origin': _json({
      'resource': 'https://other.example.com/mcp',
      'authorization_servers': [_zomato],
    }),
    'different path': _json({
      'resource': '$_zomato/other',
      'authorization_servers': [_zomato],
    }),
    'empty authorization servers': _json({
      'resource': '$_zomato/mcp',
      'authorization_servers': [],
    }),
    'invalid resource in mixed metadata': _json({
      ..._authorizationMetadata(_zomato),
      'resource': null,
    }),
    'invalid authorization servers in mixed metadata': _json({
      ..._authorizationMetadata(_zomato),
      'authorization_servers': null,
    }),
    'empty object': _json({}),
    'non-object JSON': http.Response('[]', 200),
    'malformed JSON': http.Response('{', 200),
    'redirect': http.Response(
      '',
      302,
      headers: {'location': '$_zomato$_authorizationPath'},
    ),
    'unauthorized': http.Response('', 401),
    'forbidden': http.Response('', 403),
    'rate limited': http.Response('', 429),
    'server error': http.Response('', 503),
  };
  for (final entry in invalidResources.entries) {
    test(
      'origin discovery cannot bypass resource failure: ${entry.key}',
      () async {
        final responses = _responses(_zomato)
          ..['$_zomato$_resourcePath/mcp'] = entry.value;
        final requests = <http.Request>[];
        final service = McpOAuthService(
          httpClient: _client(responses, requests),
        );
        addTearDown(service.dispose);

        await expectLater(
          service.discover('$_zomato/mcp'),
          throwsA(isA<McpOAuthException>()),
        );
        expect(
          requests.any((request) => request.url.path == _authorizationPath),
          isFalse,
        );
      },
    );
  }

  test('origin discovery cannot bypass a resource network failure', () async {
    final responses = _responses(_zomato);
    final requests = <http.Request>[];
    final service = McpOAuthService(
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '$_resourcePath/mcp') {
          throw http.ClientException('offline');
        }
        return responses[request.url.toString()] ?? http.Response('', 404);
      }),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.discover('$_zomato/mcp'),
      throwsA(
        isA<McpOAuthException>().having(
          (error) => error.isTransient,
          'transient',
          isTrue,
        ),
      ),
    );
    expect(
      requests.any((request) => request.url.path == _authorizationPath),
      isFalse,
    );
  });

  for (final issuer in [
    null,
    'https://other.example.com/',
    'http://mcp.dhan.co/',
    '$_dhan:8443/',
    '$_dhan/tenant',
    '$_dhan//',
    '$_dhan/?tenant=one',
    '$_dhan/#fragment',
    'https://user@mcp.dhan.co/',
  ]) {
    test('Dhan root exception still rejects issuer $issuer', () async {
      final responses = _responses(_dhan)
        ..['$_dhan$_authorizationPath'] = _json({
          ..._authorizationMetadata(_dhan),
          'issuer': issuer,
        });
      final service = McpOAuthService(httpClient: _client(responses));
      addTearDown(service.dispose);

      await expectLater(
        service.discover('$_dhan/mcp'),
        throwsA(
          isA<McpOAuthException>().having(
            (error) => error.message,
            'message',
            contains('issuer is missing or does not match discovery'),
          ),
        ),
      );
    });
  }

  test('same-origin tenant issuers still require exact equality', () async {
    final responses = _responses(_dhan)
      ..['$_dhan$_resourcePath/mcp'] = _json({
        'resource': '$_dhan/mcp',
        'authorization_servers': ['$_dhan/tenant'],
      })
      ..['$_dhan$_authorizationPath/tenant'] = _json({
        ..._authorizationMetadata(_dhan),
        'issuer': '$_dhan/tenant/',
      });
    final service = McpOAuthService(httpClient: _client(responses));
    addTearDown(service.dispose);

    await expectLater(
      service.discover('$_dhan/mcp'),
      throwsA(isA<McpOAuthException>()),
    );
  });

  for (final expectedIssuer in [_dhan, '$_dhan/']) {
    for (final issuer in [
      null,
      'https://other.example.com/',
      'http://mcp.dhan.co/',
      '$_dhan:8443/',
      '$_dhan/tenant',
      '$_dhan//',
      '$_dhan/?tenant=one',
      '$_dhan/#fragment',
      'https://user@mcp.dhan.co/',
    ]) {
      test(
        'delegated root $expectedIssuer still rejects issuer $issuer',
        () async {
          const origin = 'https://mcp.example.com';
          final service = McpOAuthService(
            httpClient: _client({
              '$origin$_resourcePath/mcp': _json({
                'resource': '$origin/mcp',
                'authorization_servers': [expectedIssuer],
              }),
              '$_dhan$_authorizationPath': _json({
                ..._authorizationMetadata(_dhan),
                'issuer': issuer,
              }),
            }),
          );
          addTearDown(service.dispose);

          await expectLater(
            service.discover('$origin/mcp'),
            throwsA(
              isA<McpOAuthException>().having(
                (error) => error.message,
                'message',
                contains('issuer is missing or does not match discovery'),
              ),
            ),
          );
        },
      );
    }
  }

  final invalidAuthorization = <String, Map<String, Object?>>{
    'wrong origin issuer': {'issuer': 'https://other.example.com'},
    'missing issuer': {'issuer': null},
    'missing PKCE': {'code_challenge_methods_supported': null},
    'plain PKCE': {
      'code_challenge_methods_supported': ['plain'],
    },
    'insecure authorization endpoint': {
      'authorization_endpoint': 'http://mcp-server.zomato.com/authorize',
    },
    'private token endpoint': {'token_endpoint': 'https://127.0.0.1/token'},
    'private registration endpoint': {
      'registration_endpoint': 'https://10.0.0.1/register',
    },
    'missing token endpoint': {'token_endpoint': null},
  };
  for (final entry in invalidAuthorization.entries) {
    test(
      'origin discovery rejects unsafe authorization metadata: ${entry.key}',
      () async {
        final responses = _responses(_zomato)
          ..['$_zomato$_authorizationPath'] = _json({
            ..._authorizationMetadata(_zomato),
            ...entry.value,
          });
        final service = McpOAuthService(httpClient: _client(responses));
        addTearDown(service.dispose);

        await expectLater(
          service.discover('$_zomato/mcp'),
          throwsA(isA<McpOAuthException>()),
        );
      },
    );
  }

  for (final (serverOrigin, origin) in [
    (_zomato, _zomato),
    (_dhan, _dhan),
    ('https://mcp.example.com', _zomato),
    ('https://mcp.example.com', _dhan),
  ]) {
    for (final wrongCallbackIssuer in [false, true]) {
      test(
        '$serverOrigin via $origin authorization binds tokens and callbacks to discovered issuer (wrong callback: $wrongCallbackIssuer)',
        () async {
          final responses = _responses(origin);
          final metadata = _authorizationMetadata(origin);
          final issuer = metadata['issuer']! as String;
          if (serverOrigin != origin) {
            responses['$serverOrigin$_resourcePath/mcp'] = _json({
              'resource': '$serverOrigin/mcp',
              'authorization_servers': [
                issuer.endsWith('/') ? origin : '$origin/',
              ],
            });
          }
          responses['$origin$_authorizationPath'] = _json({
            ...metadata,
            'authorization_response_iss_parameter_supported': true,
          });
          responses['$origin/register'] = _json({
            'client_id': 'registered-client',
          });
          responses['$origin/token'] = _json({
            'access_token': 'access-token',
            'token_type': 'Bearer',
          });
          final requests = <http.Request>[];
          final callback = _Callback(
            wrongCallbackIssuer
                ? (issuer.endsWith('/') ? origin : '$origin/')
                : issuer,
          );
          Uri? callbackServer;
          McpOAuthClientRegistration? registered;
          final service = McpOAuthService(
            httpClient: _client(responses, requests),
            callbackFactory:
                (authorizationServer, {expectedState, loopbackRedirect}) async {
                  callbackServer = authorizationServer;
                  return callback;
                },
          );
          addTearDown(service.dispose);

          final authorization = service.authorize(
            serverUrl: '$serverOrigin/mcp',
            serverName: 'Nonstandard MCP',
            onClientRegistered: (value) async => registered = value,
          );
          if (wrongCallbackIssuer) {
            await expectLater(
              authorization,
              throwsA(
                isA<McpOAuthException>().having(
                  (error) => error.message,
                  'message',
                  contains('authorization callback issuer mismatch'),
                ),
              ),
            );
            expect(
              requests.any((request) => request.url.path == '/token'),
              isFalse,
            );
          } else {
            final state = await authorization;
            expect(state.authorizationServer, issuer);
            expect(state.resource, '$serverOrigin/mcp');
            expect(state.accessToken, 'access-token');
            final tokenRequest = requests.singleWhere(
              (request) => request.url.path == '/token',
            );
            final tokenForm = Uri.splitQueryString(tokenRequest.body);
            expect(tokenForm['resource'], '$serverOrigin/mcp');
            expect(tokenForm['client_id'], 'registered-client');
            expect(
              oauthPkceChallenge(tokenForm['code_verifier']!),
              callback.authorizationUrl!.queryParameters['code_challenge'],
            );
            expect(
              callback
                  .authorizationUrl!
                  .queryParameters['code_challenge_method'],
              'S256',
            );
            expect(
              callback.authorizationUrl!.queryParameters['resource'],
              '$serverOrigin/mcp',
            );
          }
          expect(callbackServer.toString(), issuer);
          expect(registered!.authorizationServer, issuer);
          expect(callback.closed, isTrue);
        },
      );
    }
  }
}

Map<String, Object?> _authorizationMetadata(String origin) => {
  'issuer': origin == _zomato ? '$origin/' : origin,
  'authorization_endpoint': '$origin/authorize',
  'token_endpoint': '$origin/token',
  'registration_endpoint': '$origin/register',
  'code_challenge_methods_supported': ['S256'],
  'token_endpoint_auth_methods_supported': ['none'],
  if (origin == _zomato)
    'scopes_supported': ['mcp:tools', 'mcp:resources', 'mcp:prompts'],
};

Map<String, http.Response> _responses(String origin) => {
  '$origin/mcp': http.Response(
    '',
    401,
    headers: {
      'www-authenticate': origin == _zomato
          ? 'Bearer error="invalid_token", error_description="Authentication required"'
          : 'Bearer error="invalid_token", resource_metadata="$origin$_resourcePath/mcp"',
    },
  ),
  if (origin == _zomato)
    '$origin$_resourcePath': _json(_authorizationMetadata(origin))
  else
    '$origin$_resourcePath/mcp': _json({
      'resource': '$origin/mcp',
      'authorization_servers': ['$origin/'],
      'scopes_supported': [],
    }),
  '$origin$_authorizationPath': _json(_authorizationMetadata(origin)),
};

http.Response _json(Map<String, Object?> value) =>
    http.Response(jsonEncode(value), 200);

http.Client _client(
  Map<String, http.Response> responses, [
  List<http.Request>? requests,
]) => MockClient((request) async {
  requests?.add(request);
  return responses[request.url.toString()] ?? http.Response('', 404);
});

class _Callback implements OAuthCallback {
  _Callback(this.issuer);

  final String issuer;
  Uri? authorizationUrl;
  bool closed = false;

  @override
  final Uri redirectUri = Uri.parse('http://127.0.0.1:23456/callback');

  @override
  Future<Uri> authorize(
    Uri url,
    Duration timeout,
    OAuthUrlLauncher launch,
  ) async {
    authorizationUrl = url;
    return redirectUri.replace(
      queryParameters: {
        'code': 'authorization-code',
        'state': url.queryParameters['state']!,
        'iss': issuer,
      },
    );
  }

  @override
  Future<void> close() async => closed = true;

  @override
  Future<Uri> waitForCallback(Duration timeout) =>
      throw StateError('The test callback completes in authorize');
}
