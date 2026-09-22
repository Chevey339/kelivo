import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class KimiSearchService extends SearchService<KimiOptions> {
  KimiSearchService({super.client});

  static const String baseUrl = 'https://api.moonshot.cn/v1/tools';

  @override
  String get name => 'Kimi';

  @override
  Widget description(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.searchProviderKimiDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required KimiOptions serviceOptions,
  }) async {
    try {
      final mode = KimiOptions.normalizeMode(serviceOptions.mode);
      final endpoint = mode == 'basic' ? 'search' : 'search_pro';
      final limit = commonOptions.resultSize.clamp(1, 20);
      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse('$baseUrl/$endpoint'),
              headers: {
                'Authorization':
                    'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'text_query': query,
                'limit': limit,
                'timeout_seconds': (commonOptions.timeout / 1000).ceil().clamp(
                  1,
                  60,
                ),
              }),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        final requestId = response.headers['x-msh-track-id'] ?? '';
        throw Exception(
          'API request failed: ${response.statusCode} ${response.body}'
          '${requestId.isEmpty ? '' : ' (request_id: $requestId)'}',
        );
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final results = data['search_results'] as List;
      final items = results.take(limit).map((item) {
        final result = item as Map;
        final chunks = (result['chunks'] as List?) ?? const [];
        final content = chunks
            .map((chunk) => ((chunk as Map)['text'] ?? '').toString().trim())
            .where((text) => text.isNotEmpty)
            .join('\n\n');
        return SearchResultItem(
          title: (result['title'] ?? '').toString(),
          url: (result['url'] ?? '').toString(),
          text: content.isNotEmpty
              ? content
              : (result['snippet'] ?? '').toString(),
        );
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Kimi search failed: $e');
    }
  }
}
