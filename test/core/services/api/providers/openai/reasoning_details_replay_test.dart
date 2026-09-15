import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/providers/openai/reasoning_details_replay.dart';

void main() {
  group('normalizeReasoningDetailsForReplay', () {
    test('merges streamed fragments into one signed block', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'part A', 'index': 0},
        {'type': 'reasoning.text', 'text': ' part B', 'index': 0},
        {'type': 'reasoning.text', 'signature': 'sig-1', 'index': 0},
      ]);

      expect(details, hasLength(1));
      expect(details!.first['text'], 'part A part B');
      expect(details.first['signature'], 'sig-1');
    });

    test('drops a signature-only block that has no text to rebuild', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'signature': 'sig-1', 'index': 0},
        {'type': 'reasoning.text', 'text': 'body', 'index': 1},
      ]);

      expect(details, hasLength(1));
      expect(details!.first['text'], 'body');
    });

    test('keeps distinct signed blocks apart', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'part A', 'signature': 'sig-a'},
        {'type': 'reasoning.text', 'text': 'part B', 'signature': 'sig-b'},
      ]);

      expect(details, hasLength(2));
      expect(details![0]['signature'], 'sig-a');
      expect(details[1]['signature'], 'sig-b');
    });

    test('collapses fragments that repeat the same signature', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'part A', 'signature': 'sig-x'},
        {'type': 'reasoning.text', 'text': ' part B', 'signature': 'sig-x'},
      ]);

      expect(details, hasLength(1));
      expect(details!.first['text'], 'part A part B');
      expect(details.first['signature'], 'sig-x');
    });

    test('does not merge blocks with different indexes', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'first', 'index': 0},
        {'type': 'reasoning.text', 'text': 'second', 'index': 1},
      ]);

      expect(details, hasLength(2));
    });

    test('passes opaque encrypted payloads through untouched', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.encrypted', 'data': 'AAAA'},
        {'type': 'reasoning.encrypted', 'data': 'BBBB'},
      ]);

      expect(details, hasLength(2));
      expect(details![0]['data'], 'AAAA');
      expect(details[1]['data'], 'BBBB');
    });

    test('a signed block does not swallow the next unsigned block', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'A body'},
        {'type': 'reasoning.text', 'signature': 'sig-a'},
        {'type': 'reasoning.text', 'text': 'B body'},
        {'type': 'reasoning.text', 'signature': 'sig-b'},
      ]);

      expect(details, hasLength(2));
      expect(details![0]['text'], 'A body');
      expect(details[0]['signature'], 'sig-a');
      expect(details[1]['text'], 'B body');
      expect(details[1]['signature'], 'sig-b');
    });

    test('keeps reasoning.summary entries that carry prose in text', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.summary', 'text': 'summary body'},
      ]);

      expect(details, hasLength(1));
      expect(details!.first['text'], 'summary body');
    });

    test('merges reasoning.summary fragments in the summary field', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.summary', 'summary': 'part A', 'index': 0},
        {'type': 'reasoning.summary', 'summary': ' part B', 'index': 0},
      ]);

      expect(details, hasLength(1));
      expect(details!.first['summary'], 'part A part B');
    });

    test('later fragments fill in metadata the first one left null', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'body', 'format': null, 'index': 0},
        {
          'type': 'reasoning.text',
          'signature': 'sig-1',
          'format': 'anthropic-claude-v1',
          'index': 0,
        },
      ]);

      expect(details, hasLength(1));
      expect(details!.first['format'], 'anthropic-claude-v1');
      expect(details.first['signature'], 'sig-1');
    });

    test('reasoningDetailsLookAnthropic detects the anthropic format tag', () {
      expect(
        reasoningDetailsLookAnthropic([
          {
            'type': 'reasoning.text',
            'text': 'x',
            'format': 'anthropic-claude-v1',
          },
        ]),
        isTrue,
      );
      expect(
        reasoningDetailsLookAnthropic([
          {
            'type': 'reasoning.text',
            'text': 'x',
            'format': 'openai-responses-v1',
          },
        ]),
        isFalse,
      );
    });

    test('reasoningDetailsNeedSignedReplay keys on format or signature', () {
      expect(
        reasoningDetailsNeedSignedReplay([
          {
            'type': 'reasoning.text',
            'text': 'x',
            'format': 'anthropic-claude-v1',
          },
        ]),
        isTrue,
      );
      expect(
        reasoningDetailsNeedSignedReplay([
          {'type': 'reasoning.text', 'text': 'x', 'signature': 'sig-1'},
        ]),
        isTrue,
      );
      expect(
        reasoningDetailsNeedSignedReplay([
          {'type': 'reasoning.text', 'text': 'x'},
        ]),
        isFalse,
      );
    });

    test('returns null when nothing replayable remains', () {
      expect(normalizeReasoningDetailsForReplay(const []), isNull);
      expect(
        normalizeReasoningDetailsForReplay([
          {'type': 'reasoning.text', 'signature': 'sig-only'},
        ]),
        isNull,
      );
    });
  });
}
