import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class PerplexitySearchService extends SearchService<PerplexityOptions> {
  @override
  String get name => 'Perplexity';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(l10n.searchProviderPerplexityDescription, style: const TextStyle(fontSize: 12));
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required PerplexityOptions serviceOptions,
  }) async {
    try {
      final body = <String, dynamic>{
        'query': query,
        'max_results': commonOptions.resultSize.clamp(1, 20),
      };

      if (serviceOptions.country != null && serviceOptions.country!.trim().isNotEmpty) {
        body['country'] = serviceOptions.country!.trim();
      }
      if (serviceOptions.searchDomainFilter != null && serviceOptions.searchDomainFilter!.isNotEmpty) {
        body['search_domain_filter'] = serviceOptions.searchDomainFilter;
      }
      if (serviceOptions.maxTokensPerPage != null) {
        body['max_tokens_per_page'] = serviceOptions.maxTokensPerPage;
      }

      final response = await http
          .post(
            Uri.parse('https://api.perplexity.ai/search'),
            headers: {
              'Authorization': 'Bearer ${serviceOptions.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: commonOptions.timeout));

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = (data['results'] as List?) ?? const <dynamic>[];
      // Support both single-query (list of items) and multi-query (list of lists)
      final flat = <Map<String, dynamic>>[];
      for (final item in resultsList) {
        if (item is List) {
          for (final sub in item) {
            if (sub is Map<String, dynamic>) flat.add(sub);
          }
        } else if (item is Map<String, dynamic>) {
          flat.add(item);
        }
      }

      final items = flat.take(commonOptions.resultSize).map((m) {
        return SearchResultItem(
          title: (m['title'] ?? '').toString(),
          url: (m['url'] ?? '').toString(),
          text: (m['snippet'] ?? '').toString(),
        );
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Perplexity search failed: $e');
    }
  }
}

