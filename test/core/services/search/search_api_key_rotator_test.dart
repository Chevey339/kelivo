import 'package:Kelivo/core/services/search/search_api_key_rotator.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchApiKeyRotator', () {
    test('returns the primary key when no extras are configured', () {
      final rotator = SearchApiKeyRotator.instance;
      expect(rotator.select('svc-single', 'primary', const []), 'primary');
      expect(rotator.select('svc-single', 'primary', const []), 'primary');
    });

    test('uses the only extra key when the primary key is empty', () {
      final rotator = SearchApiKeyRotator.instance;
      expect(
        rotator.select('svc-no-primary', '', const ['valid-key']),
        'valid-key',
      );
      expect(
        rotator.select('svc-no-primary', '', const ['valid-key']),
        'valid-key',
      );
    });

    test('rotates through primary and extras in order', () {
      final rotator = SearchApiKeyRotator.instance;
      final picked = [
        for (var i = 0; i < 6; i++)
          rotator.select('svc-rotate', 'k1', const ['k2', 'k3']),
      ];
      expect(picked, ['k1', 'k2', 'k3', 'k1', 'k2', 'k3']);
    });

    test('trims and deduplicates the rotation pool', () {
      final rotator = SearchApiKeyRotator.instance;
      final picked = [
        for (var i = 0; i < 4; i++)
          rotator.select('svc-dedupe', ' k1 ', const ['k1', '  k2  ', '']),
      ];
      expect(picked, ['k1', 'k2', 'k1', 'k2']);
    });

    test('keeps independent cursors per service id', () {
      final rotator = SearchApiKeyRotator.instance;
      expect(rotator.select('svc-a', 'a1', const ['a2']), 'a1');
      expect(rotator.select('svc-b', 'b1', const ['b2']), 'b1');
      expect(rotator.select('svc-a', 'a1', const ['a2']), 'a2');
      expect(rotator.select('svc-b', 'b1', const ['b2']), 'b2');
    });

    test('rotationPool exposes the trimmed deduplicated order', () {
      expect(SearchApiKeyRotator.rotationPool('p', const ['p', 'x', ' x ']), [
        'p',
        'x',
      ]);
    });

    test('parseBatch splits on newlines, commas, semicolons and spaces', () {
      expect(SearchApiKeyRotator.parseBatch('k1\nk2,k3;k4 k5\n\n k6 '), [
        'k1',
        'k2',
        'k3',
        'k4',
        'k5',
        'k6',
      ]);
    });

    test('parseBatch deduplicates while preserving order', () {
      expect(SearchApiKeyRotator.parseBatch('a\nb\na\n\nb'), ['a', 'b']);
      expect(SearchApiKeyRotator.parseBatch(' \n,'), isEmpty);
    });

    test('mask keeps the first and last four characters', () {
      expect(SearchApiKeyRotator.mask('tvly-secret-key'), 'tvly••••-key');
      expect(SearchApiKeyRotator.mask('short'), '••••••••');
    });
  });

  group('SearchServiceOptions extra keys', () {
    test('serializes and restores extraApiKeys', () {
      final options = TavilyOptions(
        id: 't1',
        apiKey: 'primary',
        url: ' https://example.com ',
        extraApiKeys: const ['k2', 'k3'],
      );
      final decoded = SearchServiceOptions.fromJson(options.toJson());
      expect(decoded, isA<TavilyOptions>());
      expect(decoded.extraApiKeys, ['k2', 'k3']);
      expect((decoded as TavilyOptions).apiKey, 'primary');
    });

    test('omits apiKeys from json when empty and defaults to empty', () {
      final options = BraveOptions(id: 'b1', apiKey: 'primary');
      expect(options.toJson().containsKey('apiKeys'), isFalse);
      final decoded = SearchServiceOptions.fromJson(options.toJson());
      expect(decoded.extraApiKeys, isEmpty);
    });

    test('parses extraApiKeys for every key-based provider type', () {
      const types = [
        'tavily',
        'exa',
        'zhipu',
        'linkup',
        'brave',
        'metaso',
        'ollama',
        'jina',
        'perplexity',
        'bocha',
        'serper',
        'grok',
        'querit',
        'parallel',
      ];
      for (final type in types) {
        final decoded = SearchServiceOptions.fromJson({
          'type': type,
          'id': 'id-$type',
          'apiKey': 'primary',
          'apiKeys': ['extra'],
        });
        expect(decoded.extraApiKeys, [
          'extra',
        ], reason: 'type $type should restore extraApiKeys');
      }
    });
  });
}
