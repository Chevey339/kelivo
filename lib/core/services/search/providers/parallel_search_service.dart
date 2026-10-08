import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp_client/mcp_client.dart' as mcp;

import '../../../../l10n/app_localizations.dart';
import '../../network/dio_http_client.dart';
import '../search_service.dart';
import '../web_fetch.dart';

/// Parallel search provider.
///
/// When an API key is configured, uses the REST API at `api.parallel.ai`
/// for full control over search mode and higher rate limits.
///
/// Without an API key, falls back to the free hosted MCP server at
/// `search.parallel.ai/mcp` — no signup required, lower rate limits.
class ParallelSearchService extends SearchService<ParallelOptions>
    implements WebFetchCapable<ParallelOptions> {
  static const String restSearchEndpoint = 'https://api.parallel.ai/v1/search';
  static const String restExtractEndpoint =
      'https://api.parallel.ai/v1/extract';
  static const String mcpEndpoint = 'https://search.parallel.ai/mcp';

  ParallelSearchService({super.client});

  @override
  String get name => 'Parallel';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderParallelDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required ParallelOptions serviceOptions,
  }) async {
    final apiKey = serviceOptions.effectiveApiKey(serviceOptions.apiKey).trim();
    if (apiKey.isEmpty) {
      return _searchViaMcp(query, commonOptions, serviceOptions);
    }
    return _searchViaRest(query, commonOptions, serviceOptions, apiKey);
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required ParallelOptions serviceOptions,
  }) async {
    final apiKey = serviceOptions.effectiveApiKey(serviceOptions.apiKey).trim();
    if (apiKey.isEmpty) {
      return _fetchViaMcp(url, commonOptions, serviceOptions);
    }
    return _fetchViaRest(url, commonOptions, serviceOptions, apiKey);
  }

  // --- REST API path (requires API key) ---

  Future<SearchResult> _searchViaRest(
    String query,
    SearchCommonOptions commonOptions,
    ParallelOptions serviceOptions,
    String apiKey,
  ) async {
    try {
      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(restSearchEndpoint),
              headers: {
                'x-api-key': apiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'objective': query,
                'search_queries': [query],
                'mode': serviceOptions.mode,
              }),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const <dynamic>[];
      final items = results.take(commonOptions.resultSize).map((item) {
        final result = (item as Map).cast<String, dynamic>();
        final excerpts =
            (result['excerpts'] as List?)
                ?.map((excerpt) => excerpt.toString())
                .where((excerpt) => excerpt.trim().isNotEmpty)
                .join('\n\n') ??
            '';
        return SearchResultItem(
          title: (result['title'] ?? '').toString(),
          url: (result['url'] ?? '').toString(),
          text: excerpts,
        );
      }).toList();

      return SearchResult(items: items);
    } catch (e) {
      throw Exception('Parallel search failed: $e');
    }
  }

  Future<WebFetchPage> _fetchViaRest(
    String url,
    SearchCommonOptions commonOptions,
    ParallelOptions serviceOptions,
    String apiKey,
  ) async {
    try {
      final data = await postFetchJson(
        Uri.parse(restExtractEndpoint),
        headers: {'x-api-key': apiKey},
        body: {
          'urls': [url],
          'advanced_settings': {'full_content': true},
        },
        commonOptions: commonOptions,
      );
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) {
        final errors = (data['errors'] as List?) ?? const [];
        final error = errors.isEmpty ? null : errors.first as Map;
        throw Exception(
          error == null
              ? 'no content returned'
              : '${error['error_type']} ${error['http_status_code'] ?? ''}'
                    .trim(),
        );
      }
      final page = (results.first as Map).cast<String, dynamic>();
      return WebFetchPage(
        url: (page['url'] ?? url).toString(),
        title: (page['title'] ?? '').toString(),
        content: (page['full_content'] ?? '').toString(),
      );
    } catch (e) {
      throw Exception('Parallel fetch failed: $e');
    }
  }

  // --- MCP path (free, no API key) ---

  Future<SearchResult> _searchViaMcp(
    String query,
    SearchCommonOptions commonOptions,
    ParallelOptions serviceOptions,
  ) async {
    final limit = commonOptions.resultSize < 1 ? 1 : commonOptions.resultSize;
    try {
      final text = await _callMcpTool(
        'web_search',
        {
          'objective': query,
          'search_queries': [query],
        },
        commonOptions: commonOptions,
        serviceOptions: serviceOptions,
      );
      return SearchResult(items: _parseMcpResults(text).take(limit).toList());
    } catch (error) {
      final detail = error is StateError ? error.message : error.toString();
      throw Exception('Parallel search failed: $detail');
    }
  }

  Future<WebFetchPage> _fetchViaMcp(
    String url,
    SearchCommonOptions commonOptions,
    ParallelOptions serviceOptions,
  ) async {
    try {
      final text = await _callMcpTool(
        'web_fetch',
        {
          'urls': [url],
          'objective': 'Extract the full page content.',
        },
        commonOptions: commonOptions,
        serviceOptions: serviceOptions,
      );
      return _parseMcpPage(text, fallbackUrl: url);
    } catch (error) {
      final detail = error is StateError ? error.message : error.toString();
      throw Exception('Parallel fetch failed: $detail');
    }
  }

  Future<String> _callMcpTool(
    String tool,
    Map<String, dynamic> arguments, {
    required SearchCommonOptions commonOptions,
    required ParallelOptions serviceOptions,
  }) async {
    final timeout = Duration(milliseconds: commonOptions.timeout);
    final cancellation = CancelToken();
    final ownsHttpClient = client == null;
    final httpClient = client ?? DioHttpClient(cancelToken: cancellation);

    try {
      final transport = await mcp.StreamableHttpClientTransport.create(
        baseUrl: mcpEndpoint,
        httpClient: _BorrowedHttpClient(httpClient),
        timeout: timeout,
        terminateOnClose: false,
      );
      final mcpClient = mcp.Client(
        name: 'Kelivo',
        version: '1.0.0',
        requestTimeout: timeout,
      );
      final elapsed = Stopwatch()..start();
      try {
        await mcpClient.connect(transport);
        final remaining = timeout - elapsed.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('Parallel MCP $tool timed out', timeout);
        }
        mcpClient.setRequestTimeout(remaining);
        final result = await mcpClient.callTool(tool, arguments);
        final text = result.content
            .whereType<mcp.TextContent>()
            .map((content) => content.text)
            .where((text) => text.trim().isNotEmpty)
            .join('\n\n---\n\n');
        if (result.isError == true) {
          throw StateError(
            text.trim().isEmpty ? 'Parallel MCP tool failed' : text.trim(),
          );
        }
        return text;
      } finally {
        mcpClient.dispose();
        transport.close();
      }
    } finally {
      cancellation.cancel('Parallel MCP $tool finished');
      if (ownsHttpClient) httpClient.close();
    }
  }

  List<SearchResultItem> _parseMcpResults(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty ||
        normalized.startsWith('No search results found.')) {
      return [];
    }

    final items = <SearchResultItem>[];
    // Split only on horizontal rules to separate results.
    final blocks = normalized.split('\n---\n');
    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      // Find URL line.
      final urlMatch = RegExp(r'URL:\s*(\S+)').firstMatch(trimmed);
      if (urlMatch == null) continue;

      // Title is the first markdown heading or "Title:" line before the URL.
      final titleMatch = RegExp(
        r'#{1,3}\s+(.+?)(?:\n|$)|Title:\s*(.+?)(?:\n|$)',
      ).firstMatch(trimmed);
      final title = (titleMatch?.group(1) ?? titleMatch?.group(2) ?? '').trim();

      final url = urlMatch.group(1)!.trim();
      final excerpt = trimmed.substring(urlMatch.end).trim();

      items.add(SearchResultItem(title: title, url: url, text: excerpt));
    }
    return items;
  }

  WebFetchPage _parseMcpPage(String text, {required String fallbackUrl}) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final header = RegExp(
      r'^#{1,3}\s+(.*)\nURL:\s*(\S+)',
      multiLine: true,
    ).firstMatch(normalized);
    if (header == null) {
      throw StateError(normalized.isEmpty ? 'no content returned' : normalized);
    }
    return WebFetchPage(
      url: header.group(2)!.trim(),
      title: header.group(1)!.trim(),
      content: normalized.substring(header.end).trim(),
    );
  }
}

// The transport closes its HTTP client; ownership stays with the search call.
class _BorrowedHttpClient extends http.BaseClient {
  _BorrowedHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    // Intentionally empty: the caller owns the underlying client lifecycle.
  }
}
