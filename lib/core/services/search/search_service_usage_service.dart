import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../network/dio_http_client.dart';
import 'search_service.dart';

class SearchServiceUsageException implements Exception {
  const SearchServiceUsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SearchServiceUsageInfo {
  const SearchServiceUsageInfo({
    required this.remaining,
    this.used,
    this.limit,
    this.balances = const <String, num>{},
  });

  final num remaining;
  final num? used;
  final num? limit;

  /// Wallet balance per currency code, for providers billed from a balance.
  final Map<String, num> balances;
}

class SearchServiceUsageService {
  const SearchServiceUsageService._();

  /// DeepSeek Search & Fetch list price per 1,000 successful requests, keyed
  /// by balance currency. Both APIs share the same price.
  static const Map<String, num> deepSeekPricePer1000Requests = {
    'CNY': 5,
    'USD': 0.75,
  };

  static bool supports(SearchServiceOptions options) =>
      options is TavilyOptions ||
      options is LinkUpOptions ||
      options is DeepSeekOptions;

  static Future<SearchServiceUsageInfo> fetch(
    SearchServiceOptions options, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final ownsClient = client == null;
    final baseClient = client ?? DioHttpClient(timeout: timeout);
    final effectiveClient = RetryClient.withDelays(
      baseClient,
      const <Duration>[
        Duration(milliseconds: 200),
        Duration(milliseconds: 600),
      ],
      when: (_) => false,
      whenError: _shouldRetryUsageRequest,
    );
    try {
      if (options is TavilyOptions) {
        return await _fetchTavily(options, effectiveClient);
      }
      if (options is LinkUpOptions) {
        return await _fetchLinkUp(options, effectiveClient);
      }
      if (options is DeepSeekOptions) {
        return await _fetchDeepSeek(options, effectiveClient);
      }
      throw const SearchServiceUsageException(
        'Usage query is not supported for this search provider',
      );
    } on SearchServiceUsageException {
      rethrow;
    } on FormatException {
      throw const SearchServiceUsageException(
        'The provider returned an invalid usage response',
      );
    } catch (error) {
      throw SearchServiceUsageException(error.toString());
    } finally {
      if (ownsClient) effectiveClient.close();
    }
  }

  static Future<SearchServiceUsageInfo> _fetchTavily(
    TavilyOptions options,
    http.Client client,
  ) async {
    final response = await client.get(
      _tavilyUsageUri(options),
      headers: {'Authorization': 'Bearer ${options.apiKey.trim()}'},
    );
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected an object');
    }
    final account = decoded['account'];
    num? used;
    num? limit;

    if (account is Map &&
        account['plan_usage'] is num &&
        account['plan_limit'] is num) {
      used = account['plan_usage'] as num;
      limit = account['plan_limit'] as num;
    } else {
      final key = decoded['key'];
      if (key is Map && key['usage'] is num && key['limit'] is num) {
        used = key['usage'] as num;
        limit = key['limit'] as num;
      }
    }
    if (used == null || limit == null) {
      throw const FormatException('Missing usage totals');
    }
    final remaining = limit - used;
    return SearchServiceUsageInfo(
      remaining: remaining < 0 ? 0 : remaining,
      used: used,
      limit: limit,
    );
  }

  static Future<SearchServiceUsageInfo> _fetchLinkUp(
    LinkUpOptions options,
    http.Client client,
  ) async {
    final response = await client.get(
      Uri.parse('https://api.linkup.so/v1/credits/balance'),
      headers: {'Authorization': 'Bearer ${options.apiKey.trim()}'},
    );
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['balance'] is! num) {
      throw const FormatException('Missing credit balance');
    }
    return SearchServiceUsageInfo(remaining: decoded['balance'] as num);
  }

  /// Estimates remaining Search/Fetch requests from the account balance. The
  /// balance is shared with model usage, so this is an upper bound.
  static Future<SearchServiceUsageInfo> _fetchDeepSeek(
    DeepSeekOptions options,
    http.Client client,
  ) async {
    final response = await client.get(
      Uri.parse('https://api.deepseek.com/user/balance'),
      headers: {'Authorization': 'Bearer ${options.apiKey.trim()}'},
    );
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    final infos = decoded is Map<String, dynamic>
        ? decoded['balance_infos']
        : null;
    if (infos is! List) {
      throw const FormatException('Missing balance info');
    }
    final balances = <String, num>{};
    var requests = 0;
    for (final info in infos) {
      if (info is! Map) continue;
      final currency = info['currency'];
      final price = deepSeekPricePer1000Requests[currency];
      final balance = num.tryParse('${info['total_balance']}');
      if (currency is! String || price == null || balance == null) continue;
      balances[currency] = balance;
      if (balance > 0) requests += (balance * 1000 / price).floor();
    }
    if (balances.isEmpty) {
      throw const FormatException('Missing balance info');
    }
    return SearchServiceUsageInfo(remaining: requests, balances: balances);
  }

  static Uri _tavilyUsageUri(TavilyOptions options) {
    final searchUri = Uri.parse(options.resolvedUrl);
    final segments = searchUri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (segments.isEmpty) {
      segments.add('usage');
    } else if (segments.last == 'search') {
      segments[segments.length - 1] = 'usage';
    } else {
      segments.add('usage');
    }
    return Uri(
      scheme: searchUri.scheme,
      userInfo: searchUri.userInfo,
      host: searchUri.host,
      port: searchUri.hasPort ? searchUri.port : null,
      path: '/${segments.join('/')}',
    );
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SearchServiceUsageException(
        'Usage request failed (HTTP ${response.statusCode})',
      );
    }
  }

  static bool _shouldRetryUsageRequest(Object error, StackTrace _) {
    if (error is TimeoutException) return true;
    if (error is! http.ClientException) return false;
    final message = error.toString().toLowerCase();
    return message.contains('handshakeexception') ||
        message.contains('connection terminated during handshake') ||
        message.contains('connection timeout') ||
        message.contains('connection error') ||
        message.contains('socketexception') ||
        message.contains('connection reset by peer');
  }
}
