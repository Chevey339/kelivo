import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class BingSearchService extends SearchService<BingLocalOptions> {
  BingSearchService({super.client, Locale? locale})
    : locale = locale ?? PlatformDispatcher.instance.locale;

  final Locale locale;

  static final _whitespace = RegExp(r'\s+');
  static final _countryCode = RegExp(r'^[a-z]{2}$');
  static final _baseUri = Uri.https('www.bing.com');

  @override
  String get name => 'Bing (Local)';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderBingLocalDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required BingLocalOptions serviceOptions,
  }) async {
    if (commonOptions.resultSize <= 0) return SearchResult(items: []);

    try {
      final language = locale.languageCode.toLowerCase();
      final country =
          locale.countryCode?.toLowerCase() ??
          (language == 'zh' && locale.scriptCode == 'Hant' ? 'tw' : null);
      // Follow SearXNG's Bing Web request, rather than its API locale helper:
      // https://github.com/searxng/searxng/commit/ffe96f8a6f46d61c8dd30b3327c370293d1a9a15
      // mkt and cc=us/cn/ru can cause Bing to return unrelated results.
      final uri = _baseUri.replace(
        path: '/search',
        queryParameters: {
          'q': query,
          'adlt': 'moderate',
          // SearXNG's Bing traits map zh-HK to the en-HK market.
          'setlang': language == 'zh' && country == 'hk' ? 'en' : language,
          if (country != null &&
              _countryCode.hasMatch(country) &&
              !const {'us', 'cn', 'ru'}.contains(country))
            'cc': country,
        },
      );
      final languageTag = locale.toLanguageTag();

      final response = await withHttpClient(
        (client) => client
            .get(
              uri,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': [
                  language,
                  if (languageTag != language) '$languageTag;q=0.7',
                  if (language != 'en') 'en;q=0.3',
                ].join(','),
                'Upgrade-Insecure-Requests': '1',
                'Sec-Fetch-Dest': 'document',
                'Sec-Fetch-Mode': 'navigate',
                'Sec-Fetch-Site': 'none',
                'Sec-Fetch-User': '?1',
              },
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch results: ${response.statusCode}');
      }

      final document = parser.parse(response.body);
      final results = <SearchResultItem>[];
      final seenUrls = <String>{};

      final elements = document.querySelectorAll('ol#b_results > li.b_algo');
      for (final element in elements) {
        for (final br in element.querySelectorAll('br')) {
          br.replaceWith(dom.Text(' '));
        }
        final linkElement = element.querySelector('h2 > a');
        if (linkElement == null) continue;
        final title = _cleanText(linkElement.text);
        final url = _resolveResultUrl(linkElement.attributes['href'] ?? '');
        if (title.isEmpty || url == null || !seenUrls.add(url)) continue;

        // Bing can split a caption across several paragraphs. Its decorative
        // labels (for example "Web") are not part of the source's summary.
        for (final icon in element.querySelectorAll('span.algoSlug_icon')) {
          icon.remove();
        }
        final paragraphs = element.querySelectorAll('p');
        final snippet = paragraphs.isNotEmpty
            ? paragraphs.map((p) => p.text).join(' ')
            : element.querySelector('.b_algoSlug')?.text ?? '';
        results.add(
          SearchResultItem(title: title, url: url, text: _cleanText(snippet)),
        );
        if (results.length >= commonOptions.resultSize) break;
      }

      if (results.isEmpty &&
          document.querySelector('ol#b_results .b_no') == null) {
        throw const FormatException(
          'Bing returned an unrecognized search page. Please retry later.',
        );
      }

      return SearchResult(items: results);
    } catch (e) {
      throw Exception('Bing search failed: $e');
    }
  }

  static String _cleanText(String text) =>
      text.replaceAll(_whitespace, ' ').trim();

  static String? _resolveResultUrl(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      var uri = _baseUri.resolve(raw.trim());
      if ((uri.host == 'bing.com' || uri.host.endsWith('.bing.com')) &&
          (uri.path == '/ck/a' || uri.path == '/ck/a/')) {
        final target = uri.queryParameters['u'];
        if (target != null && target.startsWith('a1')) {
          uri = Uri.parse(
            utf8.decode(
              base64Url.decode(base64Url.normalize(target.substring(2))),
            ),
          );
        }
      }
      if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
        return null;
      }
      return uri.toString();
    } on FormatException {
      // A malformed tracking link must not discard the other results.
      return null;
    }
  }
}
