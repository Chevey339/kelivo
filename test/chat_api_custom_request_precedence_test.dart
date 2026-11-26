import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/request_tool_declarations.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _config(ProviderKind kind, String baseUrl, String modelId) =>
    ProviderConfig(
      id: 'CustomRequestTest',
      enabled: true,
      name: 'CustomRequestTest',
      apiKey: 'test-key',
      baseUrl: baseUrl,
      providerType: kind,
      chatPath: '/chat/completions',
      customHeaders: const [
        {'name': 'x-level', 'value': 'provider'},
        {'name': 'X-Provider', 'value': 'provider-only'},
        {'name': 'x-conversation-id', 'value': 'provider-conversation'},
      ],
      customBody: const [
        {'key': 'shared', 'value': 'provider'},
        {'key': 'providerOnly', 'value': 'true'},
        {'key': 'nested', 'value': '{"provider":true}'},
      ],
      modelOverrides: {
        modelId: const {
          'headers': [
            {'name': 'X-LEVEL', 'value': 'model'},
            {'name': 'X-Model', 'value': 'model-only'},
            {'name': 'X-CONVERSATION-ID', 'value': 'model-conversation'},
          ],
          'body': [
            {'key': 'shared', 'value': 'model'},
            {'key': 'modelOnly', 'value': '42'},
            {'key': 'nested', 'value': '{"model":true}'},
          ],
        },
      },
    );

Map<String, dynamic> _responseFor(ProviderKind kind) {
  switch (kind) {
    case ProviderKind.openai:
      return {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': 1,
          'completion_tokens': 1,
          'total_tokens': 2,
        },
      };
    case ProviderKind.claude:
      return {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      };
    case ProviderKind.google:
      return {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'ok'},
              ],
            },
          },
        ],
        'usageMetadata': {
          'promptTokenCount': 1,
          'candidatesTokenCount': 1,
          'totalTokenCount': 2,
        },
      };
  }
}

void main() {
  for (final kind in ProviderKind.values) {
    test(
      '${kind.name} sends merged custom request with expected priority',
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
          request.response.write(jsonEncode(_responseFor(kind)));
          await request.response.close();
        });

        final modelId = '${kind.name}-model';
        final baseUrl = 'http://${server.address.address}:${server.port}';
        final chunks = await ChatApiService.sendMessageStream(
          config: _config(kind, baseUrl, modelId),
          modelId: modelId,
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          extraHeaders: const {
            'X-Level': 'assistant',
            'X-Assistant': 'assistant-only',
            'X-Conversation-Id': 'conversation-123',
          },
          extraBody: const {
            'shared': 'assistant',
            'assistantOnly': '3',
            'nested': {'assistant': true},
          },
          stream: false,
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        expect(receivedHeaders.value('x-level'), 'model');
        expect(receivedHeaders.value('x-assistant'), 'assistant-only');
        expect(receivedHeaders.value('x-provider'), 'provider-only');
        expect(receivedHeaders.value('x-model'), 'model-only');
        expect(receivedHeaders.value('x-conversation-id'), 'conversation-123');
        expect(receivedBody['shared'], 'model');
        expect(receivedBody['assistantOnly'], 3);
        expect(receivedBody['providerOnly'], isTrue);
        expect(receivedBody['modelOnly'], 42);
        expect(receivedBody['nested'], {
          'assistant': true,
          'provider': true,
          'model': true,
        });
      },
    );
  }

  for (final overrideTools in [false, true]) {
    test(
      'tool callback sees the request declarations (override: $overrideTools)',
      () async {
        const kind = ProviderKind.openai;
        const model = 'openai-model';
        const fullName = LocalToolNames.askUser;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final sentNames = <List<String>>[];
        server.listen((request) async {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          sentNames.add([
            for (final tool in body['tools'] as List)
              tool['function']['name'] as String,
          ]);
          final response = _responseFor(kind);
          if (sentNames.length == 1) {
            response['choices'][0] = {
              'finish_reason': 'tool_calls',
              'message': {
                'role': 'assistant',
                'tool_calls': [
                  {
                    'id': 'call-1',
                    'type': 'function',
                    'function': {'name': 'ask_user_input', 'arguments': '{}'},
                  },
                ],
              },
            };
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(response));
          await request.response.close();
        });

        final seen = <String?>[];
        await ChatApiService.sendMessageStream(
          config: _config(
            kind,
            'http://${server.address.address}:${server.port}',
            model,
          ),
          modelId: model,
          messages: const [
            {'role': 'user', 'content': 'Ask a question'},
          ],
          tools: [LocalToolsService.definitionFor(fullName)],
          extraBody: overrideTools ? {'tools': <Map<String, dynamic>>[]} : null,
          onToolCall: (name, args, {toolCallId}) async {
            expect(name, 'ask_user_input');
            seen.add(RequestToolDeclarations.current?.advertisedName(fullName));
            return 'unknown_tool';
          },
          stream: false,
        ).drain<void>();
        final expected = overrideTools ? <String>[] : [fullName];
        expect(sentNames, [expected, expected]);
        expect(seen, [overrideTools ? null : fullName]);
      },
    );
  }
}
