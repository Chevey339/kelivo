import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class ExaSearchService extends SearchService<ExaOptions>
    implements WebFetchCapable<ExaOptions> {
  ExaSearchService({super.client});

  @override
  String get name => 'Exa';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderExaDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required ExaOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'query': query,
        'numResults': commonOptions.resultSize,
        'contents': {'text': true},
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
          text: item['text'] ?? '',
        );
      }).toList();

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('Exa search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required ExaOptions serviceOptions,
  }) async {
    try {
      final endpoint = siblingFetchEndpoint(
        serviceOptions.resolvedUrl,
        searchPath: '/search',
        fetchPath: '/contents',
      );
      final data = await postFetchJson(
        Uri.parse(endpoint),
        headers: {
          'Authorization':
              'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
        },
        body: {
          'urls': [url],
          'text': {'maxCharacters': webFetchMaxContentLength},
        },
        commonOptions: commonOptions,
      );
      final statuses = (data['statuses'] as List?) ?? const [];
      final status = statuses.isEmpty ? null : statuses.first as Map;
      if (status != null && status['status'] == 'error') {
        final error = status['error'];
        throw Exception(
          error is Map ? (error['tag'] ?? error) : 'crawl failed',
        );
      }
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) throw Exception('no content returned');
      final page = (results.first as Map).cast<String, dynamic>();
      return WebFetchPage(
        url: (page['url'] ?? url).toString(),
        title: (page['title'] ?? '').toString(),
        content: (page['text'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception('Exa fetch failed: $e');
    }
  }
}
