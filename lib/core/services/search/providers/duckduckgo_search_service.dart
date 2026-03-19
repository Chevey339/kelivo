import 'package:ddgs/ddgs.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class DuckDuckGoSearchService extends SearchService<DuckDuckGoOptions> {
  @override
  String get name => 'DuckDuckGo';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderDuckDuckGoDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required DuckDuckGoOptions serviceOptions,
  }) async {
    final ddgs = DDGS(timeout: Duration(milliseconds: commonOptions.timeout));
    final region = serviceOptions.region.trim().isNotEmpty
        ? serviceOptions.region.trim()
        : 'us-en';

    try {
      final results = await ddgs.text(
        query,
        region: region,
        maxResults: commonOptions.resultSize,
        backend: 'duckduckgo',
      );

      final items = <SearchResultItem>[];
      for (final item in results) {
        final map = Map<String, dynamic>.from(item);
        final title = map['title']?.toString() ?? '';
        final url = map['href']?.toString() ?? map['url']?.toString() ?? '';
        final snippet =
            map['body']?.toString() ??
            map['description']?.toString() ??
            map['snippet']?.toString() ??
            map['content']?.toString() ??
            '';
        if (title.isEmpty && url.isEmpty && snippet.isEmpty) continue;
        items.add(SearchResultItem(title: title, url: url, text: snippet));
      }

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('DuckDuckGo search failed: $e');
    } finally {
      ddgs.close();
    }
  }
}
