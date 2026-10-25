import 'dart:convert';

import 'package:Kelivo/core/services/mcp/mcp_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final endpoint in [
    'https://mcp.swiggy.com/im',
    'https://mcp.zepto.co.in/mcp',
  ]) {
    test('root resource advertised by $endpoint is usable', () async {
      final origin = Uri.parse(endpoint).origin;
      final service = _service(origin);
      addTearDown(service.dispose);
      final discovery = await service.discover(
        endpoint,
        wwwAuthenticate: [
          'Bearer resource_metadata="$origin/.well-known/oauth-protected-resource"',
        ],
      );
      expect(discovery.resource.toString(), origin);
      expect(discovery.authorizationServer.toString(), _issuer);
    });
  }

  for (final metadataUrl in [
    'https://mcp.example.com/.well-known/oauth-protected-resource',
    'https://metadata.example.com/.well-known/oauth-protected-resource',
  ]) {
    test(
      'explicit metadata at $metadataUrl can describe the endpoint',
      () async {
        const endpoint = 'https://mcp.example.com/mcp';
        final service = _service(endpoint);
        addTearDown(service.dispose);
        final discovery = await service.discover(
          endpoint,
          wwwAuthenticate: ['Bearer resource_metadata="$metadataUrl"'],
        );
        expect(discovery.resource.toString(), endpoint);
        expect(discovery.authorizationServer.toString(), _issuer);
      },
    );
  }

  test('root metadata fallback accepts the exact Liftosaur endpoint', () async {
    const endpoint = 'https://www.liftosaur.com/mcp';
    final requested = <Uri>[];
    final service = _service(
      endpoint,
      rootFallbackFor: endpoint,
      requested: requested,
    );
    addTearDown(service.dispose);

    final discovery = await service.discover(endpoint);

    expect(discovery.resource.toString(), endpoint);
    expect(discovery.authorizationServer.toString(), _issuer);
    expect(requested.map((uri) => uri.toString()), [
      endpoint,
      'https://www.liftosaur.com/.well-known/oauth-protected-resource/mcp',
      'https://www.liftosaur.com/.well-known/oauth-protected-resource',
      '$_issuer/.well-known/oauth-authorization-server',
    ]);
  });

  for (final endpoint in [
    'https://mcp.example.com/team/mcp?tenant=one',
    'https://mcp.example.com/team/mcp/',
  ]) {
    test('root fallback preserves the exact endpoint $endpoint', () async {
      final service = _service(endpoint, rootFallbackFor: endpoint);
      addTearDown(service.dispose);

      final discovery = await service.discover(endpoint);

      expect(discovery.resource.toString(), endpoint);
    });
  }

  test('root fallback still accepts the original root resource', () async {
    const endpoint = 'https://mcp.example.com/team/mcp?tenant=one';
    const resource = 'https://mcp.example.com';
    final service = _service(resource, rootFallbackFor: endpoint);
    addTearDown(service.dispose);

    final discovery = await service.discover(endpoint);

    expect(discovery.resource.toString(), resource);
  });

  for (final resource in [
    'https://other.example.com/team/mcp?tenant=one',
    'http://mcp.example.com/team/mcp?tenant=one',
    'https://mcp.example.com:8443/team/mcp?tenant=one',
    'https://user@mcp.example.com/team/mcp?tenant=one',
    'https://mcp.example.com/team',
    'https://mcp.example.com/team/mc?tenant=one',
    'https://mcp.example.com/other?tenant=one',
    'https://mcp.example.com/team/mcp/child?tenant=one',
    'https://mcp.example.com/team/mcp?tenant=other',
    'https://mcp.example.com/team/mcp',
    'https://mcp.example.com/team/mcp/?tenant=one',
    'https://mcp.example.com/team/mcp?tenant=one#fragment',
  ]) {
    test('root fallback rejects a different resource: $resource', () async {
      const endpoint = 'https://mcp.example.com/team/mcp?tenant=one';
      final service = _service(resource, rootFallbackFor: endpoint);
      addTearDown(service.dispose);

      await expectLater(
        service.discover(endpoint),
        throwsA(
          isA<McpOAuthException>().having(
            (error) => error.message,
            'message',
            contains('resource does not match the requested resource'),
          ),
        ),
      );
    });
  }

  test(
    'root fallback still rejects an authorization issuer mismatch',
    () async {
      const endpoint = 'https://mcp.example.com/mcp';
      final service = _service(
        endpoint,
        rootFallbackFor: endpoint,
        metadataIssuer: '$_issuer/',
      );
      addTearDown(service.dispose);

      await expectLater(
        service.discover(endpoint),
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

  test('resource can cover a child endpoint at a path boundary', () async {
    final service = _service('https://mcp.example.com/team');
    addTearDown(service.dispose);
    final result = await service.discover(
      'https://mcp.example.com/team/mcp',
      wwwAuthenticate: const [
        'Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource/team"',
      ],
    );
    expect(result.resource.toString(), 'https://mcp.example.com/team');
  });

  for (final resource in [
    'https://other.example.com/team',
    'http://mcp.example.com/team',
    'https://mcp.example.com:8443/team',
    'https://mcp.example.com/tea',
    'https://mcp.example.com/other',
    'https://mcp.example.com/team/mcp/child',
    'https://mcp.example.com/team?tenant=other',
    'https://mcp.example.com/team#fragment',
  ]) {
    test('rejects resource outside the requested endpoint: $resource', () async {
      final service = _service(resource);
      addTearDown(service.dispose);
      await expectLater(
        service.discover(
          'https://mcp.example.com/team/mcp?tenant=one',
          wwwAuthenticate: const [
            'Bearer resource_metadata="https://metadata.example.com/document"',
          ],
        ),
        throwsA(isA<McpOAuthException>()),
      );
    });
  }

  test('constructed well-known URL must describe its own resource', () async {
    final service = _service('https://mcp.example.com/team');
    addTearDown(service.dispose);
    await expectLater(
      service.discover('https://mcp.example.com/team/mcp'),
      throwsA(isA<McpOAuthException>()),
    );
  });
}

const _issuer = 'https://auth.example.com';

McpOAuthService _service(
  String resource, {
  String? rootFallbackFor,
  String metadataIssuer = _issuer,
  List<Uri>? requested,
}) => McpOAuthService(
  httpClient: MockClient((request) async {
    requested?.add(request.url);
    if (request.url.host == 'auth.example.com') {
      return http.Response(
        jsonEncode({
          'issuer': metadataIssuer,
          'authorization_endpoint': '$_issuer/authorize',
          'token_endpoint': '$_issuer/token',
          'code_challenge_methods_supported': ['S256'],
        }),
        200,
      );
    }
    if (rootFallbackFor != null) {
      final endpoint = Uri.parse(rootFallbackFor);
      if (request.url == endpoint) return http.Response('', 405);
      if (request.url.toString() !=
          '${endpoint.origin}/.well-known/oauth-protected-resource') {
        return http.Response('not found', 404);
      }
    }
    return http.Response(
      jsonEncode({
        'resource': resource,
        'authorization_servers': [_issuer],
      }),
      200,
    );
  }),
);
