import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// HTTP 请求日志拦截器
/// 
/// 使用方法:
/// ```dart
/// final client = LoggingClient(http.Client());
/// final response = await client.get(Uri.parse('https://api.example.com'));
/// ```
class LoggingClient extends http.BaseClient {
  final http.Client _inner;
  final bool enabled;

  LoggingClient(this._inner, {this.enabled = kDebugMode});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!enabled) {
      return _inner.send(request);
    }

    // 记录请求
    _logRequest(request);

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _inner.send(request);
      stopwatch.stop();

      // 读取响应体
      final responseBody = await response.stream.bytesToString();

      // 记录响应
      _logResponse(response, responseBody, stopwatch.elapsedMilliseconds);

      // 重新创建响应流
      return http.StreamedResponse(
        Stream.value(utf8.encode(responseBody)),
        response.statusCode,
        headers: response.headers,
        request: response.request,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
        contentLength: responseBody.length,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(request, e, stackTrace, stopwatch.elapsedMilliseconds);
      rethrow;
    }
  }

  void _logRequest(http.BaseRequest request) {
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'HTTP');
    developer.log('🚀 REQUEST', name: 'HTTP');
    developer.log('${request.method} ${request.url}', name: 'HTTP');

    // 记录请求头
    if (request.headers.isNotEmpty) {
      developer.log('📋 Headers:', name: 'HTTP');
      request.headers.forEach((key, value) {
        // 隐藏敏感信息
        if (key.toLowerCase().contains('authorization') ||
            key.toLowerCase().contains('api-key') ||
            key.toLowerCase().contains('token')) {
          developer.log('  $key: ***HIDDEN***', name: 'HTTP');
        } else {
          developer.log('  $key: $value', name: 'HTTP');
        }
      });
    }

    // 记录请求体
    if (request is http.Request && request.body.isNotEmpty) {
      developer.log('📦 Body:', name: 'HTTP');
      try {
        final json = jsonDecode(request.body);
        final prettyJson = JsonEncoder.withIndent('  ').convert(json);
        developer.log(prettyJson, name: 'HTTP');
      } catch (_) {
        // 如果不是 JSON，直接输出
        final body = request.body.length > 1000
            ? '${request.body.substring(0, 1000)}... (truncated)'
            : request.body;
        developer.log(body, name: 'HTTP');
      }
    }
  }

  void _logResponse(
    http.StreamedResponse response,
    String body,
    int durationMs,
  ) {
    final statusEmoji = response.statusCode >= 200 && response.statusCode < 300
        ? '✅'
        : response.statusCode >= 400
            ? '❌'
            : '⚠️';

    developer.log(
      '$statusEmoji RESPONSE (${durationMs}ms)',
      name: 'HTTP',
    );
    developer.log('Status: ${response.statusCode}', name: 'HTTP');

    // 记录响应头
    if (response.headers.isNotEmpty) {
      developer.log('📋 Headers:', name: 'HTTP');
      response.headers.forEach((key, value) {
        developer.log('  $key: $value', name: 'HTTP');
      });
    }

    // 记录响应体
    if (body.isNotEmpty) {
      developer.log('📦 Body:', name: 'HTTP');
      try {
        final json = jsonDecode(body);
        final prettyJson = JsonEncoder.withIndent('  ').convert(json);
        // 限制日志长度
        final logBody = prettyJson.length > 2000
            ? '${prettyJson.substring(0, 2000)}... (truncated)'
            : prettyJson;
        developer.log(logBody, name: 'HTTP');
      } catch (_) {
        // 如果不是 JSON，直接输出
        final logBody = body.length > 1000
            ? '${body.substring(0, 1000)}... (truncated)'
            : body;
        developer.log(logBody, name: 'HTTP');
      }
    }

    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'HTTP');
  }

  void _logError(
    http.BaseRequest request,
    Object error,
    StackTrace stackTrace,
    int durationMs,
  ) {
    developer.log(
      '❌ ERROR (${durationMs}ms)',
      name: 'HTTP',
      error: error,
      stackTrace: stackTrace,
    );
    developer.log('${request.method} ${request.url}', name: 'HTTP');
    developer.log('Error: $error', name: 'HTTP');
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'HTTP');
  }
}

/// 简化的日志客户端（只记录 URL 和状态码）
class SimpleLoggingClient extends http.BaseClient {
  final http.Client _inner;
  final bool enabled;

  SimpleLoggingClient(this._inner, {this.enabled = kDebugMode});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!enabled) {
      return _inner.send(request);
    }

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _inner.send(request);
      stopwatch.stop();

      final statusEmoji = response.statusCode >= 200 && response.statusCode < 300
          ? '✅'
          : '❌';

      developer.log(
        '$statusEmoji ${request.method} ${request.url} → ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
        name: 'HTTP',
      );

      return response;
    } catch (e) {
      stopwatch.stop();
      developer.log(
        '❌ ${request.method} ${request.url} → ERROR (${stopwatch.elapsedMilliseconds}ms): $e',
        name: 'HTTP',
      );
      rethrow;
    }
  }
}

