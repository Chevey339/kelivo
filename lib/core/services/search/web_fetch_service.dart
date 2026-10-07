import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../mcp/kelivo_fetch/kelivo_fetch_server.dart';
import 'search_service.dart';
import 'web_fetch.dart';

/// Stored values of the web fetch setting. Any other value is the id of the
/// search service pinned for reading pages.
abstract final class WebFetchMode {
  /// Use the selected search service when it can read pages, else local.
  static const follow = 'follow';
  static const local = 'local';
  static const off = 'off';
}

/// Where a page is read from.
sealed class WebFetchSource {
  const WebFetchSource();
}

/// The device requests the page itself and converts it to Markdown.
final class LocalWebFetchSource extends WebFetchSource {
  const LocalWebFetchSource();
}

/// A configured search service reads the page through its own API.
final class ProviderWebFetchSource extends WebFetchSource {
  const ProviderWebFetchSource(this.options);

  final SearchServiceOptions options;
}

abstract final class WebFetchService {
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _cacheCapacity = 8;
  static final Map<String, ({WebFetchPage page, DateTime fetchedAt})> _cache =
      {};
  static final Map<String, Future<WebFetchPage>> _pending = {};

  static bool supports(SearchServiceOptions options) =>
      SearchService.getService(options) is WebFetchCapable;

  static String effectiveMode(
    String mode,
    List<SearchServiceOptions> services,
  ) {
    if (mode == WebFetchMode.follow ||
        mode == WebFetchMode.local ||
        mode == WebFetchMode.off ||
        services.any((s) => s.id == mode && supports(s))) {
      return mode;
    }
    return WebFetchMode.follow;
  }

  /// Whether a provider type (`SearchServiceOptions.toJson()['type']`) can
  /// read pages, for pickers that list types before a service exists.
  static bool supportsType(String type) => supports(
    SearchServiceOptions.fromJson({
      'type': type,
      'id': '',
      'apiKey': '',
      'url': '',
    }),
  );

  /// Resolves the stored [mode] against the configured services. Returns
  /// null when reading pages is off. A pinned service that was removed or
  /// cannot read pages falls back to following the search selection.
  static WebFetchSource? resolve({
    required String mode,
    required List<SearchServiceOptions> services,
    required int selectedIndex,
  }) {
    if (mode == WebFetchMode.off) return null;
    if (mode == WebFetchMode.local) return const LocalWebFetchSource();
    if (mode != WebFetchMode.follow) {
      for (final service in services) {
        if (service.id == mode && supports(service)) {
          return ProviderWebFetchSource(service);
        }
      }
    }
    if (services.isEmpty) return const LocalWebFetchSource();
    final selected = services[selectedIndex.clamp(0, services.length - 1)];
    return supports(selected)
        ? ProviderWebFetchSource(selected)
        : const LocalWebFetchSource();
  }

  /// Reads [url] from [source]. Content is trimmed and capped at
  /// [webFetchMaxContentLength]; an empty page is an error.
  static Future<WebFetchPage> fetch(
    WebFetchSource source,
    String url, {
    required SearchCommonOptions commonOptions,
    http.Client? client,
  }) async {
    final uri = _parseUrl(url);
    final page = switch (source) {
      LocalWebFetchSource() => await _fetchLocally(
        uri,
        commonOptions: commonOptions,
        client: client,
      ),
      ProviderWebFetchSource(:final options) =>
        await (SearchService.getService(options) as WebFetchCapable).fetch(
          url: uri.toString(),
          commonOptions: commonOptions,
          serviceOptions: options,
        ),
    };
    var content = page.content.trim();
    if (content.isEmpty) {
      throw StateError('The page has no readable content');
    }
    if (content.length > webFetchMaxContentLength) {
      var end = webFetchMaxContentLength;
      final last = content.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      content = content.substring(0, end);
    }
    return WebFetchPage(
      url: page.url.trim().isEmpty ? uri.toString() : page.url.trim(),
      title: page.title.trim(),
      content: content,
    );
  }

  /// [fetch] behind a short-lived cache, so a model continuing a long page
  /// does not pay for the same provider request again.
  static Future<WebFetchPage> fetchCached(
    WebFetchSource source,
    String url, {
    required SearchCommonOptions commonOptions,
    http.Client? client,
  }) async {
    final normalizedUrl = _parseUrl(url).toString();
    final key = jsonEncode([_sourceKey(source), normalizedUrl]);
    final now = DateTime.now();
    _cache.removeWhere((_, v) => now.difference(v.fetchedAt) > _cacheTtl);
    final hit = _cache[key];
    if (hit != null) return hit.page;
    final pending = _pending[key];
    if (pending != null) return pending;
    final request = fetch(
      source,
      normalizedUrl,
      commonOptions: commonOptions,
      client: client,
    );
    _pending[key] = request;
    try {
      final page = await request;
      if (identical(_pending[key], request)) {
        final entry = (page: page, fetchedAt: DateTime.now());
        _cache[key] = entry;
        // Providers may return a canonical URL after a redirect. A model will
        // use that URL to continue reading the same snapshot.
        final returnedUri = Uri.tryParse(page.url);
        if (returnedUri != null &&
            returnedUri.host.isNotEmpty &&
            (returnedUri.isScheme('http') || returnedUri.isScheme('https'))) {
          final returnedKey = jsonEncode([
            _sourceKey(source),
            returnedUri.toString(),
          ]);
          _cache[returnedKey] = entry;
        }
        while (_cache.length > _cacheCapacity) {
          _cache.remove(_cache.keys.first);
        }
      }
      return page;
    } finally {
      if (identical(_pending[key], request)) _pending.remove(key);
    }
  }

  static void clearCache() {
    _cache.clear();
    _pending.clear();
  }

  static String _sourceKey(WebFetchSource source) => switch (source) {
    LocalWebFetchSource() => WebFetchMode.local,
    ProviderWebFetchSource(:final options) => jsonEncode(options.toJson()),
  };

  static Uri _parseUrl(String url) {
    final raw = url.trim();
    var uri = Uri.tryParse(raw);
    if (uri != null && !uri.hasScheme && raw.isNotEmpty) {
      uri = Uri.tryParse(raw.startsWith('//') ? 'https:$raw' : 'https://$raw');
    }
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw FormatException('Invalid URL: $url');
    }
    return uri;
  }

  static Future<WebFetchPage> _fetchLocally(
    Uri uri, {
    required SearchCommonOptions commonOptions,
    http.Client? client,
  }) async {
    try {
      final response = await withWebFetchClient(
        (client) =>
            client.get(uri, headers: {'User-Agent': KelivoFetcher.userAgent}),
        commonOptions: commonOptions,
        client: client,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final readable = KelivoFetcher.readablePage(response);
      return WebFetchPage(
        url: uri.toString(),
        title: readable.title,
        content: readable.content,
      );
    } catch (e) {
      throw Exception('Local fetch failed: $e');
    }
  }
}
