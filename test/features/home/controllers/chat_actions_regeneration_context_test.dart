import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';

ChatMessage _message({
  required String id,
  required String role,
  required String groupId,
  required int version,
  String? providerId,
  String? modelId,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: '$role-$id',
    conversationId: 'conversation-1',
    groupId: groupId,
    version: version,
    providerId: providerId,
    modelId: modelId,
  );
}

void main() {
  test('unlimited context reads the complete persisted conversation', () {
    expect(
      ChatActions.contextReadLimit(
        assistant: const Assistant(
          id: 'assistant-1',
          name: 'Unlimited',
          limitContextMessages: false,
        ),
        persistedMessageCount: 1507,
      ),
      1507,
    );
    expect(
      ChatActions.contextReadLimit(
        assistant: const Assistant(
          id: 'assistant-1',
          name: 'Limited',
          contextMessageSize: 64,
        ),
        persistedMessageCount: 1507,
      ),
      64,
    );
    expect(
      ChatActions.contextReadLimit(
        assistant: const Assistant(
          id: 'assistant-1',
          name: 'Unlimited with missing count',
          limitContextMessages: false,
        ),
        persistedMessageCount: 0,
      ),
      Assistant.maxContextMessageSize,
    );
  });

  test('only temporary regeneration physically removes trailing messages', () {
    expect(
      ChatActions.shouldPhysicallyRemoveRegenerationTail(
        deleteTrailingEnabled: false,
        isTemporaryConversation: false,
      ),
      isFalse,
    );
    expect(
      ChatActions.shouldPhysicallyRemoveRegenerationTail(
        deleteTrailingEnabled: true,
        isTemporaryConversation: false,
      ),
      isFalse,
    );
    expect(
      ChatActions.shouldPhysicallyRemoveRegenerationTail(
        deleteTrailingEnabled: true,
        isTemporaryConversation: true,
      ),
      isTrue,
    );
  });

  group('ChatActions.resolveRegenerationModelTarget', () {
    test('assistant retry keeps the model shown on that reply', () {
      final target = ChatActions.resolveRegenerationModelTarget(
        message: _message(
          id: 'grok-answer',
          role: 'assistant',
          groupId: 'answer',
          version: 2,
          providerId: 'axonhub-gpt',
          modelId: 'grok-4.5',
        ),
        fallbackProviderKey: 'google',
        fallbackModelId: 'gemini-3.5-flash',
      );

      expect(target.providerKey, 'axonhub-gpt');
      expect(target.modelId, 'grok-4.5');
    });

    test('complete reply metadata works without a current model fallback', () {
      final target = ChatActions.resolveRegenerationModelTarget(
        message: _message(
          id: 'grok-answer',
          role: 'assistant',
          groupId: 'answer',
          version: 2,
          providerId: 'axonhub-gpt',
          modelId: 'grok-4.5',
        ),
        fallbackProviderKey: null,
        fallbackModelId: null,
      );

      expect(target.providerKey, 'axonhub-gpt');
      expect(target.modelId, 'grok-4.5');
    });

    test('messages without a complete target use the current model pair', () {
      final target = ChatActions.resolveRegenerationModelTarget(
        message: _message(
          id: 'legacy-answer',
          role: 'assistant',
          groupId: 'answer',
          version: 0,
          providerId: 'legacy-provider',
        ),
        fallbackProviderKey: 'openai',
        fallbackModelId: 'gpt-5.6',
      );

      expect(target.providerKey, 'openai');
      expect(target.modelId, 'gpt-5.6');
    });
  });

  group('ChatActions.buildRegenerationMessages', () {
    test('长会话窗口重试会保留目标消息之前的完整历史前缀', () {
      final messages = <ChatMessage>[
        for (var i = 0; i < 90; i++)
          _message(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            groupId: 'm$i',
            version: 0,
          ),
      ];
      final placeholder = _message(
        id: 'm85-v1',
        role: 'assistant',
        groupId: 'm85',
        version: 1,
      ).copyWith(content: '', isStreaming: true);

      final result = ChatActions.buildRegenerationMessages(
        messages: messages,
        lastKeep: 85,
        targetGroupId: 'm85',
        assistantPlaceholder: placeholder,
      );

      expect(result.first.id, 'm0');
      expect(result.map((message) => message.id), contains('m10'));
      expect(result.map((message) => message.id), contains('m84'));
      expect(result.last.id, 'm85-v1');
      expect(result, hasLength(87));
    });

    test('重试 assistant 时不会把后续分组带入上下文', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', groupId: 'u1', version: 0),
        _message(id: 'a1-v0', role: 'assistant', groupId: 'a1', version: 0),
        _message(id: 'u2', role: 'user', groupId: 'u2', version: 0),
        _message(id: 'a2-v0', role: 'assistant', groupId: 'a2', version: 0),
        _message(id: 'a1-v1', role: 'assistant', groupId: 'a1', version: 1),
      ];
      final placeholder = _message(
        id: 'a1-v2',
        role: 'assistant',
        groupId: 'a1',
        version: 2,
      ).copyWith(content: '', isStreaming: true);

      final result = ChatActions.buildRegenerationMessages(
        messages: messages,
        lastKeep: 1,
        targetGroupId: 'a1',
        assistantPlaceholder: placeholder,
      );

      expect(result.map((message) => message.id).toList(), [
        'u1',
        'a1-v0',
        'a1-v1',
        'a1-v2',
      ]);
    });

    test('重试 user 时只保留该用户消息之前的上下文并追加新的回复占位', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', groupId: 'u1', version: 0),
        _message(id: 'a1-v0', role: 'assistant', groupId: 'a1', version: 0),
        _message(id: 'u2', role: 'user', groupId: 'u2', version: 0),
        _message(id: 'a2-v0', role: 'assistant', groupId: 'a2', version: 0),
        _message(id: 'u3', role: 'user', groupId: 'u3', version: 0),
        _message(id: 'a3-v0', role: 'assistant', groupId: 'a3', version: 0),
      ];
      final placeholder = _message(
        id: 'a2-v1',
        role: 'assistant',
        groupId: 'a2',
        version: 1,
      ).copyWith(content: '', isStreaming: true);

      final result = ChatActions.buildRegenerationMessages(
        messages: messages,
        lastKeep: 3,
        targetGroupId: 'a2',
        assistantPlaceholder: placeholder,
      );

      expect(result.map((message) => message.id).toList(), [
        'u1',
        'a1-v0',
        'u2',
        'a2-v0',
        'a2-v1',
      ]);
    });
  });

  group('ChatActions.conversationForMessageContext', () {
    test('投影历史短于持久化截断点时不截空重试上下文', () {
      final messages = <ChatMessage>[
        for (var i = 0; i < 20; i++)
          _message(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            groupId: 'm$i',
            version: 0,
          ),
      ];

      final conversation = ChatActions.conversationForMessageContext(
        conversation: Conversation(
          id: 'conversation-1',
          title: 'Long chat',
          truncateIndex: 50,
        ),
        messages: messages,
      );

      expect(conversation.truncateIndex, -1);
    });

    test('重试目标之前的上下文不使用未来截断点', () {
      final messages = <ChatMessage>[
        for (var i = 0; i < 60; i++)
          _message(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            groupId: 'm$i',
            version: 0,
          ),
      ];

      final conversation = ChatActions.conversationForMessageContext(
        conversation: Conversation(
          id: 'conversation-1',
          title: 'Long chat',
          truncateIndex: 50,
        ),
        messages: messages,
        maxRawTruncateIndex: 40,
      );

      expect(conversation.truncateIndex, -1);
    });

    test('完整历史上下文保留持久化截断点', () {
      final messages = <ChatMessage>[
        for (var i = 0; i < 80; i++)
          _message(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            groupId: 'm$i',
            version: 0,
          ),
      ];

      final conversation = ChatActions.conversationForMessageContext(
        conversation: Conversation(
          id: 'conversation-1',
          title: 'Long chat',
          truncateIndex: 50,
        ),
        messages: messages,
      );

      expect(conversation.truncateIndex, 50);
    });
  });
}
