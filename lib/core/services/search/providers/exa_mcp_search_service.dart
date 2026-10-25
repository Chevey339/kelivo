import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp_client/mcp_client.dart' as mcp;

import '../../../../l10n/app_localizations.dart';
import '../../network/dio_http_client.dart';
import '../search_service.dart';
import '../web_fetch.dart';

class ExaMcpSearchService extends SearchService<ExaMcpOptions>
    implements WebFetchCapable<ExaMcpOptions> {
  ExaMcpSearchService({super.client});

  @override
  String get name => 'Exa MCP';

  @override
  Widget description(BuildContext context) => Text(
    AppLocalizations.of(context)!.searchProviderExaMcpDescription,
    style: const TextStyle(fontSize: 12),
  );

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required ExaMcpOptions serviceOptions,
  }) async {
    final limit = commonOptions.resultSize < 1 ? 1 : commonOptions.resultSize;
    try {
      final text = await _callTool(
        'web_search_exa',
        {'query': query, 'numResults': limit},
        commonOptions: commonOptions,
        serviceOptions: serviceOptions,
      );
      return SearchResult(items: _parseResults(text).take(limit).toList());
    } catch (error) {
      final detail = error is StateError ? error.message : error.toString();
      throw Exception('Exa MCP search failed: $detail');
    }
  }

  @override
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required ExaMcpOptions serviceOptions,
  }) async {
    try {
      final text = await _callTool(
        'web_fetch_exa',
        {
          'urls': [url],
          'maxCharacters': webFetchMaxContentLength,
        },
        commonOptions: commonOptions,
        serviceOptions: serviceOptions,
      );
      return _parsePage(text);
    } catch (error) {
      final detail = error is StateError ? error.message : error.toString();
      throw Exception('Exa MCP fetch failed: $detail');
    }
  }

  /// Calls one hosted Exa tool and returns its joined text content.
  Future<String> _callTool(
    String tool,
    Map<String, dynamic> arguments, {
    required SearchCommonOptions commonOptions,
    required ExaMcpOptions serviceOptions,
  }) async {
    final timeout = Duration(milliseconds: commonOptions.timeout);
    final apiKey = serviceOptions.effectiveApiKey(serviceOptions.apiKey).trim();
    final cancellation = CancelToken();
    final ownsHttpClient = client == null;
    final httpClient = client ?? DioHttpClient(cancelToken: cancellation);

    try {
      final transport = await mcp.StreamableHttpClientTransport.create(
        baseUrl: serviceOptions.resolvedUrl,
        headers: {if (apiKey.isNotEmpty) 'x-api-key': apiKey},
        httpClient: _BorrowedHttpClient(httpClient),
        timeout: timeout,
        terminateOnClose: false,
      );
      final client = mcp.Client(
        name: 'Kelivo',
        version: '1.0.0',
        requestTimeout: timeout,
      );
      final elapsed = Stopwatch()..start();
      try {
        await client.connect(transport);
        final remaining = timeout - elapsed.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('Exa MCP $tool timed out', timeout);
        }
        client.setRequestTimeout(remaining);
        final result = await client.callTool(tool, arguments);
        final text = result.content
            .whereType<mcp.TextContent>()
            .map((content) => content.text)
            .where((text) => text.trim().isNotEmpty)
            .join('\n\n---\n\n');
        if (result.isError == true) {
          throw StateError(
            text.trim().isEmpty ? 'Exa MCP tool failed' : text.trim(),
          );
        }
        return text;
      } finally {
        client.dispose();
        transport.close();
      }
    } finally {
      // DioHttpClient.close preserves in-flight requests. This token belongs
      // only to this call, so cancellation also releases stalled requests.
      cancellation.cancel('Exa MCP $tool finished');
      if (ownsHttpClient) httpClient.close();
    }
  }

  /// Parses `web_fetch_exa` output: `# Title`, a `URL:` line, then the page.
  WebFetchPage _parsePage(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final header = RegExp(
      r'^#[ \t]*(.*)\nURL:[ \t]*(\S+)[ \t]*(?:\n|$)',
    ).firstMatch(normalized);
    if (header == null) {
      // Quota and crawl errors come back as plain text without isError.
      throw StateError(normalized.isEmpty ? 'no content returned' : normalized);
    }
    return WebFetchPage(
      url: header.group(2)!,
      title: header.group(1)!.trim(),
      content: normalized.substring(header.end).trim(),
    );
  }

  List<SearchResultItem> _parseResults(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty ||
        normalized.startsWith('No search results found.')) {
      return [];
    }

    // Require Exa's complete metadata header: pages can themselves contain
    // horizontal rules followed by Title/URL examples in the result content.
    final headers = RegExp(
      r'(?:^|\n[ \t]*\n---[ \t]*\n[ \t]*\n)'
      r'Title:[ \t]*(.*)\nURL:[ \t]*(\S+)[ \t]*\n'
      r'Published:[^\n]*\nAuthor:[^\n]*(?=\n|$)',
    ).allMatches(normalized).toList();
    if (headers.isEmpty) {
      // The hosted server also returns quota errors as plain text without
      // setting isError. Keep that actionable message instead of empty results.
      throw StateError(normalized);
    }

    final results = <SearchResultItem>[];
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      final url = header.group(2)!;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const FormatException('Exa MCP returned an invalid result URL');
      }
      final hasNext = index + 1 < headers.length;
      final body = normalized.substring(
        header.end,
        hasNext ? headers[index + 1].start : normalized.length,
      );
      final marker = RegExp(
        r'^(?:Highlights|Text):[ \t]*',
        multiLine: true,
      ).firstMatch(body);
      final title = header.group(1)!.trim();
      results.add(
        SearchResultItem(
          title: title.isEmpty || title == 'N/A' ? url : title,
          url: url,
          text: marker == null ? '' : body.substring(marker.end).trim(),
        ),
      );
    }
    return results;
  }
}

// The transport closes its HTTP client; ownership stays with the search call.
class _BorrowedHttpClient extends http.BaseClient {
  _BorrowedHttpClient(this.delegate);

  final http.Client delegate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      delegate.send(request);
}
