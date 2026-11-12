import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import '../../../../../support/collect_generation.dart';

void main() {
  test(
    'OpenRouter sends Auto reasoning and respects custom body overrides',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        bodies.add(
          (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
              .cast<String, dynamic>(),
        );
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n'
          'data: [DONE]\n\n',
        );
        await request.response.close();
      });
      final config = ProviderConfig(
        id: 'OpenRouter',
        enabled: true,
        name: 'OpenRouter',
        apiKey: 'test-key',
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
        providerType: ProviderKind.openai,
      );

      Future<void> send(
        ReasoningLevel level, {
        Map<String, dynamic>? extraBody,
      }) async {
        final chunks = await ChatApiService.sendMessageStream(
          config: config,
          modelId: 'anthropic/claude-sonnet-4.6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          reasoning: ReasoningRequest(level),
          extraBody: extraBody,
        ).toList();
        expect(chunks.isGenerationDone, isTrue);
      }

      await send(ReasoningLevel.auto);
      expect(bodies.last['reasoning'], {'enabled': true});
      expect(bodies.last.containsKey('reasoning_effort'), isFalse);

      await send(ReasoningLevel.off);
      expect(bodies.last['reasoning'], {'enabled': false});

      await send(ReasoningLevel.low);
      expect(bodies.last['reasoning'], {'effort': 'low'});

      await send(
        ReasoningLevel.auto,
        extraBody: {
          'reasoning': {'enabled': false, 'exclude': true},
        },
      );
      expect(bodies.last['reasoning'], {'enabled': false, 'exclude': true});

      await send(
        ReasoningLevel.auto,
        extraBody: {
          'reasoning': {'exclude': true},
        },
      );
      // Custom reasoning objects intentionally replace the generated object.
      expect(bodies.last['reasoning'], {'exclude': true});
    },
  );
}
