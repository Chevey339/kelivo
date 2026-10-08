import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/api_keys.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_helpers.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api_key_manager.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/features/provider/widgets/share_provider_sheet.dart';

void main() {
  test('KelivoIN defaults expose the requested models and capabilities', () {
    final config = ProviderConfig.defaultsFor('KelivoIN');
    expect(config.baseUrl, 'https://api.psycheas.top/v1');
    expect(config.chatPath, '/chat/completions');
    expect(config.useResponseApi, isFalse);
    expect(config.models, [
      'Qwen/Qwen3-8B',
      'Qwen/Qwen3.5-4B',
      'THUDM/GLM-4-9B-0414',
      'auto',
    ]);
    for (final id in config.models) {
      final spec = ModelSpecResolver.instance.spec(config, id);
      expect(spec.supportsTool, isTrue, reason: id);
      expect(spec.supportsReasoning, id != 'THUDM/GLM-4-9B-0414', reason: id);
    }
    expect(
      ModelSpecResolver.instance.spec(config, 'auto').reasoning.dialect,
      ReasoningDialect.openaiReasoningEffort,
    );
  });

  test('KelivoIN resolves its token without storing it in settings', () {
    final config = ProviderConfig.defaultsFor('KelivoIN');
    final restored = ProviderConfig.fromJson(config.toJson());
    expect(config.apiKey, isEmpty);
    expect(config.toJson()['apiKey'], isEmpty);
    expect(restored.apiKey, isEmpty);
    final key = ApiKeyManager().effectiveKeyForProvider(restored);
    expect(
      sha256.convert(utf8.encode(key)).toString(),
      '1fb95460e2cb9531b2e7399f272af2974f5968e9a98b31f1214d19280c5dd44c',
    );
    expect(apiKeyForRequest(restored, 'auto'), key);
  });

  test('the built-in token is limited to the Kelivo HTTPS endpoint', () {
    final config = ProviderConfig.defaultsFor('KelivoIN');
    final manager = ApiKeyManager();
    for (final baseUrl in [
      'https://example.test/v1',
      'https://api.psycheas.top.example.test/v1',
      'http://api.psycheas.top/v1',
      'https://api.psycheas.top:8443/v1',
      '',
    ]) {
      expect(
        manager.effectiveKeyForProvider(config.copyWith(baseUrl: baseUrl)),
        isEmpty,
        reason: baseUrl,
      );
    }
  });

  test('shared KelivoIN configurations keep authentication after import', () {
    final config = ProviderConfig.defaultsFor('KelivoIN');
    final shared =
        jsonDecode(
              utf8.decode(
                base64Decode(
                  encodeProviderConfig(
                    config,
                  ).substring('ai-provider:v1:'.length),
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(shared['apiKey'], isEmpty);
    final imported = ProviderConfig.fromJson({
      ...shared,
      'id': 'OpenAI - KelivoIN',
    });
    expect(effectiveApiKey(imported), effectiveApiKey(config));
    expect(effectiveApiKey(imported.copyWith(apiKey: 'user-key')), 'user-key');
  });

  test('explicit keys and multi-key selection take precedence', () {
    final config = ProviderConfig.defaultsFor(
      'KelivoIN',
    ).copyWith(apiKey: 'user-key');
    expect(effectiveApiKey(config), 'user-key');
    final multiKey = config.copyWith(
      multiKeyEnabled: true,
      apiKeys: [
        ApiKeyConfig(id: 'first', key: 'first-key', createdAt: 1, updatedAt: 1),
        ApiKeyConfig(id: 'next', key: 'next-key', createdAt: 1, updatedAt: 1),
      ],
    );
    expect(effectiveApiKey(multiKey), 'first-key');
    expect(effectiveApiKey(multiKey), 'next-key');
  });

  test('SiliconFlow has no built-in models or fallback credentials', () {
    final config = ProviderConfig.defaultsFor('SiliconFlow');
    expect(config.baseUrl, 'https://api.siliconflow.cn/v1');
    expect(config.models, isEmpty);
    expect(config.modelOverrides, isEmpty);
    for (final id in ['THUDM/GLM-4-9B-0414', 'Qwen/Qwen3-8B']) {
      expect(apiKeyForRequest(config, id), isEmpty);
      expect(
        apiKeyForRequest(config.copyWith(apiKey: 'user-key'), id),
        'user-key',
      );
    }
  });

  test(
    'auto sends tools and OpenAI reasoning controls on chat requests',
    () async {
      final requests = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        expect(request.uri.path, '/v1/chat/completions');
        expect(request.headers.value('authorization'), 'Bearer user-key');
        requests.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': {'content': 'OK'},
                'finish_reason': 'stop',
              },
            ],
          })}\n\ndata: [DONE]\n\n',
        );
        await request.response.close();
      });
      final config = ProviderConfig.defaultsFor('KelivoIN').copyWith(
        apiKey: 'user-key',
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
      );
      const tools = [
        {
          'type': 'function',
          'function': {
            'name': 'echo',
            'description': 'Echo the input',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
      ];
      for (final level in [ReasoningLevel.high, ReasoningLevel.off]) {
        await ChatApiService.sendMessageStream(
          config: config,
          modelId: 'auto',
          messages: const [
            {'role': 'user', 'content': 'Hello'},
          ],
          tools: tools,
          reasoning: ReasoningRequest(level),
        ).toList();
      }
      expect(requests, hasLength(2));
      expect(requests[0]['reasoning_effort'], 'high');
      expect(requests[1]['reasoning_effort'], 'none');
      for (final request in requests) {
        expect(request['model'], 'auto');
        expect(request['tools'], tools);
        expect(request['stream'], isTrue);
      }
    },
  );
}
