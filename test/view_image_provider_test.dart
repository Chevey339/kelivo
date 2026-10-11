import 'package:Kelivo/core/services/api/native_input_attachments.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import 'support/collect_generation.dart';
import 'support/claude_test_api.dart' show FakePathProviderPlatform;

enum _Api { chat, responses, claude, vertexClaude, gemini, gemini3 }

String _model(_Api api) => switch (api) {
  _Api.chat || _Api.responses => 'gpt-4.1',
  _Api.claude || _Api.vertexClaude => 'claude-sonnet-4-6',
  _Api.gemini => 'gemini-2.5-pro',
  _Api.gemini3 => 'gemini-3-flash-preview',
};

Map<String, dynamic> _response(
  _Api api,
  bool callTool, {
  String toolName = 'view_image',
}) {
  final call = {
    'id': 'call_image',
    'type': 'function',
    'function': {'name': toolName, 'arguments': '{"path":"plot.png"}'},
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
            'name': toolName,
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
            'name': toolName,
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
                    'name': toolName,
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

String _sse(_Api api, bool callTool, {String toolName = 'view_image'}) {
  final obj = _response(api, callTool, toolName: toolName);
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
                'name': toolName,
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

final _nativeInputs = NativeInputAttachments(
  config: ProviderConfig(
    id: 'test',
    enabled: true,
    name: 'test',
    apiKey: '',
    baseUrl: 'https://api.example.com/v1',
  ),
  spec: ModelSpec(id: 'test', displayName: 'test'),
  protocol: NativeInputProtocol.chatCompletions,
);

class _UnusedBuildContext extends Fake implements BuildContext {}

List<Map<String, dynamic>> _imageTools(String name) => [
  for (final definition in WorkspaceToolsService.definitions())
    if ((definition['function'] as Map)['name'] == 'view_image')
      {
        ...definition,
        'function': <String, dynamic>{
          ...(definition['function'] as Map).cast<String, dynamic>(),
          'name': name,
        },
      },
];

Future<List<Map<String, dynamic>>> _replayMessages(
  String toolName,
  ToolCallResult tool, {
  required bool preserveToolTurns,
  String toolCallId = 'call_image',
}) async {
  final chat = ChatService();
  addTearDown(chat.dispose);
  final builder = MessageBuilderService(
    chatService: chat,
    contextProvider: _UnusedBuildContext(),
  );
  final messages = builder.buildApiMessages(
    messages: [
      ChatMessage(
        role: 'user',
        conversationId: 'image-test',
        content: 'Inspect plot.png.',
      ),
      ChatMessage(
        role: 'assistant',
        conversationId: 'image-test',
        parts: [
          ToolCallPart(
            jsonEncode({
              'id': toolCallId,
              'name': toolName,
              'arguments': {'path': 'plot.png'},
              'content': tool.output,
              'metadata': tool.metadata,
            }),
          ),
          const TextPart('red image'),
        ],
      ),
      ChatMessage(
        role: 'user',
        conversationId: 'image-test',
        content: 'Describe it again.',
      ),
    ],
    versionSelections: const {},
    currentConversation: null,
    includeToolMessages: true,
    preserveToolTurns: preserveToolTurns,
  );
  await builder.inlineLocalImages(messages);
  return messages;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late Directory imageRoot;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    imageRoot = await Directory.systemTemp.createTemp('tool_images_');
    await Directory('${imageRoot.path}/images').create();
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(imageRoot.path);
    SandboxPathResolver.debugSetDirs(docsDir: imageRoot.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await imageRoot.delete(recursive: true);
  });
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
    for (final (stream, mcp) in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      final toolName = mcp ? 'svguess__view_drawing' : 'view_image';
      test(
        '${api.name} stream=$stream mcp=$mcp sends image pixels on continuation and replay',
        () async {
          final file = File('${imageRoot.path}/images/mcp_img_drawing (1).png');
          final pixels = img.Image(width: 8, height: 4);
          img.fill(pixels, color: img.ColorRgb8(255, 0, 0));
          final png = img.encodePng(pixels);
          await file.writeAsBytes(png);
          final markdown =
              'Image (8 x 4).\n![](${encodeMarkdownImageDestination(file.path)})';
          final rawResult = mcp
              ? McpToolResult(markdown: markdown, imageUris: [file.path])
              : ClientToolResult(
                  markdown,
                  metadata: {
                    ...const WorkspaceToolMetadata(
                      tool: 'view_image',
                      status: 'ok',
                    ).toJson(),
                    kMcpResultMetadataKey: mcpResultMetadata([file.path]),
                  },
                );
          final result = ClientToolResult.fromHandler(rawResult);
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
                  ? _sse(api, callTool, toolName: toolName)
                  : jsonEncode(_response(api, callTool, toolName: toolName)),
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
            tools: _imageTools(toolName),
            stream: stream,
            skipImageParsing: mcp,
            onToolCall: (name, args, {toolCallId}) async {
              calls++;
              expect(name, toolName);
              expect(args['path'], 'plot.png');
              return rawResult;
            },
          ).toList();
          expect(calls, 1);
          expect(chunks.joinedContent, contains('red image'));
          expect(chunks.isGenerationDone, isTrue);
          expect(requests.length, 2);
          expect(_imagePayloads(requests[1]), [base64Encode(png)]);
          expect(jsonEncode(requests[1]), isNot(contains(file.path)));
          if (api == _Api.chat) {
            expect(
              jsonEncode(requests[1]),
              contains('Image returned by $toolName (call_image)'),
            );
          }
          final tool = chunks.whereType<ToolCallResult>().single;
          expect(tool.metadata![kMcpResultMetadataKey], isNotNull);
          for (final preserveToolTurns in [false, true]) {
            final replay = await _replayMessages(
              toolName,
              tool,
              preserveToolTurns: preserveToolTurns,
              toolCallId: 'previous_image',
            );
            expect(
              replay.singleWhere((m) => m['role'] == 'tool')['content'],
              result.content,
            );
            final replayStart = requests.length;
            var replayCalls = 0;
            requestTool = true;
            await ChatApiService.sendMessageStream(
              config: config,
              modelId: model,
              stream: stream,
              skipImageParsing: mcp,
              messages: replay,
              tools: _imageTools(toolName),
              onToolCall: (name, args, {toolCallId}) async {
                replayCalls++;
                return 'Checked again.';
              },
            ).toList();
            expect(replayCalls, 1);
            expect(requests.length, replayStart + 2);
            // Historical images must survive both the initial replay and a
            // subsequent tool round, without exposing persistence metadata.
            for (final request in requests.skip(replayStart)) {
              expect(_imagePayloads(request), [base64Encode(png)]);
              expect(jsonEncode(request), isNot(contains(file.path)));
              expect(
                jsonEncode(request),
                isNot(contains(kMcpResultMetadataKey)),
              );
            }
          }
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
                    'function': {'name': toolName, 'arguments': '{}'},
                  },
                ],
              },
              {
                'role': 'tool',
                'tool_call_id': 'call_image',
                'name': toolName,
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
            metadata: mcp
                ? {kMcpResultMetadataKey: mcpResultMetadata([])}
                : const WorkspaceToolMetadata(
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
            tools: _imageTools(toolName),
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
                    'function': {'name': toolName, 'arguments': '{}'},
                  },
                ],
              },
              {
                'role': 'tool',
                'tool_call_id': 'call_image',
                'name': toolName,
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
      final uri = '${imageRoot.path}/images/mcp_img_parallel.png';
      await File(
        uri,
      ).writeAsBytes(img.encodePng(img.Image(width: 2, height: 2)));
      final messages = await buildOpenAIChatCompletionMessages(
        [
          {
            'role': 'tool',
            'tool_call_id': 'mcp_image',
            'name': 'view_drawing',
            'content': '![]($uri)',
            'metadata': {
              kMcpResultMetadataKey: mcpResultMetadata([uri]),
            },
          },
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
        nativeInputs: _nativeInputs,
        canImageInput: true,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.none,
      );
      expect(messages.map((m) => m['role']), ['tool', 'tool', 'tool', 'user']);
      expect(
        messages[3]['content'][0]['text'],
        contains('view_drawing (mcp_image)'),
      );
      expect(messages[3]['content'][2]['text'], contains('view_image (image)'));
      expect(_imagePayloads(messages[3]), hasLength(2));
    },
  );
}
