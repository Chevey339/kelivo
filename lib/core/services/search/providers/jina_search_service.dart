import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class JinaSearchService extends SearchService<JinaOptions>
    implements WebFetchCapable<JinaOptions> {
  JinaSearchService({super.client});

  static const String readerUrl = 'https://r.jina.ai/';

  @override
  String get name => 'Jina';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderJinaDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required JinaOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({'q': query});

      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse('https://s.jina.ai/'),
              headers: {
                'Authorization':
                    'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                // Speed up and reduce payload: omit page content in response
                // 'X-Respond-With': 'no-content',
                // Some gateways behave better with a standard UA
                // 'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              },
              body: body,
            )
            .timeout(
              Duration(
                milliseconds: commonOptions.timeout < 15000
                    ? 15000
                    : commonOptions.timeout,
              ),
            ),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Jina typically returns { data: [...] }. Be permissive in case of variant shapes.
      final listRaw =
          (data['data'] ?? data['results'] ?? const <dynamic>[]) as List;
      final list = listRaw;
      final results = list.take(commonOptions.resultSize).map((item) {
        final m = (item as Map).cast<String, dynamic>();
        return SearchResultItem(
          title: (m['title'] ?? '').toString(),
          url: (m['url'] ?? '').toString(),
          text: (m['description'] ?? '').toString(),
        );
      }).toList();

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('Jina search failed: $e');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required JinaOptions serviceOptions,
  }) async {
    try {
      final apiKey = serviceOptions
          .effectiveApiKey(serviceOptions.apiKey)
          .trim();
      final data = await postFetchJson(
        Uri.parse(readerUrl),
        headers: {
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          // Image links only cost tokens; the model reads the text.
          'X-Retain-Images': 'none',
        },
        body: {'url': url},
        commonOptions: commonOptions,
      );
      final page = (data['data'] as Map?)?.cast<String, dynamic>();
      if (page == null) throw Exception(fetchErrorDetail(jsonEncode(data)));
      return WebFetchPage(
        url: (page['url'] ?? url).toString(),
        title: (page['title'] ?? '').toString(),
        content: (page['content'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception('Jina fetch failed: $e');
    }
  }
}
