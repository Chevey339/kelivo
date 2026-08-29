import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class BraveSearchService extends SearchService<BraveOptions> {
  BraveSearchService({super.client});

  static const String webEndpoint =
      'https://api.search.brave.com/res/v1/web/search';
  static const String llmContextEndpoint =
      'https://api.search.brave.com/res/v1/llm/context';

  @override
  String get name => 'Brave Search';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderBraveDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required BraveOptions serviceOptions,
  }) async {
    try {
      if (serviceOptions.mode == BraveOptions.llmContextMode) {
        return await _searchLlmContext(
          query: query,
          commonOptions: commonOptions,
          serviceOptions: serviceOptions,
        );
      }
      return await _searchWeb(
        query: query,
        commonOptions: commonOptions,
        serviceOptions: serviceOptions,
      );
    } catch (e) {
      throw Exception('Brave search failed: $e');
    }
  }

  Future<SearchResult> _searchWeb({
    required String query,
    required SearchCommonOptions commonOptions,
    required BraveOptions serviceOptions,
  }) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url =
        '$webEndpoint?q=$encodedQuery&count=${commonOptions.resultSize}';

    final response = await withHttpClient(
      (client) => client
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'X-Subscription-Token': serviceOptions.effectiveApiKey(
                serviceOptions.apiKey,
              ),
            },
          )
          .timeout(Duration(milliseconds: commonOptions.timeout)),
    );

    if (response.statusCode != 200) {
      throw Exception('API request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final webResults = data['web']?['results'] as List? ?? [];
    final results = webResults.map((item) {
      return SearchResultItem(
        title: item['title'] ?? '',
        url: item['url'] ?? '',
        text: item['description'] ?? '',
      );
    }).toList();

    return SearchResult(items: results);
  }

  Future<SearchResult> _searchLlmContext({
    required String query,
    required SearchCommonOptions commonOptions,
    required BraveOptions serviceOptions,
  }) async {
    final response = await withHttpClient(
      (client) => client
          .post(
            Uri.parse(llmContextEndpoint),
            headers: {
              'X-Subscription-Token': serviceOptions.effectiveApiKey(
                serviceOptions.apiKey,
              ),
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'q': query,
              'count': commonOptions.resultSize,
              'maximum_number_of_urls': commonOptions.resultSize,
              'maximum_number_of_tokens': serviceOptions.maximumNumberOfTokens,
            }),
          )
          .timeout(Duration(milliseconds: commonOptions.timeout)),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'API request failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final grounding = (data['grounding'] as Map?)?.cast<String, dynamic>();
    final generic = grounding?['generic'] as List? ?? const <dynamic>[];
    final items = generic.take(commonOptions.resultSize).map((item) {
      final result = (item as Map).cast<String, dynamic>();
      final snippets =
          (result['snippets'] as List?)
              ?.map((snippet) => snippet.toString().trim())
              .where((snippet) => snippet.isNotEmpty)
              .join('\n\n') ??
          '';
      return SearchResultItem(
        title: (result['title'] ?? '').toString(),
        url: (result['url'] ?? '').toString(),
        text: snippets,
      );
    }).toList();

    return SearchResult(items: items);
  }
}
