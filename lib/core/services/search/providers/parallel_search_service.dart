import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class ParallelSearchService extends SearchService<ParallelOptions> {
  ParallelSearchService({super.client});

  static const String endpoint = 'https://api.parallel.ai/v1/search';

  @override
  String get name => 'Parallel';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderParallelDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required ParallelOptions serviceOptions,
  }) async {
    try {
      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(endpoint),
              headers: {
                'x-api-key': serviceOptions.effectiveApiKey(
                  serviceOptions.apiKey,
                ),
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'objective': query,
                'search_queries': [query],
                'mode': serviceOptions.mode,
              }),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const <dynamic>[];
      final items = results.take(commonOptions.resultSize).map((item) {
        final result = (item as Map).cast<String, dynamic>();
        final excerpts =
            (result['excerpts'] as List?)
                ?.map((excerpt) => excerpt.toString())
                .where((excerpt) => excerpt.trim().isNotEmpty)
                .join('\n\n') ??
            '';
        return SearchResultItem(
          title: (result['title'] ?? '').toString(),
          url: (result['url'] ?? '').toString(),
          text: excerpts,
        );
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Parallel search failed: $e');
    }
  }
}
