import 'package:Kelivo/core/model_capabilities/model_tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitTokens', () {
    test('splits on every separator and letter/digit boundary', () {
      expect(ModelTokenizer.splitTokens('gpt-4o'), <String>['gpt', '4', 'o']);
      expect(ModelTokenizer.splitTokens('gpt-oss-120b'), <String>[
        'gpt',
        'oss',
        '120',
        'b',
      ]);
      expect(ModelTokenizer.splitTokens('chatgpt-4o-latest'), <String>[
        'chatgpt',
        '4',
        'o',
        'latest',
      ]);
      expect(ModelTokenizer.splitTokens('MiniMax-M2.5'), <String>[
        'minimax',
        'm',
        '2',
        '5',
      ]);
      expect(ModelTokenizer.splitTokens('z.ai'), <String>['z', 'ai']);
    });

    test('treats dash, dot and adjacent boundaries as equivalent', () {
      const expected = <String>['qwen', '3', '7', 'plus'];
      expect(ModelTokenizer.splitTokens('qwen3.7-plus'), expected);
      expect(ModelTokenizer.splitTokens('qwen-3.7-plus'), expected);
      expect(ModelTokenizer.splitTokens('qwen3-7-plus'), expected);
      expect(ModelTokenizer.splitTokens('QWEN_3_7_PLUS'), expected);
    });

    test('keeps a separator present distinction between 52 and 5.2', () {
      expect(ModelTokenizer.splitTokens('gpt-52'), <String>['gpt', '52']);
      expect(ModelTokenizer.splitTokens('gpt-5.2'), <String>['gpt', '5', '2']);
    });

    test('keeps non-ascii brand names intact', () {
      expect(ModelTokenizer.splitTokens('智谱'), <String>['智谱']);
    });

    test('reports which tokens follow a colon', () {
      final fragment = ModelTokenizer.splitFragment('kimi-for-coding:fast');
      expect(fragment.tokens, <String>['kimi', 'for', 'coding', 'fast']);
      expect(fragment.colonBoundaries, <int>{3});

      expect(
        ModelTokenizer.splitFragment('kimi-for-coding-other').colonBoundaries,
        isEmpty,
      );
    });
  });

  group('tokenizeModelId', () {
    test('strips the vendor prefix', () {
      final id = ModelTokenizer.tokenizeModelId('openrouter/kimi-k3');
      expect(id.vendor, 'openrouter');
      expect(id.name, 'kimi-k3');
      expect(id.tokens, <String>['kimi', 'k', '3']);
    });

    test('tracks colon-qualified variants after the vendor prefix', () {
      final id = ModelTokenizer.tokenizeModelId(
        'moonshotai/kimi-for-coding:fast',
      );
      expect(id.vendor, 'moonshotai');
      expect(id.tokens, <String>['kimi', 'for', 'coding', 'fast']);
      expect(id.colonBoundaries, <int>{3});
    });

    test('recognizes a dashed snapshot date', () {
      final id = ModelTokenizer.tokenizeModelId('qwen3.7-max-2026-05-17');
      expect(id.tokens, <String>['qwen', '3', '7', 'max']);
      expect(id.date, const ModelDate(year: 2026, month: 5, day: 17));
    });

    test('recognizes a compact 8-digit snapshot date', () {
      final id = ModelTokenizer.tokenizeModelId('claude-sonnet-4-5-20250929');
      expect(id.tokens, <String>['claude', 'sonnet', '4', '5']);
      expect(id.date, const ModelDate(year: 2025, month: 9, day: 29));
    });

    test('recognizes a compact 6-digit snapshot date', () {
      final id = ModelTokenizer.tokenizeModelId('doubao-seed-1-6-250615');
      expect(id.tokens, <String>['doubao', 'seed', '1', '6']);
      expect(id.date, const ModelDate(year: 2025, month: 6, day: 15));
    });

    test('recognizes a yearless MMDD snapshot', () {
      final id = ModelTokenizer.tokenizeModelId('qwen3.8-max-0902');
      expect(id.tokens, <String>['qwen', '3', '8', 'max']);
      expect(id.date, const ModelDate(month: 9, day: 2));
      expect(id.date!.hasYear, isFalse);
    });

    test('recognizes a snapshot after an @ separator', () {
      final id = ModelTokenizer.tokenizeModelId('claude-3-haiku@20240307');
      expect(id.tokens, <String>['claude', '3', 'haiku']);
      expect(id.date, const ModelDate(year: 2024, month: 3, day: 7));
    });

    test('does not mistake ordinary numeric suffixes for dates', () {
      expect(ModelTokenizer.tokenizeModelId('gpt-4-32k').tokens, <String>[
        'gpt',
        '4',
        '32',
        'k',
      ]);
      expect(ModelTokenizer.tokenizeModelId('glm-4.6').tokens, <String>[
        'glm',
        '4',
        '6',
      ]);
      expect(ModelTokenizer.tokenizeModelId('qwen3-8b').tokens, <String>[
        'qwen',
        '3',
        '8',
        'b',
      ]);
      expect(ModelTokenizer.tokenizeModelId('gpt-4-turbo').tokens, <String>[
        'gpt',
        '4',
        'turbo',
      ]);
    });

    test('rejects out-of-range month/day tails', () {
      final id = ModelTokenizer.tokenizeModelId('command-r-plus-08-2024');
      expect(id.date, isNull);
      expect(id.tokens, <String>['command', 'r', 'plus', '08', '2024']);

      final invalid = ModelTokenizer.tokenizeModelId('foo-1399');
      expect(invalid.date, isNull);
      expect(invalid.tokens, <String>['foo', '1399']);
    });
  });

  group('ModelDate', () {
    test('compares full dates', () {
      const a = ModelDate(year: 2026, month: 5, day: 17);
      const later = ModelDate(year: 2026, month: 5, day: 18);
      const earlier = ModelDate(year: 2025, month: 12, day: 31);
      expect(a.isOnOrAfter(a), isTrue);
      expect(later.isOnOrAfter(a), isTrue);
      expect(earlier.isOnOrAfter(a), isFalse);
    });

    test('is never on-or-after when a year is missing', () {
      const yearless = ModelDate(month: 9, day: 2);
      const threshold = ModelDate(year: 2026, month: 8, day: 2);
      expect(yearless.isOnOrAfter(threshold), isFalse);
      expect(threshold.isOnOrAfter(yearless), isFalse);
    });
  });
}
