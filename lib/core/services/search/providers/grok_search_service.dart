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
        'stream': false,
      };
      final reasoningEffort = serviceOptions.resolvedReasoningEffort;
      if (reasoningEffort.isNotEmpty) {
        body['reasoning'] = {'effort': reasoningEffort};
      }

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

      final items = <SearchResultItem>[];
      _addCitationItems(
        items: items,
        citations: data['citations'],
        maxItems: commonOptions.resultSize,
      );
      if (items.length < commonOptions.resultSize) {
        _addCitationItems(
          items: items,
          citations: textContent['annotations'],
          maxItems: commonOptions.resultSize,
        );
      }

      return SearchResult(
        answer: textContent['text']?.toString(),
        items: items,
      );
    } catch (e) {
      throw Exception('Grok search failed: $e');
    }
  }

  static void _addCitationItems({
    required List<SearchResultItem> items,
    required Object? citations,
    required int maxItems,
  }) {
    final seenUrls = items.map((item) => item.url).toSet();
    final citationList = (citations as List?) ?? const <dynamic>[];
    for (final citation in citationList) {
      final item = _citationItem(citation);
      if (item == null || !seenUrls.add(item.url)) continue;
      items.add(item);
      if (items.length >= maxItems) return;
    }
  }

  static SearchResultItem? _citationItem(Object? citation) {
    if (citation is String) {
      final url = citation.trim();
      if (url.isEmpty) return null;
      return SearchResultItem(title: url, url: url, text: '');
    }

    if (citation is! Map || citation['type'] != 'url_citation') {
      return null;
    }
    final url = citation['url']?.toString().trim() ?? '';
    if (url.isEmpty) return null;
    final title = citation['title']?.toString().trim();
    return SearchResultItem(
      title: title?.isNotEmpty == true ? title! : url,
      url: url,
      text: '',
    );
  }
}
