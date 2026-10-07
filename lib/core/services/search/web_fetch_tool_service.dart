import 'dart:convert';

import '../../providers/settings_provider.dart';
import 'web_fetch_service.dart';

/// The `fetch_url` tool offered next to `search_web`.
class WebFetchToolService {
  static const String toolName = 'fetch_url';

  /// Characters returned per call; longer pages continue with `start_index`.
  static const int pageSize = 10000;

  static const String toolDescription = '''
Read a web page and return its main content as Markdown.

Use this when:
- A search_web result looks relevant but its snippet is not enough
- The user shares a URL and asks about its content

Only fetch URLs that appear in the conversation: given by the user or returned by search_web. Pages behind logins or paywalls cannot be read.

Long pages come back in parts. When the response has `next_start_index`, call again with that value as `start_index` to keep reading.

Response format: url, title, content, total_length, and next_start_index when more content remains.''';

  static Map<String, dynamic> getToolDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': toolName,
        'description': toolDescription,
        'parameters': {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description':
                  'Full http(s) URL, exactly as it appears in the conversation',
            },
            'start_index': {
              'type': 'integer',
              'description': 'Character offset to continue a long page from',
              'default': 0,
              'minimum': 0,
            },
          },
          'required': ['url'],
        },
      },
    };
  }

  static Future<String> executeFetch(
    Map<String, dynamic> args,
    SettingsProvider settings,
  ) async {
    final url = (args['url'] ?? '').toString().trim();
    final startRaw = args['start_index'];
    final start = startRaw is num ? startRaw.toInt() : 0;
    if (start < 0) {
      return jsonEncode({'error': 'start_index must not be negative'});
    }
    final source = WebFetchService.resolve(
      mode: settings.webFetchMode,
      services: settings.searchServices,
      selectedIndex: settings.searchServiceSelected,
    );
    if (source == null) {
      return jsonEncode({'error': 'Reading web pages is turned off'});
    }
    try {
      final page = await WebFetchService.fetchCached(
        source,
        url,
        commonOptions: settings.searchCommonOptions,
      );
      return jsonEncode(window(page.url, page.title, page.content, start));
    } catch (e) {
      return jsonEncode({'error': 'Fetch failed: $e'});
    }
  }

  /// One [pageSize] slice of [content] starting at [start].
  static Map<String, dynamic> window(
    String url,
    String title,
    String content,
    int start,
  ) {
    if (start >= content.length) {
      return {
        'url': url,
        'title': title,
        'content': '',
        'total_length': content.length,
      };
    }
    var end = start + pageSize;
    if (end >= content.length) {
      end = content.length;
    } else if (_isHighSurrogate(content.codeUnitAt(end - 1))) {
      // Keep a surrogate pair together across the cut.
      end -= 1;
    }
    return {
      'url': url,
      'title': title,
      'content': content.substring(start, end),
      'total_length': content.length,
      if (end < content.length) 'next_start_index': end,
    };
  }

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
}
