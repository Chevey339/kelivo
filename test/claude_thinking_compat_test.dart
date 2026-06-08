import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _claudeConfig(
  String baseUrl, {
  Map<String, dynamic> modelOverrides = const <String, dynamic>{},
  bool claudePromptCachingEnabled = false,
  String? claudePromptCachingTtl,
}) {
  return ProviderConfig(
    id: 'ClaudeCompatTest',
    enabled: true,
    name: 'ClaudeCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.claude,
    modelOverrides: modelOverrides,
    claudePromptCachingEnabled: claudePromptCachingEnabled,
    claudePromptCachingTtl: claudePromptCachingTtl,
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

ProviderConfig _deepSeekClaudeConfig({
  Map<String, dynamic> modelOverrides = const <String, dynamic>{},
}) {
  return ProviderConfig(
    id: 'DeepSeekClaudeCompatTest',
    enabled: true,
    name: 'DeepSeekClaudeCompatTest',
    apiKey: 'test-key',
    baseUrl: 'https://api.deepseek.com/anthropic',
    providerType: ProviderKind.claude,
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
  bool claudePromptCachingEnabled = false,
  String? claudePromptCachingTtl,
  List<Map<String, dynamic>> messages = const [
    {'role': 'user', 'content': 'hello'},
  ],
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
    config: _claudeConfig(
      'http://${server.address.address}:${server.port}',
      claudePromptCachingEnabled: claudePromptCachingEnabled,
      claudePromptCachingTtl: claudePromptCachingTtl,
    ),
    modelId: modelId,
    messages: messages,
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
  List<Map<String, dynamic>> responseContent = const [
    {'type': 'text', 'text': 'ok'},
  ],
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
        'content': responseContent,
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

Future<Map<String, dynamic>> _captureClaudeProviderBody({
  required String modelId,
  required ProviderConfig config,
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

  final effectiveConfig = config.copyWith(
    baseUrl: 'http://${server.address.address}:${server.port}',
  );
  final chunks = await ChatApiService.sendMessageStream(
    config: effectiveConfig,
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

void main() {
  group('Claude thinking compatibility', () {
    test(
      'prompt caching adds official Claude top-level cache control',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          claudePromptCachingEnabled: true,
          messages: const [
            {'role': 'system', 'content': 'Stable persona and long context.'},
            {'role': 'user', 'content': 'hello'},
          ],
        );

        expect(body['system'], 'Stable persona and long context.');
        expect(body['cache_control'], {'type': 'ephemeral'});
        expect((body['messages'] as List).cast<Map>().single['role'], 'user');
      },
    );

    test(
      'prompt caching can request official Claude one hour cache ttl',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          claudePromptCachingEnabled: true,
          claudePromptCachingTtl: '1h',
          messages: const [
            {'role': 'system', 'content': 'Stable persona and long context.'},
            {'role': 'user', 'content': 'hello'},
          ],
        );

        expect(body['cache_control'], {'type': 'ephemeral', 'ttl': '1h'});
      },
    );

    test('prompt caching ttl round trips through provider config json', () {
      final config = ProviderConfig(
        id: 'ClaudeCompatTest',
        enabled: true,
        name: 'ClaudeCompatTest',
        apiKey: 'test-key',
        baseUrl: 'https://api.anthropic.com/v1',
        providerType: ProviderKind.claude,
        claudePromptCachingEnabled: true,
        claudePromptCachingTtl: '1h',
      );

      final roundTripped = ProviderConfig.fromJson(config.toJson());

      expect(roundTripped.claudePromptCachingEnabled, isTrue);
      expect(roundTripped.claudePromptCachingTtl, '1h');
    });

    test(
      'prompt caching disabled omits official Claude cache control',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'system', 'content': 'Stable persona and long context.'},
            {'role': 'user', 'content': 'hello'},
          ],
        );

        expect(body['system'], 'Stable persona and long context.');
        expect(body.containsKey('cache_control'), isFalse);
      },
    );

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

    test('generateText Claude path reads text after thinking block', () async {
      await _captureClaudeGenerateTextBody(
        modelId: 'deepseek-v4-pro',
        thinkingBudget: -1,
        responseContent: const [
          {'type': 'thinking', 'thinking': '先思考。'},
          {'type': 'text', 'text': 'ok'},
        ],
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
      'DeepSeek Claude-compatible built-in search uses old web search tool',
      () async {
        final cfg = _deepSeekClaudeConfig(
          modelOverrides: const <String, dynamic>{
            'deepseek-chat': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.search],
              'webSearch': <String, dynamic>{
                'toolVersion': 'web_search_20260209',
              },
            },
          },
        );

        expect(
          BuiltInToolsHelper.supportsBuiltInSearchForModel(
            cfg: cfg,
            modelId: 'deepseek-chat',
          ),
          isTrue,
        );
        expect(
          BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
            cfg: cfg,
            modelId: 'deepseek-chat',
          ),
          isFalse,
        );

        final body = await _captureClaudeBuiltInSearchBody(
          modelId: 'deepseek-chat',
          config: cfg,
        );

        final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
        expect(
          tools.any((tool) => tool['type'] == 'web_search_20250305'),
          isTrue,
        );
        expect(
          tools.any((tool) => tool['type'] == 'web_search_20260209'),
          isFalse,
        );
        expect(
          tools.any((tool) => tool['type'] == 'code_execution_20250825'),
          isFalse,
        );
      },
    );

    test(
      'DeepSeek server web search end_turn does not trigger a continuation request',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBodies.add(
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>(),
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write('''
event: message_start
data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"deepseek-v4-flash","content":[],"stop_reason":null,"usage":{"input_tokens":1,"output_tokens":0}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"server_tool_use","id":"srv_1","name":"web_search","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"query\\":\\"kelivo\\"}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"web_search_tool_result","tool_use_id":"srv_1","content":[{"type":"web_search_result","title":"Kelivo","url":"https://example.com"}]}}

event: content_block_stop
data: {"type":"content_block_stop","index":1}

event: content_block_start
data: {"type":"content_block_start","index":2,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"text_delta","text":"done"}}

event: content_block_stop
data: {"type":"content_block_stop","index":2}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"input_tokens":10,"output_tokens":5,"server_tool_use":{"web_search_requests":1}}}

event: message_stop
data: {"type":"message_stop"}

''');
          await request.response.close();
        });

        final cfg = _deepSeekClaudeConfig(
          modelOverrides: const <String, dynamic>{
            'deepseek-v4-flash': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.search],
            },
          },
        ).copyWith(baseUrl: 'http://${server.address.address}:${server.port}');

        final chunks = await ChatApiService.sendMessageStream(
          config: cfg,
          modelId: 'deepseek-v4-flash',
          messages: const [
            {'role': 'user', 'content': '搜索一下kelivo'},
          ],
          stream: true,
        ).toList();

        expect(chunks.where((chunk) => chunk.content == 'done'), hasLength(1));
        expect(chunks.last.isDone, isTrue);
        expect(requestBodies, hasLength(1));
      },
    );

    test('DeepSeek Claude-compatible auto thinking stays enabled', () async {
      final body = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: -1,
      );

      expect(body['thinking'], {'type': 'enabled'});
      expect(body.containsKey('output_config'), isFalse);
    });

    test('DeepSeek Claude-compatible explicit thinking uses effort', () async {
      final mediumBody = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 16000,
      );
      final maxBody = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 64000,
      );

      expect(mediumBody['thinking'], {'type': 'enabled'});
      expect(mediumBody['output_config'], {'effort': 'high'});
      expect(maxBody['thinking'], {'type': 'enabled'});
      expect(maxBody['output_config'], {'effort': 'max'});
    });

    test('DeepSeek Claude-compatible off thinking stays disabled', () async {
      final body = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body['thinking'], {'type': 'disabled'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['temperature'], 0.7);
      expect(body['top_p'], 0.8);
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

    test(
      'OpenRouter Claude tool continuation skips redacted thinking blocks',
      () async {
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
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );

          if (requestCount == 1) {
            request.response.write('''
event: message_start
data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"model":"claude-opus-4-6","stop_reason":null}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"redacted_thinking","data":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"redacted_thinking_delta","data":"openrouter-redacted-fragment"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_1","name":"lookup","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"query\\":\\"Kelivo\\"}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":1}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"input_tokens":1,"output_tokens":1}}

event: message_stop
data: {"type":"message_stop"}

''');
          } else {
            request.response.write('''
event: message_start
data: {"type":"message_start","message":{"id":"msg_2","type":"message","role":"assistant","content":[],"model":"claude-opus-4-6","stop_reason":null}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"done"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"input_tokens":1,"output_tokens":1}}

event: message_stop
data: {"type":"message_stop"}

''');
          }
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config:
              _claudeConfig(
                'http://${server.address.address}:${server.port}',
              ).copyWith(
                id: 'OpenRouter',
                name: 'OpenRouter',
                baseUrl: 'http://${server.address.address}:${server.port}',
              ),
          modelId: 'claude-opus-4-6',
          messages: const [
            {'role': 'user', 'content': '查一下 Kelivo'},
          ],
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'query': {'type': 'string'},
                  },
                },
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
        ).toList();

        expect(chunks.last.isDone, isTrue);
        expect(requestBodies, hasLength(2));
        final secondMessages = (requestBodies[1]['messages'] as List)
            .cast<Map>();
        final assistantContent = (secondMessages[1]['content'] as List)
            .cast<Map>();
        final toolResultContent = (secondMessages[2]['content'] as List)
            .cast<Map>();

        expect(
          assistantContent.any((block) => block['type'] == 'redacted_thinking'),
          isFalse,
        );
        expect(assistantContent.single['type'], 'tool_use');
        expect(assistantContent.single['id'], 'toolu_1');
        expect(toolResultContent.single['type'], 'tool_result');
        expect(toolResultContent.single['tool_use_id'], 'toolu_1');
      },
    );

    test(
      'completed memory tool turn remains valid when followed by user text',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          thinkingBudget: 16000,
          messages: const [
            {'role': 'user', 'content': 'trigger message'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                {
                  'id': 'toolu_01SBaeK3UtXTQmybQjpPZurX',
                  'type': 'function',
                  'function': {
                    'name': 'create_memory',
                    'arguments': '{"content":"test"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'assistant_blocks': [
                        {
                          'type': 'thinking',
                          'thinking': '需要记录这个偏好。',
                          'signature': 'sig-memory-turn',
                        },
                        {
                          'type': 'tool_use',
                          'id': 'toolu_01SBaeK3UtXTQmybQjpPZurX',
                          'name': 'create_memory',
                          'input': {'content': 'test'},
                        },
                      ],
                    },
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'toolu_01SBaeK3UtXTQmybQjpPZurX',
              'name': 'create_memory',
              'content': 'test',
            },
            {'role': 'assistant', 'content': 'confirmed'},
            {'role': 'user', 'content': 'ok'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        final assistantContent = (messages[1]['content'] as List).cast<Map>();
        final toolResultContent = (messages[2]['content'] as List).cast<Map>();

        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
          'assistant',
          'user',
        ]);
        expect(assistantContent[0]['type'], 'thinking');
        expect(assistantContent[0]['signature'], 'sig-memory-turn');
        expect(assistantContent[1]['type'], 'tool_use');
        expect(assistantContent[1]['id'], 'toolu_01SBaeK3UtXTQmybQjpPZurX');
        expect(toolResultContent.single['type'], 'tool_result');
        expect(
          toolResultContent.single['tool_use_id'],
          'toolu_01SBaeK3UtXTQmybQjpPZurX',
        );
        expect(messages[3]['content'], 'confirmed');
        expect(messages[4]['content'], 'ok');
      },
    );

    test(
      'history tool replay uses complete Claude assistant tool blocks',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': '查两个信息'},
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
                          'type': 'tool_use',
                          'id': 'toolu_1',
                          'name': 'lookup',
                          'input': {'query': 'Kelivo'},
                        },
                      ],
                    },
                  },
                },
                {
                  'id': 'toolu_2',
                  'type': 'function',
                  'function': {
                    'name': 'lookup',
                    'arguments': '{"query":"Claude"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'assistant_blocks': [
                        {
                          'type': 'tool_use',
                          'id': 'toolu_1',
                          'name': 'lookup',
                          'input': {'query': 'Kelivo'},
                        },
                        {
                          'type': 'tool_use',
                          'id': 'toolu_2',
                          'name': 'lookup',
                          'input': {'query': 'Claude'},
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
              'content': '{"result":"Kelivo ok"}',
            },
            {
              'role': 'tool',
              'tool_call_id': 'toolu_2',
              'name': 'lookup',
              'content': '{"result":"Claude ok"}',
            },
            {'role': 'user', 'content': '继续总结'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        final assistantContent = (messages[1]['content'] as List).cast<Map>();
        final toolResultContent = (messages[2]['content'] as List).cast<Map>();
        final toolUseIds = assistantContent
            .where((block) => block['type'] == 'tool_use')
            .map((block) => block['id'])
            .toList();
        final toolResultIds = toolResultContent
            .where((block) => block['type'] == 'tool_result')
            .map((block) => block['tool_use_id'])
            .toList();

        expect(toolUseIds, ['toolu_1', 'toolu_2']);
        expect(toolResultIds, ['toolu_1', 'toolu_2']);
      },
    );

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
