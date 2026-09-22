import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/provider_request_headers.dart';

ProviderConfig _requestyConfig({String? baseUrl}) {
  return ProviderConfig(
    id: 'Requesty',
    enabled: true,
    name: 'Requesty',
    apiKey: 'test-key',
    baseUrl: baseUrl ?? 'https://router.requesty.ai/v1',
    providerType: ProviderKind.openai,
  );
}

void main() {
  group('Requesty provider', () {
    test('default preset is a disabled OpenAI compatible provider', () {
      final requesty = ProviderConfig.defaultsFor('Requesty');

      expect(requesty.enabled, isFalse);
      expect(requesty.providerType, ProviderKind.openai);
      expect(requesty.baseUrl, 'https://router.requesty.ai/v1');
      expect(requesty.chatPath, '/chat/completions');
      expect(requesty.models, isEmpty);
      expect(requesty.modelOverrides, isEmpty);
      expect(requesty.balanceEnabled, isFalse);
    });

    test('is detected by host or provider id', () {
      expect(isRequestyProvider(_requestyConfig()), isTrue);
      expect(
        isRequestyProvider(
          _requestyConfig(baseUrl: 'https://router.eu.requesty.ai/v1'),
        ),
        isTrue,
      );
      expect(
        isRequestyProvider(
          ProviderConfig(
            id: 'Custom',
            enabled: true,
            name: 'Custom',
            apiKey: '',
            baseUrl: 'https://api.openai.com/v1',
            providerType: ProviderKind.openai,
          ),
        ),
        isFalse,
      );
    });

    test('sends attribution headers', () {
      expect(providerDefaultHeaders(_requestyConfig()), {
        'HTTP-Referer': 'https://github.com/Chevey339/kelivo',
        'X-Title': 'Kelivo',
      });
    });

    test('lists managed policies before the full catalog', () async {
      final requestedPaths = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requestedPaths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'object': 'list',
            'data': request.uri.path.endsWith('/managed')
                ? [
                    {'id': 'claude-sonnet-4-5', 'api': 'chat'},
                    {'id': 'gpt-5.4-mini', 'api': 'chat'},
                  ]
                : [
                    {'id': 'openai/gpt-4o-mini', 'api': 'chat'},
                    {'id': 'gpt-5.4-mini', 'api': 'chat'},
                  ],
          }),
        );
        await request.response.close();
      });

      final config = _requestyConfig(
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
      );
      final models = await ProviderManager.listModels(config);

      expect(requestedPaths, ['/v1/models/managed', '/v1/models']);
      expect(models.map((model) => model.id), [
        'claude-sonnet-4-5',
        'gpt-5.4-mini',
        'openai/gpt-4o-mini',
      ]);
    });

    test('falls back to the full catalog when managed list fails', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        if (request.uri.path.endsWith('/managed')) {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'id': 'openai/gpt-4o-mini'},
            ],
          }),
        );
        await request.response.close();
      });

      final config = _requestyConfig(
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
      );
      final models = await ProviderManager.listModels(config);

      expect(models.map((model) => model.id), ['openai/gpt-4o-mini']);
    });
  });
}
