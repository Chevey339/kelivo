import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/assistant_tool_history.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends ChatService {
  @override
  List<ChatMessage> getMessages(String conversationId) => [];
}

Map<String, dynamic> _call(String id) => {
  'id': id,
  'type': 'function',
  'function': {
    'name': 'lookup',
    'arguments': jsonEncode({'id': id}),
  },
};

void main() {
  test(
    'malformed stored tools do not block healthy Chat Completions history',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tool_history_corrupt_',
      );
      final file = File('${root.path}/chat.sqlite');
      var repository = ChatDatabaseRepository.open(file: file);
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      await repository.ensureReady();
      await repository.putConversation(
        Conversation(id: 'c', title: 'Imported'),
      );
      const parts = [
        ReasoningPart('Plan'),
        TextPart('Before.'),
        ToolCallPart(
          '{"id":"good","name":"lookup","arguments":{},"content":"found"}',
        ),
        AssistantRoundEndPart(),
        ToolCallPart('{broken'),
        ToolCallPart('[]'),
        TextPart('After.'),
      ];
      await repository.putMessage(
        ChatMessage(
          id: 'a',
          role: 'assistant',
          conversationId: 'c',
          parts: parts,
        ),
      );
      await repository.close();
      repository = ChatDatabaseRepository.open(file: file);
      await repository.ensureReady();
      final restored = (await repository.getMessage('a'))!;
      final builder = MessageBuilderService(
        chatService: _Chat(),
        contextProvider: _Context(),
      );
      final history = builder.buildApiMessages(
        messages: [
          ChatMessage(role: 'user', content: 'Question', conversationId: 'c'),
          restored,
          ChatMessage(role: 'user', content: 'Next', conversationId: 'c'),
        ],
        versionSelections: {},
        currentConversation: null,
        includeToolMessages: true,
        preserveToolTurns: true,
      );
      expect(history.map((message) => message['role']), [
        'user',
        'assistant',
        'tool',
        'assistant',
        'user',
      ]);
      expect(history[1]['reasoning_content'], 'Plan');
      expect(history[1]['content'], 'Before.');
      expect((history[1]['tool_calls'] as List).single['id'], 'good');
      expect(history[2]['content'], 'found');
      expect(history[3]['content'], 'After.');
      expect(history[4]['content'], 'Next');
      expect(restored.parts, parts);
      expect((await repository.getMessage('a'))!.parts, parts);
    },
  );

  for (final stream in [true, false]) {
    for (final signed in [false, true]) {
      test(
        'tool history survives persistence and next request, stream=$stream, signed=$signed',
        () async {
          final requests = <Map<String, dynamic>>[];
          final replies = [
            {
              'role': 'assistant',
              'content': 'Checking. ',
              'reasoning_content': ' R1\n',
              if (signed)
                'reasoning_details': [
                  {
                    'type': 'reasoning.text',
                    'text': ' R1\n',
                    'signature': 'sig-1',
                  },
                ],
              'tool_calls': [_call('a'), _call('b')],
            },
            {
              'role': 'assistant',
              'content': '',
              'reasoning_content': '',
              'tool_calls': [_call('c')],
            },
            {
              'role': 'assistant',
              'content': 'Done.',
              'reasoning_content': '\nR3 ',
            },
            {'role': 'assistant', 'content': 'Next.'},
          ];
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            requests.add(
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>,
            );
            final message = replies[requests.length - 1];
            final body = {
              'choices': [
                {
                  'message': message,
                  'finish_reason': message.containsKey('tool_calls')
                      ? 'tool_calls'
                      : 'stop',
                },
              ],
            };
            if (stream) {
              request.response.headers.contentType = ContentType(
                'text',
                'event-stream',
              );
              request.response.write(
                'data: ${jsonEncode(body)}\n\ndata: [DONE]\n\n',
              );
            } else {
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode(body));
            }
            await request.response.close();
          });
          final config = ProviderConfig(
            id: 'DeepSeek',
            enabled: true,
            name: 'DeepSeek',
            apiKey: 'test',
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            providerType: ProviderKind.openai,
          );
          final tools = [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'id': {'type': 'string'},
                  },
                },
              },
            },
          ];
          final chunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: 'deepseek-v4.1-flash',
            messages: const [
              {'role': 'user', 'content': 'Check.'},
            ],
            tools: tools,
            stream: stream,
            onToolCall: (name, arguments, {toolCallId}) async =>
                'result-${arguments['id']}',
          ).toList();
          final collected = StreamChunkHandler.collect(chunks);
          expect(collected.reasoningDetails, isNull);
          // Serialize/reload the same representation used by message_part_rows.
          final persisted = collected.parts
              .map(
                (part) => MessagePart.fromRow(part.kind, part.encodePayload()),
              )
              .toList();
          final assistant = ChatMessage(
            id: 'a1',
            role: 'assistant',
            conversationId: 'c',
            parts: persisted,
            reasoningText: ' R1\n\nR3 ',
          );
          final builder = MessageBuilderService(
            chatService: _Chat(),
            contextProvider: _Context(),
          );
          final history = builder.buildApiMessages(
            messages: [
              ChatMessage(
                id: 'u1',
                role: 'user',
                content: 'Check.',
                conversationId: 'c',
              ),
              assistant,
              ChatMessage(
                id: 'u2',
                role: 'user',
                content: 'Continue.',
                conversationId: 'c',
              ),
            ],
            versionSelections: const {},
            currentConversation: Conversation(title: 'test'),
            includeToolMessages: true,
            preserveToolTurns: true,
          );
          await ChatApiService.sendMessageStream(
            config: config,
            modelId: 'deepseek-v4.1-flash',
            messages: history,
            tools: tools,
            stream: stream,
          ).toList();
          final replay = (requests.last['messages'] as List).cast<Map>();
          expect(replay.map((m) => m['role']), [
            'user',
            'assistant',
            'tool',
            'tool',
            'assistant',
            'tool',
            'assistant',
            'user',
          ]);
          if (signed) {
            expect(replay[1].containsKey('reasoning_content'), isFalse);
            expect(
              replay[1]['reasoning_details'],
              replies[0]['reasoning_details'],
            );
          } else {
            expect(replay[1]['reasoning_content'], ' R1\n');
          }
          expect(replay[4].containsKey('reasoning_details'), isFalse);
          expect(replay[6].containsKey('reasoning_details'), isFalse);
          expect(replay[1]['content'], 'Checking.');
          expect((replay[1]['tool_calls'] as List).map((t) => t['id']), [
            'a',
            'b',
          ]);
          expect(replay[4]['reasoning_content'], '');
          expect((replay[4]['tool_calls'] as List).single['id'], 'c');
          expect(replay[6]['reasoning_content'], '\nR3 ');
          expect(replay[6]['content'], 'Done.');
          expect(replay[2]['content'], 'result-a');
          expect(replay[3]['content'], 'result-b');
          expect(replay[5]['content'], 'result-c');
        },
      );
    }
  }

  test('an unfinished batch does not erase earlier completed tool rounds', () {
    ToolCallPart tool(String id, String? content) => ToolCallPart(
      jsonEncode({
        'id': id,
        'name': 'lookup',
        'arguments': {},
        'content': content,
      }),
    );
    final history = buildAssistantToolHistory([
      const ReasoningPart(' R1 '),
      tool('a', 'ok'),
      const AssistantRoundEndPart(),
      const ReasoningPart(' R2 '),
      tool('b', null),
      const AssistantRoundEndPart(),
    ]);
    expect(history.messages.map((m) => m['role']), ['assistant', 'tool']);
    expect(history.messages.first['reasoning_content'], ' R1 ');
    expect(history.messages.last['tool_call_id'], 'a');
    expect(history.reasoning, ' R2 ');
  });

  test('the response boundary owns trailing text and signed reasoning', () {
    const details = [
      {'type': 'reasoning.text', 'text': 'R1', 'signature': 'signature'},
    ];
    final history = buildAssistantToolHistory([
      const ReasoningPart('before '),
      ToolCallPart(
        jsonEncode({
          'id': 'a',
          'name': 'lookup',
          'arguments': {},
          'content': 'ok',
        }),
      ),
      const TextPart('same response'),
      const ReasoningPart('after'),
      const AssistantRoundEndPart(reasoningDetails: details),
      const TextPart('final answer'),
    ]);
    expect(history.messages.first['content'], 'same response');
    expect(history.messages.first['reasoning_content'], 'before after');
    expect(history.messages.first['reasoning_details'], details);
    expect(history.content, 'final answer');
    expect(history.reasoning, isNull);
  });

  test('a tail without response markers preserves its recorded part order', () {
    final history = buildAssistantToolHistory([
      const ReasoningPart('plan'),
      ToolCallPart(
        jsonEncode({
          'id': 'a',
          'name': 'lookup',
          'arguments': {},
          'content': 'result',
        }),
      ),
      const ReasoningPart('observed result'),
      const TextPart('answer'),
    ]);
    expect(history.messages.first['reasoning_content'], 'plan');
    expect(history.messages.first['content'], '');
    expect(history.messages.last['content'], 'result');
    expect(history.reasoning, 'observed result');
    expect(history.content, 'answer');
  });
}
