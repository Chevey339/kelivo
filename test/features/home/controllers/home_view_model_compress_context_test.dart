import 'dart:convert';

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

    test('keepRecent 直通原文，不按字符窗截断', () {
      final joined = 'a' * 7000;

      final content = buildCompressContextContent(
        joined,
        const CompressContextOptions(
          mode: CompressContextLimitMode.keepRecent,
          keepUserMessages: 2,
        ),
      );

      expect(content, joined);
    });

    test('截断不劈开 emoji 代理对', () {
      // '😀' occupies two UTF-16 code units. A raw cut at 4 would tear it.
      const joined = 'abc😀def';

      final start = buildCompressContextContent(
        joined,
        const CompressContextOptions(
          mode: CompressContextLimitMode.start,
          maxChars: 4,
        ),
      );
      expect(start, 'abc');
      expect(() => jsonEncode(start), returnsNormally);

      final recent = buildCompressContextContent(
        joined,
        const CompressContextOptions(
          mode: CompressContextLimitMode.recent,
          maxChars: 4,
        ),
      );
      expect(recent, 'def');
      expect(() => jsonEncode(recent), returnsNormally);
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

  group('defaultKeepUserMessageCountFor', () {
    test('少于 5 条用户消息时默认 1', () {
      expect(defaultKeepUserMessageCountFor(0), 1);
      expect(defaultKeepUserMessageCountFor(1), 1);
      expect(defaultKeepUserMessageCountFor(2), 1);
      expect(defaultKeepUserMessageCountFor(4), 1);
    });

    test('5-9 条用户消息时默认 2', () {
      expect(defaultKeepUserMessageCountFor(5), 2);
      expect(defaultKeepUserMessageCountFor(9), 2);
    });

    test('10 条及以上用户消息时默认 3', () {
      expect(defaultKeepUserMessageCountFor(10), 3);
      expect(defaultKeepUserMessageCountFor(100), 3);
    });
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

  group('buildBoundedConversationText', () {
    test('start 与先拼接再截断在常规长度上语义一致', () {
      final messages = [
        _message(id: 'u1', role: 'user', content: 'first round'),
        _message(id: 'a1', role: 'assistant', content: 'early answer'),
        _message(id: 'u2', role: 'user', content: 'x' * 7000),
        _message(id: 'a2', role: 'assistant', content: 'thirtieth round'),
      ];
      const options = CompressContextOptions(
        mode: CompressContextLimitMode.start,
        maxChars: 6000,
      );
      final joined = buildConversationTextForCompression(messages);

      expect(
        buildBoundedConversationText(
          messages,
          mode: CompressContextLimitMode.start,
          maxChars: 6000,
        ),
        buildCompressContextContent(joined, options),
      );
    });

    test('recent 与先拼接再截断在常规长度上语义一致', () {
      final messages = [
        _message(id: 'u1', role: 'user', content: 'first round'),
        _message(id: 'a1', role: 'assistant', content: 'early answer'),
        _message(id: 'u2', role: 'user', content: 'x' * 7000),
        _message(id: 'a2', role: 'assistant', content: 'thirtieth round'),
      ];
      const options = CompressContextOptions(
        mode: CompressContextLimitMode.recent,
        maxChars: 6000,
      );
      final joined = buildConversationTextForCompression(messages);

      expect(
        buildBoundedConversationText(
          messages,
          mode: CompressContextLimitMode.recent,
          maxChars: 6000,
        ),
        buildCompressContextContent(joined, options),
      );
    });

    test('超长历史增量截断且不超过窗口，无需先拼接全文', () {
      final messages = [
        for (var i = 0; i < 200; i++)
          _message(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            content: 'block-$i ${'x' * 500}',
          ),
      ];

      final start = buildBoundedConversationText(
        messages,
        mode: CompressContextLimitMode.start,
        maxChars: 6000,
      );
      expect(start.length, lessThanOrEqualTo(6000));
      expect(start, contains('block-0'));
      expect(start, isNot(contains('block-199')));

      final recent = buildBoundedConversationText(
        messages,
        mode: CompressContextLimitMode.recent,
        maxChars: 6000,
      );
      expect(recent.length, lessThanOrEqualTo(6000));
      expect(recent, contains('block-199'));
      expect(recent, isNot(contains('block-0')));
    });
  });

  group('chunkMessagesForCompression', () {
    test('超过预算的多条消息按消息边界拆成多块', () {
      final messages = [
        _message(id: 'u1', role: 'user', content: 'aaa'),
        _message(id: 'a1', role: 'assistant', content: 'bbb'),
        _message(id: 'u2', role: 'user', content: 'ccc'),
      ];

      final chunks = chunkMessagesForCompression(messages, maxChars: 20);

      expect(chunks, hasLength(greaterThan(1)));
      expect(chunks.every((chunk) => chunk.length <= 20), isTrue);
      expect(chunks.join('\n\n'), contains('User: aaa'));
      expect(chunks.join('\n\n'), contains('User: ccc'));
    });

    test('单条超长消息按 UTF-16 安全切分且不劈开 emoji', () {
      const emoji = '😀';
      final messages = [
        _message(id: 'u1', role: 'user', content: 'aa$emoji${'b' * 30}'),
      ];
      final line = conversationLineForCompression(messages.single)!;

      final chunks = chunkMessagesForCompression(messages, maxChars: 9);

      expect(chunks, hasLength(greaterThan(1)));
      expect(chunks.join(), line);
      expect(chunks.join(), contains(emoji));
      for (final chunk in chunks) {
        expect(() => jsonEncode(chunk), returnsNormally);
      }
    });
  });

  group('buildCompressRequestContents', () {
    test('unlimited 超过安全上限时按消息边界分块且不丢内容', () {
      final messages = [
        for (var i = 0; i < 5; i++)
          _message(id: 'u$i', role: 'user', content: 'msg-$i ${'x' * 40}'),
      ];

      final chunks = buildCompressRequestContents(
        messages,
        const CompressContextOptions(mode: CompressContextLimitMode.unlimited),
        safeRequestChars: 50,
      );

      expect(chunks, hasLength(greaterThan(1)));
      expect(chunks.every((chunk) => chunk.length <= 50), isTrue);
      expect(chunks.join('\n\n'), contains('msg-0'));
      expect(chunks.join('\n\n'), contains('msg-4'));
    });

    test('keepRecent 旧侧同样受安全上限约束', () {
      final messages = [
        for (var i = 0; i < 4; i++)
          _message(id: 'u$i', role: 'user', content: 'old-$i ${'y' * 40}'),
      ];

      final chunks = buildCompressRequestContents(
        messages,
        const CompressContextOptions(
          mode: CompressContextLimitMode.keepRecent,
          keepUserMessages: 1,
        ),
        safeRequestChars: 50,
      );

      expect(chunks, hasLength(greaterThan(1)));
      expect(chunks.join('\n\n'), contains('old-0'));
    });
  });

  group('compressRequestCharBudget', () {
    test('unknown context uses the conservative 32k default', () {
      expect(compressRequestCharBudget(), 35840);
      expect(compressRequestCharBudget(contextWindowTokens: 0), 35840);
      expect(compressRequestCharBudget(contextWindowTokens: -1), 35840);
    });

    test('32k window stays at window-minus-reserves', () {
      const window = 32000;
      final budget = compressRequestCharBudget(contextWindowTokens: window);
      final maxInputTokens =
          (window * (1 - CompressContextOptions.contextReserveFraction))
              .floor();

      expect(budget, 35840);
      expect(budget, lessThan(window * CompressContextOptions.charsPerToken));
      expect(
        (budget / CompressContextOptions.charsPerToken).ceil(),
        lessThanOrEqualTo(maxInputTokens),
      );
    });

    test('128k+ is larger than the 32k default but still hard-capped', () {
      final budget128k = compressRequestCharBudget(contextWindowTokens: 128000);
      final budget1m = compressRequestCharBudget(contextWindowTokens: 1000000);

      expect(budget128k, greaterThan(compressRequestCharBudget()));
      expect(budget128k, CompressContextOptions.safeRequestChars);
      expect(budget1m, CompressContextOptions.safeRequestChars);
      expect(
        budget128k,
        lessThanOrEqualTo(CompressContextOptions.safeRequestChars),
      );
    });
  });

  group('resolveCompressContextModel', () {
    test('优先使用显式压缩模型', () {
      final resolved = resolveCompressContextModel(
        compressProvider: 'OpenAI',
        compressModelId: 'gpt-4o-mini',
        summaryProvider: 'Gemini',
        summaryModelId: 'gemini-2.5-flash',
        currentProvider: 'DeepSeek',
        currentModelId: 'deepseek-chat',
      );

      expect(resolved.providerKey, 'OpenAI');
      expect(resolved.modelId, 'gpt-4o-mini');
    });

    test('未设置压缩模型时按 summary → title → assistant → current 回退', () {
      expect(
        resolveCompressContextModel(
          summaryProvider: 'Gemini',
          summaryModelId: 'gemini-2.5-flash',
          titleProvider: 'OpenAI',
          titleModelId: 'gpt-4o-mini',
          currentProvider: 'DeepSeek',
          currentModelId: 'deepseek-chat',
        ),
        (providerKey: 'Gemini', modelId: 'gemini-2.5-flash'),
      );
      expect(
        resolveCompressContextModel(
          titleProvider: 'OpenAI',
          titleModelId: 'gpt-4o-mini',
          assistantProvider: 'Claude',
          assistantModelId: 'claude-sonnet',
          currentProvider: 'DeepSeek',
          currentModelId: 'deepseek-chat',
        ),
        (providerKey: 'OpenAI', modelId: 'gpt-4o-mini'),
      );
      expect(
        resolveCompressContextModel(
          assistantProvider: 'Claude',
          assistantModelId: 'claude-sonnet',
          currentProvider: 'DeepSeek',
          currentModelId: 'deepseek-chat',
        ),
        (providerKey: 'Claude', modelId: 'claude-sonnet'),
      );
      expect(
        resolveCompressContextModel(
          currentProvider: 'DeepSeek',
          currentModelId: 'deepseek-chat',
        ),
        (providerKey: 'DeepSeek', modelId: 'deepseek-chat'),
      );
    });

    test('全部未设置时返回空', () {
      final resolved = resolveCompressContextModel();

      expect(resolved.providerKey, isNull);
      expect(resolved.modelId, isNull);
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
        'HttpException: max_tokens exceeded for this request',
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

  group('summarizeWithContextRetry', () {
    test('splits on a context error, retries each half, then merges', () async {
      final calls = <String>[];
      final result = await summarizeWithContextRetry(
        'A' * 32,
        minSplitChars: 4,
        summarize: (text) async {
          calls.add(text);
          if (text.contains('A') && text.length > 16) {
            throw Exception('maximum context length exceeded');
          }
          if (text.contains('S:')) return 'M';
          return 'S:${text.length}';
        },
      );

      expect(calls, ['A' * 32, 'A' * 16, 'A' * 16, 'S:16\n\nS:16']);
      expect(result, 'M');
    });

    test('UTF-16 halves stay valid when naive mid would tear a pair', () async {
      final text = 'x${'😀' * 20}';
      expect(text.length ~/ 2, 20);
      final naive = text.substring(0, text.length ~/ 2);
      final naiveLast = naive.codeUnitAt(naive.length - 1);
      expect(naiveLast >= 0xD800 && naiveLast <= 0xDBFF, isTrue);

      final seen = <String>[];
      final result = await summarizeWithContextRetry(
        text,
        minSplitChars: 4,
        summarize: (chunk) async {
          seen.add(chunk);
          _expectValidUtf16(chunk);
          if (chunk == text) {
            throw Exception('context_length_exceeded');
          }
          return 'ok';
        },
      );

      expect(seen.length, 4);
      expect(seen.first, text);
      expect('${seen[1]}${seen[2]}', text);
      expect(result, 'ok');
    });

    test('does not split-retry non-context errors', () async {
      var calls = 0;
      await expectLater(
        summarizeWithContextRetry(
          'A' * 32,
          minSplitChars: 4,
          summarize: (text) async {
            calls++;
            throw Exception('401 unauthorized');
          },
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains('401 unauthorized'),
          ),
        ),
      );
      expect(calls, 1);
    });

    test('stops after the split budget instead of looping', () async {
      var calls = 0;
      var splits = 0;
      await expectLater(
        summarizeWithContextRetry(
          'A' * 32,
          maxSplits: 2,
          minSplitChars: 4,
          onSplitRetry: (e, st, text) => splits++,
          summarize: (text) async {
            calls++;
            throw Exception('prompt is too long');
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(splits, 2);
      expect(calls, 3);
    });

    test('does not split when a half would be below minSplitChars', () async {
      var calls = 0;
      await expectLater(
        summarizeWithContextRetry(
          'A' * 20,
          minSplitChars: 16,
          summarize: (text) async {
            calls++;
            throw Exception('too many tokens');
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(calls, 1);
    });
  });
}

void _expectValidUtf16(String value) {
  for (var i = 0; i < value.length; i++) {
    final codeUnit = value.codeUnitAt(i);
    if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      expect(
        i + 1 < value.length &&
            value.codeUnitAt(i + 1) >= 0xDC00 &&
            value.codeUnitAt(i + 1) <= 0xDFFF,
        isTrue,
        reason: 'lone high surrogate at $i',
      );
      i++;
    } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
      fail('lone low surrogate at $i');
    }
  }
}
