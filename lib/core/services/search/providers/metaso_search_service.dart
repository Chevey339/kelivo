import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class MetasoSearchService extends SearchService<MetasoOptions>
    implements WebFetchCapable<MetasoOptions> {
  MetasoSearchService({super.client});

  static const String readerUrl = 'https://metaso.cn/api/v1/reader';

  @override
  String get name => 'Metaso (秘塔)';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderMetasoDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required MetasoOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'q': query,
        'scope': 'webpage',
        'size': commonOptions.resultSize,
        'includeSummary': false,
      });

      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse('https://metaso.cn/api/v1/search'),
              headers: {
                'Authorization':
                    'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
                'Accept': 'application/json',
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
      final webpages = data['webpages'] as List? ?? [];
      final results = webpages.map((item) {
        return SearchResultItem(
          title: item['title'] ?? '',
          url: item['link'] ?? '',
          text: item['snippet'] ?? '',
        );
      }).toList();

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('Metaso search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required MetasoOptions serviceOptions,
  }) async {
    try {
      // The reader answers `text/plain` with the page as Markdown.
      final response = await withWebFetchClient(
        (client) => client.post(
          Uri.parse(readerUrl),
          headers: {
            'Authorization':
                'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
            'Accept': 'text/plain',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'url': url}),
        ),
        commonOptions: commonOptions,
        client: client,
      );
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode != 200) {
        final detail = fetchErrorDetail(text);
        throw Exception('HTTP ${response.statusCode}: $detail');
      }
      return WebFetchPage(
        url: url,
        title: firstMarkdownHeading(text),
        content: text,
      );
    } catch (e) {
      throw Exception('Metaso fetch failed: $e');
    }
  }
}
