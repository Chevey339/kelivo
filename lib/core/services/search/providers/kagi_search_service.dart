import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class KagiSearchService extends SearchService<KagiOptions> {
  KagiSearchService({super.client});

  static const String endpoint = 'https://kagi.com/api/v1/search';

  @override
  String get name => 'Kagi';

  @override
  Widget description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.searchProviderKagiDescription,
      style: const TextStyle(fontSize: 12),
    );
  }

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required KagiOptions serviceOptions,
  }) async {
    try {
      final response = await withHttpClient(
        (client) => client
            .post(
              Uri.parse(endpoint),
              headers: {
                'Authorization':
                    'Bearer ${serviceOptions.effectiveApiKey(serviceOptions.apiKey)}',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'query': query,
                'workflow': 'search',
                'format': 'json',
                'limit': commonOptions.resultSize.clamp(1, 1024),
              }),
            )
            .timeout(Duration(milliseconds: commonOptions.timeout)),
      );

      final payload = _decodePayload(response.body);
      final trace = _traceId(response.headers, payload);

      if (response.statusCode != 200) {
        throw Exception(
          'API request failed: ${response.statusCode} '
          '${_errorMessage(response.body, payload: payload)}'
          '${_traceSuffix(trace)}',
        );
      }

      if (payload == null) {
        throw FormatException(
          'Expected a JSON object response${_traceSuffix(trace)}',
        );
      }
      final errors = payload['error'];
      if (errors is List && errors.isNotEmpty) {
        throw Exception(
          'API request failed: '
          '${_errorMessage(response.body, payload: payload)}'
          '${_traceSuffix(trace)}',
        );
      }

      final data = (payload['data'] as Map?)?.cast<String, dynamic>();
      final results = data?['search'] as List? ?? const <dynamic>[];
      final items = <SearchResultItem>[];
      for (final item in results) {
        if (item is! Map) continue;
        final result = item.cast<String, dynamic>();
        final title = _decodeHtmlEntities(
          (result['title'] ?? '').toString(),
        ).trim();
        final url = (result['url'] ?? '').toString().trim();
        if (title.isEmpty || url.isEmpty) continue;
        items.add(
          SearchResultItem(
            title: title,
            url: url,
            text: _decodeHtmlEntities((result['snippet'] ?? '').toString()),
          ),
        );
      }

      return SearchResult(items: items);
    } catch (error) {
      throw Exception('Kagi search failed: $error');
    }
  }

  static String _decodeHtmlEntities(String text) {
    // Preserve literal tags and code while decoding character references once.
    return html.parseFragment(text.replaceAll('<', '&lt;')).text ?? '';
  }

  static Map<String, dynamic>? _decodePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // The caller decides how to report non-JSON responses.
    }
    return null;
  }

  static String _errorMessage(String body, {Map<String, dynamic>? payload}) {
    final errors = (payload ?? _decodePayload(body))?['error'];
    if (errors is List) {
      final messages = errors
          .whereType<Map>()
          .map((error) {
            final message = error['message']?.toString().trim() ?? '';
            if (message.isNotEmpty) return message;
            return error['code']?.toString().trim() ?? '';
          })
          .where((message) => message.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) return messages.join('; ');
    }
    return body.trim().isEmpty ? 'Unknown Kagi API error' : body;
  }

  static String? _traceId(
    Map<String, String> headers,
    Map<String, dynamic>? payload,
  ) {
    final headerTrace = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'x-kagi-trace')
        .map((entry) => entry.value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (headerTrace.isNotEmpty) return headerTrace;
    final meta = payload?['meta'];
    if (meta is Map) {
      final bodyTrace = meta['trace']?.toString().trim() ?? '';
      if (bodyTrace.isNotEmpty) return bodyTrace;
    }
    return null;
  }

  static String _traceSuffix(String? trace) =>
      trace == null ? '' : ' (Kagi trace: $trace)';
}
