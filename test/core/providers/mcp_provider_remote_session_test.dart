import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_callback.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    '401 exposes authorization immediately while OAuth discovery continues',
    () async {
      const resourceMetadata = 'https://metadata.example.test/resource';
      const issuer = 'https://auth.example.test';
      final discoveryStarted = Completer<void>();
      final releaseDiscovery = Completer<void>();
      final server = await _MockMcpServer.start(
        initializeChallenge:
            'Bearer resource_metadata="$resourceMetadata", scope="tools:read"',
      );
      final oauthService = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == resourceMetadata) {
            if (!discoveryStarted.isCompleted) discoveryStarted.complete();
            await releaseDiscovery.future;
            return http.Response(
              jsonEncode({
                'resource': server.url,
                'authorization_servers': [issuer],
              }),
              HttpStatus.ok,
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
              HttpStatus.ok,
            );
          }
          return http.Response('not found', HttpStatus.notFound);
        }),
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'OAuth Remote',
          transport: McpTransportType.http,
          url: server.url,
        );

        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.needsAuthorization,
          timeout: const Duration(milliseconds: 500),
          label: 'authorization status before discovery completes',
        );
        await discoveryStarted.future.timeout(const Duration(seconds: 1));
      } finally {
        if (!releaseDiscovery.isCompleted) releaseDiscovery.complete();
        provider.dispose();
        oauthService.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'non-authorization connection failures do not start OAuth discovery',
    () async {
      final server = await _MockMcpServer.start(failInitialize: true);
      var oauthRequests = 0;
      final oauthService = McpOAuthService(
        httpClient: MockClient((request) async {
          oauthRequests++;
          return http.Response('not found', HttpStatus.notFound);
        }),
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Broken Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.error,
          label: 'connection error',
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(oauthRequests, 0);
      } finally {
        provider.dispose();
        oauthService.dispose();
        await harness.close();
        await server.close();
      }
    },
  );

  test(
    'uses the WWW-Authenticate challenge from the failed MCP POST',
    () async {
      const resourceMetadata = 'https://metadata.example.test/resource';
      const issuer = 'https://auth.example.test';
      final server = await _MockMcpServer.start(
        initializeChallenge:
            'Bearer resource_metadata="$resourceMetadata", scope="tools:read"',
      );
      var probeRequests = 0;
      final oauthService = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == server.url) {
            probeRequests++;
            return http.Response('', HttpStatus.methodNotAllowed);
          }
          if (request.url.toString() == resourceMetadata) {
            return http.Response(
              jsonEncode({
                'resource': server.url,
                'authorization_servers': [issuer],
              }),
              HttpStatus.ok,
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
              HttpStatus.ok,
            );
          }
          return http.Response('not found', HttpStatus.notFound);
        }),
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Challenge Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.needsAuthorization,
          label: 'OAuth challenge discovery',
        );

        expect(probeRequests, 0);
      } finally {
        provider.dispose();
        oauthService.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'OAuth bearer token is attached to MCP HTTP requests',
    () async {
      const authorization = 'Bearer access-token';
      final server = await _MockMcpServer.start(
        expectedAuthorization: authorization,
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'OAuth Remote',
          transport: McpTransportType.http,
          url: server.url,
          oauth: McpOAuthState(
            clientId: 'client-id',
            authorizationServer: 'https://auth.example.test',
            authorizationEndpoint: 'https://auth.example.test/authorize',
            tokenEndpoint: 'https://auth.example.test/token',
            resource: server.url,
            accessToken: 'access-token',
            tokenType: 'bearer',
          ),
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'OAuth tools',
        );

        final result = await provider.callTool(id, 'echo', const {});

        expect(result?.isError, isFalse);
        expect(server.rejectedAuthorizationCount, 0);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    '401 refreshes once while rejection and transient failures stay distinct',
    () async {
      final cases =
          <
            ({
              String name,
              int statusCode,
              String body,
              McpStatus expectedStatus,
              McpOAuthClientRegistrationSource registrationSource,
            })
          >[
            (
              name: 'success',
              statusCode: 200,
              body: jsonEncode({
                'access_token': 'fresh-token',
                'token_type': 'Bearer',
              }),
              expectedStatus: McpStatus.connected,
              registrationSource:
                  McpOAuthClientRegistrationSource.preRegistered,
            ),
            (
              name: 'invalid grant',
              statusCode: 400,
              body: jsonEncode({'error': 'invalid_grant'}),
              expectedStatus: McpStatus.needsAuthorization,
              registrationSource:
                  McpOAuthClientRegistrationSource.preRegistered,
            ),
            (
              name: 'invalid pre-registered client',
              statusCode: 401,
              body: jsonEncode({'error': 'invalid_client'}),
              expectedStatus: McpStatus.error,
              registrationSource:
                  McpOAuthClientRegistrationSource.preRegistered,
            ),
            (
              name: 'invalid dynamic client',
              statusCode: 401,
              body: jsonEncode({'error': 'invalid_client'}),
              expectedStatus: McpStatus.needsAuthorization,
              registrationSource: McpOAuthClientRegistrationSource.dcr,
            ),
            (
              name: 'provider unavailable',
              statusCode: 503,
              body: 'unavailable',
              expectedStatus: McpStatus.error,
              registrationSource:
                  McpOAuthClientRegistrationSource.preRegistered,
            ),
          ];

      for (final testCase in cases) {
        final server = await _MockMcpServer.start(
          expectedAuthorization: 'Bearer fresh-token',
        );
        final oauthService = McpOAuthService(
          httpClient: MockClient((request) async {
            expect(request.url.toString(), 'https://auth.example.test/token');
            return http.Response(testCase.body, testCase.statusCode);
          }),
        );
        final harness = await BusinessTestHarness.create();
        final provider = McpProvider(
          preferences: harness.preferences,
          oauthService: oauthService,
        );

        try {
          await _waitUntil(
            () => provider.servers.isNotEmpty,
            label: 'provider load for ${testCase.name}',
          );
          final id = await provider.addServer(
            enabled: true,
            name: testCase.name,
            transport: McpTransportType.http,
            url: server.url,
            oauth: McpOAuthState(
              clientId: 'client-id',
              authorizationServer: 'https://auth.example.test',
              authorizationEndpoint: 'https://auth.example.test/authorize',
              tokenEndpoint: 'https://auth.example.test/token',
              serverUrl: server.url,
              resource: server.url,
              accessToken: 'expired-token',
              refreshToken: 'refresh-token',
              registrationSource: testCase.registrationSource,
            ),
          );
          await _waitUntil(
            () => provider.statusFor(id) == testCase.expectedStatus,
            label: '${testCase.name} status',
          );
          if (testCase.expectedStatus == McpStatus.connected) {
            await _waitUntil(
              () => provider.getById(id)?.tools.length == 1,
              label: 'tools after refresh',
            );
            expect(provider.getById(id)?.oauth?.accessToken, 'fresh-token');
          } else {
            expect(provider.getById(id)?.oauth?.accessToken, 'expired-token');
          }
          expect(server.rejectedAuthorizationCount, 1);
        } finally {
          provider.dispose();
          oauthService.dispose();
          await harness.close();
          await server.close();
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 12)),
  );

  test(
    'a newly authorized token is not refreshed after its first 401',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const issuer = 'https://auth.example.test';
      const resourceMetadata = 'https://metadata.example.test/resource';
      final callback = _FakeOAuthCallback();
      final server = await _MockMcpServer.start(
        expectedAuthorization: 'Bearer accepted-token',
      );
      var tokenRequests = 0;
      final oauthService = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == server.url) {
            return http.Response(
              '',
              HttpStatus.unauthorized,
              headers: {
                HttpHeaders.wwwAuthenticateHeader:
                    'Bearer resource_metadata="$resourceMetadata"',
              },
            );
          }
          if (request.url.toString() == resourceMetadata) {
            return http.Response(
              jsonEncode({
                'resource': server.url,
                'authorization_servers': [issuer],
              }),
              HttpStatus.ok,
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
              HttpStatus.ok,
            );
          }
          if (request.url.toString() == '$issuer/token') {
            tokenRequests++;
            final grantType = Uri.splitQueryString(request.body)['grant_type'];
            return http.Response(
              jsonEncode({
                'access_token': grantType == 'refresh_token'
                    ? 'refreshed-token'
                    : 'fresh-token',
                'refresh_token': 'refresh-token',
                'token_type': 'Bearer',
              }),
              HttpStatus.ok,
            );
          }
          return http.Response('not found', HttpStatus.notFound);
        }),
        callbackFactory: (_) async => callback,
        launchAuthorizationUrl: (uri) async {
          scheduleMicrotask(
            () => callback.complete(
              callback.redirectUri.replace(
                queryParameters: {
                  'code': 'authorization-code',
                  'state': uri.queryParameters['state']!,
                },
              ),
            ),
          );
          return true;
        },
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Fresh token rejection',
          transport: McpTransportType.http,
          url: server.url,
          oauthClient: const McpOAuthClientRegistration(
            clientId: 'configured-client',
            authorizationServer: issuer,
          ),
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.needsAuthorization,
          label: 'initial authorization requirement',
        );

        expect(await provider.authorize(id), isFalse);
        expect(provider.statusFor(id), McpStatus.needsAuthorization);
        expect(tokenRequests, 1);
        expect(provider.getById(id)?.oauth?.accessToken, 'fresh-token');
      } finally {
        provider.dispose();
        oauthService.dispose();
        await harness.close();
        await server.close();
      }
    },
  );

  test(
    'safe refresh retries once and merges notification bursts',
    () async {
      final server = await _MockMcpServer.start(
        failFirstToolsList: true,
        sendToolsChangedBurst: true,
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial tools: ${server._counts}',
        );
        await _waitUntil(() => server.burstSent, label: 'notification burst');
        await _waitUntil(
          () => server.count('tools/list') >= 3,
          label: 'coalesced refresh: ${server._counts}',
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(server.count('initialize'), 1);
        expect(server.count('tools/list'), 3);
        expect(server.maxConcurrentToolsList, 1);
        expect(
          server.toolsListRequestTimes[1].difference(
            server.toolsListRequestTimes[0],
          ),
          greaterThanOrEqualTo(const Duration(milliseconds: 1900)),
        );

        server.coordinateCooldown = true;
        final olderSuccess = provider.callTool(id, 'slow-success', const {});
        await _waitUntil(
          () => server.count('tools/call') == 1,
          label: 'older tool call',
        );
        final limited = await provider.callTool(id, 'limited', const {});
        final callsAfterLimit = server.count('tools/call');
        expect((await olderSuccess)?.isError, isFalse);
        expect(provider.isInCooldown(id), isTrue);
        final blocked = await provider.callTool(id, 'echo', const {});

        expect(limited?.isError, isTrue);
        expect(blocked?.isError, isTrue);
        expect(provider.isInCooldown(id), isTrue);
        expect(server.count('tools/call'), callsAfterLimit);
        expect(server.count('initialize'), 1);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 12)),
  );

  test(
    'authorization stays generation-scoped and desktop retries the first connect',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const issuer = 'https://auth.example.test';
      const resourceMetadata = 'https://metadata.example.test/resource';
      final server = await _MockMcpServer.start(
        expectedAuthorization: 'Bearer access-2',
        failFirstInitialize: true,
      );
      final callbacks = <_FakeOAuthCallback>[];
      final launched = <Uri>[];
      final oauthService = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url.toString() == server.url) {
            return http.Response(
              '',
              401,
              headers: {
                HttpHeaders.wwwAuthenticateHeader:
                    'Bearer resource_metadata="$resourceMetadata"',
              },
            );
          }
          if (request.url.toString() == resourceMetadata) {
            return http.Response(
              jsonEncode({
                'resource': server.url,
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
            final code = Uri.splitQueryString(request.body)['code'];
            return http.Response(
              jsonEncode({
                'access_token': code == 'code-2' ? 'access-2' : 'access-1',
                'token_type': 'Bearer',
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        callbackFactory: (authorizationServer) async {
          final callback = _FakeOAuthCallback();
          callbacks.add(callback);
          return callback;
        },
        launchAuthorizationUrl: (uri) async {
          launched.add(uri);
          return true;
        },
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Generation OAuth',
          transport: McpTransportType.http,
          url: server.url,
          oauthClient: const McpOAuthClientRegistration(
            clientId: 'configured-client',
            authorizationServer: issuer,
          ),
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.needsAuthorization,
          label: 'initial authorization requirement',
        );

        final firstAuthorization = provider.authorize(id);
        await _waitUntil(() => launched.length == 1, label: 'first browser');

        await provider.updateServerMetadata(
          provider.getById(id)!.copyWith(name: 'Updated Generation OAuth'),
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.needsAuthorization,
          label: 'updated server authorization requirement',
        );

        final secondAuthorization = provider.authorize(id);
        await _waitUntil(() => launched.length == 2, label: 'second browser');
        callbacks[1].complete(
          callbacks[1].redirectUri.replace(
            queryParameters: {
              'code': 'code-2',
              'state': launched[1].queryParameters['state']!,
            },
          ),
        );
        expect(await secondAuthorization, isTrue);
        expect(server.count('initialize'), 2);

        callbacks[0].complete(
          callbacks[0].redirectUri.replace(
            queryParameters: {
              'code': 'code-1',
              'state': launched[0].queryParameters['state']!,
            },
          ),
        );
        expect(await firstAuthorization, isFalse);
        expect(provider.getById(id)?.oauth?.accessToken, 'access-2');
        expect(provider.statusFor(id), McpStatus.connected);
      } finally {
        for (var index = 0; index < callbacks.length; index++) {
          if (!callbacks[index].isCompleted && index < launched.length) {
            callbacks[index].complete(
              callbacks[index].redirectUri.replace(
                queryParameters: {
                  'error': 'access_denied',
                  'state': launched[index].queryParameters['state']!,
                },
              ),
            );
          }
        }
        provider.dispose();
        oauthService.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 12)),
  );

  test(
    '403 only requests step-up for insufficient_scope and bounds retries',
    () async {
      final server = await _MockMcpServer.start();
      const issuer = 'https://auth.example.test';
      final serverUri = Uri.parse(server.url);
      final resourceMetadata = serverUri.replace(
        path: '/.well-known/oauth-protected-resource${serverUri.path}',
      );
      _FakeOAuthCallback? activeCallback;
      var tokenCount = 0;
      final oauthService = McpOAuthService(
        httpClient: MockClient((request) async {
          if (request.url == resourceMetadata) {
            return http.Response(
              jsonEncode({
                'resource': server.url,
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
            tokenCount++;
            return http.Response(
              jsonEncode({
                'access_token': 'access-$tokenCount',
                'token_type': 'Bearer',
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        callbackFactory: (authorizationServer) async =>
            activeCallback = _FakeOAuthCallback(),
        launchAuthorizationUrl: (uri) async {
          final callback = activeCallback!;
          scheduleMicrotask(
            () => callback.complete(
              callback.redirectUri.replace(
                queryParameters: {
                  'code': 'code-$tokenCount',
                  'state': uri.queryParameters['state']!,
                },
              ),
            ),
          );
          return true;
        },
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Scoped Remote',
          transport: McpTransportType.http,
          url: server.url,
          oauth: McpOAuthState(
            clientId: 'client-id',
            authorizationServer: 'https://auth.example.test',
            authorizationEndpoint: 'https://auth.example.test/authorize',
            tokenEndpoint: 'https://auth.example.test/token',
            serverUrl: server.url,
            resource: server.url,
            scope: 'tools:read',
            accessToken: 'access-token',
            registrationSource: McpOAuthClientRegistrationSource.preRegistered,
          ),
          oauthClient: const McpOAuthClientRegistration(
            clientId: 'client-id',
            authorizationServer: issuer,
          ),
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial tools',
        );

        final denied = await provider.callTool(id, 'denied', const {});
        expect(
          (denied!.content.single as mcp.TextContent).text,
          contains('permission denied'),
        );
        expect(provider.statusFor(id), McpStatus.connected);

        for (var attempt = 0; attempt < 3; attempt++) {
          final result = await provider.callTool(id, 'scope', const {});
          expect(result?.isError, isTrue);
          if (attempt < 2) {
            expect(provider.statusFor(id), McpStatus.needsAuthorization);
            expect(await provider.authorize(id), isTrue);
            expect(provider.statusFor(id), McpStatus.connected);
          } else {
            expect(provider.statusFor(id), McpStatus.connected);
            expect(
              (result!.content.single as mcp.TextContent).text,
              contains('permission denied'),
            );
          }
        }
      } finally {
        provider.dispose();
        oauthService.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'unknown tool result is never replayed after a socket drop',
    () async {
      final server = await _MockMcpServer.start(dropFirstToolResponse: true);
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial tools: ${server._counts}',
        );

        final result = await provider.callTool(id, 'side-effect', const {});

        expect(result?.isError, isTrue);
        expect(
          (result!.content.single as mcp.TextContent).text,
          contains('result is unknown'),
        );
        expect(server.count('tools/call'), 1);
        expect(server.count('initialize'), 1);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'connect and manual reconnect are single-flight',
    () async {
      final firstInitializeGate = Completer<void>();
      final server = await _MockMcpServer.start(
        firstInitializeGate: firstInitializeGate,
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => server.count('initialize') == 1,
          label: 'first initialize: ${server._counts}',
        );

        final reconnect = provider.reconnect(id);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(server.count('initialize'), 1);
        firstInitializeGate.complete();

        expect(
          await reconnect.timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw StateError(
              'reconnect stuck: initialize=${server.count('initialize')} '
              'delete=${server.deleteCount} status=${provider.statusFor(id)}',
            ),
          ),
          isTrue,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'reconnected tools: ${server._counts}',
        );
        expect(server.count('initialize'), 2);
        expect(server.maxConcurrentInitialize, 1);
        expect(server.deleteCount, 1);
      } finally {
        if (!firstInitializeGate.isCompleted) firstInitializeGate.complete();
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'repeated GET 404 recovers the session once then stops',
    () async {
      final server = await _MockMcpServer.start(expireAllGets: true);
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.error,
          label: 'circuit open after repeated GET 404',
        );

        expect(server.count('initialize'), 2);
        expect(provider.errorFor(id), contains('Reconnect manually'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(server.count('initialize'), 2);

        expect(await provider.reconnect(id), isFalse);
        expect(provider.isConnected(id), isFalse);
        expect(provider.statusFor(id), McpStatus.error);
        expect(server.count('initialize'), 4);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'GET 404 replaces the expired session once',
    () async {
      final server = await _MockMcpServer.start(expireFirstGet: true);
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => server.count('initialize') == 2,
          label: 'replacement initialize',
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'replacement tools',
        );

        expect(server.count('initialize'), 2);
        expect(server.deleteCount, 0);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'concurrent session 404 responses share one replacement connection',
    () async {
      final server = await _MockMcpServer.start(
        rejectFirstSessionToolCalls: true,
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial tools',
        );

        final results = await Future.wait([
          provider.callTool(id, 'echo', const {'value': 'a'}),
          provider.callTool(id, 'echo', const {'value': 'b'}),
        ]);

        expect(results, everyElement(isNotNull));
        expect(results.map((result) => result!.isError), everyElement(isFalse));
        expect(server.count('initialize'), 2);
        expect(server.count('tools/call'), 4);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'server without tools capability stays connected with an empty list',
    () async {
      final server = await _MockMcpServer.start(supportsTools: false);
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Resources only',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.statusFor(id) == McpStatus.connected,
          label: 'resources-only connection',
        );

        expect(provider.getById(id)?.tools, isEmpty);
        expect(provider.errorFor(id), isNull);
        expect(server.count('tools/list'), 0);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'disabling returns before remote session termination finishes',
    () async {
      final deleteRelease = Completer<void>();
      final server = await _MockMcpServer.start(deleteRelease: deleteRelease);
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial tools',
        );

        final disabling = provider.updateServerMetadata(
          provider.getById(id)!.copyWith(enabled: false),
        );
        await _waitUntil(
          () => server.deleteCount == 1,
          label: 'session termination request',
        );
        await disabling.timeout(const Duration(milliseconds: 500));

        expect(provider.getById(id)?.enabled, isFalse);
        expect(provider.statusFor(id), McpStatus.idle);
        expect(deleteRelease.isCompleted, isFalse);
      } finally {
        if (!deleteRelease.isCompleted) deleteRelease.complete();
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'removing a server cannot deadlock with OAuth refresh persistence',
    () async {
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final oauthService = McpOAuthService(
        httpClient: MockClient((_) async {
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          await releaseRefresh.future;
          return http.Response(
            jsonEncode({'access_token': 'fresh-token', 'token_type': 'Bearer'}),
            200,
          );
        }),
      );
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(
        preferences: harness.preferences,
        oauthService: oauthService,
      );

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Refreshing Remote',
          transport: McpTransportType.http,
          url: 'http://127.0.0.1:9/mcp',
          oauth: McpOAuthState(
            clientId: 'client-id',
            authorizationServer: 'https://auth.example.test',
            authorizationEndpoint: 'https://auth.example.test/authorize',
            tokenEndpoint: 'https://auth.example.test/token',
            serverUrl: 'http://127.0.0.1:9/mcp',
            resource: 'http://127.0.0.1:9/mcp',
            accessToken: 'expired-token',
            refreshToken: 'refresh-token',
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        );
        await refreshStarted.future;

        final removal = provider.removeServer(id);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        releaseRefresh.complete();
        await removal.timeout(const Duration(seconds: 2));

        expect(provider.getById(id), isNull);
      } finally {
        if (!releaseRefresh.isCompleted) releaseRefresh.complete();
        provider.dispose();
        oauthService.dispose();
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'failed server persistence leaves existing connections untouched',
    () async {
      final server = await _MockMcpServer.start();
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Persistent Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial connection',
        );
        final exported = provider.exportServersAsUiJson();
        await harness.preferences.runWithRestoreWriteFence(() async {});

        await expectLater(
          provider.updateServerMetadata(
            provider.getById(id)!.copyWith(enabled: false),
          ),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          provider.removeServer(id),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          provider.replaceAllFromJson(exported),
          throwsA(isA<StateError>()),
        );

        expect(provider.getById(id)?.enabled, isTrue);
        expect(provider.isConnected(id), isTrue);
        expect(server.deleteCount, 0);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test('JSON editor hides OAuth secrets and preserves them on save', () async {
    final harness = await BusinessTestHarness.create();
    final provider = McpProvider(preferences: harness.preferences);

    try {
      await _waitUntil(
        () => provider.servers.isNotEmpty,
        label: 'provider load',
      );
      const url = 'https://mcp.example.test/mcp';
      final id = await provider.addServer(
        enabled: false,
        name: 'Secret Remote',
        transport: McpTransportType.http,
        url: url,
        oauth: const McpOAuthState(
          clientId: 'client-id',
          clientSecret: 'dynamic-secret',
          authorizationServer: 'https://auth.example.test',
          authorizationEndpoint: 'https://auth.example.test/authorize',
          tokenEndpoint: 'https://auth.example.test/token',
          serverUrl: url,
          resource: url,
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
        oauthClient: const McpOAuthClientRegistration(
          clientId: 'configured-client',
          clientSecret: 'configured-secret',
          tokenEndpointAuthMethod: 'client_secret_post',
        ),
      );

      final exported = provider.exportServersAsUiJson();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      final entry = ((decoded['mcpServers'] as Map)[id] as Map)
          .cast<String, dynamic>();
      expect(entry, isNot(contains('oauth')));
      expect(entry['oauthClient'], isNot(contains('clientSecret')));
      expect(exported, isNot(contains('access-token')));
      expect(exported, isNot(contains('refresh-token')));
      expect(exported, isNot(contains('configured-secret')));

      await provider.replaceAllFromJson(exported);
      expect(provider.getById(id)?.oauth?.accessToken, 'access-token');
      expect(
        provider.getById(id)?.oauthClient?.clientSecret,
        'configured-secret',
      );

      (entry['oauthClient'] as Map)['authorizationServer'] =
          'https://other-auth.example.test';
      await provider.replaceAllFromJson(jsonEncode(decoded));
      expect(provider.getById(id)?.oauthClient?.clientSecret, isNull);
    } finally {
      provider.dispose();
      await harness.close();
    }
  });

  test(
    'cached tools reconnect lazily and preserve validation errors',
    () async {
      final server = await _MockMcpServer.start();
      final harness = await BusinessTestHarness.create();
      final provider = McpProvider(preferences: harness.preferences);

      try {
        await _waitUntil(
          () => provider.servers.isNotEmpty,
          label: 'provider load',
        );
        final id = await provider.addServer(
          enabled: true,
          name: 'Remote',
          transport: McpTransportType.http,
          url: server.url,
        );
        await _waitUntil(
          () => provider.getById(id)?.tools.length == 1,
          label: 'initial tools',
        );
        await provider.setToolNeedsApproval(id, 'echo', true);

        final invalid = await provider.callTool(id, 'invalid', const {});
        expect(invalid?.isError, isTrue);
        expect(
          (invalid!.content.single as mcp.TextContent).text,
          contains('missing value'),
        );

        await provider.disconnect(id, terminateSession: false);
        expect(provider.getEnabledToolsForServers({id}), hasLength(1));
        expect(provider.toolNeedsApproval('echo'), isTrue);

        final reconnected = await provider.callTool(id, 'echo', const {});
        expect(reconnected?.isError, isFalse);
        expect(server.count('initialize'), 2);
      } finally {
        provider.dispose();
        await harness.close();
        await server.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String label = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('$label was not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

final class _FakeOAuthCallback implements McpOAuthCallback {
  final Completer<Uri> _callback = Completer<Uri>();

  @override
  final Uri redirectUri = Uri.parse('http://127.0.0.1:54321/oauth/callback');

  bool get isCompleted => _callback.isCompleted;

  void complete(Uri uri) => _callback.complete(uri);

  @override
  Future<Uri> authorize(
    Uri authorizationUrl,
    Duration timeout,
    McpOAuthUrlLauncher launchAuthorizationUrl,
  ) async {
    if (!await launchAuthorizationUrl(authorizationUrl)) {
      throw const McpOAuthCallbackException('launch failed');
    }
    return waitForCallback(timeout);
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) => _callback.future;

  @override
  Future<void> close() async {}
}

class _MockMcpServer {
  final HttpServer _server;
  final bool failInitialize;
  final bool failFirstInitialize;
  final bool failFirstToolsList;
  final bool sendToolsChangedBurst;
  final bool dropFirstToolResponse;
  final bool expireFirstGet;
  final bool expireAllGets;
  final bool rejectFirstSessionToolCalls;
  final bool supportsTools;
  final String? expectedAuthorization;
  final String? initializeChallenge;
  final Completer<void>? firstInitializeGate;
  final Completer<void>? deleteRelease;
  final Map<String, int> _counts = {};
  final List<HttpResponse> _openStreams = [];
  late final Future<void> _serving;
  HttpResponse? _publicStream;
  bool _toolsListSucceeded = false;
  bool _burstSent = false;
  int _activeInitialize = 0;
  int _activeToolsList = 0;
  int maxConcurrentInitialize = 0;
  int maxConcurrentToolsList = 0;
  int deleteCount = 0;
  int rejectedAuthorizationCount = 0;
  int _getCount = 0;
  final List<HttpResponse> _expiredToolResponses = [];
  final List<DateTime> toolsListRequestTimes = [];
  bool coordinateCooldown = false;

  bool get burstSent => _burstSent;

  _MockMcpServer._(
    this._server, {
    required this.failInitialize,
    required this.failFirstInitialize,
    required this.failFirstToolsList,
    required this.sendToolsChangedBurst,
    required this.dropFirstToolResponse,
    required this.expireFirstGet,
    required this.expireAllGets,
    required this.rejectFirstSessionToolCalls,
    required this.supportsTools,
    required this.expectedAuthorization,
    required this.initializeChallenge,
    required this.firstInitializeGate,
    required this.deleteRelease,
  }) {
    _serving = _serve();
  }

  static Future<_MockMcpServer> start({
    bool failInitialize = false,
    bool failFirstInitialize = false,
    bool failFirstToolsList = false,
    bool sendToolsChangedBurst = false,
    bool dropFirstToolResponse = false,
    bool expireFirstGet = false,
    bool expireAllGets = false,
    bool rejectFirstSessionToolCalls = false,
    bool supportsTools = true,
    String? expectedAuthorization,
    String? initializeChallenge,
    Completer<void>? firstInitializeGate,
    Completer<void>? deleteRelease,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _MockMcpServer._(
      server,
      failInitialize: failInitialize,
      failFirstInitialize: failFirstInitialize,
      failFirstToolsList: failFirstToolsList,
      sendToolsChangedBurst: sendToolsChangedBurst,
      dropFirstToolResponse: dropFirstToolResponse,
      expireFirstGet: expireFirstGet,
      expireAllGets: expireAllGets,
      rejectFirstSessionToolCalls: rejectFirstSessionToolCalls,
      supportsTools: supportsTools,
      expectedAuthorization: expectedAuthorization,
      initializeChallenge: initializeChallenge,
      firstInitializeGate: firstInitializeGate,
      deleteRelease: deleteRelease,
    );
  }

  String get url => 'http://${_server.address.address}:${_server.port}/mcp';

  int count(String method) => _counts[method] ?? 0;

  Future<void> close() async {
    for (final response in _openStreams) {
      unawaited(response.close());
    }
    await _server.close(force: true);
    await _serving.timeout(const Duration(seconds: 1), onTimeout: () {});
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      if (expectedAuthorization != null &&
          request.headers.value(HttpHeaders.authorizationHeader) !=
              expectedAuthorization) {
        rejectedAuthorizationCount++;
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        continue;
      }
      if (request.method == 'GET') {
        _getCount++;
        if (expireAllGets || (expireFirstGet && _getCount == 1)) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
        }
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(': connected\n\n');
        await request.response.flush();
        _publicStream = request.response;
        _openStreams.add(request.response);
        unawaited(_maybeSendBurst());
        continue;
      }
      if (request.method == 'DELETE') {
        deleteCount++;
        await request.drain<void>();
        await deleteRelease?.future;
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        continue;
      }

      final body = await utf8.decoder.bind(request).join();
      final message = jsonDecode(body) as Map<String, dynamic>;
      final method = message['method']?.toString();
      if (method != null) _counts[method] = count(method) + 1;

      switch (method) {
        case 'initialize':
          await _handleInitialize(request, message);
        case 'tools/list':
          await _handleToolsList(request, message);
        case 'tools/call':
          await _handleToolCall(request, message);
        default:
          request.response.statusCode = HttpStatus.accepted;
          await request.response.close();
      }
    }
  }

  Future<void> _handleInitialize(
    HttpRequest request,
    Map<String, dynamic> message,
  ) async {
    if (initializeChallenge != null) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.set(
        HttpHeaders.wwwAuthenticateHeader,
        initializeChallenge!,
      );
      await request.response.close();
      return;
    }
    if (failInitialize) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
      return;
    }
    if (failFirstInitialize && count('initialize') == 1) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
      return;
    }
    _activeInitialize++;
    if (_activeInitialize > maxConcurrentInitialize) {
      maxConcurrentInitialize = _activeInitialize;
    }
    if (count('initialize') == 1 && firstInitializeGate != null) {
      await firstInitializeGate!.future;
    }
    request.response.headers.set(
      'MCP-Session-Id',
      'session-${count('initialize')}',
    );
    _writeJson(request.response, {
      'jsonrpc': '2.0',
      'id': message['id'],
      'result': {
        'protocolVersion': mcp.McpProtocol.defaultVersion,
        'serverInfo': {'name': 'Mock', 'version': '1.0.0'},
        'capabilities': supportsTools
            ? {'tools': <String, dynamic>{}}
            : {'resources': <String, dynamic>{}},
      },
    });
    await request.response.close();
    _activeInitialize--;
  }

  Future<void> _handleToolsList(
    HttpRequest request,
    Map<String, dynamic> message,
  ) async {
    toolsListRequestTimes.add(DateTime.now());
    _activeToolsList++;
    if (_activeToolsList > maxConcurrentToolsList) {
      maxConcurrentToolsList = _activeToolsList;
    }
    try {
      if (failFirstToolsList && count('tools/list') == 1) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.headers.set(HttpHeaders.retryAfterHeader, '2');
        await request.response.close();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      _toolsListSucceeded = true;
      await _maybeSendBurst();
      _writeJson(request.response, {
        'jsonrpc': '2.0',
        'id': message['id'],
        'result': {
          'tools': [
            {
              'name': 'echo',
              'description': 'echo',
              'inputSchema': {'type': 'object'},
            },
          ],
        },
      });
      await request.response.close();
    } finally {
      _activeToolsList--;
    }
  }

  Future<void> _handleToolCall(
    HttpRequest request,
    Map<String, dynamic> message,
  ) async {
    final toolName = (message['params'] as Map?)?['name']?.toString();
    if (toolName == 'denied') {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    if (toolName == 'scope') {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.set(
        HttpHeaders.wwwAuthenticateHeader,
        'Bearer error="insufficient_scope", scope="tools:write"',
      );
      await request.response.close();
      return;
    }
    if (rejectFirstSessionToolCalls &&
        request.headers.value('MCP-Session-Id') == 'session-1') {
      _expiredToolResponses.add(request.response);
      if (_expiredToolResponses.length == 2) {
        for (final response in _expiredToolResponses) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
        }
      }
      return;
    }
    if (toolName == 'invalid') {
      _writeJson(request.response, {
        'jsonrpc': '2.0',
        'id': message['id'],
        'error': {'code': -32602, 'message': 'missing value'},
      });
      await request.response.close();
      return;
    }
    if (coordinateCooldown && toolName == 'limited') {
      request.response.statusCode = HttpStatus.tooManyRequests;
      request.response.headers.set(HttpHeaders.retryAfterHeader, '1');
      await request.response.close();
      return;
    }
    if (coordinateCooldown && toolName == 'slow-success') {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (dropFirstToolResponse && count('tools/call') == 1) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    _writeJson(request.response, {
      'jsonrpc': '2.0',
      'id': message['id'],
      'result': {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'isError': false,
      },
    });
    await request.response.close();
  }

  Future<void> _maybeSendBurst() async {
    final stream = _publicStream;
    if (!sendToolsChangedBurst ||
        !_toolsListSucceeded ||
        _burstSent ||
        stream == null) {
      return;
    }
    _burstSent = true;
    for (var index = 0; index < 10; index++) {
      stream.write(
        'data: ${jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/tools/list_changed'})}\n\n',
      );
    }
    await stream.flush();
  }

  void _writeJson(HttpResponse response, Object value) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
  }
}
