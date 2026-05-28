import 'dart:convert';
import 'dart:io' show HttpException;

import 'package:http/http.dart' as http;

import '../providers/settings_provider.dart';
import 'api/provider_request_headers.dart';
import 'api_key_manager.dart';
import 'network/dio_http_client.dart';

class ProviderBalanceException implements Exception {
  const ProviderBalanceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProviderBalanceValueParser {
  const ProviderBalanceValueParser._();

  static String format(dynamic json, String expression) {
    final expr = expression.trim();
    if (expr.isEmpty) {
      throw const ProviderBalanceException('Balance result path is empty');
    }

    // Division: path / literal (or path / path)
    final div = RegExp(r'\s/\s').firstMatch(expr);
    if (div != null) {
      final left = _readNumber(json, expr.substring(0, div.start));
      final right = _readNumber(json, expr.substring(div.end));
      return _formatValue(left / right);
    }

    // Multiplication: path * literal (or path * path)
    final mul = RegExp(r'\s\*\s').firstMatch(expr);
    if (mul != null) {
      final left = _readNumber(json, expr.substring(0, mul.start));
      final right = _readNumber(json, expr.substring(mul.end));
      return _formatValue(left * right);
    }

    // Subtraction: path - literal (or path - path)
    final minus = RegExp(r'\s-\s').firstMatch(expr);
    if (minus != null) {
      final left = _readNumber(json, expr.substring(0, minus.start));
      final right = _readNumber(json, expr.substring(minus.end));
      return _formatValue(left - right);
    }

    // Addition: path + literal (or path + path)
    final plus = RegExp(r'\s\+\s').firstMatch(expr);
    if (plus != null) {
      final left = _readNumber(json, expr.substring(0, plus.start));
      final right = _readNumber(json, expr.substring(plus.end));
      return _formatValue(left + right);
    }

    return _formatValue(_readPath(json, expr));
  }

  static num _readNumber(dynamic json, String path) {
    final trimmed = path.trim();
    // Try literal number first (e.g. "500000" for division)
    final literal = num.tryParse(trimmed);
    if (literal != null) return literal;

    final value = _readPath(json, trimmed);
    if (value is num) return value;
    final parsed = num.tryParse(value.toString());
    if (parsed == null) {
      throw ProviderBalanceException(
        'Balance value at "$trimmed" is not numeric',
      );
    }
    return parsed;
  }

  static dynamic _readPath(dynamic json, String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw const ProviderBalanceException('Balance result path is empty');
    }

    dynamic current = json;
    for (final part in trimmed.split('.')) {
      if (part.trim().isEmpty) {
        throw ProviderBalanceException('Invalid balance result path: $path');
      }
      current = _readPart(current, part.trim(), path);
    }
    return current;
  }

  static dynamic _readPart(dynamic current, String part, String fullPath) {
    final match = RegExp(r'^([^\[\]]+)((?:\[\d+\])*)$').firstMatch(part);
    if (match == null) {
      throw ProviderBalanceException('Invalid balance result path: $fullPath');
    }

    final key = match.group(1)!;
    if (current is! Map || !current.containsKey(key)) {
      throw ProviderBalanceException('Balance path not found: $fullPath');
    }
    current = current[key];

    final indexes = RegExp(r'\[(\d+)\]').allMatches(match.group(2) ?? '');
    for (final indexMatch in indexes) {
      final index = int.parse(indexMatch.group(1)!);
      if (current is! List || index < 0 || index >= current.length) {
        throw ProviderBalanceException('Balance path not found: $fullPath');
      }
      current = current[index];
    }

    return current;
  }

  static String _formatValue(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    final parsed = num.tryParse(value.toString());
    if (parsed != null) return parsed.toStringAsFixed(2);
    return value.toString();
  }
}

class ProviderBalanceService {
  const ProviderBalanceService._();

  static Future<String> fetchBalance(ProviderConfig config) async {
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    if (kind != ProviderKind.openai) {
      throw const ProviderBalanceException(
        'Balance is only supported for OpenAI-compatible providers',
      );
    }
    if (config.balanceEnabled != true) {
      throw const ProviderBalanceException('Balance query is disabled');
    }

    final apiPath = (config.balanceApiPath ?? '/credits').trim();
    final resultPath = (config.balanceResultPath ?? 'data.total_usage').trim();
    final uri = _balanceUri(config.baseUrl, apiPath);
    final client = _clientFor(config);
    try {
      final apiKey = _effectiveApiKey(config);
      final headers = <String, String>{
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        ...providerDefaultHeaders(config),
        if (config.balanceHeaders != null) ...config.balanceHeaders!,
      };
      final response = await client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProviderBalanceException(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
      final decoded = jsonDecode(response.body);
      return ProviderBalanceValueParser.format(decoded, resultPath);
    } on ProviderBalanceException {
      rethrow;
    } on FormatException catch (e) {
      throw ProviderBalanceException('Invalid balance response JSON: $e');
    } on HttpException catch (e) {
      throw ProviderBalanceException(e.message);
    } catch (e) {
      throw ProviderBalanceException(e.toString());
    } finally {
      client.close();
    }
  }

  static Uri _balanceUri(String baseUrl, String apiPath) {
    if (apiPath.isEmpty) {
      throw const ProviderBalanceException('Balance API path is empty');
    }
    final absolute = Uri.tryParse(apiPath);
    if (absolute != null && absolute.hasScheme) return absolute;

    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = apiPath.startsWith('/') ? apiPath : '/$apiPath';
    return Uri.parse('$base$path');
  }

  static http.Client _clientFor(ProviderConfig config) {
    final enabled = config.proxyEnabled == true;
    final host = (config.proxyHost ?? '').trim();
    final portStr = (config.proxyPort ?? '').trim();
    final user = (config.proxyUsername ?? '').trim();
    final pass = (config.proxyPassword ?? '').trim();
    if (enabled && host.isNotEmpty && portStr.isNotEmpty) {
      final port = int.tryParse(portStr) ?? 8080;
      return DioHttpClient(
        proxy: NetworkProxyConfig(
          enabled: true,
          type: ProviderConfig.resolveProxyType(config.proxyType),
          host: host,
          port: port,
          username: user.isEmpty ? null : user,
          password: pass.isEmpty ? null : pass,
        ),
      );
    }
    return DioHttpClient();
  }

  static String _effectiveApiKey(ProviderConfig config) {
    if (config.multiKeyEnabled == true &&
        (config.apiKeys?.isNotEmpty == true)) {
      final selected = ApiKeyManager().selectForProvider(config);
      if (selected.key != null) return selected.key!.key;
    }
    return config.apiKey;
  }
}
