import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class LinkUpSearchService extends SearchService<LinkUpOptions>
    implements WebFetchCapable<LinkUpOptions> {
  LinkUpSearchService({super.client});

  static const String fetchUrl = 'https://api.linkup.so/v1/fetch';

  @override
  String get name => 'LinkUp';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderLinkUpDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required LinkUpOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'q': query,
        'depth': 'standard',
        'outputType': 'sourcedAnswer',
        'includeImages': 'false',
      });

      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse('https://api.linkup.so/v1/search'),
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
      final sources = data['sources'] as List? ?? [];
      final results = sources.take(commonOptions.resultSize).map((item) {
        return SearchResultItem(
          title: item['name'] ?? '',
          url: item['url'] ?? '',
          text: item['snippet'] ?? '',
        );
      }).toList();

      return SearchResult(answer: data['answer'], items: results);
    } catch (e) {
      throw Exception('LinkUp search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required LinkUpOptions serviceOptions,
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
      final content = (data['markdown'] ?? '').toString();
      return WebFetchPage(
        url: url,
        title: firstMarkdownHeading(content),
        content: content,
      );
    } catch (e) {
      throw Exception('LinkUp fetch failed: $e');
    }
  }
}
