import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_thinking_recovery.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart' as sc;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends Fake implements SettingsProvider {
  _Settings(this.config);
  final ProviderConfig config;

  @override
  ProviderConfig getProviderConfig(String key, {String? defaultName}) => config;
}

class _Generation extends Fake implements GenerationController {}

class _Stream extends Fake implements sc.StreamController {}

class _HistoryCaptured implements Exception {}

class _Builder extends MessageBuilderService {
  _Builder({
    required super.chatService,
    required super.contextProvider,
    required super.providerArtifactLookup,
  });

  late List<Map<String, dynamic>> history;

  @override
  List<Map<String, dynamic>> buildApiMessages({
    required List<ChatMessage> messages,
    required Map<String, int> versionSelections,
    required Conversation? currentConversation,
    bool includeToolMessages = false,
    bool preserveToolTurns = false,
    ResponsesReplayScope? responsesScope,
    ({String providerId, String modelId})? claudeSource,
  }) {
    history = super.buildApiMessages(
      messages: messages,
      versionSelections: versionSelections,
      currentConversation: currentConversation,
      includeToolMessages: includeToolMessages,
      preserveToolTurns: preserveToolTurns,
      responsesScope: responsesScope,
      claudeSource: claudeSource,
    );
    // Exercise real protocol selection and history assembly, stopping before
    // unrelated prompt injection, workspace setup, and tool discovery.
    throw _HistoryCaptured();
  }
}

void main() {
  test(
    'Kimi OAuth Messages assembly preserves native blocks and recovery',
    () async {
      const model = 'kimi-for-coding';
      final config = ProviderConfig(
        id: 'oauth_kimi',
        enabled: true,
        name: 'Kimi Code',
        apiKey: 'fixture',
        baseUrl: 'https://api.kimi.com/coding/v1',
        providerType: ProviderKind.openai,
        oauthProvider: OAuthProvider.kimi,
        modelOverrides: {
          model: {'oauthProtocol': 'anthropic'},
        },
      );
      const rejected = {
        'type': 'thinking',
        'thinking': '',
        'signature': 'stale',
      };
      const thinking = {
        'type': 'thinking',
        'thinking': 'Plan',
        'signature': 'native-kimi-state',
      };
      const text = {'type': 'text', 'text': 'Answer'};
      final recovery = ClaudeThinkingRecovery();
      expect(
        recovery.recover(
          {
            'messages': [
              {
                'role': 'assistant',
                'content': [rejected],
              },
            ],
          },
          400,
          jsonEncode({
            'error': {
              'type': 'invalid_request_error',
              'message':
                  'messages.0.content.0: The block is bound to a different conversation.',
            },
          }),
        ),
        isTrue,
      );
      final chat = ChatService();
      final context = _Context();
      final builder = _Builder(
        chatService: chat,
        contextProvider: context,
        providerArtifactLookup: (message, kind) => message.id != 'a'
            ? null
            : switch (kind) {
                claudeTurnArtifactKind => encodeClaudeTurn([
                  [rejected, thinking, text],
                ]),
                claudeThinkingRecoveryArtifactKind => recovery.artifact,
                _ => null,
              },
      );
      final generation = MessageGenerationService(
        chatService: chat,
        messageBuilderService: builder,
        generationController: _Generation(),
        streamController: _Stream(),
        contextProvider: context,
      );
      await expectLater(
        generation.assembleUnprocessedRequestContext(
          messages: [
            ChatMessage(role: 'user', content: 'Question', conversationId: 'c'),
            ChatMessage(
              id: 'a',
              role: 'assistant',
              content: 'Answer',
              providerId: config.id,
              modelId: model,
              conversationId: 'c',
            ),
            ChatMessage(role: 'user', content: 'Next', conversationId: 'c'),
          ],
          versionSelections: {},
          currentConversation: null,
          settings: _Settings(config),
          assistant: null,
          assistantId: null,
          providerKey: config.id,
          modelId: model,
        ),
        throwsA(isA<_HistoryCaptured>()),
      );
      final effective = config.forModelProtocol(model);
      expect(config.providerType, ProviderKind.openai);
      expect(effective.providerType, ProviderKind.claude);
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body);
        return http.Response(
          '{"content":[{"type":"text","text":"Ok"}],"stop_reason":"end_turn"}',
          200,
        );
      });
      addTearDown(client.close);
      await sendClaudeStream(
        client,
        effective,
        model,
        builder.history,
        stream: false,
      ).toList();
      expect((body['messages'] as List)[1]['content'], [thinking, text]);
    },
  );

  for (final stream in [true, false]) {
    test(
      'Gemini replays each persisted tool round as its own turn (stream=$stream)',
      () async {
        Map<String, dynamic> call(String id) => {
          'functionCall': {
            'id': id,
            'name': 'lookup',
            'args': {'id': id},
          },
          'thoughtSignature': 'sig-$id',
        };
        final replies = [
          [
            {'text': 'Checking.'},
            call('a'),
            call('b'),
          ],
          [call('c')],
          [
            {'text': 'Done.'},
          ],
          [
            {'text': 'Ok.'},
          ],
        ];
        final requests = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          requests.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          final reply = {
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': replies[requests.length - 1],
                },
                'finishReason': 'STOP',
              },
            ],
          };
          request.response.write(
            stream ? 'data: ${jsonEncode(reply)}\n\n' : jsonEncode(reply),
          );
          await request.response.close();
        });
        const model = 'gemini-3.8-flash';
        final config = ProviderConfig(
          id: 'Gemini',
          enabled: true,
          name: 'Gemini',
          apiKey: 'test',
          baseUrl: 'http://${server.address.address}:${server.port}/v1beta',
          providerType: ProviderKind.google,
        );
        final chunks = await ChatApiService.sendMessageStream(
          config: config,
          modelId: model,
          messages: const [
            {'role': 'user', 'content': 'Check.'},
          ],
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
          stream: stream,
          onToolCall: (name, arguments, {toolCallId}) async =>
              '{"result":"${arguments['id']}"}',
        ).toList();
        final assistant = ChatMessage(
          role: 'assistant',
          conversationId: 'c',
          parts: [
            for (final part in StreamChunkHandler.collect(chunks).parts)
              MessagePart.fromRow(part.kind, part.encodePayload()),
          ],
        );
        final chat = ChatService();
        final context = _Context();
        final builder = _Builder(
          chatService: chat,
          contextProvider: context,
          providerArtifactLookup: (_, _) => null,
        );
        await expectLater(
          MessageGenerationService(
            chatService: chat,
            messageBuilderService: builder,
            generationController: _Generation(),
            streamController: _Stream(),
            contextProvider: context,
          ).assembleUnprocessedRequestContext(
            messages: [
              ChatMessage(role: 'user', content: 'Check.', conversationId: 'c'),
              assistant,
              ChatMessage(role: 'user', content: 'Next', conversationId: 'c'),
            ],
            versionSelections: {},
            currentConversation: null,
            settings: _Settings(config),
            assistant: null,
            assistantId: null,
            providerKey: config.id,
            modelId: model,
          ),
          throwsA(isA<_HistoryCaptured>()),
        );
        await ChatApiService.sendMessageStream(
          config: config,
          modelId: model,
          messages: builder.history,
          stream: stream,
        ).toList();

        final contents = (requests.last['contents'] as List).cast<Map>();
        expect(contents.map((c) => c['role']), [
          'user',
          'model',
          'user',
          'model',
          'user',
          'model',
          'user',
        ]);
        Map<String, dynamic> response(String id) => {
          'functionResponse': {
            'name': 'lookup',
            'response': {'result': id},
            'id': id,
          },
        };
        expect(
          [for (final turn in contents.sublist(1, 6)) turn['parts']],
          [
            replies[0],
            [response('a'), response('b')],
            replies[1],
            [response('c')],
            replies[2],
          ],
        );
      },
    );
  }
}
