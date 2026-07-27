import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/controllers/home_view_model.dart';

ChatMessage _message({
  required String id,
  required String role,
  required String content,
  String? groupId,
  int version = 0,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    conversationId: 'conversation-1',
    groupId: groupId ?? id,
    version: version,
  );
}

void main() {
  group('buildCompressContextContent', () {
    test('短内容在限制内保持原样', () {
      const joined = 'User: hello\n\nAssistant: hi';

      expect(
        buildCompressContextContent(
          joined,
          const CompressContextOptions(
            mode: CompressContextLimitMode.start,
            maxChars: 6000,
          ),
        ),
        joined,
      );
    });

    test('超长内容可保留开头', () {
      final early = 'User: first round\n\nAssistant: early answer\n\n';
      final middle = 'x' * 6000;
      final latest = '\n\nUser: thirtieth round\n\nAssistant: latest answer';
      final joined = '$early$middle$latest';

      final content = buildCompressContextContent(
        joined,
        const CompressContextOptions(
          mode: CompressContextLimitMode.start,
          maxChars: 6000,
        ),
      );

      expect(content.length, 6000);
      expect(content, contains('first round'));
      expect(content, isNot(contains('thirtieth round')));
    });

    test('超长内容可保留最近尾部', () {
      final early = 'User: first round\n\nAssistant: early answer\n\n';
      final middle = 'x' * 6000;
      final latest = '\n\nUser: thirtieth round\n\nAssistant: latest answer';
      final joined = '$early$middle$latest';

      final content = buildCompressContextContent(
        joined,
        const CompressContextOptions(
          mode: CompressContextLimitMode.recent,
          maxChars: 6000,
        ),
      );

      expect(content.length, 6000);
      expect(content, isNot(contains('first round')));
      expect(content, contains('thirtieth round'));
    });

    test('无限制保留完整内容', () {
      final joined = 'a' * 7000;

      final content = buildCompressContextContent(
        joined,
        const CompressContextOptions(mode: CompressContextLimitMode.unlimited),
      );

      expect(content, joined);
    });
  });

  group('buildConversationTextForCompression', () {
    test('使用完整历史生成压缩文本', () {
      final visibleWindow = [
        _message(id: 'u80', role: 'user', content: 'visible user'),
        _message(id: 'a81', role: 'assistant', content: 'visible assistant'),
      ];
      final completeHistory = [
        _message(id: 'u0', role: 'user', content: 'earliest user'),
        _message(id: 'a1', role: 'assistant', content: 'earliest assistant'),
        ...visibleWindow,
      ];

      final text = buildConversationTextForCompression(completeHistory);

      expect(text, contains('User: earliest user'));
      expect(text, contains('Assistant: earliest assistant'));
      expect(text, contains('User: visible user'));
      expect(text, contains('Assistant: visible assistant'));
    });

    test('压缩文本会忽略空内容消息', () {
      final text = buildConversationTextForCompression([
        _message(id: 'u1', role: 'user', content: '  '),
        _message(id: 'a1', role: 'assistant', content: 'answer'),
      ]);

      expect(text, 'Assistant: answer');
    });
  });

  group('HomeViewModel.computeClearContextRemainingMessageCount', () {
    test('计数来自持久化总数，与窗口缓存无关', () {
      final count = HomeViewModel.computeClearContextRemainingMessageCount(
        totalMessages: 100,
        truncateIndex: -1,
      );

      expect(count, 100);
    });

    test('已有清空点时从持久化截断位置开始计数', () {
      final count = HomeViewModel.computeClearContextRemainingMessageCount(
        totalMessages: 100,
        truncateIndex: 90,
      );

      expect(count, 10);
    });

    test('截断位置越界时按未清空处理', () {
      final beyond = HomeViewModel.computeClearContextRemainingMessageCount(
        totalMessages: 100,
        truncateIndex: 101,
      );
      final atEnd = HomeViewModel.computeClearContextRemainingMessageCount(
        totalMessages: 100,
        truncateIndex: 100,
      );

      expect(beyond, 100);
      expect(atEnd, 0);
    });
  });
}
