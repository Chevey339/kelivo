import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'support/collect_generation.dart';

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

/// A relay that ran `web_search` upstream but labelled the block `tool_use`.
const _downgradedRound = '''
event: message_start
data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-sonnet-4-6","content":[],"stop_reason":null,"usage":{"input_tokens":1,"output_tokens":0}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"web_search","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"query\\":\\"kelivo\\"}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"found it"}}

event: content_block_stop
data: {"type":"content_block_stop","index":1}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"input_tokens":10,"output_tokens":5}}

event: message_stop
data: {"type":"message_stop"}

''';

const _plainRound = '''
event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"second round"}}

event: message_stop
data: {"type":"message_stop"}

''';

/// The block shapes of a hosted / client tool hand-off, and the card the app
/// persists for one: every response of the turn carries its own block list.
Map<String, dynamic> _hostedCall(String id, String url) => {
  'type': 'server_tool_use',
  'id': id,
  'name': 'web_fetch',
  'input': {'url': url},
};

Map<String, dynamic> _hostedResult(String id, String url) => {
  'type': 'web_fetch_tool_result',
  'tool_use_id': id,
  'content': {'type': 'web_fetch_result', 'url': url},
};

Map<String, dynamic> _clientCall(String id, String content) => {
  'type': 'tool_use',
  'id': id,
  'name': 'create_memory',
  'input': {'content': content},
};

/// A card as the app persists it: it recorded the turn's responses up to the
/// one that last wrote it, so a client call's card stops at the response that
/// declared it and a hosted call's reaches the one carrying its result.
Map<String, dynamic> _replayCall(
  String id,
  String name,
  List<List<Map<String, dynamic>>> responses,
) => {
  'id': id,
  'type': 'function',
  'function': {'name': name, 'arguments': '{}'},
  'metadata': claudeReplayMetadata(responses),
};

Map<String, dynamic> _toolResult(String id, String name, String content) => {
  'role': 'tool',
  'tool_call_id': id,
  'name': name,
  'content': content,
};

List<Object?> _blockTypes(Map message) => (message['content'] as List)
    .cast<Map>()
    .map((block) => block['type'])
    .toList();

List<Object?> _resultIds(Map message) => (message['content'] as List)
    .cast<Map>()
    .map((block) => block['tool_use_id'])
    .toList();

/// The text of a whole replayed turn: every assistant message it spans, with a
/// plain-string content read as the one text block it stands for.
String _assistantText(List<Map> messages) => messages
    .where((message) => message['role'] == 'assistant')
    .expand(
      (message) => message['content'] is List
          ? (message['content'] as List)
                .cast<Map>()
                .where((block) => block['type'] == 'text')
                .map((block) => (block['text'] ?? '').toString())
          : [(message['content'] ?? '').toString()],
    )
    .join();

/// One finished web search turn, as the app persists it: the card's tool call
/// carries the blocks the API sent, and the card summary is the tool message.
const _webSearchHistory = <Map<String, dynamic>>[
  {'role': 'user', 'content': '京都有什么好玩的'},
  {
    'role': 'assistant',
    'content': '\n\n',
    'tool_calls': [
      {
        'id': 'srvtoolu_1',
        'type': 'function',
        'function': {'name': 'search_web', 'arguments': '{"query":"kyoto"}'},
        'metadata': {
          'anthropic': {
            'assistant_blocks': [
              {'type': 'text', 'text': '我先搜索一下。'},
              {
                'type': 'server_tool_use',
                'id': 'srvtoolu_1',
                'name': 'web_search',
                'input': {'query': 'kyoto'},
              },
              {
                'type': 'web_search_tool_result',
                'tool_use_id': 'srvtoolu_1',
                'content': [
                  {
                    'type': 'web_search_result',
                    'url': 'https://example.com',
                    'title': 'Example',
                    'encrypted_content': 'EqgfCioIARgBIiQ3',
                  },
                ],
              },
            ],
          },
        },
      },
    ],
  },
  {
    'role': 'tool',
    'tool_call_id': 'srvtoolu_1',
    'name': 'search_web',
    'content': '{"items":[{"title":"Example","url":"https://example.com"}]}',
  },
  {'role': 'user', 'content': '第一条具体怎么说的'},
];

/// Both request bodies of a turn where Claude calls a server tool and a client
/// tool at once: the API leaves the server tool's result in the first response,
/// and the continuation round decides whether it travels back.
Future<List<Map<String, dynamic>>> _captureClaudeServerToolRounds({
  required bool officialEndpoint,
}) async {
  const round1 = [
    {
      'type': 'content_block_start',
      'index': 0,
      'content_block': {
        'type': 'server_tool_use',
        'id': 'srvtoolu_1',
        'name': 'web_search',
      },
    },
    {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {
        'type': 'input_json_delta',
        'partial_json': '{"query":"kyoto"}',
      },
    },
    {'type': 'content_block_stop', 'index': 0},
    {
      'type': 'content_block_start',
      'index': 1,
      'content_block': {
        'type': 'web_search_tool_result',
        'tool_use_id': 'srvtoolu_1',
        'content': [
          {
            'type': 'web_search_result',
            'url': 'https://example.com',
            'title': 'Example',
            'encrypted_content': 'EqgfCioIARgBIiQ3',
          },
        ],
      },
    },
    {'type': 'content_block_stop', 'index': 1},
    {
      'type': 'content_block_start',
      'index': 2,
      'content_block': {
        'type': 'tool_use',
        'id': 'toolu_1',
        'name': 'lookup',
        'input': <String, dynamic>{},
      },
    },
    {'type': 'content_block_stop', 'index': 2},
    {
      'type': 'message_delta',
      'delta': {'stop_reason': 'tool_use'},
    },
    {'type': 'message_stop'},
  ];
  const round2 = [
    {
      'type': 'content_block_start',
      'index': 0,
      'content_block': {'type': 'text', 'text': ''},
    },
    {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'text_delta', 'text': 'done'},
    },
    {'type': 'content_block_stop', 'index': 0},
    {
      'type': 'message_delta',
      'delta': {'stop_reason': 'end_turn'},
    },
    {'type': 'message_stop'},
  ];

  final requestBodies = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  var round = 0;
  server.listen((request) async {
    round += 1;
    requestBodies.add(
      (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, dynamic>(),
    );
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(
      'event: message_start\n'
      'data: ${jsonEncode({
        'type': 'message_start',
        'message': {
          'id': 'msg_$round',
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
      })}\n\n',
    );
    for (final event in round == 1 ? round1 : round2) {
      request.response.write(
        'event: ${event['type']}\ndata: ${jsonEncode(event)}\n\n',
      );
    }
    await request.response.close();
  });

  final config = _claudeConfig(
    officialEndpoint
        ? 'http://api.anthropic.com/v1'
        : 'http://${server.address.address}:${server.port}',
  );

  Future<void> send() async {
    final chunks = await ChatApiService.sendMessageStream(
      config: config,
      modelId: 'claude-sonnet-4-6',
      messages: const [
        {'role': 'user', 'content': 'kyoto'},
      ],
      onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
    ).toList();
    expect(chunks.isGenerationDone, isTrue);
  }

  if (officialEndpoint) {
    await HttpOverrides.runZoned(
      send,
      createHttpClient: (context) =>
          _ProxyHttpOverrides(server.port).createHttpClient(context),
    );
  } else {
    await send();
  }

  expect(requestBodies, hasLength(2));
  return requestBodies;
}

Future<Map<String, dynamic>> _captureClaudeRequestBody({
  required String modelId,
  int? thinkingBudget,
  double? temperature,
  double? topP,
  bool claudePromptCachingEnabled = false,
  String? claudePromptCachingTtl,
  bool officialEndpoint = false,
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

  // Server tool blocks are gated on the endpoint's host, so a test that needs
  // the official one keeps that host and proxies the traffic to the server.
  final config = _claudeConfig(
    officialEndpoint
        ? 'http://api.anthropic.com/v1'
        : 'http://${server.address.address}:${server.port}',
    claudePromptCachingEnabled: claudePromptCachingEnabled,
    claudePromptCachingTtl: claudePromptCachingTtl,
  );

  Future<void> send() async {
    final chunks = await ChatApiService.sendMessageStream(
      config: config,
      modelId: modelId,
      messages: messages,
      thinkingBudget: thinkingBudget,
      temperature: temperature,
      topP: topP,
      stream: false,
    ).toList();
    expect(chunks.isGenerationDone, isTrue);
  }

  if (officialEndpoint) {
    await HttpOverrides.runZoned(
      send,
      createHttpClient: (context) =>
          _ProxyHttpOverrides(server.port).createHttpClient(context),
    );
  } else {
    await send();
  }
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
  List<Map<String, dynamic>>? tools,
  bool utilityCall = false,
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

  // Which built-ins may be sent depends on the host, so a config that names
  // one Vertex or Anthropic keeps it and reaches the server through a proxy.
  final keepBaseUrl =
      config.vertexAI == true ||
      (Uri.tryParse(config.baseUrl)?.host ?? '') == 'api.anthropic.com';

  Future<void> send(ProviderConfig cfg) async {
    if (utilityCall) {
      // Title / summary generation, which asks for search and nothing else.
      expect(
        await ChatApiService.generateText(
          config: cfg,
          modelId: modelId,
          prompt: 'hello',
        ),
        'ok',
      );
      return;
    }
    final chunks = await ChatApiService.sendMessageStream(
      config: cfg,
      modelId: modelId,
      messages: const [
        {'role': 'user', 'content': 'hello'},
      ],
      tools: tools,
      onToolCall: tools == null
          ? null
          : (name, args, {toolCallId}) async => '{}',
      stream: false,
    ).toList();
    expect(chunks.isGenerationDone, isTrue);
  }

  if (keepBaseUrl) {
    await HttpOverrides.runZoned(
      () => send(config),
      createHttpClient: (context) =>
          _ProxyHttpOverrides(server.port).createHttpClient(context),
    );
  } else {
    await send(
      config.copyWith(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
    );
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

  expect(chunks.isGenerationDone, isTrue);
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
      'Opus 4.8 uses adaptive thinking with xhigh effort and strips sampling',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-opus-4-8',
          thinkingBudget: 64000,
          temperature: 0.7,
          topP: 0.8,
        );

        expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
        expect(body['output_config'], {'effort': 'xhigh'});
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
      },
    );

    test('Opus 4.8 maps max reasoning to max effort', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-opus-4.8',
        thinkingBudget: 128000,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
    });

    test('Opus 5 uses summarized adaptive thinking and max effort', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-opus-5',
        thinkingBudget: 128000,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Sonnet 5 can disable thinking but still rejects sampling', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-5',
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body['thinking'], {'type': 'disabled'});
      expect(body.containsKey('output_config'), isFalse);
      expect(body['max_tokens'], 128000);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Fable 5 never sends unsupported disabled thinking', () async {
      final offBody = await _captureClaudeRequestBody(
        modelId: 'claude-fable-5',
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
      );
      final mediumBody = await _captureClaudeRequestBody(
        modelId: 'claude-fable-5',
        thinkingBudget: 16000,
      );

      expect(offBody.containsKey('thinking'), isFalse);
      expect(offBody.containsKey('output_config'), isFalse);
      expect(offBody.containsKey('temperature'), isFalse);
      expect(offBody.containsKey('top_p'), isFalse);
      expect(mediumBody['thinking'], {
        'type': 'adaptive',
        'display': 'summarized',
      });
      expect(mediumBody['output_config'], {'effort': 'medium'});
    });

    test('Fable 5 maps max reasoning to max effort', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-fable-5',
        thinkingBudget: 128000,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'max'});
    });

    test(
      'Mythos 5 never sends disabled thinking and returns summaries',
      () async {
        final offBody = await _captureClaudeRequestBody(
          modelId: 'claude-mythos-5',
          thinkingBudget: 0,
        );
        final maxBody = await _captureClaudeRequestBody(
          modelId: 'claude-mythos-5',
          thinkingBudget: 128000,
        );

        expect(offBody.containsKey('thinking'), isFalse);
        expect(offBody.containsKey('output_config'), isFalse);
        expect(maxBody['thinking'], {
          'type': 'adaptive',
          'display': 'summarized',
        });
        expect(maxBody['output_config'], {'effort': 'max'});
        expect(maxBody['max_tokens'], 128000);
      },
    );

    test('OpenRouter Anthropic format uses Claude messages path', () async {
      late Uri requestUri;
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestUri = request.uri;
        requestBody =
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
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
        config: ProviderConfig(
          id: 'OpenRouterAnthropic',
          enabled: true,
          name: 'OpenRouter Anthropic',
          apiKey: 'test-key',
          baseUrl: 'http://${server.address.address}:${server.port}',
          providerType: ProviderKind.claude,
        ),
        modelId: 'anthropic/claude-fable-5',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 16000,
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(requestUri.path, '/messages');
      expect(requestBody['thinking'], {
        'type': 'adaptive',
        'display': 'summarized',
      });
      expect(requestBody['output_config'], {'effort': 'medium'});
    });

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
      expect(body['stream'], isFalse);
      expect(body.containsKey('temperature'), isFalse);
      expect(
        (body['thinking'] as Map<String, dynamic>).containsKey('budget_tokens'),
        isFalse,
      );
    });

    test(
      'generateText Claude path omits temperature when thinking is off',
      () async {
        final body = await _captureClaudeGenerateTextBody(
          modelId: 'claude-haiku-4-5',
          thinkingBudget: 0,
        );

        expect(body.containsKey('temperature'), isFalse);
      },
    );

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

    test(
      'Claude built-in search support list includes latest Claude 5 models',
      () {
        for (final modelId in const [
          'claude-opus-4-8',
          'claude-fable-5',
          'claude-mythos-5',
          'claude-opus-5',
          'claude-sonnet-5',
        ]) {
          expect(
            BuiltInToolsHelper.isClaudeBuiltInSearchSupportedModel(modelId),
            isTrue,
          );
        }
      },
    );

    test('Claude dynamic web search support matrix is official-only', () {
      final official = _claudeConfig(
        'http://api.anthropic.com',
        modelOverrides: const <String, dynamic>{},
      );
      final vertex = _vertexClaudeConfig();

      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-opus-4-8',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-opus-5',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-sonnet-5',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: official,
          modelId: 'claude-fable-5',
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
          'http://api.anthropic.com',
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
        tools.any((tool) => tool['type'] == 'web_search_20260318'),
        isTrue,
      );
      // The API provisions code execution for dynamic filtering itself;
      // declaring it here collides with that auto-injected tool name.
      expect(tools.any((tool) => tool['name'] == 'code_execution'), isFalse);
    });

    test(
      'official Claude sends web fetch and code execution built-ins',
      () async {
        final body = await _captureClaudeBuiltInSearchBody(
          modelId: 'claude-opus-4-7',
          config: _claudeConfig(
            'http://api.anthropic.com',
            modelOverrides: const <String, dynamic>{
              'claude-opus-4-7': <String, dynamic>{
                'builtInTools': <String>[
                  BuiltInToolNames.webFetch,
                  BuiltInToolNames.codeExecution,
                ],
              },
            },
          ),
        );

        final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
        final fetch = tools.firstWhere((tool) => tool['name'] == 'web_fetch');
        expect(fetch['type'], 'web_fetch_20250910');
        // Unbounded by default, so the cap has to leave room to answer after
        // a couple of fetches. It bounds text only, never a fetched PDF.
        expect(fetch['max_content_tokens'], lessThan(50000));
        expect(
          tools.firstWhere((tool) => tool['name'] == 'code_execution')['type'],
          'code_execution_20260521',
        );
      },
    );

    test('Opus 5 gets code execution but not the web fetch it lacks', () async {
      final body = await _captureClaudeBuiltInSearchBody(
        modelId: 'claude-opus-5',
        config: _claudeConfig(
          'http://api.anthropic.com',
          modelOverrides: const <String, dynamic>{
            'claude-opus-5': <String, dynamic>{
              'builtInTools': <String>[
                BuiltInToolNames.webFetch,
                BuiltInToolNames.codeExecution,
              ],
            },
          },
        ),
      );

      final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
      expect(tools.any((tool) => tool['name'] == 'web_fetch'), isFalse);
      expect(tools.any((tool) => tool['name'] == 'code_execution'), isTrue);
    });

    test(
      'a non-streaming pause_turn resumes with the hosted exchange intact',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((request) async {
          bodies.add(
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>(),
          );
          // A hosted tool that outran the turn limit asks to be resumed, with
          // no client tool to answer first.
          final paused = bodies.length == 1;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'msg_${bodies.length}',
              'stop_reason': paused ? 'pause_turn' : 'end_turn',
              'content': paused
                  ? const [
                      {'type': 'text', 'text': 'before '},
                      {
                        'type': 'server_tool_use',
                        'id': 'srvtoolu_paused',
                        'name': 'web_search',
                        'input': {'query': '京都'},
                      },
                      {
                        'type': 'web_search_tool_result',
                        'tool_use_id': 'srvtoolu_paused',
                        'content': [],
                      },
                    ]
                  : const [
                      {'type': 'text', 'text': 'ok'},
                    ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
          await request.response.close();
        });

        final config = _claudeConfig(
          'http://api.anthropic.com',
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.search],
            },
          },
        );
        await HttpOverrides.runZoned(
          () async {
            expect(
              await ChatApiService.generateText(
                config: config,
                modelId: 'claude-opus-4-7',
                prompt: 'hello',
              ),
              'before ok',
            );
          },
          createHttpClient: (context) =>
              _ProxyHttpOverrides(server.port).createHttpClient(context),
        );

        expect(bodies, hasLength(2), reason: 'the paused turn has to resume');
        final resumed = (bodies[1]['messages'] as List).cast<Map>();
        final assistant = (resumed.last['content'] as List).cast<Map>();
        // Dropping either half of the exchange makes the API reject the round.
        expect(assistant.map((block) => block['type']).toList(), [
          'text',
          'server_tool_use',
          'web_search_tool_result',
        ]);
      },
    );

    test('a non-streaming hosted tool is persisted as a card', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'msg_1',
            'stop_reason': 'end_turn',
            'content': const [
              {
                'type': 'server_tool_use',
                'id': 'srvtoolu_fetch',
                'name': 'web_fetch',
                'input': {'url': 'https://example.com'},
              },
              {
                'type': 'web_fetch_tool_result',
                'tool_use_id': 'srvtoolu_fetch',
                'content': {
                  'type': 'web_fetch_result',
                  'url': 'https://example.com',
                },
              },
              {'type': 'text', 'text': 'ok'},
            ],
            'usage': {'input_tokens': 1, 'output_tokens': 1},
          }),
        );
        await request.response.close();
      });

      final result = await HttpOverrides.runZoned(
        () => ChatApiService.generateMessage(
          config: _claudeConfig('http://api.anthropic.com'),
          modelId: 'claude-opus-4-7',
          messages: const [
            {'role': 'user', 'content': 'fetch'},
          ],
        ),
        createHttpClient: (context) =>
            _ProxyHttpOverrides(server.port).createHttpClient(context),
      );

      expect(result.text, 'ok');
      final tool =
          jsonDecode(result.parts.whereType<ToolCallPart>().single.payloadJson)
              as Map;
      expect(tool['name'], 'web_fetch');
      expect(tool['server'], isTrue);
      expect(tool['arguments'], {'url': 'https://example.com'});
      expect(tool['content'], {
        'type': 'web_fetch_result',
        'url': 'https://example.com',
      });
      final responses =
          ((tool['metadata'] as Map)['anthropic'] as Map)['responses'] as List;
      expect(responses, hasLength(1));
      expect(
        (responses.single as List).cast<Map>().map((block) => block['type']),
        ['server_tool_use', 'web_fetch_tool_result', 'text'],
      );
    });

    test(
      'a non-streaming container run resumes in the same container and fetches its files',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final paths = <String>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((request) async {
          paths.add(request.uri.path);
          if (request.method == 'GET') {
            // A failed download costs a file, never the turn.
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          bodies.add(
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>(),
          );
          final paused = bodies.length == 1;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'msg_${bodies.length}',
              'stop_reason': paused ? 'pause_turn' : 'end_turn',
              'container': {'id': 'container_abc'},
              'content': paused
                  ? const [
                      {
                        'type': 'server_tool_use',
                        'id': 'srvtoolu_run',
                        'name': 'bash_code_execution',
                        'input': {'command': 'python plot.py'},
                      },
                      {
                        'type': 'bash_code_execution_tool_result',
                        'tool_use_id': 'srvtoolu_run',
                        'content': {
                          'type': 'bash_code_execution_result',
                          'stdout': '',
                          'stderr': '',
                          'return_code': 0,
                          'content': [
                            {
                              'type': 'code_execution_output',
                              'file_id': 'file_chart',
                            },
                          ],
                        },
                      },
                    ]
                  : const [
                      {'type': 'text', 'text': 'ok'},
                    ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
          await request.response.close();
        });

        final config = _claudeConfig(
          'http://api.anthropic.com',
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.codeExecution],
            },
          },
        );
        await HttpOverrides.runZoned(
          () async {
            // A utility call would leave the container tool out entirely.
            final chunks = await ChatApiService.sendMessageStream(
              config: config,
              modelId: 'claude-opus-4-7',
              messages: const [
                {'role': 'user', 'content': 'hello'},
              ],
              stream: false,
            ).toList();
            expect(chunks.joinedContent, 'ok');
          },
          createHttpClient: (context) =>
              _ProxyHttpOverrides(server.port).createHttpClient(context),
        );

        expect(bodies, hasLength(2));
        // The first round cannot know a container; every later one must name
        // the same container or the files it wrote are gone.
        expect(bodies[0].containsKey('container'), isFalse);
        expect(bodies[1]['container'], 'container_abc');
        expect(paths.where((path) => path.endsWith('/files/file_chart')), [
          '/files/file_chart',
        ]);
      },
    );

    test(
      'a utility call gets search only, never fetch or a container',
      () async {
        final body = await _captureClaudeBuiltInSearchBody(
          modelId: 'claude-opus-4-7',
          utilityCall: true,
          config: _claudeConfig(
            'http://api.anthropic.com',
            modelOverrides: const <String, dynamic>{
              'claude-opus-4-7': <String, dynamic>{
                'builtInTools': <String>[
                  BuiltInToolNames.search,
                  BuiltInToolNames.webFetch,
                  BuiltInToolNames.codeExecution,
                ],
              },
            },
          ),
        );

        final names = (body['tools'] as List)
            .cast<Map<String, dynamic>>()
            .map((tool) => tool['name'])
            .toList();
        // A fetch or a container run on a title request is both off-contract
        // and billed.
        expect(names, ['web_search']);
      },
    );

    test('a client tool owning the name keeps the hosted one out', () async {
      final body = await _captureClaudeBuiltInSearchBody(
        modelId: 'claude-opus-4-7',
        config: _claudeConfig(
          'http://api.anthropic.com',
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[
                BuiltInToolNames.search,
                BuiltInToolNames.webFetch,
                BuiltInToolNames.codeExecution,
              ],
            },
          },
        ),
        tools: const <Map<String, dynamic>>[
          {
            'type': 'function',
            'function': {
              'name': 'web_fetch',
              'parameters': {'type': 'object'},
            },
          },
        ],
      );

      final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
      expect(tools.where((tool) => tool['name'] == 'web_fetch'), hasLength(1));
      expect(
        tools.singleWhere(
          (tool) => tool['name'] == 'web_fetch',
        )['input_schema'],
        isNotNull,
      );
      expect(tools.any((tool) => tool['name'] == 'code_execution'), isTrue);
      expect(tools.any((tool) => tool['name'] == 'web_search'), isTrue);
    });

    test('anywhere else gets no hosted tools and plain search', () async {
      final body = await _captureClaudeBuiltInSearchBody(
        modelId: 'claude-opus-4-7',
        config: _claudeConfig(
          'https://relay.example.com/v1',
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[
                BuiltInToolNames.search,
                BuiltInToolNames.webFetch,
                BuiltInToolNames.codeExecution,
              ],
              'webSearch': <String, dynamic>{
                'toolVersion': 'web_search_20260209',
              },
            },
          },
        ),
      );

      final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
      expect(tools.any((tool) => tool['name'] == 'web_fetch'), isFalse);
      expect(tools.any((tool) => tool['name'] == 'code_execution'), isFalse);
      // Search is the one built-in a relay may implement itself, but dynamic
      // filtering runs on Anthropic's side and cannot follow it there.
      expect(
        tools.any((tool) => tool['type'] == 'web_search_20250305'),
        isTrue,
      );
      expect(
        tools.any((tool) => tool['type'] == 'web_search_20260318'),
        isFalse,
      );
    });

    test('dynamic filtering upgrades the web fetch tool version', () async {
      final body = await _captureClaudeBuiltInSearchBody(
        modelId: 'claude-opus-4-7',
        config: _claudeConfig(
          'http://api.anthropic.com',
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[
                BuiltInToolNames.search,
                BuiltInToolNames.webFetch,
              ],
              'webSearch': <String, dynamic>{
                'toolVersion': 'web_search_20260209',
              },
            },
          },
        ),
      );

      final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
      expect(
        tools.firstWhere((tool) => tool['name'] == 'web_fetch')['type'],
        'web_fetch_20260318',
      );
    });

    test('Claude-compatible vendors get no Anthropic server tools', () async {
      // An official Claude model id, so only the vendor check can reject the
      // tools — `deepseek-chat` would be filtered by the model lists instead.
      final body = await _captureClaudeBuiltInSearchBody(
        modelId: 'claude-opus-4-7',
        config: _deepSeekClaudeConfig(
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[
                BuiltInToolNames.webFetch,
                BuiltInToolNames.codeExecution,
              ],
            },
          },
        ),
      );

      final tools =
          (body['tools'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      expect(tools.any((tool) => tool['name'] == 'web_fetch'), isFalse);
      expect(tools.any((tool) => tool['name'] == 'code_execution'), isFalse);
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

        expect(
          chunks.whereType<TextDelta>().where((chunk) => chunk.text == 'done'),
          hasLength(1),
        );
        expect(chunks.isGenerationDone, isTrue);
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
      final lowBody = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 2000,
      );
      final mediumBody = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 16000,
      );
      final xhighBody = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 64000,
      );
      final maxBody = await _captureClaudeProviderBody(
        modelId: 'deepseek-v4-pro',
        config: _deepSeekClaudeConfig(),
        thinkingBudget: 128000,
      );

      expect(lowBody['thinking'], {'type': 'enabled'});
      expect(lowBody['output_config'], {'effort': 'low'});
      expect(mediumBody['thinking'], {'type': 'enabled'});
      expect(mediumBody['output_config'], {'effort': 'high'});
      expect(xhighBody['thinking'], {'type': 'enabled'});
      expect(xhighBody['output_config'], {'effort': 'high'});
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

      expect(chunks.isGenerationDone, isTrue);
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

        expect(chunks.isGenerationDone, isTrue);
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

    test(
      'replayed web search keeps its native blocks and encrypted content',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          officialEndpoint: true,
          messages: _webSearchHistory,
        );

        final messages = (body['messages'] as List).cast<Map>();
        final assistantContent = (messages[1]['content'] as List).cast<Map>();
        expect(assistantContent.map((block) => block['type']).toList(), [
          'text',
          'server_tool_use',
          'web_search_tool_result',
        ]);
        final result = assistantContent.firstWhere(
          (block) => block['type'] == 'web_search_tool_result',
        );
        expect(
          ((result['content'] as List).first as Map)['encrypted_content'],
          'EqgfCioIARgBIiQ3',
        );
        // The server tool carries its own result, so the synthesised tool
        // message must not become a second, orphaned tool_result.
        for (final message in messages) {
          final content = message['content'];
          if (content is! List) continue;
          expect(
            content.whereType<Map>().any(
              (block) => block['type'] == 'tool_result',
            ),
            isFalse,
          );
        }
        expect(messages.last['content'], '第一条具体怎么说的');
      },
    );

    test('anywhere else the same turn replays as the client pair', () async {
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        messages: _webSearchHistory,
      );

      final messages = (body['messages'] as List).cast<Map>();
      final assistantContent = (messages[1]['content'] as List).cast<Map>();
      expect(assistantContent.map((block) => block['type']).toList(), [
        'text',
        'tool_use',
      ]);
      expect(assistantContent.last['name'], 'search_web');
      // The card summary comes back as an ordinary tool_result instead, which
      // is what every provider without Anthropic's server tools already got.
      final toolResults = messages
          .expand(
            (message) =>
                (message['content'] is List ? message['content'] as List : [])
                    .whereType<Map>(),
          )
          .where((block) => block['type'] == 'tool_result');
      expect(toolResults.single['tool_use_id'], 'srvtoolu_1');
      // An account-pool relay cannot decrypt this, and one rejection poisons
      // every later turn of the conversation.
      expect(jsonEncode(body).contains('encrypted_content'), isFalse);
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
          {
            'role': 'user',
            'content': 'inspect',
            multimodalInternalMediaPathsKey: [file.path],
          },
        ],
        onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
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
      expect(jsonEncode(requestBodies[1]), isNot(contains('[image:')));
    });
    test(
      'interrupted server tool is dropped instead of replayed orphaned',
      () async {
        // Stopping the stream between `server_tool_use` and its result block
        // persists the call without an output.
        const interruptedBlocks = [
          {'type': 'text', 'text': '我先查一下。'},
          {
            'type': 'server_tool_use',
            'id': 'srvtoolu_stopped',
            'name': 'web_fetch',
            'input': {'url': 'https://example.com'},
          },
        ];
        final body = await _captureClaudeRequestBody(
          officialEndpoint: true,
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': '看看这个页面'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                {
                  'id': 'srvtoolu_stopped',
                  'type': 'function',
                  'function': {
                    'name': 'web_fetch',
                    'arguments': '{"url":"https://example.com"}',
                  },
                  'metadata': {
                    'anthropic': {'assistant_blocks': interruptedBlocks},
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'srvtoolu_stopped',
              'name': 'web_fetch',
              'content': '{"items":[]}',
            },
            {'role': 'user', 'content': '算了，直接说吧'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        for (final message in messages) {
          final content = message['content'];
          if (content is! List) continue;
          final types = content
              .whereType<Map>()
              .map((block) => block['type'])
              .toList();
          // Neither half of the pair may survive: a `server_tool_use` with no
          // result block, nor a `tool_result` pointing at a call that is gone.
          expect(types, isNot(contains('server_tool_use')));
          expect(types, isNot(contains('tool_result')));
        }
        expect(messages.last['content'], '算了，直接说吧');
      },
    );

    test(
      'a hosted result deferred past a client tool replays with its call',
      () async {
        // A turn that starts both kinds of tool at once is cut in two: the
        // first response ends with the hosted call still running so the client
        // one can be answered, and the second opens with the hosted result.
        // Each card recorded the responses up to the one that last wrote it.
        const firstResponse = [
          {'type': 'text', 'text': '我查一下。'},
          {
            'type': 'server_tool_use',
            'id': 'srvtoolu_deferred',
            'name': 'web_fetch',
            'input': {'url': 'https://example.com'},
          },
          {
            'type': 'tool_use',
            'id': 'toolu_client',
            'name': 'create_memory',
            'input': {'content': 'test'},
          },
        ];
        const secondResponse = [
          {
            'type': 'web_fetch_tool_result',
            'tool_use_id': 'srvtoolu_deferred',
            'content': {'type': 'web_fetch_result', 'url': 'https://e.com'},
          },
          {'type': 'text', 'text': '查到了。'},
        ];
        final body = await _captureClaudeRequestBody(
          officialEndpoint: true,
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': '看看这个页面'},
            {
              'role': 'assistant',
              'content': '我查一下。查到了。',
              'tool_calls': [
                {
                  'id': 'srvtoolu_deferred',
                  'type': 'function',
                  'function': {
                    'name': 'web_fetch',
                    'arguments': '{"url":"https://example.com"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'responses': [firstResponse, secondResponse],
                    },
                  },
                },
                {
                  'id': 'toolu_client',
                  'type': 'function',
                  'function': {
                    'name': 'create_memory',
                    'arguments': '{"content":"test"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'responses': [firstResponse],
                    },
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'toolu_client',
              'name': 'create_memory',
              'content': 'test',
            },
            {'role': 'user', 'content': '再说说'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        // The protocol keeps the hand-off as three messages: the first
        // response, the client result alone, then the response that opens
        // with the hosted result.
        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
          'assistant',
          'user',
        ]);
        final first = (messages[1]['content'] as List).cast<Map>();
        expect(first.map((block) => block['type']).toList(), [
          'text',
          'server_tool_use',
          'tool_use',
        ]);
        final clientResult = (messages[2]['content'] as List).cast<Map>();
        expect(clientResult.single['tool_use_id'], 'toolu_client');
        final second = (messages[3]['content'] as List).cast<Map>();
        expect(second.map((block) => block['type']).toList(), [
          'web_fetch_tool_result',
          'text',
        ]);
        expect(second.first['tool_use_id'], first[1]['id']);
        expect(messages[4]['content'], '再说说');
      },
    );

    test(
      'the persisted text of a deferred response folds into it, not after it',
      () async {
        // The store keeps the turn's final text as its own assistant message
        // after the client result; replayed, it belongs to the response that
        // opens with the hosted result and must not form a third message.
        const firstResponse = [
          {
            'type': 'server_tool_use',
            'id': 'srvtoolu_deferred',
            'name': 'web_fetch',
            'input': {'url': 'https://example.com'},
          },
          {
            'type': 'tool_use',
            'id': 'toolu_client',
            'name': 'create_memory',
            'input': {'content': 'test'},
          },
        ];
        const secondResponse = [
          {
            'type': 'web_fetch_tool_result',
            'tool_use_id': 'srvtoolu_deferred',
            'content': {'type': 'web_fetch_result', 'url': 'https://e.com'},
          },
          {'type': 'text', 'text': '查到了。'},
        ];
        final body = await _captureClaudeRequestBody(
          officialEndpoint: true,
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': '看看这个页面'},
            {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'id': 'srvtoolu_deferred',
                  'type': 'function',
                  'function': {
                    'name': 'web_fetch',
                    'arguments': '{"url":"https://example.com"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'responses': [firstResponse, secondResponse],
                    },
                  },
                },
                {
                  'id': 'toolu_client',
                  'type': 'function',
                  'function': {
                    'name': 'create_memory',
                    'arguments': '{"content":"test"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'responses': [firstResponse],
                    },
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'toolu_client',
              'name': 'create_memory',
              'content': 'test',
            },
            {'role': 'assistant', 'content': '查到了。'},
            {'role': 'user', 'content': '再说说'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
          'assistant',
          'user',
        ]);
        final second = (messages[3]['content'] as List).cast<Map>();
        expect(second.map((block) => block['type']).toList(), [
          'web_fetch_tool_result',
          'text',
        ]);
        expect(second.last['text'], '查到了。');
      },
    );

    test(
      'two hand-offs in a row keep each client result with its response',
      () async {
        // The client loop may run more than once: every response starts a
        // hosted call and a client one, so each client result closes the
        // response that declared it and the next opens with the hosted result.
        final firstResponse = [
          {'type': 'text', 'text': '我查一下。'},
          _hostedCall('srvtoolu_1', 'https://example.com/1'),
          _clientCall('toolu_client_1', 'one'),
        ];
        final secondResponse = [
          _hostedResult('srvtoolu_1', 'https://e.com/1'),
          {'type': 'text', 'text': '再查一下。'},
          _hostedCall('srvtoolu_2', 'https://example.com/2'),
          _clientCall('toolu_client_2', 'two'),
        ];
        final thirdResponse = [
          _hostedResult('srvtoolu_2', 'https://e.com/2'),
          {'type': 'text', 'text': '查到了。'},
        ];
        final body = await _captureClaudeRequestBody(
          officialEndpoint: true,
          modelId: 'claude-sonnet-4-6',
          messages: [
            {'role': 'user', 'content': '看看这两个页面'},
            {
              'role': 'assistant',
              'content': '我查一下。再查一下。查到了。',
              'tool_calls': [
                _replayCall('srvtoolu_1', 'web_fetch', [
                  firstResponse,
                  secondResponse,
                ]),
                _replayCall('toolu_client_1', 'create_memory', [firstResponse]),
                _replayCall('srvtoolu_2', 'web_fetch', [
                  firstResponse,
                  secondResponse,
                  thirdResponse,
                ]),
                _replayCall('toolu_client_2', 'create_memory', [
                  firstResponse,
                  secondResponse,
                ]),
              ],
            },
            _toolResult('toolu_client_1', 'create_memory', 'one'),
            _toolResult('toolu_client_2', 'create_memory', 'two'),
            {'role': 'user', 'content': '再说说'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
          'assistant',
          'user',
          'assistant',
          'user',
        ]);
        expect(_blockTypes(messages[1]), [
          'text',
          'server_tool_use',
          'tool_use',
        ]);
        expect(_resultIds(messages[2]), ['toolu_client_1']);
        expect(_blockTypes(messages[3]), [
          'web_fetch_tool_result',
          'text',
          'server_tool_use',
          'tool_use',
        ]);
        expect(_resultIds(messages[4]), ['toolu_client_2']);
        expect(_blockTypes(messages[5]), ['web_fetch_tool_result', 'text']);
        expect(messages[6]['content'], '再说说');
      },
    );

    test('a hand-off cut off mid loop drops the results it orphaned', () async {
      // History ends on the second client result: the response that declared
      // that call never arrived, so replaying its result would point at a
      // `tool_use` no longer in the history.
      final firstResponse = [
        {'type': 'text', 'text': '我查一下。'},
        _hostedCall('srvtoolu_1', 'https://example.com/1'),
        _clientCall('toolu_client_1', 'one'),
      ];
      final secondResponse = [
        _hostedResult('srvtoolu_1', 'https://e.com/1'),
        _hostedCall('srvtoolu_2', 'https://example.com/2'),
        _clientCall('toolu_client_2', 'two'),
      ];
      final thirdResponse = [_hostedResult('srvtoolu_2', 'https://e.com/2')];
      final body = await _captureClaudeRequestBody(
        officialEndpoint: true,
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这两个页面'},
          {
            'role': 'assistant',
            'content': '我查一下。',
            'tool_calls': [
              _replayCall('srvtoolu_1', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
              _replayCall('toolu_client_1', 'create_memory', [firstResponse]),
              _replayCall('srvtoolu_2', 'web_fetch', [
                firstResponse,
                secondResponse,
                thirdResponse,
              ]),
              _replayCall('toolu_client_2', 'create_memory', [
                firstResponse,
                secondResponse,
              ]),
            ],
          },
          _toolResult('toolu_client_1', 'create_memory', 'one'),
          _toolResult('toolu_client_2', 'create_memory', 'two'),
        ],
      );

      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.map((message) => message['role']).toList(), [
        'user',
        'assistant',
        'user',
      ]);
      // The open hosted call goes too, so only the first client pair is left.
      expect(_blockTypes(messages[1]), ['text', 'tool_use']);
      expect(_resultIds(messages[2]), ['toolu_client_1']);
    });

    test('a relayed hand-off keeps the order the API produced', () async {
      // Everywhere but the official endpoint the hosted blocks are dropped and
      // the calls replay as the client pair. The responses still come back in
      // the order recorded, the thinking block first as Anthropic requires,
      // and the persisted text folds into the turn instead of repeating it.
      final firstResponse = [
        {'type': 'thinking', 'thinking': '先查页面。', 'signature': 'sig-handoff'},
        {'type': 'text', 'text': '我查一下。'},
        _hostedCall('srvtoolu_relay', 'https://example.com'),
        _clientCall('toolu_client', 'test'),
      ];
      final secondResponse = [
        _hostedResult('srvtoolu_relay', 'https://e.com'),
        {'type': 'text', 'text': '查到了。'},
      ];
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          // The shape the app persists: the message holding the cards has no
          // text of its own, and the turn's text follows as its own message.
          {
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              _replayCall('srvtoolu_relay', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
              _replayCall('toolu_client', 'create_memory', [firstResponse]),
            ],
          },
          _toolResult('srvtoolu_relay', 'web_fetch', '{"url":"https://e.com"}'),
          _toolResult('toolu_client', 'create_memory', 'test'),
          {'role': 'assistant', 'content': '我查一下。查到了。'},
          {'role': 'user', 'content': '再说说'},
        ],
      );

      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.map((message) => message['role']).toList(), [
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      final assistant = (messages[1]['content'] as List).cast<Map>();
      expect(assistant.first['type'], 'thinking');
      // The turn's text, in the order the API wrote it and only once: the
      // persisted message aggregates it, so it must fold into the turn rather
      // than replay on top of it.
      expect(_assistantText(messages), '我查一下。查到了。');
      // Both calls replay as client tools, each with its result.
      final calls = assistant
          .where((block) => block['type'] == 'tool_use')
          .map((block) => block['id'])
          .toSet();
      expect(calls, {'srvtoolu_relay', 'toolu_client'});
      expect(_resultIds(messages[2]).toSet(), calls);
      expect(_blockTypes(messages[3]), ['text']);
    });

    test(
      'a relayed textless deferred response leaves no text behind',
      () async {
        // A response carrying only the hosted result has nothing left to send
        // once those blocks are dropped, so on a relay the turn is the one
        // assistant message and its results. The persisted message aggregates
        // the text of the whole turn, which that message already holds, so
        // sending it on top would replay the turn twice.
        final firstResponse = [
          {'type': 'text', 'text': 'checking'},
          _hostedCall('srvtoolu_relay', 'https://example.com'),
          _clientCall('toolu_client', 'test'),
        ];
        final secondResponse = [
          _hostedResult('srvtoolu_relay', 'https://e.com'),
        ];
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          messages: [
            {'role': 'user', 'content': '看看这个页面'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                _replayCall('srvtoolu_relay', 'web_fetch', [
                  firstResponse,
                  secondResponse,
                ]),
                _replayCall('toolu_client', 'create_memory', [firstResponse]),
              ],
            },
            _toolResult(
              'srvtoolu_relay',
              'web_fetch',
              '{"url":"https://e.com"}',
            ),
            _toolResult('toolu_client', 'create_memory', 'test'),
            {'role': 'assistant', 'content': 'checking'},
            {'role': 'user', 'content': '再说说'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        expect(_assistantText(messages), 'checking');
        // The results and the user message that follows them are consecutive
        // user turns, which the API combines into the one turn they were.
        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
          'user',
        ]);
        expect(_blockTypes(messages[1]), ['text', 'tool_use', 'tool_use']);
        expect(_resultIds(messages[2]).toSet(), {
          'srvtoolu_relay',
          'toolu_client',
        });
      },
    );

    test('a deferred response that wrote nothing stays textless', () async {
      // The persisted message aggregates the text of the whole turn, so the
      // first response's text must not be folded into a later one that only
      // carries the hosted result.
      final firstResponse = [
        {'type': 'text', 'text': 'checking'},
        _hostedCall('srvtoolu_deferred', 'https://example.com'),
        _clientCall('toolu_client', 'test'),
      ];
      final secondResponse = [
        _hostedResult('srvtoolu_deferred', 'https://e.com'),
      ];
      final body = await _captureClaudeRequestBody(
        officialEndpoint: true,
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          {
            'role': 'assistant',
            'content': 'checking',
            'tool_calls': [
              _replayCall('srvtoolu_deferred', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
              _replayCall('toolu_client', 'create_memory', [firstResponse]),
            ],
          },
          _toolResult('toolu_client', 'create_memory', 'test'),
          {'role': 'assistant', 'content': 'checking'},
          {'role': 'user', 'content': '再说说'},
        ],
      );

      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.map((message) => message['role']).toList(), [
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      expect(_blockTypes(messages[1]), ['text', 'server_tool_use', 'tool_use']);
      expect(_blockTypes(messages[3]), ['web_fetch_tool_result']);
    });
    test(
      'a hand-off cut off at the client result drops the open hosted call',
      () async {
        // History truncated right after the client result: the second
        // response can neither follow it (that would prefill the answer) nor
        // be skipped while the first still holds the call it resolves.
        const firstResponse = [
          {
            'type': 'server_tool_use',
            'id': 'srvtoolu_deferred',
            'name': 'web_fetch',
            'input': {'url': 'https://example.com'},
          },
          {
            'type': 'tool_use',
            'id': 'toolu_client',
            'name': 'create_memory',
            'input': {'content': 'test'},
          },
        ];
        const secondResponse = [
          {
            'type': 'web_fetch_tool_result',
            'tool_use_id': 'srvtoolu_deferred',
            'content': {'type': 'web_fetch_result', 'url': 'https://e.com'},
          },
          {'type': 'text', 'text': '查到了。'},
        ];
        final body = await _captureClaudeRequestBody(
          officialEndpoint: true,
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': '看看这个页面'},
            {
              'role': 'assistant',
              'content': '查到了。',
              'tool_calls': [
                {
                  'id': 'srvtoolu_deferred',
                  'type': 'function',
                  'function': {
                    'name': 'web_fetch',
                    'arguments': '{"url":"https://example.com"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'responses': [firstResponse, secondResponse],
                    },
                  },
                },
                {
                  'id': 'toolu_client',
                  'type': 'function',
                  'function': {
                    'name': 'create_memory',
                    'arguments': '{"content":"test"}',
                  },
                  'metadata': {
                    'anthropic': {
                      'responses': [firstResponse],
                    },
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'toolu_client',
              'name': 'create_memory',
              'content': 'test',
            },
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
        ]);
        final assistant = (messages[1]['content'] as List).cast<Map>();
        expect(assistant.map((block) => block['type']).toList(), ['tool_use']);
        final clientResult = (messages[2]['content'] as List).cast<Map>();
        expect(clientResult.single['tool_use_id'], 'toolu_client');
      },
    );

    test('a turn resumed after pause_turn replays both responses', () async {
      // A hosted tool that ran past the turn limit is resumed in a second
      // response, with no client result in between. The one card of the turn
      // was written by both responses; only the recording of the later one
      // survives, so it has to carry the earlier response too or the call and
      // the text before it would be lost.
      final firstResponse = [
        {'type': 'text', 'text': '我查一下。'},
        _hostedCall('srvtoolu_paused', 'https://example.com'),
      ];
      final secondResponse = [
        _hostedResult('srvtoolu_paused', 'https://e.com'),
        {'type': 'text', 'text': '查到了。'},
      ];
      final body = await _captureClaudeRequestBody(
        officialEndpoint: true,
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          {
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              _replayCall('srvtoolu_paused', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
            ],
          },
          _toolResult(
            'srvtoolu_paused',
            'web_fetch',
            '{"url":"https://e.com"}',
          ),
          {'role': 'assistant', 'content': '我查一下。查到了。'},
          {'role': 'user', 'content': '再说说'},
        ],
      );

      final messages = (body['messages'] as List).cast<Map>();
      // Nothing separates the two responses, so they are the one turn.
      expect(messages.map((message) => message['role']).toList(), [
        'user',
        'assistant',
        'user',
      ]);
      expect(_blockTypes(messages[1]), [
        'text',
        'server_tool_use',
        'web_fetch_tool_result',
        'text',
      ]);
      expect(_assistantText(messages), '我查一下。查到了。');
    });

    test('every turn shape replays as one assistant message', () async {
      // How the persisted assistant text can relate to the turn's own text
      // blocks, and what the replayed turn has to end up saying.
      const search = {
        'type': 'server_tool_use',
        'id': 's',
        'name': 'web_search',
      };
      const result = {'type': 'web_search_tool_result', 'tool_use_id': 's'};
      final shapes = <String, (List<Map<String, dynamic>>, String, String)>{
        'message repeats the text after the tool': (
          [
            search,
            result,
            {'type': 'text', 'text': 'A'},
          ],
          'A',
          'A',
        ),
        'message joins the text from before and after': (
          [
            {'type': 'thinking', 'thinking': '...', 'signature': 'sig'},
            {'type': 'text', 'text': 'A'},
            search,
            result,
            {'type': 'text', 'text': 'B'},
          ],
          'AB',
          'AB',
        ),
        'blocks stopped mid-text': (
          [
            search,
            result,
            {'type': 'text', 'text': 'A'},
          ],
          'AB',
          'AB',
        ),
        'turn said nothing around the tool': ([search, result], 'A', 'A'),
        'the two disagree, blocks win': (
          [
            search,
            result,
            {'type': 'text', 'text': 'A'},
          ],
          'totally different',
          'A',
        ),
        'message is the empty placeholder': (
          [
            search,
            result,
            {'type': 'text', 'text': 'A'},
          ],
          '\n\n',
          'A',
        ),
      };

      for (final entry in shapes.entries) {
        final (blocks, persistedText, expectedText) = entry.value;
        final body = await _captureClaudeRequestBody(
          officialEndpoint: true,
          modelId: 'claude-sonnet-4-6',
          messages: [
            {'role': 'user', 'content': 'q'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                {
                  'id': 's',
                  'type': 'function',
                  'function': {'name': 'search_web', 'arguments': '{}'},
                  'metadata': {
                    'anthropic': {'assistant_blocks': blocks},
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 's',
              'name': 'search_web',
              'content': '{"items":[]}',
            },
            {'role': 'assistant', 'content': persistedText},
            {'role': 'user', 'content': 'next'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        // Anthropic requires the roles to alternate; two assistant messages in
        // a row is what made it reject the replayed encrypted_content.
        expect(messages.map((m) => m['role']).toList(), [
          'user',
          'assistant',
          'user',
        ], reason: entry.key);
        final content = (messages[1]['content'] as List).cast<Map>();
        expect(
          content
              .where((b) => b['type'] == 'text')
              .map((b) => b['text'])
              .join(),
          expectedText,
          reason: entry.key,
        );
        // The tool blocks stay put whatever happens to the text around them.
        expect(
          content.map((b) => b['type']).where((t) => t != 'text').toList(),
          blocks.map((b) => b['type']).where((t) => t != 'text').toList(),
          reason: entry.key,
        );
      }
    });

    test(
      'a client tool turn still separates the two assistant messages',
      () async {
        final body = await _captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'q'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                {
                  'id': 'call_1',
                  'type': 'function',
                  'function': {'name': 'memory_read', 'arguments': '{}'},
                  'metadata': {
                    'anthropic': {
                      'assistant_blocks': [
                        {
                          'type': 'tool_use',
                          'id': 'call_1',
                          'name': 'memory_read',
                          'input': {},
                        },
                      ],
                    },
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'call_1',
              'name': 'memory_read',
              'content': 'remembered',
            },
            {'role': 'assistant', 'content': 'Here is what I recall.'},
            {'role': 'user', 'content': 'next'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        // The client tool result is a user message, so it keeps the two apart
        // and the assistant text must survive on its own.
        expect(messages.map((m) => m['role']).toList(), [
          'user',
          'assistant',
          'user',
          'assistant',
          'user',
        ]);
        expect(messages[3]['content'], 'Here is what I recall.');
      },
    );

    test(
      'a downgraded web_search tool_use never asks for a client round',
      () async {
        // Relays have been seen running the declared server tool upstream but
        // labelling its block `tool_use`. Answering that as a client tool sends
        // back an empty result, which the model reports as an empty search.
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          final round = requestBodies.length;
          requestBodies.add(
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>(),
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(round > 0 ? _plainRound : _downgradedRound);
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _claudeConfig(
            'http://${server.address.address}:${server.port}',
            modelOverrides: const <String, dynamic>{
              'claude-sonnet-4-6': <String, dynamic>{
                'builtInTools': <String>[BuiltInToolNames.search],
              },
            },
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': '搜索一下kelivo'},
          ],
          stream: true,
        ).toList();

        expect(requestBodies, hasLength(1));
        expect(chunks.whereType<ServerToolStart>(), hasLength(1));
        expect(
          chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
          'found it',
        );
      },
    );

    test('an empty tool result still carries an explicit content', () async {
      // Omitting `content` leaves the call unanswered and Anthropic rejects an
      // empty text block, so a tool that produced nothing needs a placeholder.
      final body = await _captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': '几点了'},
          {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'toolu_empty',
                'type': 'function',
                'function': {'name': 'get_time', 'arguments': '{}'},
              },
            ],
          },
          {'role': 'tool', 'tool_call_id': 'toolu_empty', 'content': ''},
          {'role': 'user', 'content': '那算了'},
        ],
      );

      final results = [
        for (final message in (body['messages'] as List).cast<Map>())
          if (message['content'] is List)
            for (final block in (message['content'] as List).whereType<Map>())
              if (block['type'] == 'tool_result') block,
      ];
      expect(results.single['content'], '(no output)');
    });

    test(
      'the continuation round carries the server tool that just ran',
      () async {
        final bodies = await _captureClaudeServerToolRounds(
          officialEndpoint: true,
        );

        final messages = (bodies[1]['messages'] as List).cast<Map>();
        final assistant = messages.firstWhere((m) => m['role'] == 'assistant');
        final types = (assistant['content'] as List)
            .cast<Map>()
            .map((block) => block['type'])
            .toList();
        expect(
          types,
          containsAll(['server_tool_use', 'web_search_tool_result']),
        );
        // Without the result block the API would run the same search again.
        expect(jsonEncode(bodies[1]), contains('EqgfCioIARgBIiQ3'));
      },
    );

    test('anywhere else the continuation round leaves it behind', () async {
      final bodies = await _captureClaudeServerToolRounds(
        officialEndpoint: false,
      );

      final messages = (bodies[1]['messages'] as List).cast<Map>();
      final assistant = messages.firstWhere((m) => m['role'] == 'assistant');
      final types = (assistant['content'] as List)
          .cast<Map>()
          .map((block) => block['type'])
          .toList();
      expect(types, ['tool_use']);
      // An account-pool relay rejects what it cannot decrypt, and that one
      // rejection ends the conversation.
      expect(jsonEncode(bodies[1]), isNot(contains('EqgfCioIARgBIiQ3')));
    });
  });
}
