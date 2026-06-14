import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class QueritSearchService extends SearchService<QueritOptions> {
  QueritSearchService({http.Client? client})
    : _client = client ?? http.Client();

  static const String endpoint = 'https://api.querit.ai/v1/search';

  final http.Client _client;

  @override
  String get name => 'Querit';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderQueritDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required QueritOptions serviceOptions,
  }) async {
    try {
      final apiKey = serviceOptions.apiKey.trim();
      if (apiKey.isEmpty) {
        throw Exception('Querit API key is required');
      }

      final body = <String, dynamic>{
        'query': query,
        'count': commonOptions.resultSize,
      };
      final filters = _buildFilters(serviceOptions);
      if (filters.isNotEmpty) {
        body['filters'] = filters;
      }

      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: commonOptions.timeout));

      if (response.statusCode != 200) {
        throw Exception(
          'API request failed: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final errorCode = data['error_code'];
      if (errorCode is int && errorCode != 200) {
        final message = data['error_msg']?.toString() ?? 'Unknown error';
        throw Exception('API request failed: $errorCode $message');
      }

      final results = (data['results'] as Map?)?['result'] as List?;
      final items = (results ?? const <dynamic>[])
          .take(commonOptions.resultSize)
          .map(_resultItem)
          .toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Querit search failed: $e');
    }
  }

  static Map<String, dynamic> _buildFilters(QueritOptions options) {
    final siteIncludes = _splitList(options.sitesInclude);
    final siteExcludes = _splitList(options.sitesExclude);
    final countries = _splitList(options.countries);
    final languages = _splitList(options.languages);
    final date = options.timeRange.trim();

    final filters = <String, dynamic>{};
    if (siteIncludes.isNotEmpty || siteExcludes.isNotEmpty) {
      filters['sites'] = <String, dynamic>{
        if (siteIncludes.isNotEmpty) 'include': siteIncludes,
        if (siteExcludes.isNotEmpty) 'exclude': siteExcludes,
      };
    }
    if (date.isNotEmpty) {
      filters['timeRange'] = {'date': date};
    }
    if (countries.isNotEmpty) {
      filters['geo'] = {
        'countries': {'include': countries},
      };
    }
    if (languages.isNotEmpty) {
      filters['languages'] = {'include': languages};
    }
    return filters;
  }

  static List<String> _splitList(String value) => value
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  static SearchResultItem _resultItem(Object? item) {
    final m = (item as Map).cast<String, dynamic>();
    final snippet = m['snippet']?.toString().trim() ?? '';
    final sourceSnippets =
        (m['snippets'] as List?) ??
        (m['sentence'] as List?) ??
        const <dynamic>[];
    final extraSnippets = sourceSnippets
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty && value != snippet)
        .toList();
    final textParts = <String>[
      if (snippet.isNotEmpty) snippet,
      ...extraSnippets,
    ];
    final url = m['url']?.toString() ?? '';
    final title = m['title']?.toString().trim() ?? '';

    return SearchResultItem(
      title: title.isNotEmpty ? title : url,
      url: url,
      text: textParts.join('\n\n'),
    );
  }
}
