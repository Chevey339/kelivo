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
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends ChatService {
  _Chat(this.events);
  final List<Map<String, dynamic>> events;

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) => events;
}

Map<String, dynamic> _call(String id) => {
  'type': 'function_call',
  'id': 'fc_$id',
  'call_id': id,
  'name': 'lookup',
  'arguments': '{ "id": "$id" }',
  'status': 'completed',
};

Map<String, dynamic> _text(String id, String text) => {
  'type': 'message',
  'id': id,
  'role': 'assistant',
  'status': 'completed',
  'content': [
    {'type': 'output_text', 'text': text, 'annotations': <Object>[]},
  ],
};

const _tools = [
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

void main() {
  for (final stream in [true, false]) {
    for (final encrypted in [true, false]) {
      test(
        'Responses history survives database reload, stream=$stream, encrypted=$encrypted',
        () async {
          Map<String, dynamic> reasoning(int round) => {
            'type': 'reasoning',
            'id': 'rs_$round',
            'summary': <Object>[],
            if (encrypted)
              'encrypted_content': 'opaque-$round'
            else
              'content': [
                {'type': 'reasoning_text', 'text': ' R$round\n'},
              ],
          };
          final outputs = [
            [reasoning(1), _text('m1', 'Checking. '), _call('a'), _call('b')],
            [reasoning(2), _call('c')],
            [reasoning(3), _text('m3', 'Done.')],
            [_text('m4', 'Next.')],
          ];
          final requests = <Map<String, dynamic>>[];
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            requests.add(jsonDecode(await utf8.decoder.bind(request).join()));
            final output = outputs[requests.length - 1];
            if (stream) {
              request.response.headers.contentType = ContentType(
                'text',
                'event-stream',
              );
              void emit(Map<String, dynamic> event) =>
                  request.response.write('data: ${jsonEncode(event)}\n\n');
              for (var i = 0; i < output.length; i++) {
                final item = output[i];
                emit({
                  'type': 'response.output_item.added',
                  'output_index': i,
                  'item': {
                    ...item,
                    // The provider's call id may arrive only in the done event.
                    if (item['type'] == 'function_call') 'call_id': '',
                    if (item['type'] == 'reasoning' && encrypted)
                      'encrypted_content': 'unfinished',
                  },
                });
                if (item['type'] == 'message') {
                  emit({
                    'type': 'response.output_text.delta',
                    'output_index': i,
                    'delta': (item['content'] as List).first['text'],
                  });
                }
                if (item['type'] == 'reasoning' && !encrypted) {
                  emit({
                    'type': 'response.reasoning_text.delta',
                    'output_index': i,
                    'delta': (item['content'] as List).first['text'],
                  });
                }
                emit({
                  'type': 'response.output_item.done',
                  'output_index': i,
                  'item': item,
                });
              }
              emit({
                'type': 'response.completed',
                // Completed items must survive an empty terminal snapshot.
                'response': {'output': encrypted ? <Object>[] : output},
              });
            } else {
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({'output': output}));
            }
            await request.response.close();
          });
          final config = ProviderConfig(
            id: encrypted ? 'OpenAI' : 'DeepSeek',
            enabled: true,
            name: 'Responses fixture',
            apiKey: 'test',
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            providerType: ProviderKind.openai,
            useResponseApi: true,
          );
          final modelId = encrypted ? 'gpt-5.4' : 'deepseek-flash';
          final chunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: modelId,
            messages: const [
              {'role': 'user', 'content': 'Check.'},
            ],
            tools: _tools,
            stream: stream,
            onToolCall: (name, arguments, {toolCallId}) async =>
                'result-${arguments['id']}',
          ).toList();
          final root = await Directory.systemTemp.createTemp(
            'responses_history_',
          );
          final dbFile = File('${root.path}/chat.sqlite');
          var repository = ChatDatabaseRepository.open(file: dbFile);
          addTearDown(() async {
            await repository.close();
            await root.delete(recursive: true);
          });
          await repository.ensureReady();
          final conversation = Conversation(id: 'c', title: 'History');
          await repository.putConversation(conversation);
          final assistant = ChatMessage(
            id: 'a1',
            role: 'assistant',
            conversationId: 'c',
            parts: StreamChunkHandler.collect(chunks).parts,
          );
          await repository.putMessage(assistant);
          for (final artifact in chunks.whereType<ProviderArtifact>()) {
            await repository.setProviderArtifact(
              assistant.id,
              artifact.kind,
              artifact.payload,
            );
          }
          await repository.close();
          repository = ChatDatabaseRepository.open(file: dbFile);
          await repository.ensureReady();
          final restored = (await repository.getMessage(assistant.id))!;
          final artifacts = await repository.getProviderArtifactsForMessages([
            assistant.id,
          ], 'responses_turn');
          final events = [
            for (final part in restored.parts.whereType<ToolCallPart>())
              (jsonDecode(part.payloadJson) as Map).cast<String, dynamic>(),
          ];
          final builder = MessageBuilderService(
            chatService: _Chat(events),
            contextProvider: _Context(),
            providerArtifactLookup: (message, kind) =>
                kind == 'responses_turn' ? artifacts[message.id] : null,
          );
          final history = builder.buildApiMessages(
            messages: [
              ChatMessage(role: 'user', content: 'Check.', conversationId: 'c'),
              restored,
              ChatMessage(role: 'user', content: 'Next?', conversationId: 'c'),
            ],
            versionSelections: const {},
            currentConversation: conversation,
            includeToolMessages: true,
            preserveToolTurns: true,
            responsesScope: responsesReplayScope(config, modelId),
          );
          await ChatApiService.sendMessageStream(
            config: config,
            modelId: modelId,
            messages: history,
            tools: _tools,
            stream: stream,
          ).toList();
          final input = (requests.last['input'] as List).cast<Map>();
          expect(input.sublist(1, input.length - 1), [
            ...outputs[0],
            {
              'type': 'function_call_output',
              'call_id': 'a',
              'output': 'result-a',
            },
            {
              'type': 'function_call_output',
              'call_id': 'b',
              'output': 'result-b',
            },
            ...outputs[1],
            {
              'type': 'function_call_output',
              'call_id': 'c',
              'output': 'result-c',
            },
            ...outputs[2],
          ]);
          expect(input.last['content'], 'Next?');
          expect(requests, hasLength(4));
        },
      );
    }
  }
}
