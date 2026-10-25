import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../network/dio_http_client.dart';
import 'search_service.dart';

/// Upper bound on the characters kept from one page. Providers that take a
/// length limit request this much; longer content is cut to it.
const int webFetchMaxContentLength = 100000;

/// Readable content of one web page.
class WebFetchPage {
  const WebFetchPage({
    required this.url,
    required this.title,
    required this.content,
  });

  final String url;
  final String title;

  /// Markdown or plain text, ready to hand to a model.
  final String content;
}

/// A search provider that can also read a page by URL with the same
/// credentials and quota as its search endpoint.
abstract interface class WebFetchCapable<T extends SearchServiceOptions> {
  Future<WebFetchPage> fetch({
    required String url,
    required SearchCommonOptions commonOptions,
    required T serviceOptions,
  });
}

/// Replaces the trailing search path of a configured endpoint with the
/// provider's page-reading path, preserving custom gateways and query options.
String siblingFetchEndpoint(
  String searchUrl, {
  required String searchPath,
  required String fetchPath,
}) {
  final uri = Uri.parse(searchUrl.trim());
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  if (!path.endsWith(searchPath)) {
    throw FormatException(
      'The custom search URL must end with $searchPath to read pages',
    );
  }
  return uri
      .replace(
        path: path.substring(0, path.length - searchPath.length) + fetchPath,
      )
      .toString();
}

/// The first Markdown H1, for providers that return a page without a title.
String firstMarkdownHeading(String content) {
  final match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
  return match?.group(1)?.trim() ?? '';
}

/// Each fetch owns its cancellation token. The total deadline also stops
/// response streams that keep sending data, and releases the connection.
/// Injected clients remain owned by their caller.
Future<http.Response> withWebFetchClient(
  Future<http.Response> Function(http.Client client) request, {
  required SearchCommonOptions commonOptions,
  http.Client? client,
}) async {
  final timeout = Duration(milliseconds: commonOptions.timeout);
  final cancellation = CancelToken();
  final effectiveClient =
      client ?? DioHttpClient(cancelToken: cancellation, timeout: timeout);
  try {
    return await request(effectiveClient).timeout(timeout);
  } finally {
    if (client == null) {
      cancellation.cancel('Web fetch finished');
      effectiveClient.close();
    }
  }
}

extension WebFetchRequests on SearchService {
  /// POSTs a JSON body to a page-reading endpoint and decodes the JSON reply.
  /// Non-2xx responses throw with the provider's own error message.
  Future<dynamic> postFetchJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
    required SearchCommonOptions commonOptions,
  }) async {
    final response = await withWebFetchClient(
      (client) => client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...headers,
        },
        body: jsonEncode(body),
      ),
      commonOptions: commonOptions,
      client: client,
    );
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = fetchErrorDetail(text);
      throw Exception(
        detail.isEmpty
            ? 'HTTP ${response.statusCode}'
            : 'HTTP ${response.statusCode}: $detail',
      );
    }
    return jsonDecode(text);
  }
}

/// Pulls a readable message out of a provider error body.
String fetchErrorDetail(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return '';
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      for (final key in const [
        'readableMessage',
        'error_msg',
        'errMsg',
        'message',
        'detail',
        'error',
      ]) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is Map && value['message'] is String) {
          return (value['message'] as String).trim();
        }
      }
    }
  } catch (_) {}
  return trimmed.length > 300 ? '${trimmed.substring(0, 300)}…' : trimmed;
}
