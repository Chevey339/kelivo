import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_container.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import '../../../../../support/claude_test_api.dart';
import '../../../../../support/collect_generation.dart';

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

/// A relay round whose thinking came back redacted before the tool call.
const redactedThinkingRound = '''
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

''';

const doneRound = '''
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

''';

void main() {
  group('Claude history replay', () {
    test(
      'a non-streaming pause_turn resumes with the hosted exchange intact',
      () async {
        // A hosted tool that outran the turn limit asks to be resumed, with
        // no client tool to answer first.
        final (:bodies, :chunks, paths: _) = await captureClaudeExchange(
          config: claudeConfig(
            baseUrl: officialBaseUrl,
            modelOverrides: const <String, dynamic>{
              'claude-opus-4-7': <String, dynamic>{
                'builtInTools': <String>[BuiltInToolNames.search],
              },
            },
          ),
          modelId: 'claude-opus-4-7',
          utilityCall: true,
          replies: const [
            {
              'stop_reason': 'pause_turn',
              'content': [
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
              ],
            },
            {
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'text', 'text': 'ok'},
              ],
            },
          ],
        );
        expect(chunks.joinedContent, 'before ok');

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

    test('history tool replay preserves thinking block signature', () async {
      final (:bodies, :chunks, paths: _) = await captureClaudeExchange(
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
      );

      expect(chunks.isGenerationDone, isTrue);
      final messages = (bodies.single['messages'] as List).cast<Map>();
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
        final (
          bodies: requestBodies,
          :chunks,
          paths: _,
        ) = await captureClaudeExchange(
          config: claudeConfig().copyWith(id: 'OpenRouter', name: 'OpenRouter'),
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
          stream: true,
          sseRounds: const [redactedThinkingRound, doneRound],
        );

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
        final body = await captureClaudeRequestBody(
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
        final body = await captureClaudeRequestBody(
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
        final body = await captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          config: claudeConfig(baseUrl: officialBaseUrl),
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
      final body = await captureClaudeRequestBody(
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

      final (
        bodies: requestBodies,
        :chunks,
        paths: _,
      ) = await captureClaudeExchange(
        modelId: 'claude-sonnet-4-6',
        messages: [
          {
            'role': 'user',
            'content': 'inspect',
            multimodalInternalMediaPathsKey: [file.path],
          },
        ],
        onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
        replies: const [
          {
            'content': [
              {
                'type': 'tool_use',
                'id': 'toolu_1',
                'name': 'lookup',
                'input': <String, dynamic>{},
              },
            ],
          },
          {
            'content': [
              {'type': 'text', 'text': 'done'},
            ],
          },
        ],
      );

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

    test('an image the assistant produced opens the next user turn', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_claude_assistant_img_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final file = File('${dir.path}/chart.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '画个图'},
          {
            'role': 'assistant',
            'content': '画好了',
            multimodalInternalMediaPathsKey: [file.path],
          },
          {'role': 'user', 'content': '哪根柱子最高'},
        ],
      );

      final messages = (body['messages'] as List).cast<Map>();
      // The API rejects an image block in an assistant turn outright.
      expect(messages[1]['content'], '画好了');
      final followUp = (messages[2]['content'] as List).cast<Map>();
      expect(followUp.map((part) => part['type']).toList(), [
        'text',
        'image',
        'text',
      ]);
      expect(followUp[1]['source']['data'], 'AQIDBA==');
      expect(followUp.last['text'], '哪根柱子最高');
    });

    test('an image on the last assistant turn has nowhere to go', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_claude_assistant_img_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final file = File('${dir.path}/chart.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '画个图'},
          {
            'role': 'assistant',
            'content': '画好了',
            multimodalInternalMediaPathsKey: [file.path],
          },
        ],
      );

      expect(jsonEncode(body), isNot(contains('"image"')));
    });

    test(
      'a chart from a persisted code execution turn opens the next user turn',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'kelivo_claude_assistant_img_',
        );
        addTearDown(() async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });
        final file = File('${dir.path}/chart.png');
        await file.writeAsBytes(const [1, 2, 3, 4]);

        // What MessageBuilder emits for a turn that ran code and drew a chart:
        // the card message, the hosted result, then the text with the image.
        const blocks = [
          {'type': 'text', 'text': '我来画。'},
          {
            'type': 'server_tool_use',
            'id': 'srvtoolu_plot',
            'name': 'bash_code_execution',
            'input': {'command': 'python plot.py'},
          },
          {
            'type': 'bash_code_execution_tool_result',
            'tool_use_id': 'srvtoolu_plot',
            'content': {
              'type': 'bash_code_execution_result',
              'stdout': '',
              'stderr': '',
              'return_code': 0,
              'content': [
                {'type': 'code_execution_output', 'file_id': 'file_chart'},
              ],
            },
          },
          {'type': 'text', 'text': '画好了'},
        ];
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
          modelId: 'claude-sonnet-4-6',
          messages: [
            {'role': 'user', 'content': '画个图'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                {
                  'id': 'srvtoolu_plot',
                  'type': 'function',
                  'function': {
                    'name': 'code_execution',
                    'arguments': '{"command":"python plot.py"}',
                  },
                  'metadata': {
                    'anthropic': {'assistant_blocks': blocks},
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'srvtoolu_plot',
              'name': 'code_execution',
              'content': '{"return_code":0}',
            },
            {
              'role': 'assistant',
              'content': '我来画。画好了',
              multimodalInternalMediaPathsKey: [file.path],
              multimodalInternalClaudeContainerKey: '{"id":"container_1"}',
            },
            {'role': 'user', 'content': '哪根柱子最高'},
          ],
        );

        final messages = (body['messages'] as List).cast<Map>();
        expect(messages.map((message) => message['role']).toList(), [
          'user',
          'assistant',
          'user',
        ]);
        // The turn is replayed as the API produced it, image-free; the text
        // message folds into it rather than repeating the text.
        final turn = (messages[1]['content'] as List).cast<Map>();
        expect(turn.map((block) => block['type']).toList(), [
          'text',
          'server_tool_use',
          'bash_code_execution_tool_result',
          'text',
        ]);
        expect(jsonEncode(turn), isNot(contains('"image"')));
        final followUp = (messages[2]['content'] as List).cast<Map>();
        expect(followUp.map((part) => part['type']).toList(), [
          'text',
          'image',
          'text',
        ]);
        expect(followUp[1]['source']['data'], 'AQIDBA==');
        expect(followUp.last['text'], '哪根柱子最高');
      },
    );

    test('an assistant image in Markdown moves on without its link', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_claude_assistant_md_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final file = File('${dir.path}/chart.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '画个图'},
          {'role': 'assistant', 'content': '画好了 ![](${file.path}) 请看'},
          {'role': 'user', 'content': '哪根柱子最高'},
        ],
      );

      final messages = (body['messages'] as List).cast<Map>();
      // The image is carried into the next user turn; the assistant keeps
      // only its words, not a path the model cannot open.
      expect(messages[1]['content'], '画好了  请看');
      final followUp = (messages[2]['content'] as List).cast<Map>();
      expect(followUp.map((part) => part['type']).toList(), [
        'text',
        'image',
        'text',
      ]);
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
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
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
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
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
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
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
          hostedCall('srvtoolu_1', 'https://example.com/1'),
          clientCall('toolu_client_1', 'one'),
        ];
        final secondResponse = [
          hostedResult('srvtoolu_1', 'https://e.com/1'),
          {'type': 'text', 'text': '再查一下。'},
          hostedCall('srvtoolu_2', 'https://example.com/2'),
          clientCall('toolu_client_2', 'two'),
        ];
        final thirdResponse = [
          hostedResult('srvtoolu_2', 'https://e.com/2'),
          {'type': 'text', 'text': '查到了。'},
        ];
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
          modelId: 'claude-sonnet-4-6',
          messages: [
            {'role': 'user', 'content': '看看这两个页面'},
            {
              'role': 'assistant',
              'content': '我查一下。再查一下。查到了。',
              'tool_calls': [
                replayCall('srvtoolu_1', 'web_fetch', [
                  firstResponse,
                  secondResponse,
                ]),
                replayCall('toolu_client_1', 'create_memory', [firstResponse]),
                replayCall('srvtoolu_2', 'web_fetch', [
                  firstResponse,
                  secondResponse,
                  thirdResponse,
                ]),
                replayCall('toolu_client_2', 'create_memory', [
                  firstResponse,
                  secondResponse,
                ]),
              ],
            },
            toolResult('toolu_client_1', 'create_memory', 'one'),
            toolResult('toolu_client_2', 'create_memory', 'two'),
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
        hostedCall('srvtoolu_1', 'https://example.com/1'),
        clientCall('toolu_client_1', 'one'),
      ];
      final secondResponse = [
        hostedResult('srvtoolu_1', 'https://e.com/1'),
        hostedCall('srvtoolu_2', 'https://example.com/2'),
        clientCall('toolu_client_2', 'two'),
      ];
      final thirdResponse = [hostedResult('srvtoolu_2', 'https://e.com/2')];
      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这两个页面'},
          {
            'role': 'assistant',
            'content': '我查一下。',
            'tool_calls': [
              replayCall('srvtoolu_1', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
              replayCall('toolu_client_1', 'create_memory', [firstResponse]),
              replayCall('srvtoolu_2', 'web_fetch', [
                firstResponse,
                secondResponse,
                thirdResponse,
              ]),
              replayCall('toolu_client_2', 'create_memory', [
                firstResponse,
                secondResponse,
              ]),
            ],
          },
          toolResult('toolu_client_1', 'create_memory', 'one'),
          toolResult('toolu_client_2', 'create_memory', 'two'),
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
        hostedCall('srvtoolu_relay', 'https://example.com'),
        clientCall('toolu_client', 'test'),
      ];
      final secondResponse = [
        hostedResult('srvtoolu_relay', 'https://e.com'),
        {'type': 'text', 'text': '查到了。'},
      ];
      final body = await captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          // The shape the app persists: the message holding the cards has no
          // text of its own, and the turn's text follows as its own message.
          {
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              replayCall('srvtoolu_relay', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
              replayCall('toolu_client', 'create_memory', [firstResponse]),
            ],
          },
          toolResult('srvtoolu_relay', 'web_fetch', '{"url":"https://e.com"}'),
          toolResult('toolu_client', 'create_memory', 'test'),
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
          hostedCall('srvtoolu_relay', 'https://example.com'),
          clientCall('toolu_client', 'test'),
        ];
        final secondResponse = [
          hostedResult('srvtoolu_relay', 'https://e.com'),
        ];
        final body = await captureClaudeRequestBody(
          modelId: 'claude-sonnet-4-6',
          messages: [
            {'role': 'user', 'content': '看看这个页面'},
            {
              'role': 'assistant',
              'content': '\n\n',
              'tool_calls': [
                replayCall('srvtoolu_relay', 'web_fetch', [
                  firstResponse,
                  secondResponse,
                ]),
                replayCall('toolu_client', 'create_memory', [firstResponse]),
              ],
            },
            toolResult(
              'srvtoolu_relay',
              'web_fetch',
              '{"url":"https://e.com"}',
            ),
            toolResult('toolu_client', 'create_memory', 'test'),
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
        hostedCall('srvtoolu_deferred', 'https://example.com'),
        clientCall('toolu_client', 'test'),
      ];
      final secondResponse = [
        hostedResult('srvtoolu_deferred', 'https://e.com'),
      ];
      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          {
            'role': 'assistant',
            'content': 'checking',
            'tool_calls': [
              replayCall('srvtoolu_deferred', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
              replayCall('toolu_client', 'create_memory', [firstResponse]),
            ],
          },
          toolResult('toolu_client', 'create_memory', 'test'),
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
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
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
        hostedCall('srvtoolu_paused', 'https://example.com'),
      ];
      final secondResponse = [
        hostedResult('srvtoolu_paused', 'https://e.com'),
        {'type': 'text', 'text': '查到了。'},
      ];
      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          {
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              replayCall('srvtoolu_paused', 'web_fetch', [
                firstResponse,
                secondResponse,
              ]),
            ],
          },
          toolResult('srvtoolu_paused', 'web_fetch', '{"url":"https://e.com"}'),
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

    test('a stored turn replays as its responses', () async {
      // The turn stored against the message is the whole recording; the cards
      // only name the calls.
      final firstResponse = [
        {'type': 'text', 'text': '我查一下。'},
        hostedCall('srvtoolu_1', 'https://example.com'),
        clientCall('toolu_client_1', 'first'),
      ];
      final secondResponse = [
        hostedResult('srvtoolu_1', 'https://e.com'),
        {'type': 'text', 'text': '查到了。'},
      ];
      final body = await captureClaudeRequestBody(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': '看看这个页面'},
          storedTurn(
            [firstResponse, secondResponse],
            [
              card('srvtoolu_1', 'web_fetch'),
              card('toolu_client_1', 'create_memory'),
            ],
          ),
          toolResult('srvtoolu_1', 'web_fetch', '{"url":"https://e.com"}'),
          toolResult('toolu_client_1', 'create_memory', 'saved'),
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
      expect(_blockTypes(messages[1]), ['text', 'server_tool_use', 'tool_use']);
      expect(_resultIds(messages[2]), ['toolu_client_1']);
      expect(_blockTypes(messages[3]), ['web_fetch_tool_result', 'text']);
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
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
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
        final body = await captureClaudeRequestBody(
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

    test('an empty tool result still carries an explicit content', () async {
      // Omitting `content` leaves the call unanswered and Anthropic rejects an
      // empty text block, so a tool that produced nothing needs a placeholder.
      final body = await captureClaudeRequestBody(
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
        final (:bodies, chunks: _) = await captureClaudeServerToolRounds(
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
      final (:bodies, chunks: _) = await captureClaudeServerToolRounds(
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
