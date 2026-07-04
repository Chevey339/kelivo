import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class TavilySearchService extends SearchService<TavilyOptions> {
  @override
  String get name => 'Tavily';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderTavilyDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required TavilyOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'query': query,
        'max_results': commonOptions.resultSize,
      });

      final response = await http
          .post(
            Uri.parse(serviceOptions.resolvedUrl),
            headers: {
              'Authorization': 'Bearer ${serviceOptions.apiKey}',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(Duration(milliseconds: commonOptions.timeout));

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final results = (data['results'] as List? ?? const <dynamic>[]).map((
        item,
      ) {
        return SearchResultItem(
          title: item['title'] ?? '',
          url: item['url'] ?? '',
          text: item['content'] ?? '',
        );
      }).toList();

      return SearchResult(answer: data['answer'], items: results);
    } catch (e) {
      throw Exception('Tavily search failed: $e');
    }
  }
}
