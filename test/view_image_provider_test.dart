import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import 'support/collect_generation.dart';

enum _Api { chat, responses, claude, vertexClaude, gemini, gemini3 }

String _model(_Api api) => switch (api) {
  _Api.chat || _Api.responses => 'gpt-4.1',
  _Api.claude || _Api.vertexClaude => 'claude-sonnet-4-6',
  _Api.gemini => 'gemini-2.5-pro',
  _Api.gemini3 => 'gemini-3-flash-preview',
};

Map<String, dynamic> _response(_Api api, bool callTool) {
  final call = {
    'id': 'call_image',
    'type': 'function',
    'function': {'name': 'view_image', 'arguments': '{"path":"plot.png"}'},
  };
  return switch (api) {
    _Api.chat => {
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': callTool ? '' : 'red image',
            if (callTool) 'tool_calls': [call],
          },
          'finish_reason': callTool ? 'tool_calls' : 'stop',
        },
      ],
    },
    _Api.responses => {
      'id': 'response_1',
      'status': 'completed',
      'output': [
        if (callTool)
          {
            'type': 'function_call',
            'id': 'fc_image',
            'call_id': 'call_image',
            'name': 'view_image',
            'arguments': '{"path":"plot.png"}',
          }
        else
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'red image'},
            ],
          },
      ],
    },
    _Api.claude || _Api.vertexClaude => {
      'id': 'msg_1',
      'type': 'message',
      'role': 'assistant',
      'content': [
        if (callTool)
          {
            'type': 'tool_use',
            'id': 'call_image',
            'name': 'view_image',
            'input': {'path': 'plot.png'},
          }
        else
          {'type': 'text', 'text': 'red image'},
      ],
      'stop_reason': callTool ? 'tool_use' : 'end_turn',
      'usage': {'input_tokens': 5, 'output_tokens': 5},
    },
    _Api.gemini || _Api.gemini3 => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              if (callTool)
                {
                  'functionCall': {
                    'id': 'call_image',
                    'name': 'view_image',
                    'args': {'path': 'plot.png'},
                  },
                  'thoughtSignature': 'test-signature',
                }
              else
                {'text': 'red image'},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    },
  };
}

String _sse(_Api api, bool callTool) {
  final obj = _response(api, callTool);
  final events = switch (api) {
    _Api.chat => [
      {
        'choices': [
          {
            'delta': callTool
                ? {
                    'tool_calls': [
                      {
                        ...(obj['choices'][0]['message']['tool_calls'][0]
                            as Map),
                        'index': 0,
                      },
                    ],
                  }
                : {'content': 'red image'},
            'finish_reason': callTool ? 'tool_calls' : 'stop',
          },
        ],
      },
    ],
    _Api.responses => [
      if (callTool)
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': obj['output'][0],
        },
      if (!callTool)
        {
          'type': 'response.output_text.delta',
          'output_index': 0,
          'content_index': 0,
          'item_id': 'msg_1',
          'delta': 'red image',
        },
      {'type': 'response.completed', 'response': obj},
    ],
    _Api.claude || _Api.vertexClaude => [
      {
        'type': 'message_start',
        'message': {
          'id': 'msg_1',
          'usage': {'input_tokens': 5, 'output_tokens': 0},
        },
      },
      {
        'type': 'content_block_start',
        'index': 0,
        'content_block': callTool
            ? {
                'type': 'tool_use',
                'id': 'call_image',
                'name': 'view_image',
                'input': {},
              }
            : {'type': 'text', 'text': ''},
      },
      {
        'type': 'content_block_delta',
        'index': 0,
        'delta': callTool
            ? {
                'type': 'input_json_delta',
                'partial_json': '{"path":"plot.png"}',
              }
            : {'type': 'text_delta', 'text': 'red image'},
      },
      {'type': 'content_block_stop', 'index': 0},
      {
        'type': 'message_delta',
        'delta': {'stop_reason': callTool ? 'tool_use' : 'end_turn'},
        'usage': {'output_tokens': 5},
      },
      {'type': 'message_stop'},
    ],
    _Api.gemini || _Api.gemini3 => [obj],
  };
  return '${events.map((e) => '${e['type'] == null ? '' : 'event: ${e['type']}\n'}data: ${jsonEncode(e)}\n\n').join()}${api == _Api.chat ? 'data: [DONE]\n\n' : ''}';
}

List<String> _imagePayloads(dynamic value) {
  final out = <String>[];
  if (value is Map) {
    if (value['type'] == 'input_image') {
      out.add(Uri.parse(value['image_url'] as String).data!.contentText);
    } else if (value['type'] == 'image_url') {
      out.add(Uri.parse(value['image_url']['url'] as String).data!.contentText);
    } else if (value['type'] == 'image' && value['source'] is Map) {
      out.add(value['source']['data'] as String);
    } else if (value['inlineData'] is Map) {
      out.add(value['inlineData']['data'] as String);
    } else {
      for (final item in value.values) {
        out.addAll(_imagePayloads(item));
      }
    }
  } else if (value is List) {
    for (final item in value) {
      out.addAll(_imagePayloads(item));
    }
  }
  return out;
}

void main() {
  test(
    'Responses non-stream tool round resets omitted usage details',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) async {
        await request.drain<void>();
        final first = requests++ == 0;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            ..._response(_Api.responses, first),
            'usage': first
                ? {
                    'input_tokens': 100,
                    'output_tokens': 40,
                    'input_tokens_details': {'cached_tokens': 80},
                    'output_tokens_details': {'reasoning_tokens': 30},
                  }
                : {'input_tokens': 120, 'output_tokens': 5},
          }),
        );
        await request.response.close();
      });
      final chunks = await ChatApiService.sendMessageStream(
        config: ProviderConfig(
          id: 'responses-usage',
          name: 'responses-usage',
          enabled: true,
          apiKey: 'test-key',
          baseUrl: 'http://127.0.0.1:${server.port}',
          providerType: ProviderKind.openai,
          useResponseApi: true,
        ),
        modelId: 'gpt-4.1',
        stream: false,
        messages: const [
          {'role': 'user', 'content': 'Inspect plot.png'},
        ],
        tools: WorkspaceToolsService.definitions()
            .where((d) => (d['function'] as Map)['name'] == 'view_image')
            .toList(),
        onToolCall: (name, args, {toolCallId}) async => 'done',
      ).toList();
      expect(requests, 2);
      expect(chunks.lastUsage!.promptTokens, 120);
      expect(chunks.lastUsage!.completionTokens, 5);
      expect(chunks.lastUsage!.totalTokens, 125);
      expect(chunks.lastUsage!.cachedTokens, 0);
      expect(chunks.lastUsage!.reasoningTokens, 0);
      final merged = chunks
          .whereType<Usage>()
          .map((chunk) => chunk.usage)
          .reduce((previous, current) => previous.merge(current));
      expect(merged.cachedTokens, 0);
      expect(merged.reasoningTokens, 0);
    },
  );

  for (final api in _Api.values) {
    for (final stream in [false, true]) {
      test(
        '${api.name} stream=$stream sends image pixels on continuation and replay',
        () async {
          final dir = await Directory.systemTemp.createTemp('tool_image_wire_');
          addTearDown(() => dir.delete(recursive: true));
          final file = File('${dir.path}/snapshot.png');
          final pixels = img.Image(width: 8, height: 4);
          img.fill(pixels, color: img.ColorRgb8(255, 0, 0));
          final png = img.encodePng(pixels);
          await file.writeAsBytes(png);
          final result = ClientToolResult(
            'Image (8 x 4).\n![](${file.path})',
            metadata: {
              ...const WorkspaceToolMetadata(
                tool: 'view_image',
                status: 'ok',
              ).toJson(),
              kMcpResultMetadataKey: mcpResultMetadata([file.path]),
            },
          );
          final requests = <Map<String, dynamic>>[];
          var requestTool = true;
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            final body =
                (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                    .cast<String, dynamic>();
            requests.add(body);
            final callTool = requestTool;
            requestTool = false;
            request.response.headers.contentType =
                body['stream'] == true ||
                    request.uri.path.contains('streamGenerateContent')
                ? ContentType('text', 'event-stream')
                : ContentType.json;
            request.response.write(
              request.response.headers.contentType!.mimeType ==
                      'text/event-stream'
                  ? _sse(api, callTool)
                  : jsonEncode(_response(api, callTool)),
            );
            await request.response.close();
          });
          final model = _model(api);
          final config = ProviderConfig(
            id: 'view-image-test',
            name: 'view-image-test',
            enabled: true,
            apiKey: 'test-key',
            baseUrl: 'http://127.0.0.1:${server.port}',
            providerType: switch (api) {
              _Api.chat || _Api.responses => ProviderKind.openai,
              _Api.claude => ProviderKind.claude,
              _ => ProviderKind.google,
            },
            useResponseApi: api == _Api.responses,
            vertexAI: api == _Api.vertexClaude,
            projectId: api == _Api.vertexClaude ? 'test' : null,
            location: api == _Api.vertexClaude ? 'global' : null,
            modelOverrides: {
              model: {
                'input': ['text', 'image'],
                'abilities': ['tool'],
              },
            },
          );
          var calls = 0;
          final chunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: model,
            messages: const [
              {'role': 'user', 'content': 'Inspect plot.png.'},
            ],
            tools: WorkspaceToolsService.definitions()
                .where((d) => (d['function'] as Map)['name'] == 'view_image')
                .toList(),
            stream: stream,
            onToolCall: (name, args, {toolCallId}) async {
              calls++;
              expect(name, 'view_image');
              expect(args['path'], 'plot.png');
              return result;
            },
          ).toList();
          expect(calls, 1);
          expect(chunks.joinedContent, contains('red image'));
          expect(chunks.isGenerationDone, isTrue);
          expect(requests.length, 2);
          expect(_imagePayloads(requests[1]), [base64Encode(png)]);
          final tool = chunks.whereType<ToolCallResult>().single;
          expect(tool.metadata![kMcpResultMetadataKey], isNotNull);
          await ChatApiService.sendMessageStream(
            config: config,
            modelId: model,
            stream: stream,
            messages: [
              {'role': 'user', 'content': 'Inspect plot.png.'},
              {
                'role': 'assistant',
                'content': '',
                'tool_calls': [
                  {
                    'id': 'call_image',
                    'type': 'function',
                    'function': {
                      'name': 'view_image',
                      'arguments': '{"path":"plot.png"}',
                    },
                  },
                ],
              },
              {
                'role': 'tool',
                'tool_call_id': 'call_image',
                'name': 'view_image',
                'content': tool.output,
                'metadata': tool.metadata,
              },
              {'role': 'assistant', 'content': 'red image'},
              {'role': 'user', 'content': 'Describe it again.'},
            ],
          ).toList();
          expect(requests.length, 3);
          expect(_imagePayloads(requests[2]), [base64Encode(png)]);
          // Paths/Markdown are UI persistence, never the model's image payload.
          expect(jsonEncode(requests[2]), isNot(contains(file.path)));
          await ChatApiService.sendMessageStream(
            config: config.copyWith(
              modelOverrides: {
                model: {
                  'input': ['text'],
                },
              },
            ),
            modelId: model,
            stream: stream,
            skipImageParsing: true,
            messages: [
              {'role': 'user', 'content': 'Earlier image'},
              {
                'role': 'assistant',
                'content': '',
                'tool_calls': [
                  {
                    'id': 'call_image',
                    'type': 'function',
                    'function': {'name': 'view_image', 'arguments': '{}'},
                  },
                ],
              },
              {
                'role': 'tool',
                'tool_call_id': 'call_image',
                'name': 'view_image',
                'content': result.content,
                'metadata': result.metadata,
              },
            ],
          ).toList();
          expect(_imagePayloads(requests.last), isEmpty);
          expect(jsonEncode(requests.last), isNot(contains(file.path)));
          expect(jsonEncode(requests.last), isNot(contains(base64Encode(png))));

          final errorText = jsonEncode({
            'error': 'path_error',
            'message': 'Invalid path /invalid/![](${file.path})',
          });
          final errorResult = ClientToolResult(
            errorText,
            metadata: const WorkspaceToolMetadata(
              tool: 'view_image',
              status: 'error',
              code: 'path_error',
            ).toJson(),
          );
          requestTool = true;
          final failedChunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: model,
            stream: stream,
            messages: const [
              {'role': 'user', 'content': 'Inspect a rejected path.'},
            ],
            tools: WorkspaceToolsService.definitions()
                .where((d) => (d['function'] as Map)['name'] == 'view_image')
                .toList(),
            onToolCall: (name, args, {toolCallId}) async => errorResult,
          ).toList();
          expect(
            failedChunks.whereType<ToolCallResult>().single.output,
            errorText,
          );
          expect(_imagePayloads(requests.last), isEmpty);
          expect(jsonEncode(requests.last), isNot(contains(base64Encode(png))));
          await ChatApiService.sendMessageStream(
            config: config,
            modelId: model,
            stream: stream,
            messages: [
              {'role': 'user', 'content': 'Earlier error'},
              {
                'role': 'assistant',
                'content': '',
                'tool_calls': [
                  {
                    'id': 'call_image',
                    'type': 'function',
                    'function': {'name': 'view_image', 'arguments': '{}'},
                  },
                ],
              },
              {
                'role': 'tool',
                'tool_call_id': 'call_image',
                'name': 'view_image',
                'content': errorText,
                'metadata': errorResult.metadata,
              },
            ],
          ).toList();
          expect(_imagePayloads(requests.last), isEmpty);
          expect(jsonEncode(requests.last), isNot(contains(base64Encode(png))));
        },
      );
    }
  }

  test(
    'Chat Completions keeps parallel tool replies adjacent before images',
    () async {
      final dir = await Directory.systemTemp.createTemp('parallel_image_');
      addTearDown(() => dir.delete(recursive: true));
      final uri = '${dir.path}/snapshot.png';
      await File(
        uri,
      ).writeAsBytes(img.encodePng(img.Image(width: 2, height: 2)));
      final messages = await buildOpenAIChatCompletionMessages(
        [
          {
            'role': 'tool',
            'tool_call_id': 'image',
            'name': 'view_image',
            'content': '![]($uri)',
            'metadata': {
              ...const WorkspaceToolMetadata(
                tool: 'view_image',
                status: 'ok',
              ).toJson(),
              kMcpResultMetadataKey: mcpResultMetadata([uri]),
            },
          },
          {
            'role': 'tool',
            'tool_call_id': 'text',
            'name': 'read_file',
            'content': 'ordinary text',
          },
        ],
        canImageInput: true,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.none,
      );
      expect(messages.map((m) => m['role']), ['tool', 'tool', 'user']);
      expect(messages[2]['content'][0]['text'], contains('(image)'));
    },
  );
}
