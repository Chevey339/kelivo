import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class OllamaSearchService extends SearchService<OllamaOptions>
    implements WebFetchCapable<OllamaOptions> {
  OllamaSearchService({super.client});

  static const String fetchUrl = 'https://ollama.com/api/web_fetch';

  @override
  String get name => 'Ollama';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderOllamaDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required OllamaOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'query': query,
        'max_results': commonOptions.resultSize.clamp(1, 10),
      });

      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse('https://ollama.com/api/web_search'),
              headers: {
                'Authorization':
                    'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['results'] as List? ?? const []);
      final results = list.map((item) {
        final map = item as Map<String, dynamic>;
        return SearchResultItem(
          title: (map['title'] ?? '').toString(),
          url: (map['url'] ?? '').toString(),
          text: (map['content'] ?? '').toString(),
        );
      }).toList();

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('Ollama search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required OllamaOptions serviceOptions,
  }) async {
    try {
      final data = await postFetchJson(
        Uri.parse(fetchUrl),
        headers: {
          'Authorization':
              'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
        },
        body: {'url': url},
        commonOptions: commonOptions,
      );
      return WebFetchPage(
        url: url,
        title: (data['title'] ?? '').toString(),
        content: (data['content'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception('Ollama fetch failed: $e');
    }
  }
}
