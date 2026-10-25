import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'search_service.dart';
import '../../providers/settings_provider.dart';

class SearchToolService {
  static const String toolName = 'search_web';
  static const String toolDescription = '''
Search the web for current information, news, and real-time data.

Use this when:
- The user asks about recent events, current prices, or live data
- You need to verify facts you are uncertain about or that may have changed
- The user references something you don't have context on (products, people, docs, APIs)

Don't use for:
- Math, code reasoning, or things you can answer from your training
- Well-known facts unlikely to have changed

Write focused keyword queries, not full sentences. You may call this multiple times to broaden coverage:
- If the topic likely has more authoritative sources in another language (English for tech/scientific topics, the local language for regional news), repeat the search with the query translated into that language.
- If the first results miss an angle, refine with synonyms or sub-aspects.

Response format:
- items[]: search results, each with index (result number), id (short unique id), title, url, text
- answer: an optional pre-synthesized answer (may be absent)

Cite: append [cite:id] immediately after each statement a result supports, using that result's exact `id` field.''';

  static final RegExp _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

  static String _normalizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;

    // Strip surrounding quotes if the backend returns a JSON-ish value.
    if ((u.startsWith('"') && u.endsWith('"')) ||
        (u.startsWith("'") && u.endsWith("'"))) {
      u = u.substring(1, u.length - 1).trim();
    }
    if (u.isEmpty) return u;

    // Protocol-relative URL (e.g. //example.com/path)
    if (u.startsWith('//')) return 'https:$u';

    // No scheme => default to https.
    if (!_schemeRe.hasMatch(u)) return 'https://$u';
    return u;
  }

  static Map<String, dynamic> getToolDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': toolName,
        'description': toolDescription,
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query to look up online',
            },
          },
          'required': ['query'],
        },
      },
    };
  }

  static Future<String> executeSearch(
    String query,
    SettingsProvider settings,
  ) async {
    try {
      // Get selected search service
      final services = settings.searchServices;
      if (services.isEmpty) {
        return jsonEncode({'error': 'No search services configured'});
      }

      final selectedIndex = settings.searchServiceSelected.clamp(
        0,
        services.length - 1,
      );
      final service = SearchService.getService(
        services[selectedIndex],
        locale: settings.effectiveLocale,
      );

      // Execute search
      final result = await service.search(
        query: query,
        commonOptions: settings.searchCommonOptions,
        serviceOptions: services[selectedIndex],
      );

      // Add unique IDs to each result item
      final itemsWithIds = result.items.asMap().entries.map((entry) {
        final item = entry.value;
        return SearchResultItem(
          title: item.title,
          url: _normalizeUrl(item.url),
          text: item.text,
          id: const Uuid().v4().substring(0, 6),
          index: entry.key + 1,
        );
      }).toList();

      // Return formatted result
      return jsonEncode({
        if (result.answer != null) 'answer': result.answer,
        'items': itemsWithIds.map((item) => item.toJson()).toList(),
      });
    } catch (e) {
      return jsonEncode({'error': 'Search failed: $e'});
    }
  }

  static String getSystemPrompt() {
    return '''
<citations>
When a statement in your answer is based on a search_web result, append a citation marker immediately after that statement: [cite:id], where id is the exact `id` field of the supporting result item.
- Example: "The event took place yesterday afternoon. [cite:a1b2c3]"
- Chain markers when several results support one statement: [cite:a1b2c3][cite:d4e5f6]
- Copy ids exactly as returned by the tool. Never invent, renumber, or reuse ids from other results.
- Place markers inline right after the supported statement (after its punctuation). Do not collect them at the end of the response, and do not add a "References" or "Sources" section — the app renders citations from the inline markers.
- Statements from your own knowledge take no marker.
</citations>
''';
  }
}
