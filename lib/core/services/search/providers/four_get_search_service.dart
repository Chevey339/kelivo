import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../l10n/app_localizations.dart';
import '../search_service.dart';

class FourGetSearchService extends SearchService<FourGetOptions> {
  FourGetSearchService({super.client});

  @override
  String get name => '4get';

  @override
  Widget description(BuildContext context) => Text(
    AppLocalizations.of(context)!.searchProviderFourGetDescription,
    style: const TextStyle(fontSize: 12),
  );

  @override
  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required FourGetOptions serviceOptions,
  }) async {
    final instance = FourGetOptions.parseInstanceUrl(serviceOptions.url);
    if (instance == null) {
      throw const FormatException('4get requires a valid instance URL.');
    }
    final basePath = instance.path.replaceFirst(RegExp(r'/+$'), '');
    final scraper = serviceOptions.scraper.trim();
    final endpoint = instance.replace(
      path: '$basePath/api/v1/web',
      queryParameters: {'s': query, if (scraper.isNotEmpty) 'scraper': scraper},
    );

    final request = http.Request('GET', endpoint);
    request.headers['Accept'] = 'application/json';
    final passToken = serviceOptions.passToken.trim();
    if (passToken.isNotEmpty) {
      try {
        final cookie = Cookie('pass', passToken);
        request.headers['Cookie'] = '${cookie.name}=${cookie.value}';
      } on FormatException {
        throw const FormatException('Invalid 4get pass cookie value.');
      }
      // Restrict the credential to the configured instance URL.
      request.followRedirects = false;
    }

    final response = await withHttpClient(
      (client) => client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(Duration(milliseconds: commonOptions.timeout)),
    );
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // A proxy or an instance without the API can return a non-JSON response.
    }

    final status = data?['status'];
    if (response.statusCode != 200) {
      final detail = status is String && status.isNotEmpty && status != 'ok'
          ? ' $status'
          : '';
      throw Exception('4get returned HTTP ${response.statusCode}.$detail');
    }
    if (status is! String || status.isEmpty) {
      throw const FormatException('4get returned an invalid search response.');
    }
    if (status != 'ok') throw Exception('4get search failed. $status');

    final web = data?['web'];
    if (web == null) return SearchResult(items: const []);
    if (web is! List) {
      throw const FormatException('4get returned invalid web results.');
    }
    final items = web
        .whereType<Map<String, dynamic>>()
        .map(_webResult)
        .whereType<SearchResultItem>()
        .take(commonOptions.resultSize)
        .toList();
    return SearchResult(items: items);
  }

  static SearchResultItem? _webResult(Map<String, dynamic> item) {
    final url = item['url'];
    if (url is! String || url.trim().isEmpty) return null;
    final title = item['title'];
    final description = item['description'];
    return SearchResultItem(
      url: url.trim(),
      title: title is String && title.isNotEmpty ? title : url.trim(),
      text: description is String ? description : '',
    );
  }
}
