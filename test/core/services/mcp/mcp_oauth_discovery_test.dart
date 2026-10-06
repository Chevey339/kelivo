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

McpOAuthService _service(String resource) => McpOAuthService(
  httpClient: MockClient((request) async {
    if (request.url.host == 'auth.example.com') {
      return http.Response(
        jsonEncode({
          'issuer': _issuer,
          'authorization_endpoint': '$_issuer/authorize',
          'token_endpoint': '$_issuer/token',
          'code_challenge_methods_supported': ['S256'],
        }),
        200,
      );
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
