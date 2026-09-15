import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  for (final (kind, vertexAI, authHeader) in [
    (ProviderKind.openai, false, 'authorization'),
    (ProviderKind.claude, false, 'x-api-key'),
    (ProviderKind.google, false, 'x-goog-api-key'),
    (ProviderKind.google, true, 'authorization'),
  ]) {
    for (final customUserAgent in [null, 'User-Agent', 'user-agent']) {
      test('${kind.name} vertex=$vertexAI lists models with '
          '${customUserAgent ?? 'default'} headers', () async {
        late HttpHeaders receivedHeaders;
        late String receivedMethod;
        late Uri receivedUri;
        late String receivedBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          receivedHeaders = request.headers;
          receivedMethod = request.method;
          receivedUri = request.uri;
          receivedBody = await utf8.decoder.bind(request).join();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(
              kind == ProviderKind.google
                  ? {
                      'models': [
                        {
                          'name': 'models/test-model',
                          'supportedGenerationMethods': ['generateContent'],
                        },
                      ],
                    }
                  : {
                      'data': [
                        {'id': 'test-model'},
                      ],
                    },
            ),
          );
          await request.response.close();
        });

        final config = ProviderConfig(
          id: 'ListModelsTest',
          enabled: true,
          name: 'ListModelsTest',
          apiKey: 'test-key',
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          providerType: kind,
          vertexAI: vertexAI,
          customHeaders: [
            if (customUserAgent != null) ...[
              {'name': customUserAgent, 'value': 'GatewayClient/1.0'},
              {'name': authHeader.toUpperCase(), 'value': 'custom-auth'},
              {'name': ' X-Gateway-Key ', 'value': 'gateway-key'},
              if (kind == ProviderKind.claude)
                {'name': 'Anthropic-Version', 'value': 'custom-version'},
            ],
          ],
          customBody: const [
            {'key': 'chatOnly', 'value': 'true'},
          ],
          modelOverrides: const {
            'test-model': {
              'headers': [
                {'name': 'X-Model-Only', 'value': 'model'},
              ],
            },
          },
        );

        final models = await ProviderManager.listModels(config);

        expect(models.map((model) => model.id), contains('test-model'));
        expect(receivedMethod, 'GET');
        expect(receivedUri.path, '/v1/models');
        expect(receivedBody, isEmpty);
        expect(receivedHeaders.value('x-model-only'), isNull);
        expect(
          receivedHeaders.value('user-agent'),
          customUserAgent == null ? 'Kelivo' : 'GatewayClient/1.0',
        );
        expect(
          receivedHeaders.value(authHeader),
          customUserAgent != null
              ? 'custom-auth'
              : authHeader == 'authorization'
              ? 'Bearer test-key'
              : 'test-key',
        );
        expect(
          receivedHeaders.value('x-gateway-key'),
          customUserAgent == null ? isNull : 'gateway-key',
        );
        if (kind == ProviderKind.claude) {
          expect(
            receivedHeaders.value('anthropic-version'),
            customUserAgent == null
                ? ClaudeProvider.anthropicVersion
                : 'custom-version',
          );
        }
      });
    }
  }

  test(
    'connection test applies provider request and lets model override it',
    () async {
      late HttpHeaders receivedHeaders;
      late Map<String, dynamic> receivedBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        receivedHeaders = request.headers;
        receivedBody =
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{}');
        await request.response.close();
      });

      final config = ProviderConfig(
        id: 'ConnectionTest',
        enabled: true,
        name: 'ConnectionTest',
        apiKey: 'test-key',
        baseUrl: 'http://${server.address.address}:${server.port}',
        providerType: ProviderKind.openai,
        chatPath: '/chat/completions',
        customHeaders: const [
          {'name': 'X-Level', 'value': 'provider'},
          {'name': 'X-Provider', 'value': 'provider-only'},
        ],
        customBody: const [
          {'key': 'shared', 'value': 'provider'},
          {'key': 'providerOnly', 'value': 'true'},
        ],
        modelOverrides: const {
          'test-model': {
            'headers': [
              {'name': 'x-level', 'value': 'model'},
            ],
            'body': [
              {'key': 'shared', 'value': 'model'},
            ],
          },
        },
      );

      await ProviderManager.testConnection(config, 'test-model');

      expect(receivedHeaders.value('x-level'), 'model');
      expect(receivedHeaders.value('x-provider'), 'provider-only');
      expect(receivedBody['shared'], 'model');
      expect(receivedBody['providerOnly'], isTrue);
    },
  );
}
