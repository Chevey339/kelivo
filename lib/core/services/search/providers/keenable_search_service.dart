import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class KeenableSearchService extends SearchService<KeenableOptions>
    implements WebFetchCapable<KeenableOptions> {
  static const String publicSearchUrl =
      'https://api.keenable.ai/v1/search/public';
  static const String keyedSearchUrl = 'https://api.keenable.ai/v1/search';
  static const String publicFetchUrl =
      'https://api.keenable.ai/v1/fetch/public';
  static const String keyedFetchUrl = 'https://api.keenable.ai/v1/fetch';
  static const String appTitle = 'Kelivo';

  KeenableSearchService({super.client});

  @override
  String get name => 'Keenable';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderKeenableDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  // Resolve the key once per request: effectiveApiKey advances the rotator.
  String _resolveApiKey(KeenableOptions serviceOptions) =>
      serviceOptions.effectiveApiKey(serviceOptions.apiKey).trim();

  Map<String, String> _headers(String apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Keenable-Title': appTitle,
    };
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    return headers;
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required KeenableOptions serviceOptions,
  }) async {
    try {
      final apiKey = _resolveApiKey(serviceOptions);
      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(apiKey.isNotEmpty ? keyedSearchUrl : publicSearchUrl),
              headers: _headers(apiKey),
              body: jsonEncode({
                'query': query,
                'max_results': commonOptions.resultSize,
              }),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final results = (data['results'] as List?) ?? const [];
      final items = results
          .map((item) {
            final result = (item as Map).cast<String, dynamic>();
            return SearchResultItem(
              title: (result['title'] ?? '').toString(),
              url: (result['url'] ?? result['link'] ?? '').toString(),
              text:
                  (result['snippet'] ??
                          result['content'] ??
                          result['description'] ??
                          '')
                      .toString(),
            );
          })
          .where((item) => item.url.trim().isNotEmpty)
          .toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Keenable search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required KeenableOptions serviceOptions,
  }) async {
    try {
      final apiKey = _resolveApiKey(serviceOptions);
      final endpoint = apiKey.isNotEmpty ? keyedFetchUrl : publicFetchUrl;
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'url': url,
          'max_chars': webFetchMaxContentLength.toString(),
        },
      );
      final response = await withHttpClient(
        (client) => client
            .get(uri, headers: _headers(apiKey))
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );
      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (data is! Map) {
        throw Exception('no content returned');
      }
      final page = data.cast<String, dynamic>();
      final content =
          (page['content'] ??
                  page['text'] ??
                  page['markdown'] ??
                  page['snippet'] ??
                  '')
              .toString();
      if (content.trim().isEmpty) {
        throw Exception('no content returned');
      }
      return WebFetchPage(
        url: (page['url'] ?? url).toString(),
        title: (page['title'] ?? '').toString(),
        content: content,
      );
    } catch (e) {
      throw Exception('Keenable fetch failed: $e');
    }
  }
}
