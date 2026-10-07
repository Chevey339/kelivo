import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_thinking_recovery.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

import '../../../support/claude_test_api.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends ChatService {
  _Chat([this.events = const []]);
  final List<Map<String, dynamic>> events;

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) => events;
}

const _thinking = {
  'type': 'thinking',
  // Omitted display still carries a signature that must survive storage.
  'thinking': '',
  'signature': 'opaque-state',
};
const _text = {'type': 'text', 'text': 'Answer.'};
const _tools = [
  {
    'type': 'function',
    'function': {
      'name': 'lookup',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
];

String _round() => sseRound('m1', [
  {
    'type': 'content_block_start',
    'index': 0,
    'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'signature_delta', 'signature': 'opaque-state'},
  },
  {'type': 'content_block_stop', 'index': 0},
  {
    'type': 'content_block_start',
    'index': 1,
    'content_block': {'type': 'text', 'text': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 1,
    'delta': {'type': 'text_delta', 'text': 'Answer.'},
  },
  {'type': 'content_block_stop', 'index': 1},
  {
    'type': 'message_delta',
    'delta': {'stop_reason': 'end_turn'},
  },
  {'type': 'message_stop'},
]);

void main() {
  for (final deepseek in [false, true]) {
    for (final stream in [false, true]) {
      for (final toolsAvailable in [false, true]) {
        test(
          'no-tool thinking survives SQLite reload: deepseek=$deepseek, stream=$stream, tools=$toolsAvailable',
          () async {
            final config = deepseek ? deepSeekClaudeConfig() : claudeConfig();
            final modelId = deepseek ? 'deepseek-flash' : 'claude-sonnet-4-6';
            final exchange = await captureClaudeExchange(
              config: config,
              modelId: modelId,
              stream: stream,
              tools: toolsAvailable ? _tools : null,
              replies: const [
                {
                  'content': [_thinking, _text],
                  'stop_reason': 'end_turn',
                },
              ],
              sseRounds: stream ? [_round()] : null,
            );
            final root = await Directory.systemTemp.createTemp(
              'claude_history_',
            );
            final dbFile = File('${root.path}/chat.sqlite');
            var repository = ChatDatabaseRepository.open(file: dbFile);
            addTearDown(() async {
              await repository.close();
              await root.delete(recursive: true);
            });
            await repository.ensureReady();
            final conversation = Conversation(id: 'c', title: 'Thinking');
            await repository.putConversation(conversation);
            final assistant = ChatMessage(
              id: 'a1',
              role: 'assistant',
              conversationId: 'c',
              providerId: config.id,
              modelId: modelId,
              parts: StreamChunkHandler.collect(exchange.chunks).parts,
            );
            await repository.putMessage(assistant);
            for (final artifact
                in exchange.chunks.whereType<ProviderArtifact>()) {
              await repository.setProviderArtifact(
                assistant.id,
                artifact.kind,
                artifact.payload,
              );
            }
            await repository.close();
            repository = ChatDatabaseRepository.open(file: dbFile);
            await repository.ensureReady();
            final restored = (await repository.getMessage('a1'))!;
            final artifacts = await repository.getProviderArtifactsForMessages([
              'a1',
            ], claudeTurnArtifactKind);
            final builder = MessageBuilderService(
              chatService: _Chat(),
              contextProvider: _Context(),
              providerArtifactLookup: (message, kind) =>
                  kind == claudeTurnArtifactKind ? artifacts[message.id] : null,
            );
            final history = builder.buildApiMessages(
              messages: [
                ChatMessage(
                  role: 'user',
                  content: 'hello',
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
            final body = await captureClaudeRequestBody(
              config: config,
              modelId: modelId,
              messages: history,
              tools: toolsAvailable ? _tools : null,
            );
            expect(body['messages'], [
              {'role': 'user', 'content': 'hello'},
              {
                'role': 'assistant',
                'content': [_thinking, _text],
              },
              {'role': 'user', 'content': 'Continue.'},
            ]);
          },
        );
      }
    }
  }

  test('an empty visible reply still carries its original thinking', () async {
    final config = claudeConfig();
    const modelId = 'claude-sonnet-4-6';
    final assistant = ChatMessage(
      role: 'assistant',
      conversationId: 'c',
      providerId: config.id,
      modelId: modelId,
      content: '',
    );
    final builder = MessageBuilderService(
      chatService: _Chat(),
      contextProvider: _Context(),
      providerArtifactLookup: (message, kind) => kind == claudeTurnArtifactKind
          ? encodeClaudeTurn([
              [_thinking],
            ])
          : null,
    );
    List<Map<String, dynamic>> build(String provider, String model) =>
        builder.buildApiMessages(
          messages: [
            ChatMessage(role: 'user', content: 'hello', conversationId: 'c'),
            assistant,
            ChatMessage(
              role: 'user',
              content: 'Continue.',
              conversationId: 'c',
            ),
          ],
          versionSelections: const {},
          currentConversation: null,
          includeToolMessages: true,
          claudeSource: (providerId: provider, modelId: model),
        );
    final body = await captureClaudeRequestBody(
      config: config,
      modelId: modelId,
      messages: build(config.id, modelId),
    );
    expect((body['messages'] as List)[1], {
      'role': 'assistant',
      'content': [_thinking],
    });
    for (final source in [
      (providerId: 'another-provider', modelId: modelId),
      (providerId: config.id, modelId: 'another-model'),
    ]) {
      expect(
        build(source.providerId, source.modelId).any(
          (message) => message.containsKey(multimodalInternalClaudeTurnKey),
        ),
        isFalse,
      );
    }
  });

  test(
    'prefix recovery survives SQLite reload without dropping fresh thinking',
    () async {
      final config = claudeConfig();
      const modelId = 'claude-fable-5-1';
      final oldTurn = encodeClaudeTurn([
        [
          {..._thinking, 'signature': 'stale-state'},
          _text,
        ],
      ]);
      final exchange = await captureClaudeExchange(
        config: config,
        modelId: modelId,
        messages: [
          {'role': 'user', 'content': 'Edited question'},
          {
            'role': 'assistant',
            'content': 'Answer.',
            multimodalInternalClaudeTurnKey: oldTurn,
          },
          {'role': 'user', 'content': 'Continue'},
        ],
        statusCodes: const [400, 200],
        replies: const [
          {
            'type': 'error',
            'error': {
              'type': 'invalid_request_error',
              'message':
                  'messages.1.content.0: Invalid `signature` in `thinking` block. '
                  'The block is bound to a different conversation. Remove the block.',
            },
          },
          {
            'content': [_thinking, _text],
            'stop_reason': 'end_turn',
          },
        ],
      );
      expect(exchange.bodies, hasLength(2));
      final root = await Directory.systemTemp.createTemp('claude_recovery_');
      final file = File('${root.path}/chat.sqlite');
      var repository = ChatDatabaseRepository.open(file: file);
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      await repository.ensureReady();
      final conversation = Conversation(id: 'c', title: 'Edited history');
      await repository.putConversation(conversation);
      for (final id in ['old', 'fresh']) {
        await repository.putMessage(
          ChatMessage(
            id: id,
            role: 'assistant',
            conversationId: 'c',
            providerId: config.id,
            modelId: modelId,
            content: 'Answer.',
          ),
        );
      }
      await repository.setProviderArtifact(
        'old',
        claudeTurnArtifactKind,
        oldTurn,
      );
      for (final artifact in exchange.chunks.whereType<ProviderArtifact>()) {
        await repository.setProviderArtifact(
          'fresh',
          artifact.kind,
          artifact.payload,
        );
      }
      await repository.close();
      repository = ChatDatabaseRepository.open(file: file);
      await repository.ensureReady();
      final artifacts = <String, Map<String, String>>{};
      for (final kind in [
        claudeTurnArtifactKind,
        claudeThinkingRecoveryArtifactKind,
      ]) {
        artifacts[kind] = await repository.getProviderArtifactsForMessages([
          'old',
          'fresh',
        ], kind);
      }
      final builder = MessageBuilderService(
        chatService: _Chat(),
        contextProvider: _Context(),
        providerArtifactLookup: (message, kind) => artifacts[kind]?[message.id],
      );
      final history = builder.buildApiMessages(
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Edited question',
            conversationId: 'c',
          ),
          (await repository.getMessage('old'))!,
          ChatMessage(role: 'user', content: 'Continue', conversationId: 'c'),
          (await repository.getMessage('fresh'))!,
          ChatMessage(role: 'user', content: 'Next', conversationId: 'c'),
        ],
        versionSelections: const {},
        currentConversation: conversation,
        includeToolMessages: true,
        claudeSource: (providerId: config.id, modelId: modelId),
      );
      final resumed = await captureClaudeExchange(
        config: config,
        modelId: modelId,
        messages: history,
      );
      expect(resumed.bodies, hasLength(1));
      final messages = resumed.bodies.single['messages'] as List;
      expect(messages[1]['content'], [_text]);
      expect(messages[3]['content'], [_thinking, _text]);
      expect(
        resumed.chunks
            .whereType<ProviderArtifact>()
            .lastWhere(
              (artifact) => artifact.kind == claudeThinkingRecoveryArtifactKind,
            )
            .payload,
        artifacts[claudeThinkingRecoveryArtifactKind]!['fresh'],
      );
      expect(
        await repository.getProviderArtifactsForMessages([
          'old',
        ], claudeTurnArtifactKind),
        {'old': oldTurn},
      );
      final fresh = (await repository.getMessage('fresh'))!;
      for (final edit in ['unchanged', 'text', 'remove-parts']) {
        final text = edit == 'text' ? 'Edited answer' : fresh.content;
        final version = (await repository.appendMessageVersion(
          messageId: fresh.id,
          content: text,
          parts: edit == 'remove-parts' ? [TextPart(text)] : null,
        ))!.message;
        for (final kind in artifacts.keys) {
          artifacts[kind]!.addAll(
            await repository.getProviderArtifactsForMessages([
              version.id,
            ], kind),
          );
        }
        final editedHistory = builder.buildApiMessages(
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Edited question',
              conversationId: 'c',
            ),
            (await repository.getMessage('old'))!,
            ChatMessage(role: 'user', content: 'Continue', conversationId: 'c'),
            version,
            ChatMessage(role: 'user', content: 'Next', conversationId: 'c'),
          ],
          versionSelections: const {},
          currentConversation: conversation,
          includeToolMessages: true,
          claudeSource: (providerId: config.id, modelId: modelId),
        );
        final body = await captureClaudeRequestBody(
          config: config,
          modelId: modelId,
          messages: editedHistory,
        );
        final sent = body['messages'] as List;
        expect(sent[1]['content'], [_text], reason: edit);
        expect(
          sent[3]['content'],
          edit == 'remove-parts'
              ? text
              : [
                  _thinking,
                  {'type': 'text', 'text': text},
                ],
          reason: edit,
        );
      }
    },
  );

  for (final edited in ['Edited answer', '']) {
    test('editing a tool reply preserves its tool pair: "$edited"', () async {
      final config = claudeConfig();
      const modelId = 'claude-sonnet-4-6';
      final assistant = ChatMessage(
        role: 'assistant',
        conversationId: 'c',
        providerId: config.id,
        modelId: modelId,
        content: edited,
      );
      final builder = MessageBuilderService(
        chatService: _Chat([
          {
            'id': 'call1',
            'name': 'create_memory',
            'arguments': {'content': 'remember'},
            'content': 'saved',
          },
        ]),
        contextProvider: _Context(),
        providerArtifactLookup: (_, kind) => kind == claudeTurnArtifactKind
            ? encodeClaudeTurn([
                [_thinking, _text, clientCall('call1', 'remember')],
                [
                  {'type': 'text', 'text': 'Final answer'},
                ],
              ])
            : null,
      );
      final history = builder.buildApiMessages(
        messages: [
          ChatMessage(role: 'user', content: 'Question', conversationId: 'c'),
          assistant,
          ChatMessage(role: 'user', content: 'Next', conversationId: 'c'),
        ],
        versionSelections: const {},
        currentConversation: null,
        includeToolMessages: true,
        claudeSource: (providerId: config.id, modelId: modelId),
      );
      final body = await captureClaudeRequestBody(
        config: config,
        modelId: modelId,
        messages: history,
      );
      expect(body['messages'], [
        {'role': 'user', 'content': 'Question'},
        {
          'role': 'assistant',
          'content': [
            _thinking,
            if (edited.isNotEmpty) {'type': 'text', 'text': edited},
            clientCall('call1', 'remember'),
          ],
        },
        {
          'role': 'user',
          'content': [
            {'type': 'tool_result', 'tool_use_id': 'call1', 'content': 'saved'},
          ],
        },
        {'role': 'user', 'content': 'Next'},
      ]);
    });
  }

  test('unfinished tools do not leak through the ordinary artifact path', () {
    final builder = MessageBuilderService(
      chatService: _Chat([
        {'id': 'call1', 'name': 'lookup', 'arguments': <String, dynamic>{}},
      ]),
      contextProvider: _Context(),
      providerArtifactLookup: (message, kind) => kind == claudeTurnArtifactKind
          ? encodeClaudeTurn([
              [_thinking, clientCall('call1', 'remember')],
            ])
          : null,
    );
    final history = builder.buildApiMessages(
      messages: [
        ChatMessage(
          role: 'assistant',
          conversationId: 'c',
          providerId: 'p',
          modelId: 'm',
          content: 'Waiting.',
        ),
      ],
      versionSelections: const {},
      currentConversation: null,
      includeToolMessages: true,
      claudeSource: (providerId: 'p', modelId: 'm'),
    );
    expect(history.single['content'], 'Waiting.');
    expect(
      history.single.containsKey(multimodalInternalClaudeTurnKey),
      isFalse,
    );
    expect(history.single.containsKey('tool_calls'), isFalse);
  });
}
