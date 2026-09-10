import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

import '../../../support/business_test_harness.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {
  _FakeChatService(this._toolEventsByMessageId);

  final Map<String, List<Map<String, dynamic>>> _toolEventsByMessageId;

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    return List<Map<String, dynamic>>.of(
      _toolEventsByMessageId[assistantMessageId] ?? const [],
    );
  }
}

ChatMessage _message({
  required String id,
  required String role,
  required String content,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    conversationId: 'conversation-1',
  );
}

MessageBuilderService _service({
  Map<String, List<Map<String, dynamic>>> toolEvents = const {},
}) {
  return MessageBuilderService(
    chatService: _FakeChatService(toolEvents),
    contextProvider: _FakeBuildContext(),
  );
}

bool _hasSegmentsKey(List<Map<String, dynamic>> messages) {
  return messages.any(
    (message) => message.containsKey(kelivoContextSegmentsKey),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ContextLogger.setEnabled(false);
  });

  tearDown(() async {
    await ContextLogger.setEnabled(false);
  });

  test('logger disabled still records provenance for in-memory inspection', () {
    final service = _service();
    final apiMessages = service.buildApiMessages(
      messages: [
        _message(id: 'u1', role: 'user', content: 'hello'),
        _message(id: 'a1', role: 'assistant', content: 'hi'),
      ],
      versionSelections: const {},
      currentConversation: Conversation(title: 'test'),
    );

    service.injectSearchPrompt(
      apiMessages,
      SettingsProvider(createBusinessTestPreferences()),
      const Assistant(id: 'a1', name: 'A', searchEnabled: true),
      false,
    );

    expect(_hasSegmentsKey(apiMessages), isTrue);
    service.stripInternalRevisionIds(apiMessages);
    expect(_hasSegmentsKey(apiMessages), isFalse);
  });

  test(
    'enabled buildApiMessages tags chatHistory, toolCall, and toolResult',
    () async {
      await ContextLogger.setEnabled(true);
      final service = _service(
        toolEvents: {
          'a1': [
            {
              'id': 'call_1',
              'name': 'get_weather',
              'arguments': {'location': 'Hangzhou'},
              'content': 'Cloudy 7~13°C',
            },
          ],
        },
      );

      final apiMessages = service.buildApiMessages(
        messages: [
          _message(id: 'u1', role: 'user', content: '杭州天气'),
          _message(id: 'a1', role: 'assistant', content: '明天多云。'),
        ],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
        includeToolMessages: true,
      );

      final user = apiMessages.firstWhere((m) => m['role'] == 'user');
      final toolCall = apiMessages.firstWhere(
        (m) => m['role'] == 'assistant' && m['tool_calls'] is List,
      );
      final toolResult = apiMessages.firstWhere((m) => m['role'] == 'tool');
      final finalAssistant = apiMessages.lastWhere(
        (m) => m['role'] == 'assistant' && m['tool_calls'] == null,
      );

      expect(
        ContextSegmentTags.read(user).single['source'],
        ContextSource.chatHistory.wireName,
      );
      expect(ContextSegmentTags.read(user).single['length'], '杭州天气'.length);

      expect(
        ContextSegmentTags.read(toolCall).single['source'],
        ContextSource.toolCall.wireName,
      );
      expect(ContextSegmentTags.read(toolCall).single['length'], '\n\n'.length);

      expect(
        ContextSegmentTags.read(toolResult).single['source'],
        ContextSource.toolResult.wireName,
      );
      expect(
        ContextSegmentTags.read(toolResult).single['length'],
        'Cloudy 7~13°C'.length,
      );

      expect(
        ContextSegmentTags.read(finalAssistant).single['source'],
        ContextSource.chatHistory.wireName,
      );
      expect(
        ContextSegmentTags.read(finalAssistant).single['length'],
        '明天多云。'.length,
      );
    },
  );

  test(
    'injectSearchPrompt appends a second segment and keeps \\n\\n',
    () async {
      await ContextLogger.setEnabled(true);
      final service = _service();
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'sys'},
      ];
      ContextSegmentTags.replaceWithSingle(
        apiMessages.first,
        source: ContextSource.systemPrompt,
        length: 3,
      );

      service.injectSearchPrompt(
        apiMessages,
        SettingsProvider(createBusinessTestPreferences()),
        const Assistant(id: 'a1', name: 'A', searchEnabled: true),
        false,
      );

      final content = apiMessages.first['content'] as String;
      final prompt = SearchToolService.getSystemPrompt();
      expect(content, 'sys\n\n$prompt');

      final tags = ContextSegmentTags.read(apiMessages.first);
      expect(tags, hasLength(2));
      expect(tags[0]['source'], ContextSource.systemPrompt.wireName);
      expect(tags[0]['length'], 3);
      expect(tags[1]['source'], ContextSource.searchPrompt.wireName);
      expect(tags[1]['length'], 2 + prompt.length);
    },
  );

  test('stripInternalRevisionIds removes the segments key', () async {
    await ContextLogger.setEnabled(true);
    final service = _service();
    final apiMessages = service.buildApiMessages(
      messages: [
        _message(id: 'u1', role: 'user', content: 'hello'),
        _message(id: 'a1', role: 'assistant', content: 'hi'),
      ],
      versionSelections: const {},
      currentConversation: Conversation(title: 'test'),
    );

    expect(apiMessages.first.containsKey(kelivoContextSegmentsKey), isTrue);
    expect(
      apiMessages.first[MessageBuilderService.internalRevisionIdKey],
      'u1',
    );

    service.stripInternalRevisionIds(apiMessages);

    expect(_hasSegmentsKey(apiMessages), isFalse);
    expect(
      apiMessages.any(
        (message) =>
            message.containsKey(MessageBuilderService.internalRevisionIdKey),
      ),
      isFalse,
    );
  });
}
