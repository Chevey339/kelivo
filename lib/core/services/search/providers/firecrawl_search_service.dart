import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

/// Firecrawl Search (v2). Hosted `/v2/search` accepts keyless requests;
/// a Bearer API key is optional and only used for higher rate limits.
class FirecrawlSearchService extends SearchService<FirecrawlOptions>
    implements WebFetchCapable<FirecrawlOptions> {
  FirecrawlSearchService({super.client});

  @override
  String get name => 'Firecrawl';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderFirecrawlDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required FirecrawlOptions serviceOptions,
  }) async {
    try {
      final apiKey = serviceOptions
          .effectiveApiKey(serviceOptions.apiKey)
          .trim();

      final body = <String, dynamic>{
        'query': query,
        'limit': commonOptions.resultSize.clamp(1, 100),
        if (serviceOptions.sources.isNotEmpty)
          'sources': serviceOptions.sources
              .map((s) => {'type': s})
              .toList(growable: false),
        if (serviceOptions.categories.isNotEmpty)
          'categories': serviceOptions.categories
              .map((c) => {'type': c})
              .toList(growable: false),
        if (serviceOptions.country.trim().isNotEmpty)
          'country': serviceOptions.country.trim(),
        if (serviceOptions.location.trim().isNotEmpty)
          'location': serviceOptions.location.trim(),
      };

      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(serviceOptions.resolvedUrl),
              headers: {
                'Content-Type': 'application/json',
                if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(body),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'API request failed: ${response.statusCode} ${response.body}',
        );
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data =
          (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
      final items = <SearchResultItem>[];

      void addWeb(List? list) {
        if (list == null) return;
        for (final item in list) {
          if (item is! Map) continue;
          final m = item.cast<String, dynamic>();
          items.add(
            SearchResultItem(
              title: (m['title'] ?? '').toString(),
              url: (m['url'] ?? '').toString(),
              text: (m['description'] ?? m['snippet'] ?? m['markdown'] ?? '')
                  .toString(),
            ),
          );
          if (items.length >= commonOptions.resultSize) return;
        }
      }

      addWeb(data['web'] as List?);
      if (items.length < commonOptions.resultSize) {
        addWeb(data['news'] as List?);
      }

      return SearchResult(items: items.take(commonOptions.resultSize).toList());
    } catch (e) {
      throw Exception('Firecrawl search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required FirecrawlOptions serviceOptions,
  }) async {
    try {
      final apiKey = serviceOptions
          .effectiveApiKey(serviceOptions.apiKey)
          .trim();
      final endpoint = siblingFetchEndpoint(
        serviceOptions.resolvedUrl,
        searchPath: '/search',
        fetchPath: '/scrape',
      );
      final data = await postFetchJson(
        Uri.parse(endpoint),
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        body: {
          'url': url,
          'formats': ['markdown'],
          'onlyMainContent': true,
        },
        commonOptions: commonOptions,
      );
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'scrape failed');
      }
      final page = (data['data'] as Map).cast<String, dynamic>();
      final metadata = (page['metadata'] as Map?)?.cast<String, dynamic>();
      final title = metadata?['title'];
      return WebFetchPage(
        url: (metadata?['url'] ?? metadata?['sourceURL'] ?? url).toString(),
        title: (title is List ? title.firstOrNull : title)?.toString() ?? '',
        content: (page['markdown'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception('Firecrawl fetch failed: $e');
    }
  }
}
