import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class DeepSeekSearchService extends SearchService<DeepSeekOptions>
    implements WebFetchCapable<DeepSeekOptions> {
  DeepSeekSearchService({super.client});

  static const String searchEndpoint =
      'https://api.deepseek.com/v1/tools/search';
  static const String fetchEndpoint = 'https://api.deepseek.com/v1/tools/fetch';

  @override
  String get name => 'DeepSeek';

  @override
  Widget description(BuildContext context) => Text(
    AppLocalizations.of(context)!.searchProviderDeepSeekDescription,
    style: const TextStyle(fontSize: 12),
  );

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required DeepSeekOptions serviceOptions,
  }) async {
    try {
      final response = await withWebFetchClient(
        (client) => client.post(
          Uri.parse(searchEndpoint),
          headers: {
            'Authorization':
                'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'query': query,
            'count': commonOptions.resultSize.clamp(1, 50),
            'need_content': false,
          }),
        ),
        commonOptions: commonOptions,
        client: client,
      );
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: ${fetchErrorDetail(body)}',
        );
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = data['results'] as List;
      return SearchResult(
        items: results.map((item) {
          final result = item as Map<String, dynamic>;
          final summary = (result['summary'] ?? '').toString();
          var text = summary.trim().isNotEmpty
              ? summary
              : (result['snippet'] ?? '').toString();
          final rawDate = result['date'];
          final publishedAt = rawDate is String
              ? DateTime.tryParse(rawDate)
              : null;
          if (publishedAt != null && publishedAt.isUtc) {
            final date = publishedAt.toIso8601String().split('T').first;
            text = '[Published: $date] $text';
          }
          return SearchResultItem(
            title: (result['title'] ?? '').toString(),
            url: (result['url'] ?? '').toString(),
            text: text,
          );
        }).toList(),
      );
    } catch (e) {
      throw Exception('DeepSeek search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required DeepSeekOptions serviceOptions,
  }) async {
    try {
      final data = await postFetchJson(
        Uri.parse(fetchEndpoint),
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
        content: data['content'] as String,
      );
    } catch (e) {
      throw Exception('DeepSeek fetch failed: $e');
    }
  }
}
