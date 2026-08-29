import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

/// AnySearch unified search API. Authentication is optional; anonymous
/// requests use the provider's shared per-IP quota.
class AnySearchSearchService extends SearchService<AnySearchOptions> {
  AnySearchSearchService({super.client});

  @override
  String get name => 'AnySearch';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderAnySearchDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required AnySearchOptions serviceOptions,
  }) async {
    try {
      final apiKey = serviceOptions
          .effectiveApiKey(serviceOptions.apiKey)
          .trim();
      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(serviceOptions.resolvedUrl),
              headers: {
                'Content-Type': 'application/json',
                if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'query': query,
                'max_results': commonOptions.resultSize.clamp(1, 20),
                'format': 'json',
              }),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'API request failed: ${response.statusCode} ${response.body}',
        );
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['code'] != null && payload['code'] != 0) {
        final message = (payload['message'] ?? 'Unknown API error').toString();
        final requestId = (payload['request_id'] ?? '').toString().trim();
        throw Exception(
          'API request failed: $message'
          '${requestId.isEmpty ? '' : ' (request_id: $requestId)'}',
        );
      }
      final data =
          (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
      final results = (data['results'] as List?) ?? const <dynamic>[];
      final items = results.map((item) {
        final result = (item as Map).cast<String, dynamic>();
        final snippet = (result['snippet'] ?? '').toString().trim();
        return SearchResultItem(
          title: (result['title'] ?? '').toString(),
          url: (result['url'] ?? '').toString(),
          text: snippet.isNotEmpty
              ? snippet
              : (result['content'] ?? '').toString(),
        );
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('AnySearch search failed: $e');
    }
  }
}
