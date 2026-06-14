import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant_memory.dart';
import 'package:Kelivo/core/services/proactive_care_service.dart';

void main() {
  final now = DateTime(2026, 6, 12, 10, 0, 0);

  group('ProactiveCareService.parseDecision', () {
    test('parses plain JSON with a future time', () {
      const raw =
          '{"should_update": true, "next_care_time": "2026-06-13T08:30:00"}';
      final result = ProactiveCareService.parseDecision(raw, now: now);
      expect(result, DateTime(2026, 6, 13, 8, 30, 0));
    });

    test('parses JSON wrapped in markdown code fences', () {
      const raw =
          '```json\n'
          '{"should_update": true, "next_care_time": "2026-06-12T22:00:00"}\n'
          '```';
      final result = ProactiveCareService.parseDecision(raw, now: now);
      expect(result, DateTime(2026, 6, 12, 22, 0, 0));
    });

    test('parses JSON surrounded by extra prose', () {
      const raw =
          '好的，以下是我的决策：\n'
          '{"should_update": true, "next_care_time": "2026-06-14T09:00:00"}\n'
          '请查收。';
      final result = ProactiveCareService.parseDecision(raw, now: now);
      expect(result, DateTime(2026, 6, 14, 9, 0, 0));
    });

    test('converts UTC time to local time', () {
      const raw =
          '{"should_update": true, "next_care_time": "2026-06-13T00:00:00Z"}';
      final result = ProactiveCareService.parseDecision(raw, now: now);
      expect(result, isNotNull);
      expect(result!.isUtc, isFalse);
      expect(result.toUtc(), DateTime.utc(2026, 6, 13));
    });

    test('returns null when should_update is false', () {
      const raw =
          '{"should_update": false, "next_care_time": "2026-06-13T08:30:00"}';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });

    test('returns null when the time is in the past', () {
      const raw =
          '{"should_update": true, "next_care_time": "2026-06-11T08:30:00"}';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });

    test('returns null when the time equals now', () {
      const raw =
          '{"should_update": true, "next_care_time": "2026-06-12T10:00:00"}';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });

    test('returns null when the time string is invalid', () {
      const raw =
          '{"should_update": true, "next_care_time": "tomorrow morning"}';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });

    test('returns null when next_care_time is missing', () {
      const raw = '{"should_update": true}';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });

    test('returns null for a non-JSON reply', () {
      const raw = '我觉得明天早上比较合适。';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });

    test('returns null for malformed JSON', () {
      const raw = '{"should_update": true, "next_care_time": ';
      expect(ProactiveCareService.parseDecision(raw, now: now), isNull);
    });
  });

  group('ProactiveCareService.buildDecisionTimeFooter', () {
    test('includes next care time and current system time', () {
      final nextCare = DateTime(2026, 6, 13, 8, 0, 0);
      final footer = ProactiveCareService.buildDecisionTimeFooter(
        now: now,
        currentNextCareTime: nextCare,
      );
      expect(footer, contains(nextCare.toIso8601String()));
      expect(footer, contains(now.toIso8601String()));
    });

    test('marks next care time as unset when null', () {
      final footer = ProactiveCareService.buildDecisionTimeFooter(
        now: now,
        currentNextCareTime: null,
      );
      expect(footer, contains('未设定'));
    });
  });

  group('ProactiveCareService.buildDecisionApiMessages', () {
    const history = <Map<String, dynamic>>[
      {'role': 'user', 'content': 'hello'},
      {'role': 'assistant', 'content': 'hi there'},
    ];

    test(
      'puts decision rules in system and times in the last user message',
      () {
        final nextCare = DateTime(2026, 6, 13, 8, 0, 0);
        final messages = ProactiveCareService.buildDecisionApiMessages(
          decisionPrompt: '决策说明提示词',
          currentNextCareTime: nextCare,
          now: now,
          history: history,
        );

        expect(messages.first['role'], 'system');
        expect(messages.first['content'], contains('决策说明提示词'));
        expect(messages.first['content'], contains('【输出要求】'));
        expect(
          messages.first['content'],
          isNot(contains(nextCare.toIso8601String())),
        );
        expect(
          messages.first['content'],
          isNot(contains(now.toIso8601String())),
        );

        expect(messages.last['role'], 'user');
        expect(messages.last['content'], contains(nextCare.toIso8601String()));
        expect(messages.last['content'], contains(now.toIso8601String()));
      },
    );

    test(
      'orders system, persona, memories, history header, history, time footer',
      () {
        final messages = ProactiveCareService.buildDecisionApiMessages(
          decisionPrompt: '决策说明提示词',
          currentNextCareTime: null,
          now: now,
          history: history,
          personaPrompt: '你是一只猫娘',
          memoriesBlock: '## Memories\n<memories></memories>',
        );

        expect(messages[0]['role'], 'system');
        expect(messages[1]['role'], 'user');
        expect(
          messages[1]['content'],
          contains(ProactiveCareService.personaReferencePrefix),
        );
        expect(messages[1]['content'], contains('你是一只猫娘'));
        expect(messages[2]['role'], 'user');
        expect(
          messages[2]['content'],
          contains(ProactiveCareService.memoriesReferencePrefix),
        );
        expect(messages[2]['content'], contains('## Memories'));
        expect(messages[3]['role'], 'user');
        expect(messages[3]['content'], ProactiveCareService.chatHistoryPrefix);
        expect(messages[4], history[0]);
        expect(messages[5], history[1]);
        expect(messages[6]['role'], 'user');
        expect(messages[6]['content'], contains('未设定'));
      },
    );

    test('skips persona and memory user messages when empty', () {
      final messages = ProactiveCareService.buildDecisionApiMessages(
        decisionPrompt: '决策说明提示词',
        currentNextCareTime: null,
        now: now,
        history: history,
        personaPrompt: '   ',
        memoriesBlock: '',
      );

      expect(messages, hasLength(5));
      expect(messages[0]['role'], 'system');
      expect(messages[1]['content'], ProactiveCareService.chatHistoryPrefix);
      expect(messages[2], history[0]);
      expect(messages[3], history[1]);
      expect(messages[4]['role'], 'user');
      expect(messages[4]['content'], contains(now.toIso8601String()));
    });

    test('includes only memory user message when persona is empty', () {
      final messages = ProactiveCareService.buildDecisionApiMessages(
        decisionPrompt: '决策说明提示词',
        currentNextCareTime: null,
        now: now,
        history: history,
        memoriesBlock: '## Memories\n<memories></memories>',
      );

      expect(
        messages[1]['content'],
        contains(ProactiveCareService.memoriesReferencePrefix),
      );
      expect(
        messages.any(
          (m) => (m['content'] as String).contains(
            ProactiveCareService.personaReferencePrefix,
          ),
        ),
        isFalse,
      );
    });

    test(
      'omits chat history header when history is empty but keeps time footer',
      () {
        final messages = ProactiveCareService.buildDecisionApiMessages(
          decisionPrompt: '决策说明提示词',
          currentNextCareTime: null,
          now: now,
          history: const <Map<String, dynamic>>[],
        );

        expect(messages, hasLength(2));
        expect(messages[0]['role'], 'system');
        expect(
          messages.any(
            (m) => m['content'] == ProactiveCareService.chatHistoryPrefix,
          ),
          isFalse,
        );
        expect(messages.last['role'], 'user');
        expect(messages.last['content'], contains(now.toIso8601String()));
      },
    );
  });

  group('ProactiveCareService.buildMemoriesBlock', () {
    test('formats memory records without memory tool instructions', () {
      final block = ProactiveCareService.buildMemoriesBlock(const [
        AssistantMemory(id: 1, assistantId: 'a1', content: '用户喜欢早睡'),
        AssistantMemory(id: 2, assistantId: 'a1', content: '用户在学日语'),
      ]);

      expect(block, contains('## Memories'));
      expect(block, contains('<memories>'));
      expect(block, contains('<record>'));
      expect(block, contains('<id>1</id>'));
      expect(block, contains('<content>用户喜欢早睡</content>'));
      expect(block, contains('<content>用户在学日语</content>'));
      expect(block, contains('</memories>'));
      expect(block, isNot(contains('Memory Tool')));
      expect(block, isNot(contains('create_memory')));
    });

    test('returns empty string for an empty memory list', () {
      expect(ProactiveCareService.buildMemoriesBlock(const []), '');
    });
  });
}
