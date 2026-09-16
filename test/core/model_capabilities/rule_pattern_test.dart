import 'package:Kelivo/core/model_capabilities/model_tokenizer.dart';
import 'package:Kelivo/core/model_capabilities/rule_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsing', () {
    test('caches parsed patterns', () {
      expect(
        identical(RulePattern.parse('gpt'), RulePattern.parse('gpt')),
        isTrue,
      );
    });

    test('rejects malformed patterns', () {
      expect(() => RulePattern.parse(''), throwsFormatException);
      expect(() => RulePattern.parse('^'), throwsFormatException);
      expect(() => RulePattern.parse('{1|3|4'), throwsFormatException);
      expect(() => RulePattern.parse('1|3|4}'), throwsFormatException);
      expect(() => RulePattern.parse('{ }'), throwsFormatException);
      expect(() => RulePattern.parse('{v>=x}'), throwsFormatException);
      expect(() => RulePattern.parse('{5.2|6}'), throwsFormatException);
      expect(
        () => RulePattern.parse('^gpt @>=2026-13-01'),
        throwsFormatException,
      );
    });
  });

  group('matching', () {
    test('alternation matches any branch', () {
      final pattern = RulePattern.parse('gpt | chatgpt');
      final match = pattern.bestMatch(<String>['chatgpt', '4']);
      expect(match, isNotNull);
      expect(match!.consumedTokens, 1);
      expect(match.literalTokens, 1);
    });

    test('unanchored patterns match at any offset', () {
      final pattern = RulePattern.parse('gpt 5');
      final match = pattern.bestMatch(<String>['vendor', 'gpt', '5', '2']);
      expect(match, isNotNull);
      expect(match!.anchored, isFalse);
      expect(match.consumedTokens, 2);
    });

    test('anchored patterns only match at the start', () {
      final anchored = RulePattern.parse('^gpt 5');
      expect(anchored.matches(<String>['vendor', 'gpt', '5']), isFalse);
      expect(anchored.matches(<String>['gpt', '5', '2']), isTrue);
    });

    test('literal chunks are tokenized like ids', () {
      final pattern = RulePattern.parse('^gpt 5.2');
      final match = pattern.bestMatch(<String>['gpt', '5', '2', 'codex']);
      expect(match, isNotNull);
      expect(match!.consumedTokens, 3);
      expect(match.literalTokens, 3);
    });

    test('token sets match exactly one position', () {
      final pattern = RulePattern.parse('^o {1|3|4}');
      final match = pattern.bestMatch(<String>['o', '3', 'mini']);
      expect(match, isNotNull);
      expect(match!.consumedTokens, 2);
      expect(match.literalTokens, 1);
      expect(pattern.matches(<String>['o', '2']), isFalse);
    });

    test('version bounds consume one or two numeric tokens', () {
      final pattern = RulePattern.parse('^gemini {v>=3.5} flash');
      final pair = pattern.bestMatch(<String>['gemini', '3', '5', 'flash']);
      expect(pair, isNotNull);
      expect(pair!.consumedTokens, 4);
      expect(pair.literalTokens, 2);

      final single = pattern.bestMatch(<String>['gemini', '4', 'flash']);
      expect(single, isNotNull);
      expect(single!.consumedTokens, 3);

      expect(pattern.matches(<String>['gemini', '3', 'flash']), isFalse);
      expect(pattern.matches(<String>['gemini', '2', '5', 'flash']), isFalse);
    });

    test('prefers the most specific matching alternative', () {
      final pattern = RulePattern.parse('^a | ^a b');
      final match = pattern.bestMatch(<String>['a', 'b', 'c']);
      expect(match!.consumedTokens, 2);
    });
  });

  group('end anchor', () {
    test('requires the id to close after the consumed tokens', () {
      final pattern = RulePattern.parse(r'^k 3 $');
      expect(pattern.matches(<String>['k', '3']), isTrue);
      expect(pattern.matches(<String>['k', '3', '256', 'k']), isFalse);
      expect(pattern.matches(<String>['my', 'k', '3']), isFalse);
    });

    test('accepts a colon-qualified variant but not a dash continuation', () {
      final pattern = RulePattern.parse(r'^kimi for coding $');
      expect(
        pattern.matches(
          <String>['kimi', 'for', 'coding', 'fast'],
          colonBoundaries: const <int>{3},
        ),
        isTrue,
      );
      expect(
        pattern.matches(<String>['kimi', 'for', 'coding', 'other']),
        isFalse,
      );
    });

    test('outranks a non-end-anchored match of equal breadth', () {
      final pattern = RulePattern.parse(r'^a $ | ^a');
      final exact = pattern.bestMatch(<String>['a']);
      expect(exact!.endAnchored, isTrue);
      final loose = pattern.bestMatch(<String>['a', 'b']);
      expect(loose!.endAnchored, isFalse);
    });

    test('parses before or after a date bound', () {
      expect(
        RulePattern.parse(
          r'qwen 3 7 max $ @>=2026-05-17',
        ).matches(<String>['qwen', '3', '7', 'max']),
        isTrue,
      );
      expect(
        RulePattern.parse(
          r'qwen 3 7 max @>=2026-05-17 $',
        ).matches(<String>['qwen', '3', '7', 'max']),
        isTrue,
      );
    });
  });

  group('date bounds', () {
    final pattern = RulePattern.parse('qwen 3 7 max @>=2026-05-17');

    test('admits dated snapshots at or after the bound', () {
      expect(
        pattern.matches(<String>[
          'qwen',
          '3',
          '7',
          'max',
        ], date: const ModelDate(year: 2026, month: 5, day: 17)),
        isTrue,
      );
      expect(
        pattern.matches(<String>[
          'qwen',
          '3',
          '7',
          'max',
        ], date: const ModelDate(year: 2026, month: 6, day: 1)),
        isTrue,
      );
    });

    test('admits bare aliases with no snapshot', () {
      expect(pattern.matches(<String>['qwen', '3', '7', 'max']), isTrue);
    });

    test('rejects older and yearless snapshots', () {
      expect(
        pattern.matches(<String>[
          'qwen',
          '3',
          '7',
          'max',
        ], date: const ModelDate(year: 2026, month: 5, day: 16)),
        isFalse,
      );
      expect(
        pattern.matches(<String>[
          'qwen',
          '3',
          '7',
          'max',
        ], date: const ModelDate(month: 9, day: 2)),
        isFalse,
      );
    });
  });
}
