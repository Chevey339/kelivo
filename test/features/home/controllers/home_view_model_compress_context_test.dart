import 'package:Kelivo/l10n/app_localizations_en.dart';

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

      final text = buildConversationTextForCompression(
        completeHistory,
        quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
      );

      expect(text, contains('User: earliest user'));
      expect(text, contains('Assistant: earliest assistant'));
      expect(text, contains('User: visible user'));
      expect(text, contains('Assistant: visible assistant'));
    });

    test('压缩文本会忽略空内容消息', () {
      final text = buildConversationTextForCompression([
        _message(id: 'u1', role: 'user', content: '  '),
        _message(id: 'a1', role: 'assistant', content: 'answer'),
      ], quoteMarker: AppLocalizationsEn().selectionQuoteMarker);

      expect(text, '[source message:a1; role=assistant]\nAssistant: answer');
    });
  });

  group('selectKeepRecentMessages', () {
    test('保留最近 N 条用户消息及其后的全部消息，边界以用户消息开始', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: 'a1'),
        _message(id: 'u2', role: 'user', content: 'q2'),
        _message(id: 'a2', role: 'assistant', content: 'a2'),
        _message(id: 'u3', role: 'user', content: 'q3'),
        _message(id: 'a3', role: 'assistant', content: 'a3'),
      ];

      final kept = selectKeepRecentMessages(messages, 2);

      expect(kept.map((m) => m.id).toList(), ['u2', 'a2', 'u3', 'a3']);
    });

    test('保留区可包含未答复的尾部用户消息', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: 'a1'),
        _message(id: 'u2', role: 'user', content: 'q2'),
      ];

      final kept = selectKeepRecentMessages(messages, 1);

      expect(kept.map((m) => m.id).toList(), ['u2']);
    });

    test('N 覆盖全部用户消息时返回完整列表（无可压缩内容）', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: 'a1'),
        _message(id: 'u2', role: 'user', content: 'q2'),
      ];

      final kept = selectKeepRecentMessages(messages, 3);

      expect(kept.length, messages.length);
    });

    test('空内容的用户消息不参与计数', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: 'a1'),
        _message(id: 'u2', role: 'user', content: '   '),
        _message(id: 'u3', role: 'user', content: 'q3'),
        _message(id: 'a3', role: 'assistant', content: 'a3'),
      ];

      final kept = selectKeepRecentMessages(messages, 1);

      expect(kept.map((m) => m.id).toList(), ['u3', 'a3']);
    });

    test('保留区内的空内容助手消息（纯工具调用）严格保留为空气泡', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: ''),
        _message(id: 'u2', role: 'user', content: 'q2'),
        _message(id: 'a2', role: 'assistant', content: ''),
      ];

      final kept = selectKeepRecentMessages(messages, 1);

      expect(kept.map((m) => m.id).toList(), ['u2', 'a2']);
    });

    test('空输入 / 无 user / N ≤ 0 返回空', () {
      expect(
        selectKeepRecentMessages([
          _message(id: 'a1', role: 'assistant', content: 'a1'),
        ], 1),
        isEmpty,
      );
      expect(selectKeepRecentMessages(const [], 1), isEmpty);

      final messages = [
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: 'a1'),
      ];
      expect(selectKeepRecentMessages(messages, 0), isEmpty);
      expect(selectKeepRecentMessages(messages, -1), isEmpty);
    });
  });

  group('countUserMessages', () {
    test('只统计内容非空的用户消息', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', content: 'q1'),
        _message(id: 'a1', role: 'assistant', content: 'a1'),
        _message(id: 'u2', role: 'user', content: '   '),
        _message(id: 'u3', role: 'user', content: 'q3'),
      ];

      expect(countUserMessages(messages), 2);
    });
  });

  test('first use retains six user messages', () {
    expect(CompressContextOptions.defaultKeepUserMessages, 6);
  });

  group('estimateCompressionTokens', () {
    test('保留区按长度占比折算 token', () {
      final est = estimateCompressionTokens(
        totalText: 'a' * 1000,
        keptText: 'b' * 250,
      );

      // tokenx: 1000 lowercase letters → ceil(1000/7) = 143
      expect(est.totalTokens, 143);
      expect(est.keptTokens, 36);
      expect(est.minResultTokens, 47);
      expect(est.maxResultTokens, 68);
    });

    test('CJK 走 tokenx 汉字权重', () {
      final est = estimateCompressionTokens(
        totalText: '中' * 400,
        keptText: '中' * 100,
      );

      expect(est.totalTokens, 348);
      expect(est.keptTokens, 87);
    });

    test('混合文本走 tokenx（整段命中 CJK 则按汉字计价）', () {
      final est = estimateCompressionTokens(
        totalText: '中' * 200 + 'a' * 400,
        keptText: '',
      );

      expect(est.totalTokens, 522);
    });

    test('空文本返回全零', () {
      final est = estimateCompressionTokens(totalText: '', keptText: '');

      expect(est.totalTokens, 0);
      expect(est.keptTokens, 0);
      expect(est.minResultTokens, 0);
      expect(est.maxResultTokens, 0);
    });

    test('区间上界不低于下界', () {
      final est = estimateCompressionTokens(
        totalText: 'a' * 5000,
        keptText: 'b' * 100,
      );

      expect(est.minResultTokens, lessThanOrEqualTo(est.maxResultTokens));
      expect(est.keptTokens, lessThanOrEqualTo(est.totalTokens));
    });
  });

  group('resolveCompressContextModel', () {
    test('uses explicit model as a pair', () {
      expect(
        resolveCompressContextModel(
          compressProvider: 'summary',
          compressModelId: 'sum',
          currentProvider: 'chat',
          currentModelId: 'model',
        ),
        (providerKey: 'summary', modelId: 'sum'),
      );
    });
    test('incomplete explicit pair cannot mix providers', () {
      expect(
        resolveCompressContextModel(
          compressProvider: 'broken',
          currentProvider: 'chat',
          currentModelId: 'model',
        ),
        (providerKey: 'chat', modelId: 'model'),
      );
    });
    test('current chat model is the only fallback', () {
      expect(
        resolveCompressContextModel(
          currentProvider: 'chat',
          currentModelId: 'model',
        ),
        (providerKey: 'chat', modelId: 'model'),
      );
      expect(resolveCompressContextModel(), (providerKey: null, modelId: null));
    });
  });

  group('isContextLengthError', () {
    test('matches likely input-token overflow phrases', () {
      const overflowing = <String>[
        'HTTP 400: context_length_exceeded',
        "This model's maximum context length is 8192 tokens",
        'The request exceeds the context window',
        'max context size exceeded',
        'too many tokens in the prompt',
        'prompt is too long: 40000 tokens > 32000 maximum',
        'prompt too long',
        'input is too long',
        'input too long for this model',
        'Please reduce the length of the messages',
        'Please reduce the length of the prompt',
        'The input token count exceeds the maximum number of tokens allowed',
      ];
      for (final message in overflowing) {
        expect(
          isContextLengthError(Exception(message)),
          isTrue,
          reason: message,
        );
      }
    });

    test('does not match unrelated or max_tokens config errors', () {
      const unrelated = <String>[
        '401 unauthorized',
        'rate limit exceeded',
        'empty_summary',
        'max_tokens is required',
        'HttpException: max_tokens exceeded for this request',
        'max_tokens must be at least 1',
        'invalid api key',
        'network timeout',
      ];
      for (final message in unrelated) {
        expect(
          isContextLengthError(Exception(message)),
          isFalse,
          reason: message,
        );
      }
    });
  });
}
