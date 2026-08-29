/// Shared scaffolding for the Claude provider tests: provider configs, the
/// block shapes a tool turn is persisted in, and a fake Messages API that
/// records what it was sent.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'collect_generation.dart';

/// The official endpoint, the one host Anthropic's server tools are sent to.
const officialBaseUrl = 'http://api.anthropic.com';

/// Anywhere else: [captureClaudeExchange] points it at the fake server.
const relayBaseUrl = 'https://relay.example.com/v1';

ProviderConfig claudeConfig({
  String baseUrl = relayBaseUrl,
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

ProviderConfig vertexClaudeConfig({
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

ProviderConfig deepSeekClaudeConfig({
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

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

class ProxyHttpOverrides extends HttpOverrides {
  ProxyHttpOverrides(this.port);

  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
    return client;
  }
}

/// A relay that ran `web_search` upstream but labelled the block `tool_use`.
const downgradedRound = '''
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

const plainRound = '''
event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"second round"}}

event: message_stop
data: {"type":"message_stop"}

''';

/// One streamed response as the API frames it: a `message_start` naming
/// [messageId], then [events] each under its own `event:` line.
String sseRound(String messageId, List<Map<String, dynamic>> events) {
  final buffer = StringBuffer()
    ..write('event: message_start\n')
    ..write(
      'data: ${jsonEncode({
        'type': 'message_start',
        'message': {
          'id': messageId,
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
      })}\n\n',
    );
  for (final event in events) {
    buffer.write('event: ${event['type']}\ndata: ${jsonEncode(event)}\n\n');
  }
  return buffer.toString();
}

/// The block shapes of a hosted / client tool hand-off, and the card the app
/// persists for one: every response of the turn carries its own block list.
Map<String, dynamic> hostedCall(String id, String url) => {
  'type': 'server_tool_use',
  'id': id,
  'name': 'web_fetch',
  'input': {'url': url},
};

Map<String, dynamic> hostedResult(String id, String url) => {
  'type': 'web_fetch_tool_result',
  'tool_use_id': id,
  'content': {'type': 'web_fetch_result', 'url': url},
};

Map<String, dynamic> clientCall(String id, String content) => {
  'type': 'tool_use',
  'id': id,
  'name': 'create_memory',
  'input': {'content': content},
};

/// A card as an earlier version of the app persisted it: it recorded the
/// turn's responses up to the one that last wrote it, so a client call's card
/// stops at the response that declared it and a hosted call's reaches the one
/// carrying its result. The turn is now stored once, against the message — see
/// [storedTurn] — and these cards are read only for what was written before.
Map<String, dynamic> replayCall(
  String id,
  String name,
  List<List<Map<String, dynamic>>> responses,
) => {
  'id': id,
  'type': 'function',
  'function': {'name': name, 'arguments': '{}'},
  'metadata': {
    'anthropic': {'responses': responses},
  },
};

/// The tool turn as the app now persists it: a message holding the cards,
/// with the turn's responses stored once against it.
Map<String, dynamic> storedTurn(
  List<List<Map<String, dynamic>>> responses,
  List<Map<String, dynamic>> calls,
) => {
  'role': 'assistant',
  'content': '\n\n',
  'tool_calls': calls,
  multimodalInternalClaudeTurnKey: encodeClaudeTurn(responses),
};

Map<String, dynamic> card(String id, String name) => {
  'id': id,
  'type': 'function',
  'function': {'name': name, 'arguments': '{}'},
};

Map<String, dynamic> toolResult(String id, String name, String content) => {
  'role': 'tool',
  'tool_call_id': id,
  'name': name,
  'content': content,
};

typedef ClaudeExchange = ({
  List<Map<String, dynamic>> bodies,
  List<StreamChunk> chunks,
  List<String> paths,
});

/// What Claude was sent and what came back, for a turn against a fake API.
///
/// Each round is answered from [replies] as JSON — a response body whose `id`
/// and `usage` are filled in when missing — or, when [sseRounds] is given, with
/// that raw SSE body instead; the last entry answers every later round.
/// [utilityCall] runs the turn as `generateText`, the title / summary path,
/// and hands its text back as the one chunk. Server tool blocks are gated on
/// the endpoint's host, so a [config] naming Anthropic or Vertex keeps its
/// `baseUrl` and reaches the server through a proxy; any other has its
/// `baseUrl` rewritten to the server.
Future<ClaudeExchange> captureClaudeExchange({
  ProviderConfig? config,
  required String modelId,
  List<Map<String, dynamic>> messages = const [
    {'role': 'user', 'content': 'hello'},
  ],
  List<Map<String, dynamic>>? tools,
  Future<String> Function(
    String name,
    Map<String, dynamic> args, {
    String? toolCallId,
  })?
  onToolCall,
  int? thinkingBudget,
  double? temperature,
  double? topP,
  bool utilityCall = false,
  bool stream = false,
  List<Map<String, dynamic>> replies = const [
    {
      'content': [
        {'type': 'text', 'text': 'ok'},
      ],
    },
  ],
  List<String>? sseRounds,
}) async {
  final bodies = <Map<String, dynamic>>[];
  final paths = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    final round = bodies.length;
    paths.add(request.uri.path);
    bodies.add(
      (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, dynamic>(),
    );
    request.response.statusCode = HttpStatus.ok;
    if (sseRounds != null) {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(sseRounds[round.clamp(0, sseRounds.length - 1)]);
    } else {
      final reply = replies[round.clamp(0, replies.length - 1)];
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'id': 'msg_${round + 1}',
          'usage': {'input_tokens': 1, 'output_tokens': 1},
          ...reply,
        }),
      );
    }
    await request.response.close();
  });

  final serverUrl = 'http://${server.address.address}:${server.port}';
  final cfg = config ?? claudeConfig();
  final keepBaseUrl =
      cfg.vertexAI == true ||
      (Uri.tryParse(cfg.baseUrl)?.host ?? '') == 'api.anthropic.com';

  final chunks = <StreamChunk>[];
  Future<void> send(ProviderConfig effective) async {
    if (utilityCall) {
      final text = await ChatApiService.generateText(
        config: effective,
        modelId: modelId,
        prompt: 'hello',
        thinkingBudget: thinkingBudget,
      );
      // The text of every round, in order, is what the call must hand back.
      expect(
        text,
        replies
            .expand((reply) => (reply['content'] as List).cast<Map>())
            .where((block) => block['type'] == 'text')
            .map((block) => block['text'])
            .join(),
      );
      chunks.add(TextDelta(id: 'utility', text: text));
      return;
    }
    chunks.addAll(
      await ChatApiService.sendMessageStream(
        config: effective,
        modelId: modelId,
        messages: messages,
        tools: tools,
        onToolCall: onToolCall,
        thinkingBudget: thinkingBudget,
        temperature: temperature,
        topP: topP,
        stream: stream,
      ).toList(),
    );
    expect(chunks.isGenerationDone, isTrue);
  }

  if (keepBaseUrl) {
    await HttpOverrides.runZoned(
      () => send(cfg),
      createHttpClient: (context) =>
          ProxyHttpOverrides(server.port).createHttpClient(context),
    );
  } else {
    await send(cfg.copyWith(baseUrl: serverUrl));
  }
  return (bodies: bodies, chunks: chunks, paths: paths);
}

/// The one request body of a single-round turn; see [captureClaudeExchange].
Future<Map<String, dynamic>> captureClaudeRequestBody({
  ProviderConfig? config,
  required String modelId,
  List<Map<String, dynamic>> messages = const [
    {'role': 'user', 'content': 'hello'},
  ],
  List<Map<String, dynamic>>? tools,
  int? thinkingBudget,
  double? temperature,
  double? topP,
  bool utilityCall = false,
  List<Map<String, dynamic>> replies = const [
    {
      'content': [
        {'type': 'text', 'text': 'ok'},
      ],
    },
  ],
}) async => (await captureClaudeExchange(
  config: config,
  modelId: modelId,
  messages: messages,
  tools: tools,
  onToolCall: tools == null ? null : (name, args, {toolCallId}) async => '{}',
  thinkingBudget: thinkingBudget,
  temperature: temperature,
  topP: topP,
  utilityCall: utilityCall,
  replies: replies,
)).bodies.single;

/// Both request bodies of a turn where Claude calls a server tool and a client
/// tool at once, and every chunk it produced: the API leaves the server tool's
/// result in the first response, and the continuation round decides whether
/// it travels back.
Future<({List<Map<String, dynamic>> bodies, List<StreamChunk> chunks})>
captureClaudeServerToolRounds({required bool officialEndpoint}) async {
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

  final exchange = await captureClaudeExchange(
    config: officialEndpoint ? claudeConfig(baseUrl: officialBaseUrl) : null,
    modelId: 'claude-sonnet-4-6',
    messages: const [
      {'role': 'user', 'content': 'kyoto'},
    ],
    onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
    stream: true,
    sseRounds: [sseRound('msg_1', round1), sseRound('msg_2', round2)],
  );
  expect(exchange.bodies, hasLength(2));
  return (bodies: exchange.bodies, chunks: exchange.chunks);
}
