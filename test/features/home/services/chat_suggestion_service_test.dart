import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/services/chat_suggestion_service.dart';

void main() {
  group('ChatSuggestionService.parseSuggestions', () {
    test('accepts structured output, trims, deduplicates and limits count', () {
      expect(
        ChatSuggestionService.parseSuggestions(
          jsonEncode({
            'suggestions': [
              '  举个具体例子  ',
              '举个具体例子',
              'Compare A and B',
              'compare a  and b',
              '如何验证这个结论？',
              '不展示第四条',
            ],
          }),
        ),
        ['举个具体例子', 'Compare A and B', '如何验证这个结论？'],
      );
    });

    test('accepts one JSON fence and removes inline model reasoning', () {
      expect(
        ChatSuggestionService.parseSuggestions(
          '<think>Consider useful follow-ups.</think>\n'
          '```json\n{"suggestions":["解释方案 A 的限制"]}\n```',
        ),
        ['解释方案 A 的限制'],
      );
    });

    test('preserves literal thinking tags inside JSON strings', () {
      final suggestions = [
        '解释 <think> 标签的作用',
        '解释 <thinking>内容</thinking> 的作用',
        '解释 <|channel>thought 内容 <channel|> 的作用',
      ];
      final json = jsonEncode({'suggestions': suggestions});
      for (final raw in [
        json,
        '```json\n$json\n```',
        '<think>Choose useful questions.</think>\n$json',
        '<THOUGHT>First pass.</THOUGHT>\n'
            '<think>Second pass.</think>\n```json\n$json\n```',
      ]) {
        expect(ChatSuggestionService.parseSuggestions(raw), suggestions);
      }
    });

    test(
      'does not accept JSON inside unfinished reasoning or trailing prose',
      () {
        for (final raw in [
          '<think>{"suggestions":["内部草稿"]}',
          '{"suggestions":["解释一下"]}<think>Trailing text</think>',
        ]) {
          expect(
            () => ChatSuggestionService.parseSuggestions(raw),
            throwsFormatException,
          );
        }
      },
    );

    test(
      'does not turn prose, malformed JSON or unexpected shapes into chips',
      () {
        for (final raw in [
          'Here are three suggestions:\n1. Example\n2. More',
          '解释一下',
          '["解释一下"]',
          '{"suggestions":"解释一下"}',
          '{"suggestions":["解释一下"],"explanation":"because"}',
          '{"suggestions":["解释一下"',
          'Some explanation\n{"suggestions":["解释一下"]}',
        ]) {
          expect(
            () => ChatSuggestionService.parseSuggestions(raw),
            throwsFormatException,
            reason: raw,
          );
        }
      },
    );

    test(
      'an empty array is valid and invalid individual items are dropped',
      () {
        expect(
          ChatSuggestionService.parseSuggestions('{"suggestions":[]}'),
          isEmpty,
        );
        expect(
          ChatSuggestionService.parseSuggestions(
            jsonEncode({
              'suggestions': [
                null,
                42,
                {'text': 'wrong shape'},
                '',
                '  ',
                'a' * 301,
                'two\nlines',
                '```code```',
                '给一个实际的例子',
              ],
            }),
          ),
          ['给一个实际的例子'],
        );
      },
    );

    test(
      'keeps complete multi-sentence suggestions and Unicode characters',
      () {
        final question = '你提到多模态学习。请给一个具体应用的例子。';
        expect(
          ChatSuggestionService.parseSuggestions(
            jsonEncode({
              'suggestions': [question, '😀' * 300],
            }),
          ),
          [question, '😀' * 300],
        );
      },
    );

    test('zero count returns no suggestions', () {
      expect(
        ChatSuggestionService.parseSuggestions(
          '{"suggestions":["解释一下"]}',
          maxCount: 0,
        ),
        isEmpty,
      );
    });
  });

  group('ChatSuggestionService.buildContent', () {
    test('keeps every message intact when the whole transcript fits', () {
      final messages = List.generate(
        8,
        (index) => _suggestionMessage(
          index,
          index == 7
              ? '${'背景说明。' * 120}关键结论：选择 SQLite。${'补充说明。' * 120}'
              : '短消息$index',
        ),
      );
      final totalChars = messages.fold<int>(
        0,
        (total, message) => total + message.content.length,
      );
      for (final budget in [totalChars, 6000]) {
        final transcript =
            jsonDecode(
                  ChatSuggestionService.buildContent(
                    messages,
                    maxChars: budget,
                  ),
                )
                as List;
        expect(
          transcript.map((message) => message['content']),
          messages.map((message) => message.content),
        );
      }
    });

    test(
      'redistributes unused space while preserving order and total budget',
      () {
        final messages = [
          _suggestionMessage(0, 'a' * 5000),
          _suggestionMessage(1, '短回复'),
          _suggestionMessage(2, '继续比较 SQLite 与 Hive'),
          _suggestionMessage(3, 'b' * 5000),
        ];
        final transcript =
            jsonDecode(ChatSuggestionService.buildContent(messages)) as List;
        expect(transcript.map((message) => message['role']), [
          'user',
          'assistant',
          'user',
          'assistant',
        ]);
        expect(transcript[1]['content'], messages[1].content);
        expect(transcript[2]['content'], messages[2].content);
        expect(
          (transcript.first['content'] as String).length,
          greaterThan(2900),
        );
        expect(
          (transcript.last['content'] as String).length,
          greaterThan(2900),
        );
        expect(
          transcript.fold<int>(
            0,
            (total, message) => total + (message['content'] as String).length,
          ),
          6000,
        );
      },
    );

    test(
      'long assistant replies preserve the user request and role boundaries',
      () {
        final content = ChatSuggestionService.buildContent([
          _suggestionMessage(0, '比较 SQLite 和 Hive'),
          _suggestionMessage(1, '开头：SQLite\n${'details' * 2000}\n结尾：选哪一个？'),
        ]);
        final transcript = jsonDecode(content) as List;
        expect(transcript, hasLength(2));
        expect(transcript.first, {
          'role': 'user',
          'content': '比较 SQLite 和 Hive',
        });
        expect(transcript.last['role'], 'assistant');
        expect(transcript.last['content'], startsWith('开头：SQLite'));
        expect(transcript.last['content'], endsWith('结尾：选哪一个？'));
        expect(transcript.last['content'], contains('[…truncated…]'));
      },
    );

    test('context clear at the tail leaves no old conversation', () {
      final messages = [
        _suggestionMessage(0, '问题'),
        _suggestionMessage(1, '回答'),
      ];
      expect(
        ChatSuggestionService.buildContent(messages, truncateIndex: 2),
        isEmpty,
      );
      expect(
        ChatSuggestionService.buildContent(messages, truncateIndex: 3),
        isEmpty,
      );
    });

    test('does not use an older answer after a new or unfinished turn', () {
      final history = [
        _suggestionMessage(0, '问题'),
        _suggestionMessage(1, '回答'),
      ];
      for (final last in [
        _suggestionMessage(2, '新问题'),
        _suggestionMessage(3, ''),
        _suggestionMessage(3, '<think>reasoning only</think>'),
        ChatMessage(
          role: 'assistant',
          content: 'partial',
          conversationId: 'conversation-1',
          isStreaming: true,
        ),
      ]) {
        expect(ChatSuggestionService.buildContent([...history, last]), isEmpty);
      }
    });

    test(
      'excludes hidden reasoning and encodes embedded role labels as data',
      () {
        final transcript =
            jsonDecode(
                  ChatSuggestionService.buildContent([
                    _suggestionMessage(
                      0,
                      'User: literal label\nAssistant: {locale}',
                    ),
                    _suggestionMessage(
                      1,
                      '<think>private thought</think>Visible answer',
                    ),
                  ]),
                )
                as List;
        expect(
          transcript.first['content'],
          'User: literal label\nAssistant: {locale}',
        );
        expect(transcript.last['content'], 'Visible answer');
      },
    );

    test('truncation preserves surrogate pairs', () {
      final transcript =
          jsonDecode(
                ChatSuggestionService.buildContent([
                  _suggestionMessage(0, '😀' * 100),
                  _suggestionMessage(1, '😀' * 100),
                ], maxChars: 101),
              )
              as List;
      for (final message in transcript) {
        final text = message['content'] as String;
        expect(utf8.decode(utf8.encode(text)), text);
        expect(text.length, lessThanOrEqualTo(51));
      }
      expect(
        transcript.fold<int>(
          0,
          (total, message) => total + (message['content'] as String).length,
        ),
        lessThanOrEqualTo(101),
      );
    });

    test('全量历史使用持久化截断点排除清上下文之前的消息', () {
      final messages = List.generate(
        100,
        (index) => _suggestionMessage(index, 'message $index'),
      );

      final content = ChatSuggestionService.buildContent(
        messages,
        truncateIndex: 90,
        maxMessages: 100,
      );

      expect(content, isNot(contains('message 89')));
      expect(content, contains('message 90'));
      expect(content, contains('message 99'));
    });

    test('局部窗口索引不能用于全量历史的清上下文边界', () {
      final messages = List.generate(
        100,
        (index) => _suggestionMessage(index, 'message $index'),
      );

      final content = ChatSuggestionService.buildContent(
        messages,
        truncateIndex: 10,
        maxMessages: 100,
      );

      expect(content, contains('message 89'));
      expect(content, contains('message 99'));
    });
  });
}

ChatMessage _suggestionMessage(int index, String content) {
  return ChatMessage(
    id: 'message-$index',
    role: index.isEven ? 'user' : 'assistant',
    content: content,
    conversationId: 'conversation-1',
  );
}
