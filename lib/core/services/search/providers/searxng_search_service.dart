import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class SearXNGSearchService extends SearchService<SearXNGOptions> {
  @override
  String get name => 'SearXNG';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderSearXNGDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required SearXNGOptions serviceOptions,
  }) async {
    try {
      if (serviceOptions.url.isEmpty) {
        throw Exception('SearXNG URL cannot be empty');
      }

      final baseUrl = serviceOptions.url.trimRight().replaceAll(
        RegExp(r'/$'),
        '',
      );
      final encodedQuery = Uri.encodeComponent(query);
      var url = '$baseUrl/search?q=$encodedQuery&format=json';

      if (serviceOptions.engines.isNotEmpty) {
        url += '&engines=${Uri.encodeComponent(serviceOptions.engines)}';
      }
      if (serviceOptions.language.isNotEmpty) {
        url += '&language=${Uri.encodeComponent(serviceOptions.language)}';
      }

      final headers = <String, String>{};
      if (serviceOptions.username.isNotEmpty &&
          serviceOptions.password.isNotEmpty) {
        final auth = base64Encode(
          utf8.encode('${serviceOptions.username}:${serviceOptions.password}'),
        );
        headers['Authorization'] = 'Basic $auth';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(milliseconds: commonOptions.timeout));

      if (response.statusCode != 200) {
        throw Exception('Request failed with status ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final results = (data['results'] as List? ?? const <dynamic>[])
          .take(commonOptions.resultSize)
          .map((item) {
            return SearchResultItem(
              title: item['title'] ?? '',
              url: item['url'] ?? '',
              text: item['content'] ?? '',
            );
          })
          .toList();

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('SearXNG search failed: $e');
    }
  }
}
