import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class DoubaoSearchService extends SearchService<DoubaoOptions> {
  @override
  String get name => 'Doubao';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderDoubaoDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required DoubaoOptions serviceOptions,
  }) async {
    try {
      final body = jsonEncode({
        'Query': query,
        'DocCount': commonOptions.resultSize,
        'MaxSnippetLength': 1000,
        'MaxImageCountPerDoc': 0,
      });

      final response = await http
          .post(
            Uri.parse('https://open.feedcoopapi.com/search_api/global_search'),
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

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final metadata = data['ResponseMetadata'] as Map<String, dynamic>?;
      final error = metadata?['Error'] as Map<String, dynamic>?;
      if (error != null) {
        throw Exception(
          'API error ${error['Code']}: ${error['Message']}',
        );
      }

      final result = data['Result'] as Map<String, dynamic>?;
      if (result == null) {
        return SearchResult(items: []);
      }

      final documents = (result['Documents'] as List?) ?? const [];
      final items = documents.map((doc) {
        final m = (doc as Map).cast<String, dynamic>();
        final title = (m['Title'] ?? '').toString();
        final url = (m['Url'] ?? '').toString();

        // Extract text from snippets
        final snippets = (m['Snippet'] as List?) ?? const [];
        final textParts = <String>[];
        for (final snippet in snippets) {
          final s = (snippet as Map).cast<String, dynamic>();
          if (s['Type'] == 'text' && s['Text'] != null) {
            textParts.add(s['Text'].toString());
          }
        }
        final text = textParts.join('\n').trim();

        return SearchResultItem(title: title, url: url, text: text);
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Doubao search failed: $e');
    }
  }
}
