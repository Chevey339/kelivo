import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/chat_api_helpers.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_user_context_parts.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import '../../support/business_test_harness.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Iterable<String> _strings(Object? value) sync* {
  if (value is String) yield value;
  if (value is Map) {
    for (final entry in value.values) {
      yield* _strings(entry);
    }
  }
  if (value is List) {
    for (final entry in value) {
      yield* _strings(entry);
    }
  }
}

void main() {
  test(
    'persist and send regexes change the ordinary body, never the frozen part',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      addTearDown(settings.dispose);
      final service = MessageBuilderService(
        chatService: ChatService(),
        contextProvider: _Context(),
      );
      final frozen = UiContextText(title: 'Original', body: 'value: ORIGINAL');
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        regexRules: [
          AssistantRegex(
            id: 'persist',
            name: 'persist',
            pattern: 'ORIGINAL',
            replacement: 'SAVED',
            scopes: [AssistantRegexScope.user],
          ),
          AssistantRegex(
            id: 'send',
            name: 'send',
            pattern: 'SAVED|ORIGINAL',
            replacement: 'SENT',
            scopes: [AssistantRegexScope.user],
            replaceOnly: true,
          ),
        ],
      );
      final body =
          await MessageGenerationService.buildPersistedUserMessageParts(
            ChatInputData(
              text: 'ORIGINAL',
              uiContext: UiContextAttachment.history(frozen),
            ),
            assistant: assistant,
          );
      final message = ChatMessage(
        role: 'user',
        conversationId: 'c',
        parts: UiUserContextParts.attach(body, frozen),
      );
      expect(UiUserContextParts.read(message.parts).bodyText, 'SAVED');
      final edited = service.parseInputFromMessage(message);
      expect(edited.text, 'SAVED');
      expect(edited.uiContext!.previouslySent, isTrue);
      expect(edited.uiContext!.text, frozen);
      final api = service.buildApiMessages(
        messages: [message],
        versionSelections: const {},
        currentConversation: null,
      );
      await service.processUserMessagesForApi(
        api,
        settings,
        assistant,
        sourceMessages: [message],
      );
      expect(api.single['content'], '${frozen.exactText}\n\nSENT');
      expect(api.single[multimodalInternalLiteralTextKey], frozen.exactText);
    },
  );

  test(
    'image parsing protects the exact bounded part but processes ordinary images',
    () async {
      final frozen = UiContextText(
        title: 'Value',
        body: '![x](data:image/png;base64,YQ==)',
      );
      final parsed = await parseTextAndImages(
        '${frozen.exactText}\n\n![outside](data:image/png;base64,Yg==)',
        literalText: frozen.exactText,
        allowRemoteImages: true,
        allowLocalImages: true,
      );
      expect(parsed.text, frozen.exactText);
      expect(parsed.images.map((image) => image.src), [
        'data:image/png;base64,Yg==',
      ]);
      // A Markdown opener outside the part cannot swallow its protected text.
      final spanning = await parseTextAndImages(
        '![before](${frozen.exactText})',
        literalText: frozen.exactText,
        allowRemoteImages: true,
        allowLocalImages: true,
      );
      expect(spanning.text, contains(frozen.exactText));
      expect(spanning.images, isEmpty);
    },
  );

  for (final variant in [
    'chat',
    'text-only',
    'responses',
    'claude',
    'gemini',
    'images',
  ]) {
    test(
      '$variant wire preserves frozen media syntax without reads or image blocks',
      () async {
        final directory = await Directory.systemTemp.createTemp('genui-wire-');
        addTearDown(() => directory.delete(recursive: true));
        final local = await File(
          '${directory.path}/fixture.png',
        ).writeAsString('fixture-only-secret');
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final base = 'http://${server.address.address}:${server.port}';
        final frozen = UiContextText(
          title: 'Frozen literal',
          body:
              '![local](${local.path})\n![remote]($base/probe)\n![data](data:image/png;base64,YQ==)',
        );
        var requests = 0;
        Map<String, dynamic>? body;
        String? requestPath;
        server.listen((request) async {
          requests++;
          requestPath = request.uri.path;
          final raw = await utf8.decoder.bind(request).join();
          if (raw.isNotEmpty) body = jsonDecode(raw) as Map<String, dynamic>;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(switch (variant) {
              'responses' => {
                'id': 'r',
                'status': 'completed',
                'output': [
                  {
                    'type': 'message',
                    'role': 'assistant',
                    'content': [
                      {'type': 'output_text', 'text': 'ok'},
                    ],
                  },
                ],
              },
              'claude' => {
                'id': 'r',
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'ok'},
                ],
                'stop_reason': 'end_turn',
                'usage': {'input_tokens': 1, 'output_tokens': 1},
              },
              'gemini' => {
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        {'text': 'ok'},
                      ],
                    },
                    'finishReason': 'STOP',
                  },
                ],
              },
              'images' => {
                'data': [
                  {'url': 'https://example.invalid/result.png'},
                ],
              },
              _ => {
                'choices': [
                  {
                    'message': {'role': 'assistant', 'content': 'ok'},
                    'finish_reason': 'stop',
                  },
                ],
              },
            }),
          );
          await request.response.close();
        });
        final message = ChatMessage(
          role: 'user',
          conversationId: 'c',
          parts: UiUserContextParts.attach(const [TextPart('Explain')], frozen),
        );
        final builder = MessageBuilderService(
          chatService: ChatService(),
          contextProvider: _Context(),
        );
        final api = builder.buildApiMessages(
          messages: [message],
          versionSelections: const {},
          currentConversation: null,
        );
        await builder.inlineLocalImages(api);
        expect(api.single['content'], message.content);
        builder.stripInternalRevisionIds(api);
        final model = switch (variant) {
          'claude' => 'claude-sonnet-4-6',
          'gemini' => 'gemini-2.5-flash',
          'images' => 'gpt-image-2',
          _ => 'gpt-4o',
        };
        await ChatApiService.sendMessageStream(
          config: ProviderConfig(
            id: 'GenUiTest',
            name: 'GenUiTest',
            enabled: true,
            apiKey: 'test',
            baseUrl: '$base/v1',
            providerType: switch (variant) {
              'claude' => ProviderKind.claude,
              'gemini' => ProviderKind.google,
              _ => ProviderKind.openai,
            },
            useResponseApi: variant == 'responses',
            modelOverrides: {
              model: {
                'input': variant == 'text-only' ? ['text'] : ['text', 'image'],
              },
            },
          ),
          modelId: model,
          messages: api,
          stream: false,
        ).toList();
        expect(
          requests,
          1,
          reason: 'frozen remote syntax must not cause a HEAD/download',
        );
        expect(
          _strings(body).any((text) => text.contains(frozen.exactText)),
          isTrue,
        );
        expect(
          jsonEncode(body),
          isNot(contains(multimodalInternalLiteralTextKey)),
        );
        expect(_strings(body), isNot(contains('image_url')));
        expect(_strings(body), isNot(contains('input_image')));
        expect(jsonEncode(body), isNot(contains('inlineData')));
        if (variant == 'images') expect(requestPath, '/v1/images/generations');
      },
    );
  }
}
