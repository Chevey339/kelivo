import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';

class DebugConversationSeed {
  const DebugConversationSeed({
    required this.conversation,
    required this.messages,
    required this.totalContentBytes,
  });

  final Conversation conversation;
  final List<ChatMessage> messages;
  final int totalContentBytes;
}

class DebugConversationFactory {
  DebugConversationFactory._();

  static const int oversizedConversationBytes = 30 * 1024 * 1024;
  static const int manyMessagesCount = 1024;
  static const int dailyMixedMarkdownMessagesCount = 3000;
  static const int longReasoningMessagesCount = 128;

  static DebugConversationSeed createOversizedConversation({
    required String title,
    required String? assistantId,
    required String chunkText,
    int targetBytes = oversizedConversationBytes,
  }) {
    if (targetBytes <= 0) {
      throw ArgumentError.value(targetBytes, 'targetBytes');
    }
    if (chunkText.isEmpty) {
      throw ArgumentError.value(chunkText, 'chunkText');
    }

    final conversation = Conversation(title: title, assistantId: assistantId);
    final messages = <ChatMessage>[];
    var totalBytes = 0;
    var index = 0;
    const uuid = Uuid();

    while (totalBytes < targetBytes) {
      final role = index.isEven ? 'user' : 'assistant';
      final messageId = uuid.v4();
      final content = _buildOversizedContent(
        chunkText: chunkText,
        index: index,
        role: role,
      );
      totalBytes += utf8.encode(content).length;
      messages.add(
        ChatMessage(
          id: messageId,
          role: role,
          content: content,
          conversationId: conversation.id,
          groupId: messageId,
        ),
      );
      index++;
    }

    conversation.messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    conversation.updatedAt = DateTime.now();

    return DebugConversationSeed(
      conversation: conversation,
      messages: messages,
      totalContentBytes: totalBytes,
    );
  }

  static DebugConversationSeed createManyMessagesConversation({
    required String title,
    required String? assistantId,
    required String Function(int index, String role) contentBuilder,
    int messageCount = manyMessagesCount,
  }) {
    if (messageCount <= 0) {
      throw ArgumentError.value(messageCount, 'messageCount');
    }

    final conversation = Conversation(title: title, assistantId: assistantId);
    final messages = <ChatMessage>[];
    var totalBytes = 0;
    const uuid = Uuid();

    for (var index = 0; index < messageCount; index++) {
      final role = index.isEven ? 'user' : 'assistant';
      final messageId = uuid.v4();
      final content = contentBuilder(index, role);
      totalBytes += utf8.encode(content).length;
      messages.add(
        ChatMessage(
          id: messageId,
          role: role,
          content: content,
          conversationId: conversation.id,
          groupId: messageId,
        ),
      );
    }

    conversation.messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    conversation.updatedAt = DateTime.now();

    return DebugConversationSeed(
      conversation: conversation,
      messages: messages,
      totalContentBytes: totalBytes,
    );
  }

  static DebugConversationSeed createLongReasoningConversation({
    required String title,
    required String? assistantId,
    int messageCount = longReasoningMessagesCount,
  }) {
    if (messageCount <= 0) {
      throw ArgumentError.value(messageCount, 'messageCount');
    }

    final conversation = Conversation(title: title, assistantId: assistantId);
    final messages = <ChatMessage>[];
    var totalBytes = 0;
    const uuid = Uuid();
    final baseTime = DateTime.now();

    for (var index = 0; index < messageCount; index++) {
      final role = index.isEven ? 'user' : 'assistant';
      final messageId = uuid.v4();
      final timestamp = baseTime.add(Duration(seconds: index));
      final content = role == 'user'
          ? _buildReasoningUserContent(index)
          : _buildReasoningAssistantContent(index);
      final reasoningText = role == 'assistant'
          ? _buildReasoningText(index)
          : null;
      final reasoningStartAt = reasoningText == null
          ? null
          : timestamp.subtract(const Duration(seconds: 18));
      final reasoningFinishedAt = reasoningText == null
          ? null
          : timestamp.subtract(const Duration(seconds: 2));
      final reasoningSegmentsJson = reasoningText == null
          ? null
          : _buildReasoningSegmentsJson(
              reasoningText: reasoningText,
              startAt: reasoningStartAt!,
              finishedAt: reasoningFinishedAt!,
              expanded: index < messageCount - 16,
            );

      totalBytes += utf8.encode(content).length;
      if (reasoningText != null) {
        totalBytes += utf8.encode(reasoningText).length;
      }
      messages.add(
        ChatMessage(
          id: messageId,
          role: role,
          content: content,
          timestamp: timestamp,
          conversationId: conversation.id,
          groupId: messageId,
          reasoningText: reasoningText,
          reasoningStartAt: reasoningStartAt,
          reasoningFinishedAt: reasoningFinishedAt,
          reasoningSegmentsJson: reasoningSegmentsJson,
        ),
      );
    }

    conversation.messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    conversation.updatedAt = DateTime.now();

    return DebugConversationSeed(
      conversation: conversation,
      messages: messages,
      totalContentBytes: totalBytes,
    );
  }

  static DebugConversationSeed createDailyMixedMarkdownConversation({
    required String title,
    required String? assistantId,
    int messageCount = dailyMixedMarkdownMessagesCount,
  }) {
    if (messageCount <= 0) {
      throw ArgumentError.value(messageCount, 'messageCount');
    }

    return createManyMessagesConversation(
      title: title,
      assistantId: assistantId,
      messageCount: messageCount,
      contentBuilder: (index, role) => role == 'user'
          ? _buildDailyUserMarkdownContent(index)
          : _buildDailyAssistantMarkdownContent(index),
    );
  }

  static String _buildOversizedContent({
    required String chunkText,
    required int index,
    required String role,
  }) {
    final buffer = StringBuffer()
      ..writeln('debug-message-index: $index')
      ..writeln('debug-message-role: $role');
    for (var block = 0; block < 128; block++) {
      buffer
        ..write(chunkText)
        ..write(' index=')
        ..write(index)
        ..write(' block=')
        ..write(block)
        ..write('\n');
    }
    return buffer.toString();
  }

  static String _buildReasoningUserContent(int index) {
    final turn = (index ~/ 2) + 1;
    return [
      'Debug long reasoning prompt #$turn.',
      'Please answer with a visible final answer after extended thinking.',
      'Keep enough detail to exercise long conversation history replay.',
    ].join('\n');
  }

  static String _buildDailyUserMarkdownContent(int index) {
    final turn = (index ~/ 2) + 1;
    switch (turn % 6) {
      case 0:
        return [
          '第 $turn 轮：帮我整理今天的待办，优先处理工作和生活事项。',
          '',
          '- [ ] 回复产品评审意见',
          '- [ ] 晚上 8 点前确认旅行预算',
          '- [ ] 把会议纪要压缩成 3 个结论',
        ].join('\n');
      case 1:
        return [
          'Can you review this Markdown note from my daily work?',
          '',
          '## Context $turn',
          '',
          '| Item | Status | Owner |',
          '| --- | --- | --- |',
          '| API retry | blocked | me |',
          '| UI copy | ready | design |',
        ].join('\n');
      case 2:
        return [
          '请解释这段代码为什么偶尔会重复提交：',
          '',
          '```dart',
          'if (isSending) return;',
          'isSending = true;',
          'await submitMessage(input);',
          'isSending = false;',
          '```',
        ].join('\n');
      case 3:
        return [
          'Summarize this shopping comparison in Chinese:',
          '',
          '1. Keyboard: quiet switches, compact layout.',
          '2. Monitor light: needs USB-C power.',
          '3. SSD enclosure: check heat during long copies.',
          '',
          '> I want a practical answer, not a long review.',
        ].join('\n');
      case 4:
        return [
          '今天的健身记录：',
          '',
          '- 跑步 32 分钟',
          '- 深蹲 4 组',
          '- 睡眠只有 6 小时',
          '',
          '请给一个**不过度激进**的明日计划。',
        ].join('\n');
      default:
        return [
          'Draft a short reply for this message:',
          '',
          '```text',
          'Thanks for the update. Could we move the sync to Thursday?',
          'I need one more day to finish the migration checks.',
          '```',
        ].join('\n');
    }
  }

  static String _buildDailyAssistantMarkdownContent(int index) {
    final turn = (index ~/ 2) + 1;
    switch (turn % 6) {
      case 0:
        return [
          '可以，建议按影响面排序：',
          '',
          '1. 先处理会阻塞他人的产品评审意见。',
          '2. 旅行预算只需要定上限，避免展开成完整攻略。',
          '3. 会议纪要保留结论、负责人和截止时间。',
          '',
          '- [x] 给出优先级',
          '- [ ] 等你补充具体时间',
        ].join('\n');
      case 1:
        return [
          'Here is the cleaned version:',
          '',
          '## Daily Status',
          '',
          '| Area | Next step | Risk |',
          '| --- | --- | --- |',
          '| API retry | Confirm idempotency key | duplicate writes |',
          '| UI copy | Ship current draft | low |',
        ].join('\n');
      case 2:
        return [
          '问题通常出在异常路径：如果 `submitMessage` 抛错，`isSending` 不会恢复。',
          '',
          '```dart',
          'if (isSending) return;',
          'isSending = true;',
          'try {',
          '  await submitMessage(input);',
          '} finally {',
          '  isSending = false;',
          '}',
          '```',
        ].join('\n');
      case 3:
        return [
          '建议这样决策：',
          '',
          '- **键盘**：如果每天打字超过 4 小时，优先买。',
          '- **屏幕灯**：确认供电和桌面空间后再买。',
          '- **硬盘盒**：只有频繁大文件拷贝才值得升级。',
          '',
          '> 结论：先买键盘，其他两个延后。',
        ].join('\n');
      case 4:
        return [
          '明天计划应该保守一点：',
          '',
          '- 轻松跑 20 分钟或快走 35 分钟',
          '- 下肢力量减到 2 组',
          '- 目标睡眠 7.5 小时',
          '',
          '重点是恢复，不是继续加量。',
        ].join('\n');
      default:
        return [
          'You could reply:',
          '',
          '```text',
          'Thursday works for me. I will use the extra day to finish the',
          'migration checks and send a concise status before the sync.',
          '```',
          '',
          'This keeps the tone direct and accountable.',
        ].join('\n');
    }
  }

  static String _buildReasoningAssistantContent(int index) {
    final turn = (index ~/ 2) + 1;
    return [
      'Debug answer #$turn.',
      '',
      'Summary:',
      '- The requested scenario was analyzed against earlier turns.',
      '- The final answer stays short while the reasoning payload is stored separately.',
      '- This message intentionally keeps structured reasoning metadata.',
    ].join('\n');
  }

  static String _buildReasoningText(int index) {
    final turn = (index ~/ 2) + 1;
    final buffer = StringBuffer()
      ..writeln('Debug reasoning chain for assistant turn #$turn.')
      ..writeln('1. Inspect the recent user request and retained context.')
      ..writeln('2. Compare it with previous constraints and generated state.')
      ..writeln('3. Decide whether the final answer needs a concise response.');
    for (var step = 0; step < 12; step++) {
      buffer.writeln(
        'Reasoning detail $step for turn $turn: repeated diagnostic content '
        'keeps this block large enough to reproduce long-chat rendering and '
        'persistence behavior without calling a real provider.',
      );
    }
    return buffer.toString().trimRight();
  }

  static String _buildReasoningSegmentsJson({
    required String reasoningText,
    required DateTime startAt,
    required DateTime finishedAt,
    required bool expanded,
  }) {
    return jsonEncode({
      'v': 2,
      'segments': [
        {
          'text': reasoningText,
          'startAt': startAt.toIso8601String(),
          'finishedAt': finishedAt.toIso8601String(),
          'expanded': expanded,
          'toolStartIndex': 0,
        },
      ],
      'contentSplits': {
        'offsets': [0],
        'reasoningCounts': [1],
        'toolCounts': [0],
      },
    });
  }
}
