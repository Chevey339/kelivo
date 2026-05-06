import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class GrokSearchService extends SearchService<GrokOptions> {
  GrokSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get name => 'Grok';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderGrokDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required GrokOptions serviceOptions,
  }) async {
    try {
      if (serviceOptions.apiKey.trim().isEmpty) {
        throw Exception('Grok API key is required');
      }

      final body = <String, dynamic>{
        'model': serviceOptions.resolvedModel,
        'input': [
          {'role': 'system', 'content': serviceOptions.resolvedSystemPrompt},
          {'role': 'user', 'content': query},
        ],
        'tools': [
          {'type': 'web_search'},
          {'type': 'x_search'},
        ],
        'store': false,
      };

      final response = await _client
          .post(
            Uri.parse(serviceOptions.resolvedUrl),
            headers: {
              'Authorization': 'Bearer ${serviceOptions.apiKey.trim()}',
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
      final output = (data['output'] as List?) ?? const <dynamic>[];
      final message = output.cast<Object?>().whereType<Map>().firstWhere(
        (item) => item['type'] == 'message' && item['role'] == 'assistant',
        orElse: () => const <String, dynamic>{},
      );
      final content = (message['content'] as List?) ?? const <dynamic>[];
      final textContent = content.cast<Object?>().whereType<Map>().firstWhere(
        (item) => item['type'] == 'output_text',
        orElse: () => const <String, dynamic>{},
      );

      final seenUrls = <String>{};
      final annotations =
          (textContent['annotations'] as List?) ?? const <dynamic>[];
      final items = <SearchResultItem>[];
      for (final annotation in annotations.cast<Object?>().whereType<Map>()) {
        if (annotation['type'] != 'url_citation') continue;
        final url = annotation['url']?.toString().trim() ?? '';
        if (url.isEmpty || !seenUrls.add(url)) continue;
        items.add(
          SearchResultItem(
            title: annotation['title']?.toString().trim().isNotEmpty == true
                ? annotation['title'].toString()
                : url,
            url: url,
            text: '',
          ),
        );
        if (items.length >= commonOptions.resultSize) break;
      }

      return SearchResult(
        answer: textContent['text']?.toString(),
        items: items,
      );
    } catch (e) {
      throw Exception('Grok search failed: $e');
    }
  }
}
