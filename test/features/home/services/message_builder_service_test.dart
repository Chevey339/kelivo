import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_container.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/api/providers/google/gemini_thought_signature.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/ocr_service.dart';

import '../../../support/business_test_harness.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {
  _FakeChatService(
    this._toolEventsByMessageId, {
    this.persistedMessages = const [],
  });

  final Map<String, List<Map<String, dynamic>>> _toolEventsByMessageId;
  final List<ChatMessage> persistedMessages;

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    return List<Map<String, dynamic>>.of(
      _toolEventsByMessageId[assistantMessageId] ?? const [],
    );
  }

  @override
  List<ChatMessage> getMessages(String conversationId) {
    return persistedMessages
        .where((message) => message.conversationId == conversationId)
        .toList();
  }
}

class _StubGenerationController extends Fake implements GenerationController {}

class _StubStreamController extends Fake
    implements stream_ctrl.StreamController {}

MessageGenerationService _messageGenerationServiceForAudioCheck() {
  final chatService = _FakeChatService(const {});
  final messageBuilderService = MessageBuilderService(
    chatService: chatService,
    contextProvider: _FakeBuildContext(),
  );
  return MessageGenerationService(
    chatService: chatService,
    messageBuilderService: messageBuilderService,
    generationController: _StubGenerationController(),
    streamController: _StubStreamController(),
    contextProvider: _FakeBuildContext(),
  );
}

ChatMessage _message({
  required String id,
  required String role,
  required String content,
  String? reasoningText,
  String? groupId,
  int version = 0,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    conversationId: 'conversation-1',
    reasoningText: reasoningText,
    groupId: groupId,
    version: version,
  );
}

void main() {
  test('collapseVersions 按真实版本号选择消息', () {
    final service = MessageBuilderService(
      chatService: _FakeChatService(const {}),
      contextProvider: _FakeBuildContext(),
    );

    final collapsed = service.collapseVersions(
      [
        _message(
          id: 'v1',
          role: 'assistant',
          content: 'selected',
          groupId: 'answer',
          version: 1,
        ),
        _message(
          id: 'v2',
          role: 'assistant',
          content: 'not selected',
          groupId: 'answer',
          version: 2,
        ),
      ],
      const {'answer': 1},
    );

    expect(collapsed.single.id, 'v1');
  });

  group('MessageBuilderService.parseInputFromMessage', () {
    test('reads image/file parts without marker strings', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final message = ChatMessage(
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('media'),
          ImagePart(uri: 'C:/tmp/photo.png', mime: 'image/png'),
          FilePart(uri: 'C:/tmp/clip.mp4', name: 'clip.mp4', mime: 'video/mp4'),
        ],
      );
      final input = service.parseInputFromMessage(message);
      expect(input.text, 'media');
      expect(input.imagePaths, contains('C:/tmp/photo.png'));
      expect(input.imagePaths, contains('C:/tmp/clip.mp4'));
      expect(input.documents.single.fileName, 'clip.mp4');
    });

    test(
      'skips unavailable parts for API media and keeps mime on documents',
      () {
        final service = MessageBuilderService(
          chatService: _FakeChatService(const {}),
          contextProvider: _FakeBuildContext(),
        );
        final input = service.parseInputFromMessage(
          ChatMessage(
            role: 'user',
            conversationId: 'c1',
            parts: const [
              TextPart('media'),
              ImagePart(
                uri: '/tmp/missing.png',
                mime: 'image/png',
                unavailable: true,
              ),
              ImagePart(uri: '/tmp/ok.png', mime: 'image/png'),
              FilePart(
                uri: '/tmp/gone.wav',
                name: 'gone.wav',
                mime: 'audio/wav',
                unavailable: true,
              ),
              FilePart(
                uri: '/tmp/keep.wav',
                name: 'keep.wav',
                mime: 'audio/wav',
              ),
            ],
          ),
        );
        expect(input.imagePaths, ['/tmp/ok.png', '/tmp/keep.wav']);
        expect(input.documents.single.fileName, 'keep.wav');
        expect(input.documents.single.mime, 'audio/wav');
      },
    );

    test('TextPart-only content does not decode legacy attachment markers', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final message = ChatMessage(
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart(
            'see [image:/tmp/a.png] and [file:/tmp/a.pdf|a.pdf|application/pdf]',
          ),
        ],
      );
      final input = service.parseInputFromMessage(message);
      expect(
        input.text,
        'see [image:/tmp/a.png] and [file:/tmp/a.pdf|a.pdf|application/pdf]',
      );
      expect(input.imagePaths, isEmpty);
      expect(input.documents, isEmpty);
    });
  });

  group('MessageBuilderService.parseInputFromApiMap', () {
    test('uses content text and internal media paths only', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final input = service.parseInputFromApiMap({
        'role': 'user',
        'content': 'caption [image:/tmp/ignored.png]',
        MessageBuilderService.internalMediaPathsKey: [
          '/tmp/real.png',
          '/tmp/clip.mp3',
        ],
      });
      expect(input.text, 'caption [image:/tmp/ignored.png]');
      expect(input.imagePaths, ['/tmp/real.png', '/tmp/clip.mp3']);
      expect(input.documents.single.fileName, 'clip.mp3');
      expect(input.documents.single.mime.startsWith('audio/'), isTrue);
    });

    test('reads structured map media refs and preserves mime', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final input = service.parseInputFromApiMap({
        'role': 'user',
        'content': 'caption',
        MessageBuilderService.internalMediaPathsKey: [
          encodeInternalMediaRef(uri: '/tmp/real.png', mime: 'image/png'),
          encodeInternalMediaRef(uri: '/tmp/voice.bin', mime: 'audio/wav'),
        ],
      });
      expect(input.imagePaths, ['/tmp/real.png', '/tmp/voice.bin']);
      expect(input.documents.single.fileName, 'voice.bin');
      expect(input.documents.single.mime, 'audio/wav');
    });
  });

  group('MessageBuilderService.parseInputFromMessage media files', () {
    test(
      'image/png FilePart enters imagePaths when includeMediaFilePathsAsImages',
      () {
        final service = MessageBuilderService(
          chatService: _FakeChatService(const {}),
          contextProvider: _FakeBuildContext(),
        );
        final input = service.parseInputFromMessage(
          ChatMessage(
            role: 'user',
            conversationId: 'c1',
            parts: const [
              TextPart('caption'),
              FilePart(
                uri: '/tmp/photo.png',
                name: 'photo.png',
                mime: 'image/png',
              ),
            ],
          ),
        );
        expect(input.imagePaths, contains('/tmp/photo.png'));
        expect(input.documents.single.fileName, 'photo.png');
        expect(input.documents.single.mime, 'image/png');
      },
    );

    test('默认将视频和音频 FilePart 纳入媒体路径供 API 使用', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromMessage(
        ChatMessage(
          role: 'user',
          conversationId: 'c1',
          parts: const [
            TextPart('media'),
            FilePart(
              uri: 'C:/tmp/clip.mp4',
              name: 'clip.mp4',
              mime: 'video/mp4',
            ),
            FilePart(
              uri: 'C:/tmp/audio.wav',
              name: 'audio.wav',
              mime: 'audio/wav',
            ),
          ],
        ),
      );

      expect(input.text, 'media');
      expect(input.imagePaths, ['C:/tmp/clip.mp4', 'C:/tmp/audio.wav']);
      expect(input.documents.map((document) => document.fileName), [
        'clip.mp4',
        'audio.wav',
      ]);
    });

    test('编辑恢复草稿时不把视频和音频 FilePart 伪装成图片', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromMessage(
        ChatMessage(
          role: 'user',
          conversationId: 'c1',
          parts: const [
            TextPart('media'),
            ImagePart(uri: 'C:/tmp/photo.png', mime: 'image/png'),
            FilePart(
              uri: 'C:/tmp/clip.mp4',
              name: 'clip.mp4',
              mime: 'video/mp4',
            ),
            FilePart(
              uri: 'C:/tmp/audio.wav',
              name: 'audio.wav',
              mime: 'audio/wav',
            ),
          ],
        ),
        includeMediaFilePathsAsImages: false,
      );

      expect(input.text, 'media');
      expect(input.imagePaths, ['C:/tmp/photo.png']);
      expect(input.documents.map((document) => document.fileName), [
        'clip.mp4',
        'audio.wav',
      ]);
    });
  });

  group('MessageBuilderService.buildApiMessages media paths', () {
    test('pure-attachment user message emits structured media paths', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = service.buildApiMessages(
        messages: [
          ChatMessage(
            id: 'u1',
            role: 'user',
            conversationId: 'c1',
            parts: const [ImagePart(uri: '/tmp/only.png', mime: 'image/png')],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      expect(apiMessages, hasLength(1));
      expect(apiMessages.single['content'], '');
      expect(
        apiMessages.single[MessageBuilderService.internalRevisionIdKey],
        'u1',
      );
      expect(apiMessages.single[MessageBuilderService.internalMediaPathsKey], [
        encodeInternalMediaRef(uri: '/tmp/only.png', mime: 'image/png'),
      ]);
    });

    test('assistant ImagePart gets media paths too', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: 'hi'),
          ChatMessage(
            id: 'a1',
            role: 'assistant',
            conversationId: 'c1',
            parts: const [
              TextPart('see image'),
              ImagePart(uri: '/tmp/assistant.png', mime: 'image/png'),
            ],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      final assistant = apiMessages.lastWhere(
        (message) => message['role'] == 'assistant',
      );
      expect(assistant[MessageBuilderService.internalMediaPathsKey], [
        encodeInternalMediaRef(uri: '/tmp/assistant.png', mime: 'image/png'),
      ]);
    });

    test('unavailable parts are omitted from media paths', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = service.buildApiMessages(
        messages: [
          ChatMessage(
            id: 'u1',
            role: 'user',
            conversationId: 'c1',
            parts: const [
              TextPart('mixed'),
              ImagePart(
                uri: '/tmp/missing.png',
                mime: 'image/png',
                unavailable: true,
              ),
              ImagePart(uri: '/tmp/ok.png', mime: 'image/png'),
              FilePart(
                uri: '/tmp/gone.mp3',
                name: 'gone.mp3',
                mime: 'audio/mpeg',
                unavailable: true,
              ),
            ],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      expect(apiMessages.single[MessageBuilderService.internalMediaPathsKey], [
        encodeInternalMediaRef(uri: '/tmp/ok.png', mime: 'image/png'),
      ]);
    });

    test('pure PDF FilePart-only user message appears in buildApiMessages', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = service.buildApiMessages(
        messages: [
          ChatMessage(
            id: 'u-pdf',
            role: 'user',
            conversationId: 'c1',
            parts: const [
              FilePart(
                uri: '/tmp/spec.pdf',
                name: 'spec.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      expect(apiMessages, hasLength(1));
      expect(apiMessages.single['role'], 'user');
      expect(apiMessages.single['content'], '');
      expect(
        apiMessages.single[MessageBuilderService.internalRevisionIdKey],
        'u-pdf',
      );
      // PDF is a document, not a media-path attachment.
      expect(
        apiMessages.single.containsKey(
          MessageBuilderService.internalMediaPathsKey,
        ),
        isFalse,
      );
    });

    test(
      'octet-stream video FilePart emits inferred video mime in media refs',
      () {
        final refs = MessageBuilderService.mediaRefsFromParts(
          ChatMessage(
            role: 'user',
            conversationId: 'c1',
            parts: const [
              FilePart(
                uri: '/tmp/clip.mp4',
                name: 'clip.mp4',
                mime: 'application/octet-stream',
              ),
            ],
          ),
        );
        expect(refs, hasLength(1));
        expect(refs.single['uri'], '/tmp/clip.mp4');
        expect(refs.single['mime'], 'video/mp4');
      },
    );

    test('audio FilePart is detectable without processUserMessagesForApi', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = service.buildApiMessages(
        messages: [
          ChatMessage(
            id: 'u1',
            role: 'user',
            conversationId: 'c1',
            parts: const [
              FilePart(
                uri: '/tmp/voice.bin',
                name: 'voice.bin',
                mime: 'audio/wav',
              ),
            ],
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      final refs = parseInternalMediaRefs(
        apiMessages.single[MessageBuilderService.internalMediaPathsKey],
      );
      expect(refs, isNotEmpty);
      expect(
        refs.any(
          (ref) => isAudioMime(
            (ref.mime != null && ref.mime!.isNotEmpty)
                ? ref.mime!
                : inferMediaMimeFromSource(ref.uri),
          ),
        ),
        isTrue,
      );
      expect(refs.single.mime, 'audio/wav');
    });

    test(
      'assistant audio media refs trip apiMessagesContainAudioAttachments',
      () {
        final builder = MessageBuilderService(
          chatService: _FakeChatService(const {}),
          contextProvider: _FakeBuildContext(),
        );
        final apiMessages = builder.buildApiMessages(
          messages: [
            _message(id: 'u1', role: 'user', content: 'hi'),
            ChatMessage(
              id: 'a1',
              role: 'assistant',
              conversationId: 'c1',
              parts: const [
                TextPart('voice reply'),
                FilePart(
                  uri: '/tmp/assistant.wav',
                  name: 'assistant.wav',
                  mime: 'audio/wav',
                ),
              ],
            ),
          ],
          versionSelections: const {},
          currentConversation: Conversation(title: 'test'),
        );
        final generation = _messageGenerationServiceForAudioCheck();
        expect(
          generation.apiMessagesContainAudioAttachments(apiMessages),
          isTrue,
        );
      },
    );
  });

  group('MessageBuilderService.buildApiMessages', () {
    test('有工具调用时会把 reasoning_content 回填到 assistant tool 消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_weather',
              'arguments': {'location': 'Hangzhou', 'date': '2026-04-25'},
              'content': 'Cloudy 7~13°C',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '杭州明天天气怎么样？'),
          _message(
            id: 'a1',
            role: 'assistant',
            content: '明天多云，7 到 13 度。',
            reasoningText: '先判断日期，再查询天气。',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      expect(assistantToolMessage['content'], '\n\n');
      expect(assistantToolMessage['reasoning_content'], '先判断日期，再查询天气。');
      expect(finalAssistantMessage['reasoning_content'], '先判断日期，再查询天气。');
    });

    test(
      'a stored Claude turn rides on the tool message, the container on both',
      () {
        final service = MessageBuilderService(
          chatService: _FakeChatService({
            'a1': [
              {
                'id': 'srvtoolu_1',
                'name': 'web_fetch',
                'arguments': {'url': 'https://example.com'},
                'content': '{}',
              },
            ],
          }),
          contextProvider: _FakeBuildContext(),
          providerArtifactLookup: (message, kind) => switch (kind) {
            claudeTurnArtifactKind => '[[{"type":"text","text":"hi"}]]',
            claudeContainerArtifactKind => '{"id":"container_1"}',
            _ => null,
          },
        );

        final apiMessages = service.buildApiMessages(
          messages: [
            _message(id: 'u1', role: 'user', content: '看看'),
            _message(id: 'a1', role: 'assistant', content: 'hi'),
          ],
          versionSelections: const {},
          currentConversation: Conversation(title: 'test'),
          includeToolMessages: true,
        );

        final toolMessage = apiMessages.firstWhere(
          (message) => message['tool_calls'] is List,
        );
        final finalMessage = apiMessages.last;
        expect(
          toolMessage[multimodalInternalClaudeTurnKey],
          '[[{"type":"text","text":"hi"}]]',
        );
        expect(
          toolMessage[multimodalInternalClaudeContainerKey],
          '{"id":"container_1"}',
        );
        expect(finalMessage[multimodalInternalClaudeTurnKey], isNull);
        expect(
          finalMessage[multimodalInternalClaudeContainerKey],
          '{"id":"container_1"}',
        );
      },
    );

    test('a stored Gemini signature rides on the final assistant message', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
        providerArtifactLookup: (message, kind) =>
            kind == geminiThoughtSignatureArtifactKind && message.id == 'a1'
            ? 'sig-stored'
            : null,
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '你好'),
          _message(id: 'a1', role: 'assistant', content: '你好呀'),
          _message(id: 'u2', role: 'user', content: '再见'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      expect(
        apiMessages.map((m) => m[multimodalInternalGeminiThoughtSignatureKey]),
        [null, 'sig-stored', null],
      );
    });

    test(
      'a turn that ran code and said nothing still carries its container',
      () {
        final service = MessageBuilderService(
          chatService: _FakeChatService({
            'a1': [
              {
                'id': 'srvtoolu_1',
                'name': 'code_execution',
                'arguments': {'code': 'print(1)'},
                'content': '{"stdout":"1\\n"}',
              },
            ],
          }),
          contextProvider: _FakeBuildContext(),
          providerArtifactLookup: (message, kind) =>
              kind == claudeContainerArtifactKind
              ? '{"id":"container_1"}'
              : null,
        );

        final apiMessages = service.buildApiMessages(
          messages: [
            _message(id: 'u1', role: 'user', content: '跑一下'),
            _message(id: 'a1', role: 'assistant', content: ''),
          ],
          versionSelections: const {},
          currentConversation: Conversation(title: 'test'),
          includeToolMessages: true,
        );

        expect(apiMessages.last['role'], 'tool');
        final toolMessage = apiMessages.firstWhere(
          (message) => message['tool_calls'] is List,
        );
        expect(
          toolMessage[multimodalInternalClaudeContainerKey],
          '{"id":"container_1"}',
        );
      },
    );

    test('reasoningText 为空时不会伪造 reasoning_content', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_date',
              'arguments': <String, dynamic>{},
              'content': '2026-04-24',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '今天几号？'),
          _message(
            id: 'a1',
            role: 'assistant',
            content: '今天是 2026-04-24。',
            reasoningText: '',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      expect(assistantToolMessage.containsKey('reasoning_content'), isFalse);
      expect(finalAssistantMessage.containsKey('reasoning_content'), isFalse);
    });

    test('reasoning_details 只挂在最终 assistant 消息，不重复到 tool call 消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_weather',
              'arguments': {'location': 'Hangzhou'},
              'content': 'Cloudy 7~13°C',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      const reasoningDetails = [
        {
          'type': 'reasoning.text',
          'text': 'final round thinking',
          'signature': 'sig-final',
        },
      ];
      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '杭州明天天气怎么样？'),
          ChatMessage(
            id: 'a1',
            role: 'assistant',
            content: '明天多云，7 到 13 度。',
            conversationId: 'conversation-1',
            reasoningSegmentsJson:
                '{"v":2,"segments":[],"reasoningDetails":[{"type":"reasoning.text","text":"final round thinking","signature":"sig-final"}]}',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      // Replaying the same reasoning on both assistant messages makes
      // OpenRouter/Anthropic reject the history; only the final message may
      // carry it.
      expect(assistantToolMessage.containsKey('reasoning_details'), isFalse);
      expect(finalAssistantMessage['reasoning_details'], reasoningDetails);
    });

    test('恢复工具回答续写时只发送 tool call 和 tool result', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'ask_user_input_v0',
              'arguments': {
                'questions': [
                  {
                    'id': 'scope',
                    'question': '选哪个范围？',
                    'type': 'single',
                    'options': ['最小', '完整'],
                  },
                ],
              },
              'content':
                  '{"type":"ask_user_answer","answers":{"scope":{"type":"single","value":"完整","custom":false,"skipped":false}}}',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '开始吧'),
          _message(id: 'a1', role: 'assistant', content: ''),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      expect(
        apiMessages.where(
          (message) =>
              message['role'] == 'assistant' && message['tool_calls'] == null,
        ),
        isEmpty,
      );
      expect(
        apiMessages.where(
          (message) =>
              message['role'] == 'assistant' && message['tool_calls'] is List,
        ),
        hasLength(1),
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        hasLength(1),
      );
    });

    test('传入消息缺少 reasoningText 时会从已持久化消息兜底回填', () {
      final persistedAssistant = _message(
        id: 'a1',
        role: 'assistant',
        content: '现在是北京时间下午三点。',
        reasoningText: '先调用时间工具，再整理成中文时间。',
      );
      final service = MessageBuilderService(
        chatService: _FakeChatService(
          {
            'a1': [
              {
                'id': 'call_1',
                'name': 'get-current-time',
                'arguments': {'timeZone': 'Asia/Shanghai'},
                'content': 'Friday, 2026-04-24 15:25:41',
              },
            ],
          },
          persistedMessages: [
            _message(id: 'u1', role: 'user', content: '现在几点了'),
            persistedAssistant,
          ],
        ),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '现在几点了'),
          _message(id: 'a1', role: 'assistant', content: '现在是北京时间下午三点。'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      final finalAssistantMessage = apiMessages.lastWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] == null,
      );

      expect(assistantToolMessage['reasoning_content'], '先调用时间工具，再整理成中文时间。');
      expect(finalAssistantMessage['reasoning_content'], '先调用时间工具，再整理成中文时间。');
    });

    test('关闭 OpenAI 工具消息重建时不额外注入 assistant tool 消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_weather',
              'arguments': {'location': 'Hangzhou'},
              'content': 'Cloudy',
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '帮我查天气'),
          _message(
            id: 'a1',
            role: 'assistant',
            content: '明天多云。',
            reasoningText: '先查日期，再查天气。',
          ),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: false,
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        isEmpty,
      );
    });

    test('工具历史会保留 provider 元数据供 Claude 和 Gemini 重放', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'lookup',
              'arguments': {'query': 'Kelivo'},
              'content': '{"result":"ok"}',
              'metadata': {
                'anthropic': {
                  'assistant_blocks': [
                    {
                      'type': 'thinking',
                      'thinking': '需要查询资料。',
                      'signature': 'sig-claude',
                    },
                    {
                      'type': 'tool_use',
                      'id': 'call_1',
                      'name': 'lookup',
                      'input': {'query': 'Kelivo'},
                    },
                  ],
                },
                'google': {
                  'part': {
                    'functionCall': {
                      'name': 'lookup',
                      'args': {'query': 'Kelivo'},
                    },
                    'thoughtSignature': 'sig-gemini',
                  },
                },
              },
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '查 Kelivo'),
          _message(id: 'a1', role: 'assistant', content: '查到了。'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final assistantToolMessage = apiMessages.firstWhere(
        (message) => message['tool_calls'] is List,
      );
      final toolMessage = apiMessages.firstWhere(
        (message) => message['role'] == 'tool',
      );
      final toolCall =
          (assistantToolMessage['tool_calls'] as List).single
              as Map<String, dynamic>;

      expect(toolCall['metadata']['anthropic']['assistant_blocks'], isNotEmpty);
      expect(
        toolCall['metadata']['google']['part']['thoughtSignature'],
        'sig-gemini',
      );
      expect(
        toolMessage['metadata']['google']['part']['thoughtSignature'],
        'sig-gemini',
      );
    });

    test('工具历史会保留 OpenAI 兼容 Gemini 的 extra_content', () {
      const extraContent = <String, dynamic>{
        'google': <String, dynamic>{'thought_signature': 'sig-create-memory'},
      };
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_mem',
              'name': 'create_memory',
              'arguments': {'content': 'note'},
              'content': '{"ok":true}',
              'metadata': {
                'google': {'extra_content': extraContent},
              },
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: 'remember this'),
          _message(id: 'a1', role: 'assistant', content: 'saved'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final toolCall =
          (apiMessages.firstWhere(
                        (message) => message['tool_calls'] is List,
                      )['tool_calls']
                      as List)
                  .single
              as Map<String, dynamic>;

      expect(toolCall['metadata']['google']['extra_content'], extraContent);
    });

    test('未完成的工具占位事件不会被重建为 API tool call', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({
          'a1': [
            {
              'id': 'call_1',
              'name': 'create_memory',
              'arguments': {'content': 'test'},
              'content': null,
              'metadata': {
                'anthropic': {
                  'assistant_blocks': [
                    {
                      'type': 'tool_use',
                      'id': 'call_1',
                      'name': 'create_memory',
                      'input': {'content': 'test'},
                    },
                  ],
                },
              },
            },
          ],
        }),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '记一下'),
          _message(id: 'a1', role: 'assistant', content: '稍后继续。'),
          _message(id: 'u2', role: 'user', content: 'ok'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        isEmpty,
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        isEmpty,
      );
      expect(apiMessages.map((message) => message['content']).toList(), [
        '记一下',
        '稍后继续。',
        'ok',
      ]);
    });

    test('user 消息会附带内部 revision id，strip 后不再出现', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: 'hello'),
          _message(id: 'a1', role: 'assistant', content: 'hi'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );

      expect(apiMessages.first['role'], 'user');
      expect(
        apiMessages.first[MessageBuilderService.internalRevisionIdKey],
        'u1',
      );
      expect(
        apiMessages.last.containsKey(
          MessageBuilderService.internalRevisionIdKey,
        ),
        isFalse,
      );

      service.stripInternalRevisionIds(apiMessages);
      expect(
        apiMessages.any(
          (message) => message.containsKey(multimodalInternalRevisionIdKey),
        ),
        isFalse,
      );
    });

    test('WorldBook 注入后的最终裁剪会限制发送消息数', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      // prepareApiMessages injects WorldBook against the full history, then
      // applies a single context trim before OCR — only when the assistant
      // opts into limitContextMessages (default is unlimited, D-30).
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'system'},
        for (var index = 0; index < 6; index++)
          {
            'role': index.isEven ? 'user' : 'assistant',
            'content': 'message-$index',
          },
        {'role': 'user', 'content': 'worldbook-top'},
        {'role': 'user', 'content': 'worldbook-bottom'},
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(
          id: 'assistant-1',
          name: 'test',
          contextMessageSize: 4,
          limitContextMessages: true,
        ),
      );
      expect(apiMessages.length, 5); // system + 4
      expect(apiMessages.first['role'], 'system');
      // Images in dropped history are never OCR'd because OCR runs after this trim.
      expect(
        apiMessages.any((m) => (m['content'] ?? '').toString() == 'message-0'),
        isFalse,
      );
    });

    test('上下文裁剪会丢掉历史图片消息并保留内部 revision id', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );

      final apiMessages = <Map<String, dynamic>>[
        for (var index = 0; index < 6; index++)
          if (index.isEven)
            {
              'role': 'user',
              'content': 'u$index',
              MessageBuilderService.internalMediaPathsKey: ['/img-$index.png'],
              MessageBuilderService.internalRevisionIdKey: 'u$index',
            }
          else
            {'role': 'assistant', 'content': 'a$index'},
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(
          id: 'assistant-1',
          name: 'test',
          contextMessageSize: 2,
          limitContextMessages: true,
        ),
      );

      expect(apiMessages, hasLength(2));
      final retainedMediaPaths = apiMessages
          .expand(
            (message) =>
                (message[MessageBuilderService.internalMediaPathsKey]
                    as List?) ??
                const [],
          )
          .map((path) => path.toString())
          .toList();
      expect(retainedMediaPaths, isNot(contains('/img-0.png')));
      expect(retainedMediaPaths, isNot(contains('/img-2.png')));
      expect(retainedMediaPaths, contains('/img-4.png'));

      final retainedUser = apiMessages.firstWhere(
        (message) => message['role'] == 'user',
      );
      expect(
        retainedUser[MessageBuilderService.internalRevisionIdKey],
        isNotNull,
      );
      expect(retainedUser[MessageBuilderService.internalMediaPathsKey], [
        '/img-4.png',
      ]);
      expect(
        (retainedUser['content'] ?? '').toString(),
        isNot(contains('[image:')),
      );
    });

    test('无限制上下文不会裁掉一千条以上的消息', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = <Map<String, dynamic>>[
        for (var index = 0; index < 1507; index++)
          {
            'role': index.isEven ? 'user' : 'assistant',
            'content': 'message-$index',
          },
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(
          id: 'assistant-1',
          name: 'test',
          limitContextMessages: false,
        ),
      );

      expect(apiMessages, hasLength(1507));
      expect(apiMessages.first['content'], 'message-0');
      expect(apiMessages.last['content'], 'message-1506');
    });

    test('上下文裁剪不会保留缺少 tool result 的 assistant tool call', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'before'},
        {
          'role': 'assistant',
          'content': '\n\n',
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {'name': 'create_memory', 'arguments': '{}'},
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call_1',
          'name': 'create_memory',
          'content': 'ok',
        },
        {'role': 'assistant', 'content': 'done'},
        {'role': 'user', 'content': 'next'},
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(
          id: 'assistant-1',
          name: 'test',
          contextMessageSize: 3,
          limitContextMessages: true,
        ),
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        isEmpty,
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        isEmpty,
      );
      expect(apiMessages.map((message) => message['content']).toList(), [
        'done',
        'next',
      ]);
    });

    test('上下文裁剪会保留完整的 assistant tool call 与 tool result', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
      );
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'before'},
        {
          'role': 'assistant',
          'content': '\n\n',
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {'name': 'create_memory', 'arguments': '{}'},
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call_1',
          'name': 'create_memory',
          'content': 'ok',
        },
        {'role': 'assistant', 'content': 'done'},
        {'role': 'user', 'content': 'next'},
      ];

      service.applyContextLimit(
        apiMessages,
        const Assistant(
          id: 'assistant-1',
          name: 'test',
          contextMessageSize: 4,
          limitContextMessages: true,
        ),
      );

      expect(
        apiMessages.where((message) => message['tool_calls'] is List),
        hasLength(1),
      );
      expect(
        apiMessages.where((message) => message['role'] == 'tool'),
        hasLength(1),
      );
      expect(apiMessages.map((message) => message['role']).toList(), [
        'assistant',
        'tool',
        'assistant',
        'user',
      ]);
    });
  });

  group('MessageBuilderService.hasPendingAttachmentWork', () {
    Future<SettingsProvider> newSettings() async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      return settings;
    }

    Future<SettingsProvider> settingsWithOcr() async {
      final settings = await newSettings();
      await settings.setProviderConfig(
        'ocr-provider',
        ProviderConfig(
          id: 'ocr-provider',
          enabled: true,
          name: 'OCR',
          apiKey: 'key',
          baseUrl: 'https://example.test',
          models: const ['ocr-model'],
          modelOverrides: const {
            'ocr-model': {
              'input': ['text', 'image'],
            },
          },
        ),
      );
      await settings.setOcrModel('ocr-provider', 'ocr-model');
      await settings.setOcrEnabled(true);
      return settings;
    }

    MessageBuilderService serviceWithOcr() => MessageBuilderService(
      chatService: _FakeChatService({}),
      contextProvider: _FakeBuildContext(),
      ocrHandler: (imagePaths, {revisionId, session, requestId}) async => 'ocr',
    );

    List<Map<String, dynamic>> apiMessagesFor(ChatMessage message) => [
      {
        'role': 'user',
        'content': message.content,
        MessageBuilderService.internalRevisionIdKey: message.id,
      },
    ];

    test('纯文本消息没有待解析附件', () async {
      final settings = await settingsWithOcr();
      final user = ChatMessage(
        id: 'u1',
        role: 'user',
        conversationId: 'c1',
        parts: const [TextPart('just text')],
      );
      expect(
        serviceWithOcr().hasPendingAttachmentWork(
          apiMessagesFor(user),
          settings,
          sourceMessages: [user],
        ),
        isFalse,
      );
    });

    test('关闭 OCR 时纯图片消息没有待解析附件', () async {
      final settings = await newSettings();
      final user = ChatMessage(
        id: 'u1',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('look'),
          ImagePart(uri: '/tmp/a.png', mime: 'image/png'),
        ],
      );
      expect(
        serviceWithOcr().hasPendingAttachmentWork(
          apiMessagesFor(user),
          settings,
          sourceMessages: [user],
        ),
        isFalse,
      );
    });

    test('开启 OCR 时图片消息需要解析', () async {
      final settings = await settingsWithOcr();
      final user = ChatMessage(
        id: 'u1',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('look'),
          ImagePart(uri: '/tmp/a.png', mime: 'image/png'),
        ],
      );
      expect(
        serviceWithOcr().hasPendingAttachmentWork(
          apiMessagesFor(user),
          settings,
          sourceMessages: [user],
        ),
        isTrue,
      );
    });

    test('文档附件无论 OCR 开关都需要解析', () async {
      final settings = await newSettings();
      final user = ChatMessage(
        id: 'u1',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('read this'),
          FilePart(uri: '/tmp/a.pdf', name: 'a.pdf', mime: 'application/pdf'),
        ],
      );
      expect(
        serviceWithOcr().hasPendingAttachmentWork(
          apiMessagesFor(user),
          settings,
          sourceMessages: [user],
        ),
        isTrue,
      );
    });

    test('音视频附件不算待解析文档', () async {
      final settings = await newSettings();
      final user = ChatMessage(
        id: 'u1',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('listen'),
          FilePart(uri: '/tmp/clip.mp3', name: 'clip.mp3', mime: 'audio/mpeg'),
        ],
      );
      expect(
        serviceWithOcr().hasPendingAttachmentWork(
          apiMessagesFor(user),
          settings,
          sourceMessages: [user],
        ),
        isFalse,
      );
    });

    test('缺少 revision id 的 WorldBook lore 不算待解析附件', () async {
      final settings = await settingsWithOcr();
      expect(
        serviceWithOcr().hasPendingAttachmentWork(const [
          {'role': 'user', 'content': 'lore [image:/tmp/lore.png]'},
        ], settings),
        isFalse,
      );
    });
  });

  group('MessageBuilderService.processUserMessagesForApi', () {
    test('不处理缺少内部 revision ID 的 WorldBook lore user 消息', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;

      final ocrCalls = <List<String>>[];
      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
        ocrHandler: (imagePaths, {revisionId, session, requestId}) async {
          ocrCalls.add(List<String>.of(imagePaths));
          return 'ocr-should-not-run';
        },
        ocrPrefetch: ({required revisionIds, required imagePaths}) async {
          ocrCalls.add(['prefetch', ...imagePaths]);
          return OcrPrepareSession();
        },
      );

      // Intentional negative: literal marker text in WorldBook lore must be
      // ignored when the message has no internal revision id.
      const loreContent =
          'lore with markers\n[image:/tmp/lore.png]\n[file:/tmp/lore.txt|lore.txt|text/plain]';
      final realUser = ChatMessage(
        id: 'u-real',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('real user'),
          ImagePart(uri: '/tmp/real.png', mime: 'image/png'),
        ],
      );
      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': loreContent, // WorldBook injection: no revision id
        },
        {
          'role': 'user',
          'content': realUser.content,
          MessageBuilderService.internalRevisionIdKey: realUser.id,
        },
      ];

      await settings.setProviderConfig(
        'ocr-provider',
        ProviderConfig(
          id: 'ocr-provider',
          enabled: true,
          name: 'OCR',
          apiKey: 'key',
          baseUrl: 'https://example.test',
          models: const ['ocr-model'],
          modelOverrides: const {
            'ocr-model': {
              'input': ['text', 'image'],
            },
          },
        ),
      );
      await settings.setOcrModel('ocr-provider', 'ocr-model');
      await settings.setOcrEnabled(true);

      await service.processUserMessagesForApi(
        apiMessages,
        settings,
        const Assistant(id: 'a1', name: 'test'),
        sourceMessages: [realUser],
      );

      expect(apiMessages.first['content'], loreContent);
      expect(
        apiMessages.first.containsKey(
          MessageBuilderService.internalMediaPathsKey,
        ),
        isFalse,
      );
      expect(
        ocrCalls.expand((paths) => paths),
        isNot(contains('/tmp/lore.png')),
      );
      expect(ocrCalls.expand((paths) => paths), contains('/tmp/real.png'));
      expect(apiMessages.last['content'], isNot(contains('[image:')));
      expect(apiMessages.first['content'], contains('[image:/tmp/lore.png]'));
    });

    test('writes structured media refs and keeps OCR filtering', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;

      final service = MessageBuilderService(
        chatService: _FakeChatService({}),
        contextProvider: _FakeBuildContext(),
        ocrHandler: (imagePaths, {revisionId, session, requestId}) async =>
            'ocr',
      );

      final realUser = ChatMessage(
        id: 'u-real',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('real user'),
          ImagePart(uri: '/tmp/real.png', mime: 'image/png'),
          FilePart(uri: '/tmp/clip.mp3', name: 'clip.mp3', mime: 'audio/mpeg'),
        ],
      );
      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': realUser.content,
          MessageBuilderService.internalRevisionIdKey: realUser.id,
          MessageBuilderService.internalMediaPathsKey:
              MessageBuilderService.mediaRefsFromParts(realUser),
        },
      ];

      await settings.setProviderConfig(
        'ocr-provider',
        ProviderConfig(
          id: 'ocr-provider',
          enabled: true,
          name: 'OCR',
          apiKey: 'key',
          baseUrl: 'https://example.test',
          models: const ['ocr-model'],
          modelOverrides: const {
            'ocr-model': {
              'input': ['text', 'image'],
            },
          },
        ),
      );
      await settings.setOcrModel('ocr-provider', 'ocr-model');
      await settings.setOcrEnabled(true);

      await service.processUserMessagesForApi(
        apiMessages,
        settings,
        const Assistant(id: 'a1', name: 'test'),
        sourceMessages: [realUser],
      );

      final media =
          apiMessages.single[MessageBuilderService.internalMediaPathsKey]
              as List;
      // OCR active: image paths filtered out, audio kept as structured ref.
      expect(media, [
        encodeInternalMediaRef(uri: '/tmp/clip.mp3', mime: 'audio/mpeg'),
      ]);
      expect(apiMessages.single['content'], isNot(contains('[image:')));
    });

    test(
      'octet-stream mp4 FilePart stays video/mp4 in processUserMessagesForApi',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;

        final service = MessageBuilderService(
          chatService: _FakeChatService({}),
          contextProvider: _FakeBuildContext(),
        );

        final realUser = ChatMessage(
          id: 'u-video',
          role: 'user',
          conversationId: 'c1',
          parts: const [
            TextPart('clip please'),
            FilePart(
              uri: '/tmp/clip.mp4',
              name: 'clip.mp4',
              mime: 'application/octet-stream',
            ),
          ],
        );
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': realUser.content,
            MessageBuilderService.internalRevisionIdKey: realUser.id,
            // Seed with raw/stale mime so the rebuild path must re-resolve.
            MessageBuilderService.internalMediaPathsKey: [
              encodeInternalMediaRef(
                uri: '/tmp/clip.mp4',
                mime: 'application/octet-stream',
              ),
            ],
          },
        ];

        await service.processUserMessagesForApi(
          apiMessages,
          settings,
          const Assistant(id: 'a1', name: 'test'),
          sourceMessages: [realUser],
        );

        final media =
            apiMessages.single[MessageBuilderService.internalMediaPathsKey]
                as List;
        expect(media, [
          encodeInternalMediaRef(uri: '/tmp/clip.mp4', mime: 'video/mp4'),
        ]);
      },
    );
  });
}
