import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

/// TinyFish Search and Fetch APIs. Requires `X-API-Key`.
class TinyFishSearchService extends SearchService<TinyFishOptions>
    implements WebFetchCapable<TinyFishOptions> {
  static const String fetchEndpoint = 'https://api.fetch.tinyfish.ai';

  TinyFishSearchService({super.client});

  @override
  String get name => 'TinyFish';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderTinyFishDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required TinyFishOptions serviceOptions,
  }) async {
    try {
      final apiKey = serviceOptions
          .effectiveApiKey(serviceOptions.apiKey)
          .trim();
      if (apiKey.isEmpty) {
        throw Exception('TinyFish API key is required');
      }

      final params = <String, String>{
        'query': query,
        if (serviceOptions.location.trim().isNotEmpty)
          'location': serviceOptions.location.trim(),
        if (serviceOptions.language.trim().isNotEmpty)
          'language': serviceOptions.language.trim(),
        if (serviceOptions.includeDomains.trim().isNotEmpty)
          'include_domains': serviceOptions.includeDomains.trim(),
        if (serviceOptions.excludeDomains.trim().isNotEmpty)
          'exclude_domains': serviceOptions.excludeDomains.trim(),
      };

      final uri = Uri.parse(
        serviceOptions.resolvedUrl,
      ).replace(queryParameters: params);

      final response = await withHttpClient(
        (client) => client
            .get(uri, headers: {'X-API-Key': apiKey})
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'API request failed: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const <dynamic>[];
      final items = results.take(commonOptions.resultSize).map((item) {
        final m = (item as Map).cast<String, dynamic>();
        return SearchResultItem(
          title: (m['title'] ?? '').toString(),
          url: (m['url'] ?? '').toString(),
          text: (m['snippet'] ?? '').toString(),
        );
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('TinyFish search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required TinyFishOptions serviceOptions,
  }) async {
    try {
      final searchUri = Uri.parse(serviceOptions.resolvedUrl);
      final endpoint =
          searchUri.host == Uri.parse(TinyFishOptions.defaultUrl).host
          ? searchUri.replace(host: Uri.parse(fetchEndpoint).host).toString()
          : siblingFetchEndpoint(
              serviceOptions.resolvedUrl,
              searchPath: '/search',
              fetchPath: '/fetch',
            );
      final data = await postFetchJson(
        Uri.parse(endpoint),
        headers: {
          'X-API-Key': serviceOptions.effectiveApiKey(serviceOptions.apiKey),
        },
        body: {
          'urls': [url],
          'format': 'markdown',
        },
        commonOptions: commonOptions,
      );
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) {
        final errors = (data['errors'] as List?) ?? const [];
        throw Exception(
          errors.isEmpty
              ? 'no content returned'
              : (errors.first as Map)['error'],
        );
      }
      final page = (results.first as Map).cast<String, dynamic>();
      final text = page['text'];
      return WebFetchPage(
        url: (page['final_url'] ?? page['url'] ?? url).toString(),
        title: (page['title'] ?? '').toString(),
        content: text is String ? text : (text == null ? '' : jsonEncode(text)),
      );
    } catch (e) {
      throw Exception('TinyFish fetch failed: $e');
    }
  }
}
