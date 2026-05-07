import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _claudeConfig(
  String baseUrl, {
  Map<String, dynamic> modelOverrides = const <String, dynamic>{},
}) {
  return ProviderConfig(
    id: 'ClaudeCompatTest',
    enabled: true,
    name: 'ClaudeCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.claude,
    modelOverrides: modelOverrides,
  );
}

ProviderConfig _vertexClaudeConfig({
  Map<String, dynamic> modelOverrides = const <String, dynamic>{},
}) {
  return ProviderConfig(
    id: 'VertexClaudeCompatTest',
    enabled: true,
    name: 'VertexClaudeCompatTest',
    apiKey: 'test-key',
    baseUrl: 'https://aiplatform.googleapis.com',
    providerType: ProviderKind.google,
    vertexAI: true,
    location: 'global',
    projectId: 'test-project',
    modelOverrides: modelOverrides,
  );
}

class _ProxyHttpOverrides extends HttpOverrides {
  _ProxyHttpOverrides(this.port);

  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
    return client;
  }
}

Future<Map<String, dynamic>> _captureClaudeRequestBody({
  required String modelId,
  int? thinkingBudget,
  double? temperature,
  double? topP,
}) async {
  late Map<String, dynamic> requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    requestBody = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
        .cast<String, dynamic>();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'id': 'msg_1',
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
    );
    await request.response.close();
  });

  final chunks = await ChatApiService.sendMessageStream(
    config: _claudeConfig('http://${server.address.address}:${server.port}'),
    modelId: modelId,
    messages: const [
      {'role': 'user', 'content': 'hello'},
    ],
    thinkingBudget: thinkingBudget,
    temperature: temperature,
    topP: topP,
    stream: false,
  ).toList();

  expect(chunks.last.isDone, isTrue);
  return requestBody;
}

Future<Map<String, dynamic>> _captureClaudeGenerateTextBody({
  required String modelId,
  int? thinkingBudget,
}) async {
  late Map<String, dynamic> requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    requestBody = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
        .cast<String, dynamic>();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'id': 'msg_1',
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
    );
    await request.response.close();
  });

  final text = await ChatApiService.generateText(
    config: _claudeConfig('http://${server.address.address}:${server.port}'),
    modelId: modelId,
    prompt: 'hello',
    thinkingBudget: thinkingBudget,
  );

  expect(text, 'ok');
  return requestBody;
}

Future<Map<String, dynamic>> _captureClaudeBuiltInSearchBody({
  required String modelId,
  required ProviderConfig config,
}) async {
  late Map<String, dynamic> requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    requestBody = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
        .cast<String, dynamic>();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'id': 'msg_1',
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
    );
    await request.response.close();
  });

  if (config.vertexAI == true) {
    await HttpOverrides.runZoned(
      () async {
        final chunks = await ChatApiService.sendMessageStream(
          config: config,
          modelId: modelId,
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          stream: false,
        ).toList();
        expect(chunks.last.isDone, isTrue);
      },
      createHttpClient: (context) {
        return _ProxyHttpOverrides(server.port).createHttpClient(context);
      },
    );
  } else {
    final effectiveConfig = config.copyWith(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    final chunks = await ChatApiService.sendMessageStream(
      config: effectiveConfig,
      modelId: modelId,
      messages: const [
        {'role': 'user', 'content': 'hello'},
      ],
      stream: false,
    ).toList();
    expect(chunks.last.isDone, isTrue);
  }

  return requestBody;
}

void main() {
  group('Claude thinking compatibility', () {
    test(
      'Opus 4.7 uses adaptive thinking with effort and strips sampling',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          thinkingBudget: 16000,
          temperature: 0.7,
          topP: 0.8,
        );

        expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
        expect(body['output_config'], {'effort': 'medium'});
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
        expect(
          (body['thinking'] as Map<String, dynamic>).containsKey(
            'budget_tokens',
          ),
          isFalse,
        );
      },
    );

    test(
      'Opus 4.7 off keeps sampling params and omits output config',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          thinkingBudget: 0,
          temperature: 0.7,
          topP: 0.8,
        );

        expect(body['thinking'], {'type': 'disabled'});
        expect(body['temperature'], 0.7);
        expect(body['top_p'], 0.8);
        expect(body.containsKey('output_config'), isFalse);
      },
    );

    test('Sonnet 4.6 enabled budget now uses adaptive thinking', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        thinkingBudget: 1024,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'low'});
      expect(
        (body['thinking'] as Map<String, dynamic>).containsKey('budget_tokens'),
        isFalse,
      );
    });

    test('Sonnet 4.6 thinking omits temperature and invalid top_p', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        thinkingBudget: 1024,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Sonnet 4.6 clamps large budget to max instead of xhigh', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        thinkingBudget: 64000,
      );

      expect(body['output_config'], {'effort': 'max'});
    });

    test('Opus 4.7 allows xhigh for large but non-max budgets', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        thinkingBudget: 64000,
      );

      expect(body['output_config'], {'effort': 'xhigh'});
    });

    test('generateText Claude path matches Opus 4.7 adaptive rules', () async {
      final body = await _captureClaudeGenerateTextBody(
        modelId: 'claude-opus-4-7',
        thinkingBudget: 16000,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'medium'});
      expect(body.containsKey('temperature'), isFalse);
      expect(
        (body['thinking'] as Map<String, dynamic>).containsKey('budget_tokens'),
        isFalse,
      );
    });

    test('Claude built-in search support list includes Opus 4.7', () {
      expect(
        BuiltInToolsHelper.isClaudeBuiltInSearchSupportedModel(
          'claude-opus-4-7',
        ),
        isTrue,
      );
    });

    test('Claude dynamic web search support matrix is official-only', () {
      final official = _claudeConfig(
        'http://localhost',
        modelOverrides: const <String, dynamic>{},
      );
      final vertex = _vertexClaudeConfig();

      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-opus-4-7',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-sonnet-4-6',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-mythos-preview',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: vertex,
          modelId: 'claude-opus-4-7',
        ),
        isFalse,
      );
    });

    test('official Claude built-in search can switch to 20260209', () async {
      final body = await _captureClaudeBuiltInSearchBody(
        modelId: 'claude-opus-4-7',
        config: _claudeConfig(
          'http://localhost',
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.search],
              'webSearch': <String, dynamic>{
                'toolVersion': 'web_search_20260209',
              },
            },
          },
        ),
      );

      final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
      expect(
        tools.any((tool) => tool['type'] == 'web_search_20260209'),
        isTrue,
      );
      expect(
        tools.any((tool) => tool['type'] == 'code_execution_20250825'),
        isTrue,
      );
    });

    test(
      'Vertex Claude keeps old search tool selection even with new flag',
      () {
        final cfg = _vertexClaudeConfig(
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.search],
              'webSearch': <String, dynamic>{
                'toolVersion': 'web_search_20260209',
              },
            },
          },
        );

        expect(
          BuiltInToolsHelper.claudeBuiltInSearchToolType(
            cfg: cfg,
            modelId: 'claude-opus-4-7',
          ),
          'web_search_20250305',
        );
      },
    );

    test('history tool replay preserves thinking block signature', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody =
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'msg_2',
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
            'usage': {'input_tokens': 1, 'output_tokens': 1},
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _claudeConfig(
          'http://${server.address.address}:${server.port}',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': '查一下 Kelivo'},
          {
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              {
                'id': 'toolu_1',
                'type': 'function',
                'function': {
                  'name': 'lookup',
                  'arguments': '{"query":"Kelivo"}',
                },
                'metadata': {
                  'anthropic': {
                    'assistant_blocks': [
                      {
                        'type': 'thinking',
                        'thinking': '需要先查资料。',
                        'signature': 'sig-claude-history',
                      },
                      {
                        'type': 'tool_use',
                        'id': 'toolu_1',
                        'name': 'lookup',
                        'input': {'query': 'Kelivo'},
                      },
                    ],
                  },
                },
              },
            ],
          },
          {
            'role': 'tool',
            'tool_call_id': 'toolu_1',
            'name': 'lookup',
            'content': '{"result":"ok"}',
          },
          {'role': 'user', 'content': '继续总结'},
        ],
        stream: false,
      ).toList();

      expect(chunks.last.isDone, isTrue);
      final messages = (requestBody['messages'] as List).cast<Map>();
      final assistantContent = (messages[1]['content'] as List).cast<Map>();
      final toolResultContent = (messages[2]['content'] as List).cast<Map>();

      expect(assistantContent[0]['type'], 'thinking');
      expect(assistantContent[0]['thinking'], '需要先查资料。');
      expect(assistantContent[0]['signature'], 'sig-claude-history');
      expect(assistantContent[1]['type'], 'tool_use');
      expect(assistantContent[1]['id'], 'toolu_1');
      expect(toolResultContent.single['type'], 'tool_result');
      expect(toolResultContent.single['tool_use_id'], 'toolu_1');
    });

    test('live tool continuation keeps initial user image blocks', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_claude_tool_img_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final file = File('${dir.path}/claude.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final requestBodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount += 1;
        requestBodies.add(
          (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
              .cast<String, dynamic>(),
        );
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;

        if (requestCount == 1) {
          request.response.write(
            jsonEncode({
              'id': 'msg_1',
              'content': [
                {
                  'type': 'tool_use',
                  'id': 'toolu_1',
                  'name': 'lookup',
                  'input': <String, dynamic>{},
                },
              ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
        } else {
          request.response.write(
            jsonEncode({
              'id': 'msg_2',
              'content': [
                {'type': 'text', 'text': 'done'},
              ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
        }
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _claudeConfig(
          'http://${server.address.address}:${server.port}',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': 'inspect'},
        ],
        userImagePaths: [file.path],
        onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
        stream: false,
      ).toList();

      expect(chunks.last.isDone, isTrue);
      expect(requestBodies, hasLength(2));
      final messages = (requestBodies[1]['messages'] as List).cast<Map>();
      final firstUserContent = (messages.first['content'] as List).cast<Map>();

      expect(firstUserContent.first['text'], 'inspect');
      expect(firstUserContent.any((part) => part['type'] == 'image'), isTrue);
      final imagePart = firstUserContent.firstWhere(
        (part) => part['type'] == 'image',
      );
      expect(imagePart['source']['media_type'], 'image/png');
      expect(imagePart['source']['data'], 'AQIDBA==');
    });
  });
}
