import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import '../../../../../support/claude_test_api.dart';
import '../../../../../support/collect_generation.dart';

/// One DeepSeek round that runs its own `web_search` and ends the turn.
const deepSeekSearchRound = '''
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

''';

void main() {
  group('Claude hosted tools request', () {
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
      final official = claudeConfig(
        baseUrl: officialBaseUrl,
        modelOverrides: const <String, dynamic>{},
      );
      final vertex = vertexClaudeConfig();

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
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        config: claudeConfig(
          baseUrl: officialBaseUrl,
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
        final body = await captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          config: claudeConfig(
            baseUrl: officialBaseUrl,
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
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-5',
        config: claudeConfig(
          baseUrl: officialBaseUrl,
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
      'a utility call gets search only, never fetch or a container',
      () async {
        final body = await captureClaudeRequestBody(
          modelId: 'claude-opus-4-7',
          utilityCall: true,
          config: claudeConfig(
            baseUrl: officialBaseUrl,
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
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        config: claudeConfig(
          baseUrl: officialBaseUrl,
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
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        config: claudeConfig(
          baseUrl: relayBaseUrl,
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
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        config: claudeConfig(
          baseUrl: officialBaseUrl,
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
      final body = await captureClaudeRequestBody(
        modelId: 'claude-opus-4-7',
        config: deepSeekClaudeConfig(
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
        final cfg = deepSeekClaudeConfig(
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

        final body = await captureClaudeRequestBody(
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
        final (
          bodies: requestBodies,
          :chunks,
          paths: _,
        ) = await captureClaudeExchange(
          config: deepSeekClaudeConfig(
            modelOverrides: const <String, dynamic>{
              'deepseek-v4-flash': <String, dynamic>{
                'builtInTools': <String>[BuiltInToolNames.search],
              },
            },
          ),
          modelId: 'deepseek-v4-flash',
          messages: const [
            {'role': 'user', 'content': '搜索一下kelivo'},
          ],
          stream: true,
          sseRounds: const [deepSeekSearchRound],
        );

        expect(
          chunks.whereType<TextDelta>().where((chunk) => chunk.text == 'done'),
          hasLength(1),
        );
        expect(chunks.isGenerationDone, isTrue);
        expect(requestBodies, hasLength(1));
      },
    );

    test(
      'Vertex Claude keeps old search tool selection even with new flag',
      () {
        final cfg = vertexClaudeConfig(
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

    test(
      'a downgraded web_search tool_use never asks for a client round',
      () async {
        // Relays have been seen running the declared server tool upstream but
        // labelling its block `tool_use`. Answering that as a client tool sends
        // back an empty result, which the model reports as an empty search.
        final (
          bodies: requestBodies,
          :chunks,
          paths: _,
        ) = await captureClaudeExchange(
          config: claudeConfig(
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
          sseRounds: const [downgradedRound, plainRound],
        );

        expect(requestBodies, hasLength(1));
        expect(chunks.whereType<ServerToolStart>(), hasLength(1));
        expect(
          chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
          'found it',
        );
      },
    );
  });
}
