import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/brave_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Brave search service', () {
    test('serializes options and resolves factory/icon mapping', () {
      final options = BraveOptions(
        id: 'brave-1',
        apiKey: 'brave-test',
        mode: BraveOptions.llmContextMode,
        maximumNumberOfTokens: 4096,
        extraApiKeys: const ['extra-key'],
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<BraveOptions>());
      final brave = restored as BraveOptions;
      expect(brave.id, 'brave-1');
      expect(brave.apiKey, 'brave-test');
      expect(brave.mode, BraveOptions.llmContextMode);
      expect(brave.maximumNumberOfTokens, 4096);
      expect(brave.extraApiKeys, ['extra-key']);
      expect(brave.primaryApiKey, 'brave-test');
      expect(SearchService.getService(brave), isA<BraveSearchService>());
      expect(BrandAssets.assetForName('brave'), 'assets/icons/brave-color.svg');
    });

    test('accepts empty or in-range token input and rejects the rest', () {
      expect(BraveOptions.isValidMaximumNumberOfTokensInput(null), isTrue);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput(''), isTrue);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('  '), isTrue);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('1024'), isTrue);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput(' 2048 '), isTrue);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('32768'), isTrue);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('abc'), isFalse);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('1000'), isFalse);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('50000'), isFalse);
      expect(BraveOptions.isValidMaximumNumberOfTokensInput('2048.5'), isFalse);
    });

    test('defaults missing mode to web and keeps old configs unchanged', () {
      final restored = SearchServiceOptions.fromJson({
        'type': 'brave',
        'id': 'brave-legacy',
        'apiKey': 'legacy-key',
      });

      expect(restored, isA<BraveOptions>());
      final brave = restored as BraveOptions;
      expect(brave.mode, BraveOptions.webMode);
      expect(
        brave.maximumNumberOfTokens,
        BraveOptions.defaultMaximumNumberOfTokens,
      );
    });

    test('uses web search GET for the default web mode', () async {
      http.Request? captured;
      final service = BraveSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'web': {
                'results': [
                  {
                    'title': 'Brave Web',
                    'url': 'https://example.com/brave',
                    'description': 'Web snippet',
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo search',
        commonOptions: const SearchCommonOptions(resultSize: 4, timeout: 1000),
        serviceOptions: BraveOptions(id: 'brave-1', apiKey: 'brave-test'),
      );

      expect(
        captured?.url.toString(),
        '${BraveSearchService.webEndpoint}?q=kelivo%20search&count=4',
      );
      expect(captured?.method, 'GET');
      expect(captured?.headers['X-Subscription-Token'], 'brave-test');
      expect(captured?.headers['Accept'], 'application/json');
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Brave Web');
      expect(result.items.single.url, 'https://example.com/brave');
      expect(result.items.single.text, 'Web snippet');
    });

    test('posts LLM Context body and joins generic snippets', () async {
      http.Request? captured;
      final service = BraveSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'grounding': {
                'generic': [
                  {
                    'title': 'LLM Context',
                    'url': 'https://example.com/llm',
                    'snippets': ['First chunk', 'Second chunk'],
                  },
                  {
                    'title': 'Ignored by resultSize',
                    'url': 'https://example.com/ignored',
                    'snippets': ['ignored'],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo search',
        commonOptions: const SearchCommonOptions(resultSize: 1, timeout: 1000),
        serviceOptions: BraveOptions(
          id: 'brave-1',
          apiKey: 'brave-test',
          mode: BraveOptions.llmContextMode,
          maximumNumberOfTokens: 2048,
        ),
      );

      expect(captured?.url.toString(), BraveSearchService.llmContextEndpoint);
      expect(captured?.method, 'POST');
      expect(captured?.headers['X-Subscription-Token'], 'brave-test');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(captured?.headers['Accept'], 'application/json');
      expect(jsonDecode(captured!.body), {
        'q': 'kelivo search',
        'count': 1,
        'maximum_number_of_urls': 1,
        'maximum_number_of_tokens': 2048,
      });
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'LLM Context');
      expect(result.items.single.url, 'https://example.com/llm');
      expect(result.items.single.text, 'First chunk\n\nSecond chunk');
    });

    test(
      'returns an empty list when LLM Context has no generic results',
      () async {
        final service = BraveSearchService(
          client: MockClient(
            (_) async => http.Response(jsonEncode({'grounding': {}}), 200),
          ),
        );

        final result = await service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: BraveOptions(
            id: 'brave-1',
            apiKey: 'brave-test',
            mode: BraveOptions.llmContextMode,
          ),
        );

        expect(result.items, isEmpty);
      },
    );

    test('rotates extra API keys across LLM Context requests', () async {
      final keys = <String>[];
      final service = BraveSearchService(
        client: MockClient((request) async {
          keys.add(request.headers['X-Subscription-Token'] ?? '');
          return http.Response(jsonEncode({'grounding': {}}), 200);
        }),
      );
      final options = BraveOptions(
        id: 'brave-rotate',
        apiKey: 'key-a',
        extraApiKeys: const ['key-b'],
        mode: BraveOptions.llmContextMode,
      );

      await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: options,
      );
      await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: options,
      );

      expect(keys, ['key-a', 'key-b']);
    });

    test('includes status and body when LLM Context is not 200', () async {
      final service = BraveSearchService(
        client: MockClient(
          (_) async => http.Response('plan does not include llm context', 403),
        ),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: BraveOptions(
            id: 'brave-1',
            apiKey: 'brave-test',
            mode: BraveOptions.llmContextMode,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains('Brave search failed'),
              contains('403'),
              contains('plan does not include llm context'),
            ),
          ),
        ),
      );
    });

    test('throws when web search returns a non-200 response', () async {
      final service = BraveSearchService(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: BraveOptions(id: 'brave-1', apiKey: 'brave-test'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Brave search failed'),
          ),
        ),
      );
    });
  });
}
