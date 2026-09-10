import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/chat/runtime_context.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

List<Map<String, dynamic>> preparedMessages() {
  final messages = <Map<String, dynamic>>[
    {'role': 'system', 'content': 'Stable system instructions'},
    {'role': 'user', 'content': 'hello', multimodalInternalRevisionIdKey: 'u'},
  ];
  injectRuntimeContext(
    messages,
    RuntimeContextSnapshot.capture(
      assistant: const Assistant(
        id: 'a',
        name: 'A',
        appendCurrentTimeToUserMessage: true,
      ),
      now: DateTime.utc(2026, 9, 10, 12),
      appLocale: '',
      modelName: '',
      modelId: '',
    ),
  );
  for (final message in messages) {
    message.remove(multimodalInternalRevisionIdKey);
    message.remove(kelivoContextSegmentsKey);
  }
  return messages;
}

void main() {
  for (final protocol in ['chat', 'responses', 'claude', 'gemini']) {
    test(
      '$protocol serializes runtime metadata once without changing system instructions',
      () async {
        final requests = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          requests.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          final response = switch (protocol) {
            'responses' => {
              'id': 'resp_1',
              'object': 'response',
              'status': 'completed',
              'output_text': 'ok',
              'output': [],
            },
            'claude' => {
              'id': 'msg_1',
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'ok'},
              ],
              'stop_reason': 'end_turn',
              'usage': {'input_tokens': 5, 'output_tokens': 1},
            },
            'gemini' => {
              'candidates': [
                {
                  'content': {
                    'role': 'model',
                    'parts': [
                      {'text': 'ok'},
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
            },
            _ => {
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
            },
          };
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(response));
          await request.response.close();
        });
        final kind = switch (protocol) {
          'claude' => ProviderKind.claude,
          'gemini' => ProviderKind.google,
          _ => ProviderKind.openai,
        };
        await ChatApiService.sendMessageStream(
          config: ProviderConfig(
            id: 'fixture',
            name: 'Fixture',
            enabled: true,
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            apiKey: 'fixture-key',
            providerType: kind,
            useResponseApi: protocol == 'responses',
          ),
          modelId: switch (protocol) {
            'claude' => 'claude-sonnet-4-6',
            'gemini' => 'gemini-3.1-flash',
            _ => 'gpt-4.1',
          },
          messages: preparedMessages(),
          stream: false,
          thinkingBudget: 0,
          retryOverride: const AutoRetryOptions.defaults(),
        ).toList();
        expect(requests, hasLength(1));
        final encoded = jsonEncode(requests.single);
        expect('<runtime_context>'.allMatches(encoded), hasLength(1));
        expect(encoded, contains('2026-09-10T12:00:00+00:00'));
        expect(encoded, contains('Stable system instructions'));
        expect(encoded, isNot(contains('_kelivo_')));
        if (protocol == 'claude') {
          expect(
            jsonEncode(requests.single['system']),
            isNot(contains('runtime_context')),
          );
        } else if (protocol == 'gemini') {
          expect(
            jsonEncode(requests.single['systemInstruction']),
            isNot(contains('runtime_context')),
          );
        } else if (protocol == 'responses') {
          expect(
            jsonEncode(requests.single['instructions']),
            isNot(contains('runtime_context')),
          );
          expect(
            jsonEncode(requests.single['instructions']),
            contains('Stable system instructions'),
          );
        } else {
          final items =
              (requests.single[protocol == 'chat' ? 'messages' : 'input']
                  as List);
          expect(jsonEncode(items.first), isNot(contains('runtime_context')));
        }
      },
    );
  }

  test(
    'HTTP retry and client-tool continuation retain the same time block',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var executed = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        bodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType.json;
        if (bodies.length == 1) {
          request.response.statusCode = 503;
          request.response.write('{"error":{"message":"retry"}}');
        } else {
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': bodies.length == 2 ? 'tool_calls' : 'stop',
                  'message': bodies.length == 2
                      ? {
                          'role': 'assistant',
                          'content': '',
                          'tool_calls': [
                            {
                              'id': 'call_1',
                              'type': 'function',
                              'function': {'name': 'probe', 'arguments': '{}'},
                            },
                          ],
                        }
                      : {'role': 'assistant', 'content': 'done'},
                },
              ],
            }),
          );
        }
        await request.response.close();
      });
      await ChatApiService.sendMessageStream(
        config: ProviderConfig(
          id: 'fixture',
          name: 'Fixture',
          enabled: true,
          apiKey: 'fixture-key',
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          providerType: ProviderKind.openai,
        ),
        modelId: 'gpt-4.1',
        messages: preparedMessages(),
        stream: false,
        tools: [
          {
            'type': 'function',
            'function': {
              'name': 'probe',
              'parameters': {'type': 'object', 'properties': {}},
            },
          },
        ],
        onToolCall: (name, args, {toolCallId}) async {
          executed++;
          return 'done';
        },
        retryOverride: const AutoRetryOptions.defaults().copyWith(
          enabled: true,
          maxRetries: 1,
          initialDelayMs: 1,
          maxDelayMs: 1,
          jitter: false,
        ),
      ).toList();
      expect(bodies, hasLength(3));
      expect(executed, 1);
      for (final body in bodies) {
        final encoded = jsonEncode(body);
        expect('<runtime_context>'.allMatches(encoded), hasLength(1));
        expect(encoded, contains('2026-09-10T12:00:00+00:00'));
      }
      final messages = bodies.last['messages'] as List;
      expect(messages.map((message) => message['role']), [
        'system',
        'user',
        'assistant',
        'tool',
      ]);
      expect(messages.last['tool_call_id'], 'call_1');
    },
  );
}
