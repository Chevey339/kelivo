import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/auth/oauth_callback.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_http_client.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_http_client_io.dart'
    show isPublicMcpOAuthAddress;
import 'package:Kelivo/core/services/mcp/mcp_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loopback callback listens before waitForCallback is called', () async {
    final callback = await openOAuthCallback(
      Uri.parse('https://auth.example.com'),
    );
    final redirectUri = callback.redirectUri;
    final client = HttpClient();

    try {
      final request = await client.getUrl(
        redirectUri.replace(
          queryParameters: const {'code': 'code', 'state': 'state'},
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      final responseBody = await utf8.decodeStream(response);
      final callbackUri = await callback.waitForCallback(
        const Duration(seconds: 2),
      );

      expect(callbackUri.queryParameters['code'], 'code');
      expect(callback.redirectUri, redirectUri);
      expect(responseBody, contains('You may close this window'));
      expect(responseBody, isNot(contains('kelivo://oauth-return')));
      expect(responseBody, isNot(contains('Authorization complete')));
    } finally {
      client.close(force: true);
      await callback.close();
    }
  });

  test('completes MCP OAuth discovery, PKCE, DCR, token, and refresh', () async {
    const serverUrl = 'https://mcp.example.com/tenant/mcp';
    const issuer = 'https://auth.example.com/tenant';
    final callback = _FakeCallback();
    Uri? launchedUrl;
    var tokenRequests = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.toString() == serverUrl) {
        return http.Response(
          '',
          401,
          headers: {
            'www-authenticate':
                'Bearer resource_metadata="https://mcp.example.com/oauth-meta", '
                'scope="tools:read"',
          },
        );
      }
      if (request.method == 'GET' &&
          request.url.toString() == 'https://mcp.example.com/oauth-meta') {
        return http.Response(
          jsonEncode({
            'resource': serverUrl,
            'authorization_servers': [issuer],
            'scopes_supported': ['tools:read', 'tools:write'],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.toString() ==
              'https://auth.example.com/.well-known/'
                  'oauth-authorization-server/tenant') {
        return http.Response(
          jsonEncode({
            'issuer': issuer,
            'authorization_endpoint': '$issuer/authorize',
            'token_endpoint': '$issuer/token',
            'registration_endpoint': '$issuer/register',
            'code_challenge_methods_supported': ['S256'],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.toString() == '$issuer/register') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['application_type'], 'native');
        expect(body['token_endpoint_auth_method'], 'none');
        expect(body['scope'], 'tools:read');
        expect(body['redirect_uris'], [callback.redirectUri.toString()]);
        return http.Response(jsonEncode({'client_id': 'kelivo-client'}), 201);
      }
      if (request.method == 'POST' &&
          request.url.toString() == '$issuer/token') {
        tokenRequests++;
        final form = Uri.splitQueryString(request.body);
        expect(form['resource'], serverUrl);
        expect(form['client_id'], 'kelivo-client');
        if (form['grant_type'] == 'authorization_code') {
          expect(form['code'], 'authorization-code');
          expect(form['code_verifier'], isNotEmpty);
          expect(form['redirect_uri'], callback.redirectUri.toString());
          return http.Response(
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'scope': 'tools:read',
            }),
            200,
          );
        }
        expect(form['grant_type'], 'refresh_token');
        expect(form['refresh_token'], 'refresh-1');
        return http.Response(
          jsonEncode({
            'access_token': 'access-2',
            'token_type': 'Bearer',
            'expires_in': 7200,
          }),
          200,
        );
      }
      return http.Response('not found: ${request.method} ${request.url}', 404);
    });
    final service = McpOAuthService(
      httpClient: client,
      callbackFactory: (authorizationServer) async {
        expect(authorizationServer.toString(), issuer);
        return callback;
      },
      launchAuthorizationUrl: (uri) async {
        launchedUrl = uri;
        scheduleMicrotask(
          () => callback.complete(
            callback.redirectUri.replace(
              queryParameters: {
                'code': 'authorization-code',
                'state': uri.queryParameters['state']!,
                'iss': issuer,
              },
            ),
          ),
        );
        return true;
      },
    );

    final state = await service.authorize(
      serverUrl: serverUrl,
      serverName: 'Test MCP',
    );

    expect(launchedUrl?.queryParameters['resource'], serverUrl);
    expect(launchedUrl?.queryParameters['scope'], 'tools:read');
    expect(launchedUrl?.queryParameters['code_challenge_method'], 'S256');
    expect(launchedUrl?.queryParameters['code_challenge'], isNotEmpty);
    expect(state.accessToken, 'access-1');
    expect(state.refreshToken, 'refresh-1');
    expect(state.registrationSource, McpOAuthClientRegistrationSource.dcr);
    expect(state.redirectUri, callback.redirectUri.toString());
    expect(callback.closed, isTrue);

    final refreshed = await service.refresh(state);
    expect(refreshed.accessToken, 'access-2');
    expect(refreshed.refreshToken, 'refresh-1');
    expect(refreshed.redirectUri, callback.redirectUri.toString());
    expect(tokenRequests, 2);
    service.dispose();
  });

  test(
    'discovery and same-scope DCR are reused while changed scopes re-register',
    () async {
      const serverUrl = 'https://mcp.example.com/mcp';
      const metadataUrl = 'https://mcp.example.com/oauth-resource';
      const issuer = 'https://auth.example.com';
      final callbacks = <_FakeCallback>[];
      var metadataRequests = 0;
      var authorizationMetadataRequests = 0;
      final registrationScopes = <String?>[];
      var launches = 0;
      final service = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == metadataUrl) {
            metadataRequests++;
            return http.Response(
              jsonEncode({
                'resource': serverUrl,
                'authorization_servers': [issuer],
              }),
              HttpStatus.ok,
            );
          }
          if (request.url.toString() ==
              '$issuer/.well-known/oauth-authorization-server') {
            authorizationMetadataRequests++;
            return http.Response(
              jsonEncode({
                'issuer': issuer,
                'authorization_endpoint': '$issuer/authorize',
                'token_endpoint': '$issuer/token',
                'registration_endpoint': '$issuer/register',
                'code_challenge_methods_supported': ['S256'],
              }),
              HttpStatus.ok,
            );
          }
          if (request.url.toString() == '$issuer/register') {
            registrationScopes.add(
              (jsonDecode(request.body) as Map<String, dynamic>)['scope']
                  as String?,
            );
            return http.Response(
              jsonEncode({'client_id': 'registered-client'}),
              HttpStatus.created,
            );
          }
          if (request.url.toString() == '$issuer/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'access-token',
                'token_type': 'Bearer',
              }),
              HttpStatus.ok,
            );
          }
          return http.Response('not found', HttpStatus.notFound);
        }),
        callbackFactory: (_) async {
          final callback = _FakeCallback();
          callbacks.add(callback);
          return callback;
        },
        launchAuthorizationUrl: (uri) async {
          final callback = callbacks.last;
          final currentLaunch = launches++;
          scheduleMicrotask(
            () => callback.complete(
              callback.redirectUri.replace(
                queryParameters: {
                  if (currentLaunch < 2)
                    'error': 'access_denied'
                  else
                    'code': 'authorization-code',
                  'state': uri.queryParameters['state']!,
                },
              ),
            ),
          );
          return true;
        },
      );
      addTearDown(service.dispose);
      const challenge = 'Bearer resource_metadata="$metadataUrl"';

      await service.prefetchAuthorization(
        serverUrl,
        wwwAuthenticate: const [challenge],
      );
      await expectLater(
        service.authorize(
          serverUrl: serverUrl,
          serverName: 'Retry MCP',
          wwwAuthenticate: const [challenge],
          additionalScopes: const ['tools:read'],
        ),
        throwsA(isA<McpOAuthException>()),
      );
      await expectLater(
        service.authorize(
          serverUrl: serverUrl,
          serverName: 'Retry MCP',
          wwwAuthenticate: const [challenge],
          additionalScopes: const ['tools:read'],
        ),
        throwsA(isA<McpOAuthException>()),
      );
      final state = await service.authorize(
        serverUrl: serverUrl,
        serverName: 'Retry MCP',
        wwwAuthenticate: const [challenge],
        additionalScopes: const ['tools:read', 'tools:write'],
      );

      expect(state.clientId, 'registered-client');
      expect(metadataRequests, 1);
      expect(authorizationMetadataRequests, 1);
      expect(registrationScopes, ['tools:read', 'tools:read tools:write']);
      expect(launches, 3);
    },
  );

  test(
    'discovery preserves query and strictly validates resource and issuer',
    () async {
      const serverUrl = 'https://mcp.example.com/tenant/mcp?tenant=a';
      const metadataUrl =
          'https://mcp.example.com/.well-known/'
          'oauth-protected-resource/tenant/mcp?tenant=a';
      const issuer = 'https://auth.example.com/tenant';
      final cases =
          <
            ({
              String name,
              String resource,
              String? metadataIssuer,
              bool succeeds,
            })
          >[
            (
              name: 'valid',
              resource: serverUrl,
              metadataIssuer: issuer,
              succeeds: true,
            ),
            (
              name: 'wrong resource',
              resource: 'https://mcp.example.com/other',
              metadataIssuer: issuer,
              succeeds: false,
            ),
            (
              name: 'missing issuer',
              resource: serverUrl,
              metadataIssuer: null,
              succeeds: false,
            ),
            (
              name: 'normalized issuer is not equal',
              resource: serverUrl,
              metadataIssuer: '$issuer/',
              succeeds: false,
            ),
          ];

      for (final testCase in cases) {
        final requested = <Uri>[];
        final service = McpOAuthService(
          httpClient: MockClient((request) async {
            requested.add(request.url);
            if (request.url.toString() == serverUrl) {
              return http.Response('', 405);
            }
            if (request.url.toString() == metadataUrl) {
              return http.Response(
                jsonEncode({
                  'resource': testCase.resource,
                  'authorization_servers': [issuer],
                }),
                200,
              );
            }
            if (request.url.toString() ==
                'https://auth.example.com/.well-known/'
                    'oauth-authorization-server/tenant') {
              return http.Response(
                jsonEncode({
                  if (testCase.metadataIssuer != null)
                    'issuer': testCase.metadataIssuer,
                  'authorization_endpoint': '$issuer/authorize',
                  'token_endpoint': '$issuer/token',
                  'code_challenge_methods_supported': ['S256'],
                }),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
        );
        try {
          if (testCase.succeeds) {
            final discovery = await service.discover(serverUrl);
            expect(discovery.resource.toString(), serverUrl);
          } else {
            await expectLater(
              service.discover(serverUrl),
              throwsA(isA<McpOAuthException>()),
              reason: testCase.name,
            );
          }
          expect(requested.map((uri) => uri.toString()), contains(metadataUrl));
        } finally {
          service.dispose();
        }
      }

      final service = McpOAuthService(
        httpClient: MockClient((_) async {
          return http.Response('', 404);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.discover('$serverUrl#fragment'),
        throwsA(isA<McpOAuthException>()),
      );
    },
  );

  test(
    'WWW-Authenticate parsing keeps challenge boundaries and explicit metadata does not fall back',
    () async {
      expect(
        McpOAuthService.bearerChallengeParameter(const [
          'Bearer requested_scope="wrong", Basic scope="basic"',
        ], 'scope'),
        isNull,
      );
      expect(
        McpOAuthService.bearerChallengeParameter(const [
          'Bearer error_description="quoted\\"value"',
        ], 'error_description'),
        'quoted"value',
      );
      expect(
        McpOAuthService.bearerChallengeParameterForError(
          const [
            'Bearer error="insufficient_scope", Basic realm="other", '
                'scope="must-not-leak"',
          ],
          'insufficient_scope',
          'scope',
        ),
        isNull,
      );

      const serverUrl = 'https://mcp.example.com/mcp';
      const explicitMetadata = 'https://metadata.example.com/resource';
      var wellKnownRequests = 0;
      final service = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == explicitMetadata) {
            return http.Response(
              jsonEncode({
                'resource': 'https://mcp.example.com/wrong',
                'authorization_servers': ['https://auth.example.com'],
              }),
              200,
            );
          }
          if (request.url.path.startsWith(
            '/.well-known/oauth-protected-resource',
          )) {
            wellKnownRequests++;
            return http.Response(
              jsonEncode({
                'resource': serverUrl,
                'authorization_servers': ['https://auth.example.com'],
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.discover(
          serverUrl,
          wwwAuthenticate: const [
            'Basic realm="legacy", '
                'Bearer resource_metadata="$explicitMetadata", '
                'scope="tools:read", Basic realm="other"',
          ],
        ),
        throwsA(isA<McpOAuthException>()),
      );
      expect(wellKnownRequests, 0);
    },
  );

  test('DCR credentials are re-registered when the issuer changes', () async {
    const serverUrl = 'https://mcp.example.com/mcp';
    const metadataUrl = 'https://mcp.example.com/oauth-resource';
    const oldIssuer = 'https://old-auth.example.com';
    const issuer = 'https://auth.example.com';
    final callback = _FakeCallback();
    var registrations = 0;
    final service = McpOAuthService(
      httpClient: MockClient((request) async {
        if (request.url.toString() == metadataUrl) {
          return http.Response(
            jsonEncode({
              'resource': serverUrl,
              'authorization_servers': [issuer],
            }),
            200,
          );
        }
        if (request.url.toString() ==
            '$issuer/.well-known/oauth-authorization-server') {
          return http.Response(
            jsonEncode({
              'issuer': issuer,
              'authorization_endpoint': '$issuer/authorize',
              'token_endpoint': '$issuer/token',
              'registration_endpoint': '$issuer/register',
              'code_challenge_methods_supported': ['S256'],
            }),
            200,
          );
        }
        if (request.url.toString() == '$issuer/register') {
          registrations++;
          return http.Response(jsonEncode({'client_id': 'new-client'}), 201);
        }
        if (request.url.toString() == '$issuer/token') {
          expect(Uri.splitQueryString(request.body)['client_id'], 'new-client');
          return http.Response(
            jsonEncode({'access_token': 'access', 'token_type': 'Bearer'}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
      callbackFactory: (authorizationServer) async => callback,
      launchAuthorizationUrl: (uri) async {
        scheduleMicrotask(
          () => callback.complete(
            callback.redirectUri.replace(
              queryParameters: {
                'code': 'code',
                'state': uri.queryParameters['state']!,
              },
            ),
          ),
        );
        return true;
      },
    );
    addTearDown(service.dispose);

    final state = await service.authorize(
      serverUrl: serverUrl,
      serverName: 'Migrated MCP',
      wwwAuthenticate: const ['Bearer resource_metadata="$metadataUrl"'],
      clientRegistration: McpOAuthClientRegistration(
        clientId: 'old-client',
        authorizationServer: oldIssuer,
        redirectUri: callback.redirectUri.toString(),
        registrationSource: McpOAuthClientRegistrationSource.dcr,
      ),
    );

    expect(registrations, 1);
    expect(state.clientId, 'new-client');
    expect(state.authorizationServer, issuer);
    expect(state.registrationSource, McpOAuthClientRegistrationSource.dcr);
  });

  test('DCR credentials ignore only loopback port changes', () async {
    const serverUrl = 'https://mcp.example.com/mcp';
    const metadataUrl = 'https://mcp.example.com/oauth-resource';
    const issuer = 'https://auth.example.com';
    late _FakeCallback callback;
    var registrations = 0;
    final service = McpOAuthService(
      httpClient: MockClient((request) async {
        if (request.url.toString() == metadataUrl) {
          return http.Response(
            jsonEncode({
              'resource': serverUrl,
              'authorization_servers': [issuer],
            }),
            200,
          );
        }
        if (request.url.toString() ==
            '$issuer/.well-known/oauth-authorization-server') {
          return http.Response(
            jsonEncode({
              'issuer': issuer,
              'authorization_endpoint': '$issuer/authorize',
              'token_endpoint': '$issuer/token',
              'registration_endpoint': '$issuer/register',
              'code_challenge_methods_supported': ['S256'],
            }),
            200,
          );
        }
        if (request.url.toString() == '$issuer/register') {
          registrations++;
          return http.Response(jsonEncode({'client_id': 'new-client'}), 201);
        }
        if (request.url.toString() == '$issuer/token') {
          return http.Response(
            jsonEncode({'access_token': 'access', 'token_type': 'Bearer'}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
      callbackFactory: (authorizationServer) async =>
          callback = _FakeCallback(),
      launchAuthorizationUrl: (uri) async {
        scheduleMicrotask(
          () => callback.complete(
            callback.redirectUri.replace(
              queryParameters: {
                'code': 'code',
                'state': uri.queryParameters['state']!,
              },
            ),
          ),
        );
        return true;
      },
    );
    addTearDown(service.dispose);

    final reusedState = await service.authorize(
      serverUrl: serverUrl,
      serverName: 'Migrated MCP',
      wwwAuthenticate: const ['Bearer resource_metadata="$metadataUrl"'],
      clientRegistration: const McpOAuthClientRegistration(
        clientId: 'old-client',
        authorizationServer: issuer,
        redirectUri: 'http://127.0.0.1:12345/oauth/callback',
        registrationSource: McpOAuthClientRegistrationSource.dcr,
      ),
    );

    expect(registrations, 0);
    expect(reusedState.clientId, 'old-client');

    final replacedState = await service.authorize(
      serverUrl: serverUrl,
      serverName: 'Migrated MCP',
      wwwAuthenticate: const ['Bearer resource_metadata="$metadataUrl"'],
      clientRegistration: const McpOAuthClientRegistration(
        clientId: 'old-client',
        authorizationServer: issuer,
        redirectUri: 'http://127.0.0.1:12345/old-callback',
        registrationSource: McpOAuthClientRegistrationSource.dcr,
      ),
    );

    expect(registrations, 1);
    expect(replacedState.clientId, 'new-client');
    expect(replacedState.redirectUri, callback.redirectUri.toString());
  });

  test('OAuth discovery rejects non-public resolved addresses', () async {
    expect(isPublicMcpOAuthAddress(InternetAddress('8.8.8.8')), isTrue);
    expect(
      isPublicMcpOAuthAddress(InternetAddress('2001:4860:4860::8888')),
      isTrue,
    );
    for (final address in [
      '10.0.0.1',
      '::1',
      '::ffff:127.0.0.1',
      '::ffff:0a00:0001',
      'fc00::1',
      '4000::1',
    ]) {
      expect(
        isPublicMcpOAuthAddress(InternetAddress(address)),
        isFalse,
        reason: address,
      );
    }
    final proxyFakeIp = InternetAddress('198.18.0.23');
    expect(isPublicMcpOAuthAddress(proxyFakeIp), isFalse);
    expect(
      isPublicMcpOAuthAddress(proxyFakeIp, allowProxyFakeIp: true),
      isTrue,
    );
    await expectLater(
      validateMcpOAuthPublicUri(Uri.parse('https://localhost/oauth')),
      throwsA(isA<SocketException>()),
    );
    await expectLater(
      validateMcpOAuthPublicUri(Uri.parse('https://198.18.0.23/oauth')),
      throwsA(isA<SocketException>()),
    );
  });

  test('authorization callback requires the exact redirect target', () async {
    const serverUrl = 'https://mcp.example.com/mcp';
    const metadataUrl = 'https://mcp.example.com/meta';
    const issuer = 'https://auth.example.com';
    const mismatchedCallbacks = [
      'https://127.0.0.1:54321/oauth/callback',
      'http://localhost:54321/oauth/callback',
      'http://127.0.0.1:54322/oauth/callback',
      'http://127.0.0.1:54321/oauth/other',
    ];

    for (final callbackBase in mismatchedCallbacks) {
      final callback = _FakeCallback();
      var tokenRequests = 0;
      final service = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == metadataUrl) {
            return http.Response(
              jsonEncode({
                'resource': serverUrl,
                'authorization_servers': [issuer],
              }),
              200,
            );
          }
          if (request.url.toString() ==
              '$issuer/.well-known/oauth-authorization-server') {
            return http.Response(
              jsonEncode({
                'issuer': issuer,
                'authorization_endpoint': '$issuer/authorize',
                'token_endpoint': '$issuer/token',
                'code_challenge_methods_supported': ['S256'],
              }),
              200,
            );
          }
          if (request.url.toString() == '$issuer/token') {
            tokenRequests++;
          }
          return http.Response('not found', 404);
        }),
        callbackFactory: (authorizationServer) async => callback,
        launchAuthorizationUrl: (uri) async {
          scheduleMicrotask(
            () => callback.complete(
              Uri.parse(callbackBase).replace(
                queryParameters: {
                  'code': 'code',
                  'state': uri.queryParameters['state']!,
                },
              ),
            ),
          );
          return true;
        },
      );

      try {
        await expectLater(
          service.authorize(
            serverUrl: serverUrl,
            serverName: 'Test',
            wwwAuthenticate: const ['Bearer resource_metadata="$metadataUrl"'],
            clientRegistration: const McpOAuthClientRegistration(
              clientId: 'pre-registered-client',
            ),
          ),
          throwsA(
            isA<McpOAuthException>().having(
              (error) => error.message,
              'message',
              contains('redirect URI mismatch'),
            ),
          ),
          reason: callbackBase,
        );
        expect(tokenRequests, 0, reason: callbackBase);
      } finally {
        service.dispose();
      }
    }
  });

  test('authorization callback validates all issuer parameter cases', () async {
    const serverUrl = 'https://mcp.example.com/mcp';
    const issuer = 'https://auth.example.com';
    final cases = <({bool advertised, String? callbackIssuer, bool succeeds})>[
      (advertised: true, callbackIssuer: issuer, succeeds: true),
      (advertised: true, callbackIssuer: null, succeeds: false),
      (advertised: false, callbackIssuer: issuer, succeeds: true),
      (advertised: false, callbackIssuer: null, succeeds: true),
      (
        advertised: false,
        callbackIssuer: 'https://other.example.com',
        succeeds: false,
      ),
    ];

    for (final testCase in cases) {
      final callback = _FakeCallback();
      final service = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == serverUrl) {
            return http.Response(
              '',
              401,
              headers: {
                'www-authenticate':
                    'Bearer resource_metadata="https://mcp.example.com/meta"',
              },
            );
          }
          if (request.url.toString() == 'https://mcp.example.com/meta') {
            return http.Response(
              jsonEncode({
                'resource': serverUrl,
                'authorization_servers': [issuer],
              }),
              200,
            );
          }
          if (request.url.toString() ==
              '$issuer/.well-known/oauth-authorization-server') {
            return http.Response(
              jsonEncode({
                'issuer': issuer,
                'authorization_endpoint': '$issuer/authorize',
                'token_endpoint': '$issuer/token',
                'code_challenge_methods_supported': ['S256'],
                'authorization_response_iss_parameter_supported':
                    testCase.advertised,
                'client_id_metadata_document_supported': true,
              }),
              200,
            );
          }
          if (request.url.toString() == '$issuer/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'access-token',
                'token_type': 'Bearer',
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        callbackFactory: (authorizationServer) async => callback,
        launchAuthorizationUrl: (uri) async {
          scheduleMicrotask(() {
            callback.complete(
              callback.redirectUri.replace(
                queryParameters: {
                  'code': 'code',
                  'state': uri.queryParameters['state']!,
                  if (testCase.callbackIssuer != null)
                    'iss': testCase.callbackIssuer!,
                },
              ),
            );
          });
          return true;
        },
      );
      try {
        final authorization = service.authorize(
          serverUrl: serverUrl,
          serverName: 'Test',
          clientRegistration: const McpOAuthClientRegistration(
            clientId: 'pre-registered-client',
          ),
        );
        if (testCase.succeeds) {
          expect((await authorization).accessToken, 'access-token');
        } else {
          await expectLater(authorization, throwsA(isA<McpOAuthException>()));
        }
      } finally {
        service.dispose();
      }
    }
  });

  test(
    'refresh honors client auth and distinguishes rejected, transient, and timeout errors',
    () async {
      final basicService = McpOAuthService(
        httpClient: MockClient((request) async {
          expect(
            request.headers['authorization'],
            'Basic ${base64Encode(utf8.encode('client:secret'))}',
          );
          final form = Uri.splitQueryString(request.body);
          expect(form, isNot(contains('client_id')));
          expect(form, isNot(contains('client_secret')));
          return http.Response(
            jsonEncode({'access_token': 'fresh', 'token_type': 'Bearer'}),
            200,
          );
        }),
      );
      final basicState = _oauthState(
        clientSecret: 'secret',
        tokenEndpointAuthMethod: 'client_secret_basic',
      );
      expect((await basicService.refresh(basicState)).accessToken, 'fresh');
      basicService.dispose();

      for (final testCase in [
        (
          status: 400,
          body: jsonEncode({'error': 'invalid_grant'}),
          kind: McpOAuthFailureKind.authorizationRequired,
        ),
        (
          status: 401,
          body: jsonEncode({'error': 'invalid_client'}),
          kind: McpOAuthFailureKind.invalidResponse,
        ),
        (status: 503, body: 'unavailable', kind: McpOAuthFailureKind.transient),
      ]) {
        final service = McpOAuthService(
          httpClient: MockClient((_) async {
            return http.Response(testCase.body, testCase.status);
          }),
        );
        try {
          await expectLater(
            service.refresh(_oauthState()),
            throwsA(
              isA<McpOAuthException>().having(
                (error) => error.kind,
                'kind',
                testCase.kind,
              ),
            ),
          );
        } finally {
          service.dispose();
        }
      }

      final timeoutService = McpOAuthService(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('{}', 200);
        }),
        requestTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(timeoutService.dispose);
      await expectLater(
        timeoutService.refresh(_oauthState()),
        throwsA(
          isA<McpOAuthException>().having(
            (error) => error.isTransient,
            'isTransient',
            isTrue,
          ),
        ),
      );
    },
  );

  test('MCP server JSON keeps OAuth tokens only for their bound resource', () {
    final oauth = McpOAuthState(
      clientId: 'client-id',
      authorizationServer: 'https://auth.example.com',
      authorizationEndpoint: 'https://auth.example.com/authorize',
      tokenEndpoint: 'https://auth.example.com/token',
      resource: 'https://mcp.example.com/mcp',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(123456789),
    );
    final json = McpServerConfig(
      id: 'server',
      enabled: false,
      name: 'OAuth MCP',
      transport: McpTransportType.http,
      url: oauth.resource,
      oauth: oauth,
    ).toJson();

    expect(McpServerConfig.fromJson(json).oauth?.accessToken, 'access-token');
    json['url'] = 'https://other.example.com/mcp';
    expect(McpServerConfig.fromJson(json).oauth, isNull);
  });
}

McpOAuthState _oauthState({
  String? clientSecret,
  String tokenEndpointAuthMethod = 'none',
}) => McpOAuthState(
  clientId: 'client',
  clientSecret: clientSecret,
  authorizationServer: 'https://auth.example.com',
  authorizationEndpoint: 'https://auth.example.com/authorize',
  tokenEndpoint: 'https://auth.example.com/token',
  resource: 'https://mcp.example.com/mcp',
  scope: 'tools:read',
  tokenEndpointAuthMethod: tokenEndpointAuthMethod,
  accessToken: 'expired',
  refreshToken: 'refresh',
);

final class _FakeCallback implements OAuthCallback {
  final Completer<Uri> _callback = Completer<Uri>();

  @override
  final Uri redirectUri = Uri.parse('http://127.0.0.1:54321/oauth/callback');

  bool closed = false;

  void complete(Uri uri) => _callback.complete(uri);

  @override
  Future<Uri> authorize(
    Uri authorizationUrl,
    Duration timeout,
    OAuthUrlLauncher launchAuthorizationUrl,
  ) async {
    if (!await launchAuthorizationUrl(authorizationUrl)) {
      throw const OAuthCallbackException('launch failed');
    }
    return waitForCallback(timeout);
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) => _callback.future;

  @override
  Future<void> close() async => closed = true;
}
