import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class TavilySearchService extends SearchService<TavilyOptions>
    implements WebFetchCapable<TavilyOptions> {
  TavilySearchService({super.client});

  @override
  String get name => 'Tavily';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderTavilyDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required TavilyOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'query': query,
        'max_results': commonOptions.resultSize,
      });

      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(serviceOptions.resolvedUrl),
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

      final data = jsonDecode(response.body);
      final results = (data['results'] as List).map((item) {
        return SearchResultItem(
          title: item['title'] ?? '',
          url: item['url'] ?? '',
          text: item['content'] ?? '',
        );
      }).toList();

      return SearchResult(answer: data['answer'], items: results);
    } catch (e) {
      throw Exception('Tavily search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required TavilyOptions serviceOptions,
  }) async {
    try {
      final endpoint = siblingFetchEndpoint(
        serviceOptions.resolvedUrl,
        searchPath: '/search',
        fetchPath: '/extract',
      );
      final data = await postFetchJson(
        Uri.parse(endpoint),
        headers: {
          'Authorization':
              'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
        },
        body: {'urls': url, 'format': 'markdown'},
        commonOptions: commonOptions,
      );
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) {
        final failed = (data['failed_results'] as List?) ?? const [];
        final error = failed.isEmpty ? null : (failed.first as Map)['error'];
        throw Exception(error ?? 'no content returned');
      }
      final page = (results.first as Map).cast<String, dynamic>();
      final content = (page['raw_content'] ?? '').toString();
      return WebFetchPage(
        url: (page['url'] ?? url).toString(),
        title: firstMarkdownHeading(content),
        content: content,
      );
    } catch (e) {
      throw Exception('Tavily fetch failed: $e');
    }
  }
}
