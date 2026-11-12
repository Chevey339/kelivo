import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/assistant_tool_history.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

import '../../../support/claude_test_api.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _search = {
  'type': 'server_tool_use',
  'id': 'srvtoolu_search',
  'name': 'web_search',
  'input': {'query': 'example'},
};
const _searchResult = {
  'type': 'web_search_tool_result',
  'tool_use_id': 'srvtoolu_search',
  'content': [
    {
      'type': 'web_search_result',
      'url': 'https://example.com',
      'title': 'Example',
      'encrypted_content': 'opaque-search-result',
    },
  ],
};
const _client = {
  'type': 'tool_use',
  'id': 'toolu_client',
  'name': 'lookup',
  'input': <String, dynamic>{},
};

void main() {
  for (final withArtifact in [true, false]) {
    test(
      'citation cards survive reload without becoming client calls: artifact=$withArtifact',
      () async {
        final config = claudeConfig(baseUrl: officialBaseUrl);
        const modelId = 'claude-sonnet-4-6';
        final exchange = await captureClaudeExchange(
          config: config,
          modelId: modelId,
          stream: true,
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => 'found',
          sseRounds: [
            sseRound('search-and-client', [
              for (final (index, block) in [
                _search,
                _searchResult,
                _client,
              ].indexed) ...[
                {
                  'type': 'content_block_start',
                  'index': index,
                  'content_block': {
                    ...block,
                    if (block.containsKey('input'))
                      'input': <String, dynamic>{},
                  },
                },
                if (block.containsKey('input'))
                  {
                    'type': 'content_block_delta',
                    'index': index,
                    'delta': {
                      'type': 'input_json_delta',
                      'partial_json': jsonEncode(block['input']),
                    },
                  },
                {'type': 'content_block_stop', 'index': index},
              ],
              {
                'type': 'message_delta',
                'delta': {'stop_reason': 'tool_use'},
              },
              {'type': 'message_stop'},
            ]),
            sseRound('citation-only', [
              {
                'type': 'content_block_start',
                'index': 0,
                'content_block': {'type': 'text', 'text': ''},
              },
              {
                'type': 'content_block_delta',
                'index': 0,
                'delta': {'type': 'text_delta', 'text': 'Answer.'},
              },
              {
                'type': 'content_block_delta',
                'index': 0,
                'delta': {
                  'type': 'citations_delta',
                  'citation': {
                    'type': 'web_search_result_location',
                    'url': 'https://example.com',
                    'title': 'Example',
                    'cited_text': 'source',
                  },
                },
              },
              {'type': 'content_block_stop', 'index': 0},
              {
                'type': 'message_delta',
                'delta': {'stop_reason': 'end_turn'},
              },
              {'type': 'message_stop'},
            ]),
          ],
        );
        expect(exchange.bodies, hasLength(2));
        final parts = StreamChunkHandler.collect(exchange.chunks).parts;
        final citation = parts
            .whereType<ToolCallPart>()
            .map((p) => jsonDecode(p.payloadJson) as Map)
            .singleWhere((p) => p['id'].toString().contains(':search-'));
        expect(citation['server'], isTrue);
        final root = await Directory.systemTemp.createTemp('claude_citations_');
        final file = File('${root.path}/chat.sqlite');
        var repository = ChatDatabaseRepository.open(file: file);
        addTearDown(() async {
          await repository.close();
          await root.delete(recursive: true);
        });
        await repository.ensureReady();
        final conversation = Conversation(id: 'c', title: 'Citations');
        await repository.putConversation(conversation);
        await repository.putMessage(
          ChatMessage(
            id: 'a',
            role: 'assistant',
            conversationId: 'c',
            providerId: config.id,
            modelId: modelId,
            parts: parts,
          ),
        );
        if (withArtifact) {
          for (final artifact
              in exchange.chunks.whereType<ProviderArtifact>()) {
            await repository.setProviderArtifact(
              'a',
              artifact.kind,
              artifact.payload,
            );
          }
        }
        await repository.close();
        repository = ChatDatabaseRepository.open(file: file);
        await repository.ensureReady();
        final restored = (await repository.getMessage('a'))!;
        final artifacts = await repository.getProviderArtifactsForMessages([
          'a',
        ], claudeTurnArtifactKind);
        final builder = MessageBuilderService(
          chatService: ChatService(),
          contextProvider: _Context(),
          providerArtifactLookup: (message, kind) =>
              kind == claudeTurnArtifactKind ? artifacts[message.id] : null,
        );
        final history = builder.buildApiMessages(
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Search, then look up.',
              conversationId: 'c',
            ),
            restored,
            ChatMessage(
              role: 'user',
              content: 'Continue.',
              conversationId: 'c',
            ),
          ],
          versionSelections: const {},
          currentConversation: conversation,
          includeToolMessages: true,
          claudeSource: (providerId: config.id, modelId: modelId),
        );
        // Disabling search for the next request must also recover this history.
        final body = await captureClaudeRequestBody(
          config: config,
          modelId: modelId,
          messages: history,
        );
        final sent = (body['messages'] as List).cast<Map>();
        final blocks = sent
            .where((m) => m['content'] is List)
            .expand((m) => (m['content'] as List).cast<Map>())
            .toList();
        expect(blocks.where((b) => b['type'] == 'tool_use').toList(), [
          if (!withArtifact)
            {..._search, 'type': 'tool_use', 'name': 'search_web'},
          _client,
        ]);
        final results = blocks
            .where((b) => b['type'] == 'tool_result')
            .toList();
        expect(results.map((b) => b['tool_use_id']), [
          if (!withArtifact) 'srvtoolu_search',
          'toolu_client',
        ]);
        expect(results.last['content'], 'found');
        expect(
          blocks.where((b) => b['type'] == 'server_tool_use').toList(),
          withArtifact ? [_search] : isEmpty,
        );
        expect(
          blocks.where((b) => b['type'] == 'web_search_tool_result').toList(),
          withArtifact ? [_searchResult] : isEmpty,
        );
        expect(jsonEncode(body), isNot(contains(citation['id'])));
        expect(sent.last['content'], 'Continue.');
        expect(
          sent
              .where((m) => m['role'] == 'assistant')
              .expand(
                (m) => m['content'] is List
                    ? (m['content'] as List)
                          .cast<Map>()
                          .where((b) => b['type'] == 'text')
                          .map((b) => b['text'])
                    : [m['content']],
              )
              .join(),
          'Answer.',
        );
        // Reading history must not remove the visible citation card from storage.
        expect((await repository.getMessage('a'))!.parts, parts);
      },
    );
  }

  test('server identity is internal metadata in ordered tool history', () {
    final history = buildAssistantToolHistory(const [
      ToolCallPart(
        '{"id":"search_1","name":"search_web","arguments":{},"content":"found","server":true,"metadata":{"anthropic":{"test":"kept"}}}',
      ),
    ]);
    final call = (history.messages.first['tool_calls'] as List).single as Map;
    expect(call['metadata'], {
      'server': true,
      'anthropic': {'test': 'kept'},
    });
    final wire = copyChatCompletionMessage(history.messages.first);
    expect((wire['tool_calls'] as List).single, {
      'id': 'search_1',
      'type': 'function',
      'function': {'name': 'search_web', 'arguments': '{}'},
    });
  });

  test('a recorded turn supplements only unfinished client calls', () async {
    final body = await captureClaudeRequestBody(
      config: claudeConfig(baseUrl: officialBaseUrl),
      modelId: 'claude-sonnet-4-6',
      messages: [
        {'role': 'user', 'content': 'hello'},
        storedTurn(
          [
            [
              {'type': 'text', 'text': 'Checking.'},
            ],
          ],
          [
            {
              ...card('search_1', 'search_web'),
              'metadata': {'server': true},
            },
            card('toolu_client', 'lookup'),
          ],
        ),
        toolResult('search_1', 'search_web', 'sources'),
        toolResult('toolu_client', 'lookup', 'found'),
        {'role': 'assistant', 'content': 'Checking.'},
        {'role': 'user', 'content': 'continue'},
      ],
    );
    final sent = (body['messages'] as List).cast<Map>();
    final blocks = sent
        .where((m) => m['content'] is List)
        .expand((m) => (m['content'] as List).cast<Map>())
        .toList();
    expect(blocks.where((b) => b['type'] == 'tool_use').toList(), [_client]);
    expect(
      blocks.where((b) => b['type'] == 'tool_result').single['tool_use_id'],
      'toolu_client',
    );
    expect(jsonEncode(body), isNot(contains('search_1')));
  });

  for (final id in ['ws_search', 'builtin_search']) {
    test(
      'switching to Claude preserves other providers server history: $id',
      () async {
        final builder = MessageBuilderService(
          chatService: ChatService(),
          contextProvider: _Context(),
        );
        final history = builder.buildApiMessages(
          messages: [
            ChatMessage(role: 'user', content: 'search', conversationId: 'c'),
            ChatMessage(
              role: 'assistant',
              conversationId: 'c',
              providerId: 'openai',
              modelId: 'gpt-5',
              parts: [
                ToolCallPart(
                  jsonEncode({
                    'id': id,
                    'name': 'search_web',
                    'arguments': {'query': 'example'},
                    'content': 'Useful search result',
                    'server': true,
                  }),
                ),
                const TextPart('Answer.'),
              ],
            ),
            ChatMessage(
              role: 'user',
              content: 'What did the source say?',
              conversationId: 'c',
            ),
          ],
          versionSelections: const {},
          currentConversation: null,
          includeToolMessages: true,
        );
        final body = await captureClaudeRequestBody(
          config: claudeConfig(baseUrl: officialBaseUrl),
          modelId: 'claude-sonnet-4-6',
          messages: history,
        );
        final sent = (body['messages'] as List).cast<Map>();
        final blocks = sent
            .where((m) => m['content'] is List)
            .expand((m) => (m['content'] as List).cast<Map>())
            .toList();
        expect(blocks.where((b) => b['type'] == 'tool_use').single, {
          'type': 'tool_use',
          'id': id,
          'name': 'search_web',
          'input': {'query': 'example'},
        });
        expect(blocks.where((b) => b['type'] == 'tool_result').single, {
          'type': 'tool_result',
          'tool_use_id': id,
          'content': 'Useful search result',
        });
      },
    );
  }
}
