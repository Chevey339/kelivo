import 'package:flutter/material.dart';
import 'package:html/parser.dart' as parser;
import '../../../../l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import '../search_service.dart';

class BingSearchService extends SearchService<BingLocalOptions> {
  @override
  String get name => 'Bing (Local)';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderBingLocalDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required BingLocalOptions serviceOptions,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://www.bing.com/search?q=$encodedQuery';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept-Language': serviceOptions.acceptLanguage,
            },
          )
          .timeout(Duration(milliseconds: commonOptions.timeout));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch results: ${response.statusCode}');
      }

      final document = parser.parse(response.body);
      final results = <SearchResultItem>[];

      final elements = document.querySelectorAll('li.b_algo');
      for (final element in elements.take(commonOptions.resultSize)) {
        final titleElement = element.querySelector('h2');
        final linkElement = element.querySelector('h2 > a');
        final snippetElement = element.querySelector(
          '.b_caption p, .b_algoSlug',
        );

        if (titleElement != null && linkElement != null) {
          results.add(
            SearchResultItem(
              title: titleElement.text.trim(),
              url: linkElement.attributes['href'] ?? '',
              text: snippetElement?.text.trim() ?? '',
            ),
          );
        }
      }

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('Bing search failed: $e');
    }
  }
}
