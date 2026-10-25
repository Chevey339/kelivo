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

    test('keeps completed blocks even when their signatures are identical', () {
      final details = normalizeReasoningDetailsForReplay([
        {'type': 'reasoning.text', 'text': 'part A', 'signature': 'sig-x'},
        {'type': 'reasoning.text', 'text': ' part B', 'signature': 'sig-x'},
      ]);

      expect(details, hasLength(2));
      expect(details![0]['text'], 'part A');
      expect(details[1]['text'], ' part B');
      expect(details.map((entry) => entry['signature']), ['sig-x', 'sig-x']);
    });

    test(
      'merges unsigned text without trimming, deduplicating or adding breaks',
      () {
        final fragments = [
          for (final text in ['Let', ' me', ' me', '\n', 'check.'])
            {
              'type': 'reasoning.text',
              'text': text,
              'format': 'unknown',
              'index': 0,
            },
        ];
        final details = normalizeReasoningDetailsForReplay(fragments);

        expect(details, [
          {
            'type': 'reasoning.text',
            'text': 'Let me me\ncheck.',
            'format': 'unknown',
            'index': 0,
          },
        ]);
        expect(fragments.map((entry) => entry['text']), [
          'Let',
          ' me',
          ' me',
          '\n',
          'check.',
        ]);
        expect(normalizeReasoningDetailsForReplay(details), details);
      },
    );

    for (final field in ['id', 'index', 'format']) {
      test('preserves text block boundaries with different $field', () {
        final details = normalizeReasoningDetailsForReplay([
          {
            'type': 'reasoning.text',
            'text': 'first',
            field: field == 'index' ? 0 : 'a',
          },
          {
            'type': 'reasoning.text',
            'text': 'second',
            field: field == 'index' ? 1 : 'b',
          },
        ]);
        expect(details, hasLength(2));
        expect(details!.map((entry) => entry['text']), ['first', 'second']);
      });
    }

    test('encrypted and unknown blocks remain opaque merge boundaries', () {
      const encrypted = {
        'type': 'reasoning.encrypted',
        'data': 'AAAA',
        'id': 'r',
      };
      const unknown = {
        'type': 'reasoning.future',
        'payload': {'value': 1},
      };
      const raw = [
        {'type': 'reasoning.text', 'text': 'before'},
        encrypted,
        encrypted,
        {'type': 'reasoning.text', 'text': 'after'},
        unknown,
        {'type': 'reasoning.text', 'text': 'last'},
      ];
      final details = normalizeReasoningDetailsForReplay(raw);
      expect(details, raw);
      expect(normalizeReasoningDetailsForReplay(details), raw);
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

    test(
      'retains orphan signatures in captured data but not request blocks',
      () {
        const raw = [
          {'type': 'reasoning.text', 'signature': 'orphan'},
        ];
        final captured = mergeReasoningDetails(raw);
        expect(captured, raw);
        expect(reasoningDetailsNeedSignedReplay(captured), isTrue);
        expect(normalizeReasoningDetailsForReplay(captured), isNull);
      },
    );
  });
}
