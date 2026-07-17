import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/models/assistant.dart';
import 'package:Cuplivo/core/models/chat_message.dart';
import 'package:Cuplivo/core/models/conversation.dart';
import 'package:Cuplivo/core/services/chat/chat_service.dart';
import 'package:Cuplivo/features/home/services/message_builder_service.dart';

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

ChatMessage _message({
  required String id,
  required String role,
  required String content,
  String? reasoningText,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    conversationId: 'conversation-1',
    reasoningText: reasoningText,
  );
}

void main() {
  group('MessageBuilderService.parseInputFromRaw', () {
    test('adds video and audio paths to imagePaths by default', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromRaw(
        'media\n'
        '[file:C:/tmp/clip.mp4|clip.mp4|video/mp4]\n'
        '[file:C:/tmp/audio.wav|audio.wav|audio/wav]',
      );

      expect(input.text, 'media');
      expect(input.imagePaths, ['C:/tmp/clip.mp4', 'C:/tmp/audio.wav']);
      expect(input.documents.map((document) => document.fileName), [
        'clip.mp4',
        'audio.wav',
      ]);
    });

    test('excludes video and audio from imagePaths when flag is false', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromRaw(
        'media\n'
        '[image:C:/tmp/photo.png]\n'
        '[file:C:/tmp/clip.mp4|clip.mp4|video/mp4]\n'
        '[file:C:/tmp/audio.wav|audio.wav|audio/wav]',
        includeMediaFilePathsAsImages: false,
      );

      expect(input.text, 'media');
      expect(input.imagePaths, ['C:/tmp/photo.png']);
      expect(input.documents.map((document) => document.fileName), [
        'clip.mp4',
        'audio.wav',
      ]);
    });

    test(
      'office documents never leak into imagePaths (bugfix: docx sent as png)',
      () {
        final service = MessageBuilderService(
          chatService: _FakeChatService(const {}),
          contextProvider: _FakeBuildContext(),
        );

        final input = service.parseInputFromRaw(
          'text\n'
          '[file:C:/tmp/report.docx|report.docx|application/vnd.openxmlformats-officedocument.wordprocessingml.document]\n'
          '[file:C:/tmp/slides.pptx|slides.pptx|application/vnd.openxmlformats-officedocument.presentationml.presentation]\n'
          '[file:C:/tmp/data.xlsx|data.xlsx|application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]\n'
          '[file:C:/tmp/doc.pdf|doc.pdf|application/pdf]',
        );

        expect(input.text, 'text');
        expect(input.imagePaths, isEmpty);
        expect(input.documents.map((d) => d.fileName), [
          'report.docx',
          'slides.pptx',
          'data.xlsx',
          'doc.pdf',
        ]);
      },
    );

    test('mixed: images in imagePaths, office docs in documents only', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromRaw(
        'look at these\n'
        '[image:C:/tmp/photo.jpg]\n'
        '[image:C:/tmp/screenshot.png]\n'
        '[file:C:/tmp/report.docx|report.docx|application/vnd.openxmlformats-officedocument.wordprocessingml.document]\n'
        '[file:C:/tmp/doc.pdf|doc.pdf|application/pdf]',
      );

      expect(input.text, 'look at these');
      expect(input.imagePaths, ['C:/tmp/photo.jpg', 'C:/tmp/screenshot.png']);
      expect(input.documents.map((d) => d.fileName), [
        'report.docx',
        'doc.pdf',
      ]);
    });

    test('mixed with video: video in imagePaths, office docs excluded', () {
      final service = MessageBuilderService(
        chatService: _FakeChatService(const {}),
        contextProvider: _FakeBuildContext(),
      );

      final input = service.parseInputFromRaw(
        'media\n'
        '[image:C:/tmp/photo.png]\n'
        '[file:C:/tmp/clip.mp4|clip.mp4|video/mp4]\n'
        '[file:C:/tmp/report.docx|report.docx|application/vnd.openxmlformats-officedocument.wordprocessingml.document]',
      );

      expect(input.text, 'media');
      expect(input.imagePaths, ['C:/tmp/photo.png', 'C:/tmp/clip.mp4']);
      expect(input.documents.map((d) => d.fileName), [
        'clip.mp4',
        'report.docx',
      ]);
    });
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
        Assistant(id: 'assistant-1', name: 'test', contextMessageSize: 3),
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
        Assistant(id: 'assistant-1', name: 'test', contextMessageSize: 4),
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
}
