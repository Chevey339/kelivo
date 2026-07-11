import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/controllers/active_streaming_message_store.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  required String id,
  required String conversationId,
  bool isStreaming = true,
}) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    content: id,
    conversationId: conversationId,
    isStreaming: isStreaming,
  );
}

void main() {
  group('ActiveStreamingMessageStore', () {
    test('取消目标不依赖消息是否仍在加载窗口', () {
      final store = ActiveStreamingMessageStore();
      final active = _message(id: 'off-window', conversationId: 'chat');
      store.put(active);

      final target = store.cancellationTarget('chat', const []);

      expect(target?.id, 'off-window');
    });

    test('兼容回退只选择目标会话内最后一个 streaming assistant', () {
      final store = ActiveStreamingMessageStore();
      final target = store.cancellationTarget('chat', [
        _message(id: 'other', conversationId: 'other-chat'),
        _message(id: 'finished', conversationId: 'chat', isStreaming: false),
        _message(id: 'expected', conversationId: 'chat'),
      ]);

      expect(target?.id, 'expected');
    });

    test('旧终态不能移除同会话中已经替换的新 generation', () {
      final store = ActiveStreamingMessageStore();
      final old = _message(id: 'old', conversationId: 'chat');
      final replacement = _message(id: 'replacement', conversationId: 'chat');
      store
        ..put(old)
        ..put(replacement)
        ..removeIfMatches(old);

      expect(store['chat']?.id, 'replacement');
      store.removeIfMatches(replacement);
      expect(store['chat'], isNull);
    });

    test('取消移除 active 后旧 prepare 不能重新开始 generation', () {
      final store = ActiveStreamingMessageStore();
      final preparing = _message(id: 'preparing', conversationId: 'chat');
      store.put(preparing);
      expect(store.isActive(preparing), isTrue);

      store.removeIfMatches(preparing);

      expect(store.isActive(preparing), isFalse);
    });
  });
}
