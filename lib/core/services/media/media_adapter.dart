import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:dio/dio.dart' show CancelToken, DioException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../utils/sandbox_path_resolver.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_helpers.dart';
import '../auth/provider_oauth_service.dart';
import '../custom_request_merger.dart';
import '../network/media_http_log.dart';
import '../network/request_logger.dart';
import 'media_request.dart';

abstract interface class MediaAdapter {
  MediaCapabilities capabilities(ProviderConfig provider, String modelId);
  Stream<MediaEvent> generate(MediaContext context, MediaRequest request);
}

MediaFailure classifyMediaFailure(Object error) {
  if (error is MediaFailure) return error;
  if (error is ProviderOAuthException) {
    return MediaFailure(
      MediaFailureKind.login,
      error.kind.name,
      statusCode: error.statusCode,
    );
  }
  if (error is http.ClientException ||
      error is SocketException ||
      error is DioException ||
      error is TimeoutException) {
    return const MediaFailure(
      MediaFailureKind.network,
      'Media request could not connect',
    );
  }
  return const MediaFailure(
    MediaFailureKind.invalidResponse,
    'Unexpected media response',
  );
}

/// Request diagnostics retain only protocol metadata and allowlisted fields.
class MediaRequestLog {
  Map<String, Object?>? _request;
  Map<String, Object?>? _response;
  final _retries = <Map<String, Object?>>[];
  int? _networkId;
  void recordProviderFailure(MediaFailure failure) {
    final id = _networkId;
    final detail =
        failure.logDetail ??
        (failure.kind == MediaFailureKind.rejected ? failure.kind.name : null);
    if (id != null && detail != null && failure.statusCode == null) {
      RequestLogger.logLine('[RES $id] error=${RequestLogger.escape(detail)}');
      _networkId = null;
    }
  }

  bool get startedPost => _request?['method'] == 'POST';

  void start(http.BaseRequest request, Map<String, dynamic>? payload) {
    _networkId = null;
    const knownSegments = {
      'images',
      'generations',
      'edits',
      'videos',
      'tasks',
      'contents',
      'services',
      'aigc',
      'video',
      'submit',
      'status',
      'requests',
      'image-synthesis',
      'generation',
      'multimodal-generation',
      'video-synthesis',
      'content',
      'gateway',
      'minimax',
      'kling',
      'ark',
      'alibaba',
      'wan3',
      'happyhorse',
      'v1',
      'v2',
      'v3',
      'video_generation',
      'query',
      'text2video',
      'image2video',
      'omni-video',
      'image-generation',
      'models',
      'interactions',
      'predictions',
      'async-result',
      'files',
      'chat',
      'completions',
      'long-image-generation',
    };
    final route = request.url.pathSegments
        .map((part) {
          if (knownSegments.contains(part)) return part;
          if (part.endsWith(':generateContent')) return ':generateContent';
          if (part.endsWith(':predict')) return ':predict';
          if (part.endsWith(':predictLongRunning')) {
            return ':predictLongRunning';
          }
          return '…';
        })
        .take(10)
        .join('/');
    final body = <String, Object?>{};
    if (payload != null) {
      final parameters = payload['parameters'];
      final fields = parameters is Map ? parameters : payload;
      for (final key in [
        'n',
        'count',
        'partial_images',
        'duration',
        'seconds',
      ]) {
        final value = fields[key];
        if (value is int && value >= 0 && value <= 60) body[key] = value;
      }
      if (fields['size'] case final String size
          when RegExp(r'^(auto|[0-9]{2,4}[x*][0-9]{2,4})$').hasMatch(size)) {
        body['size'] = size;
      }
      for (final key in ['stream', 'watermark']) {
        if (fields[key] case final bool value) body[key] = value;
      }
      if (payload['input'] case {
        'messages': [{'content': final List content}],
      }) {
        body['referenceCount'] = content
            .whereType<Map>()
            .where((part) => part.containsKey('image'))
            .length;
      }
    }
    _request = {
      'method': request.method,
      'host': request.url.host,
      'route': '/$route',
      if (body.isNotEmpty) 'body': body,
    };
    _response = null;
  }

  void response(int status, {MediaFailureKind? errorKind}) {
    _response = {
      'status': status,
      if (errorKind != null) 'body': {'kind': errorKind.name},
    };
  }

  void retry(MediaFailure failure, Duration wait) {
    _retries.add({
      'at': DateTime.now().toIso8601String(),
      'kind': failure.kind.name,
      if (failure.statusCode case final status?) 'status': status,
      'waitMs': wait.inMilliseconds,
    });
  }

  Map<String, Object?> toJson() => {
    if (_request != null) 'request': _request,
    if (_response != null) 'response': _response,
    if (_retries.isNotEmpty) 'retries': _retries,
  };
}

class MediaContext {
  const MediaContext({
    required this.provider,
    required this.client,
    required this.apiKey,
    required this.cancelToken,
    required this.requestId,
    this.delay = Future<void>.delayed,
    this.log,
  });

  final ProviderConfig provider;
  final http.Client client;
  final String apiKey;
  final CancelToken cancelToken;
  final String requestId;
  final Future<void> Function(Duration) delay;
  final MediaRequestLog? log;

  Uri endpoint(String path, {String? base}) {
    final root = Uri.parse(base ?? provider.baseUrl);
    final route = Uri.parse(path);
    final prefix = root.path.replaceFirst(RegExp(r'/+$'), '');
    final query = [
      if (root.hasQuery) root.query,
      if (route.hasQuery) route.query,
    ].join('&');
    return root
        .replace(
          path: path.startsWith('/') ? route.path : '$prefix/${route.path}',
          query: query.isEmpty ? null : query,
        )
        .removeFragment();
  }

  /// A relay may mount multiple native APIs below its own path prefix.
  String nativeBase(String apiPath) {
    final uri = Uri.parse(provider.baseUrl);
    final root = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final prefix = root.replaceFirst(
      RegExp(
        r'/(?:api/v2/apps/protocols/compatible-mode/v1|compatible-mode/v1|v1beta/openai|api/v[13]|v1beta|v1)$',
      ),
      '',
    );
    return uri.replace(path: '$prefix/$apiPath').toString();
  }

  Map<String, String> headers(
    String modelId, {
    Map<String, String>? auth,
    bool json = true,
    Map<String, String> extra = const {},
  }) => customHeaders(
    provider,
    modelId,
    baseHeaders: {
      if (json) HttpHeaders.contentTypeHeader: 'application/json',
      if (auth != null)
        ...auth
      else if (!provider.isOAuth && apiKey.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      ...extra,
    },
  );

  Map<String, dynamic> body(
    MediaRequest request,
    Map<String, dynamic> generated, {
    bool includeExtra = true,
  }) {
    final payload = {...generated};
    CustomRequestMerger.applyBody(
      payload,
      customBody(provider, request.modelId),
    );
    final extra = request.parameters['extra'];
    if (includeExtra && extra is Map) {
      CustomRequestMerger.applyBody(payload, Map<String, dynamic>.from(extra));
    }
    return payload;
  }

  Future<http.StreamedResponse> send(
    http.BaseRequest request, {
    Map<String, dynamic>? diagnosticBody,
  }) async {
    final cancellation = cancelToken.cancelError;
    if (cancellation != null) throw cancellation;
    request.followRedirects = false;
    log?.start(request, diagnosticBody);
    MediaHttpLog.describeRequest(request, diagnosticBody);
    final response = await client.send(request);
    log?._networkId = MediaHttpLog.requestId(response.request);
    log?.response(response.statusCode);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    // Error pages can be large or binary. Only a small diagnostic prefix is used.
    final prefix = BytesBuilder(copy: false);
    const limit = 64 * 1024;
    await for (final chunk in response.stream) {
      final room = limit - prefix.length;
      prefix.add(chunk.length > room ? chunk.sublist(0, room) : chunk);
      if (prefix.length == limit) break;
    }
    final body = utf8.decode(prefix.takeBytes(), allowMalformed: true);
    final failure = mediaHttpFailure(response, body);
    log?.response(response.statusCode, errorKind: failure.kind);
    throw failure;
  }

  Future<Map<String, dynamic>> jsonRequest(
    String method,
    Uri url, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    bool allowZeroErrorCode = false,
  }) async {
    final request = http.Request(method, url)..headers.addAll(headers);
    if (body != null) request.bodyBytes = await encodeMediaJson(body);
    return readMediaJson(
      await send(request, diagnosticBody: body),
      allowZeroErrorCode: allowZeroErrorCode,
    );
  }
}

Future<Uint8List> encodeMediaJson(Map<String, dynamic> body) =>
    compute(_mediaJsonBytes, body);

Uint8List _mediaJsonBytes(Map<String, dynamic> body) =>
    utf8.encode(jsonEncode(body));

// A 128 MiB inline result expands to about 171 MiB in base64. Share the same
// response budget across ordinary JSON and streamed generation events.
const maxMediaResponseBytes = 180 * 1024 * 1024;
Stream<List<int>> boundedMediaResponse(http.StreamedResponse response) async* {
  const failure = MediaFailure(
    MediaFailureKind.invalidResponse,
    'Media response too large',
  );
  if ((response.contentLength ?? 0) > maxMediaResponseBytes) {
    await response.stream.listen(null).cancel();
    throw failure;
  }
  var received = 0;
  await for (final bytes in response.stream) {
    received += bytes.length;
    if (received > maxMediaResponseBytes) throw failure;
    yield bytes;
  }
}

Future<Map<String, dynamic>> _parseMediaResponse(
  http.StreamedResponse response,
) async {
  // Most polls fit in a single packet. Spool inline images and videos so the
  // isolate that parses them need not receive a second copy of the whole body.
  final small = BytesBuilder(copy: false);
  Directory? spool;
  RandomAccessFile? writer;
  try {
    await for (final bytes in boundedMediaResponse(response)) {
      if (writer == null && small.length + bytes.length <= 256 * 1024) {
        small.add(bytes);
        continue;
      }
      if (writer == null) {
        spool = await Directory.systemTemp.createTemp('kelivo-media-response-');
        writer = await File(
          p.join(spool.path, 'body'),
        ).open(mode: FileMode.write);
        await writer.writeFrom(small.takeBytes());
      }
      await writer.writeFrom(bytes);
    }
    if (spool == null) return decodeMediaJson(small.takeBytes());
    await writer!.close();
    writer = null;
    return await compute(_parseMediaFile, p.join(spool.path, 'body'));
  } finally {
    await writer?.close();
    if (spool != null) await spool.delete(recursive: true);
  }
}

Future<Map<String, dynamic>> _parseMediaFile(String path) async {
  final value = await File(
    path,
  ).openRead().transform(utf8.decoder).transform(json.decoder).single;
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a media response object');
  }
  return value;
}

Future<Map<String, dynamic>> readMediaJson(
  http.StreamedResponse response, {
  bool allowZeroErrorCode = false,
}) async {
  final value = await _parseMediaResponse(response);
  final error = value['error'];
  if (error != null &&
      !(allowZeroErrorCode && error is Map && error['code'] == 0)) {
    throw mediaResponseFailure(error);
  }
  return value;
}

Map<String, dynamic> decodeMediaJson(List<int> bytes) {
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a media response object');
  }
  return value;
}

MediaFailure filteredMediaFailure(String message, Object? reason) =>
    MediaFailure(
      MediaFailureKind.rejected,
      message,
      logDetail: MediaHttpLog.failure({
        'error': 'content_filter',
        'reason': reason,
      }),
    );

MediaFailure mediaResponseFailure(
  Object? error, {
  int? statusCode,
  Duration? retryAfter,
}) {
  final details = error is Map ? error : const <String, Object?>{};
  final code = (details['code'] ?? details['type'] ?? '')
      .toString()
      .toLowerCase();
  final message = (details['message'] ?? error ?? '').toString();
  final moderation = '$code $message'.toLowerCase();
  final kind = switch (statusCode ?? 0) {
    _
        when [
          'moderation',
          'content_policy',
          'content_filter',
          'safety_violation',
          'datainspectionfailed',
          'data_inspection_failed',
          'inappropriate content',
        ].any(moderation.contains) =>
      MediaFailureKind.rejected,
    401 || 403 => MediaFailureKind.login,
    429 => MediaFailureKind.rateLimited,
    >= 500 => MediaFailureKind.server,
    404 || 405 => MediaFailureKind.unavailable,
    _ when code == 'model_not_found' => MediaFailureKind.unavailable,
    400 || 415 || 422 => MediaFailureKind.parameters,
    _ => MediaFailureKind.invalidResponse,
  };
  const knownCodes = {
    'content_policy_violation',
    'content_filter',
    'datainspectionfailed',
    'inputdatainspectionfailed',
    'outputdatainspectionfailed',
    'invalidparameter',
    'invalidparameter.range',
    'invalid_size',
    'invalid_request_error',
    'model_not_found',
    'rate_limit',
    'rate_limit_exceeded',
    'insufficient_quota',
    'overloaded_error',
    'server_error',
  };
  return MediaFailure(
    kind,
    [
      if (statusCode != null) 'HTTP $statusCode',
      if (knownCodes.contains(code)) code,
      if (details['param'] case final String field
          when const {
            'model',
            'prompt',
            'size',
            'n',
            'image',
            'image[]',
            'images',
            'input',
            'parameters',
          }.contains(field))
        field,
    ].join(' · '),
    logDetail: statusCode == null ? MediaHttpLog.failure(error) : null,
    statusCode: statusCode,
    retryAfter: retryAfter,
  );
}

MediaFailure mediaHttpFailure(http.StreamedResponse response, String body) {
  Object? reason;
  try {
    final payload = jsonDecode(body);
    if (payload is Map) reason = payload['error'] ?? payload;
  } on FormatException {
    // Keep non-JSON upstream bodies out of persistent error records.
  }
  final rawRetry = response.headers['retry-after'];
  Duration? retry;
  if (rawRetry != null) {
    final seconds = int.tryParse(rawRetry);
    if (seconds != null && seconds >= 0) {
      retry = Duration(seconds: seconds);
    } else {
      try {
        final wait = HttpDate.parse(rawRetry).difference(DateTime.now());
        if (!wait.isNegative) retry = wait;
      } on FormatException {
        // Use the runner's ordinary backoff.
      }
    }
  }
  return mediaResponseFailure(
    reason,
    statusCode: response.statusCode,
    retryAfter: retry,
  );
}

Future<String> mediaReferenceDataUri(MediaReference reference) =>
    _encodeMediaReference(reference, withMimePrefix: true);

Future<String> mediaReferenceBase64(MediaReference reference) =>
    _encodeMediaReference(reference, withMimePrefix: false);

Future<String> _encodeMediaReference(
  MediaReference reference, {
  required bool withMimePrefix,
}) async {
  final path = SandboxPathResolver.resolveForIo(reference.path);
  if (path == null) {
    throw const MediaFailure(
      MediaFailureKind.parameters,
      'Reference file unavailable',
    );
  }
  return compute(_encodeReference, (path: path, prefix: withMimePrefix));
}

Future<Uint8List> readMediaReference(MediaReference reference) async {
  final path = SandboxPathResolver.resolveForIo(reference.path);
  if (path == null) {
    throw const MediaFailure(
      MediaFailureKind.parameters,
      'Reference file unavailable',
    );
  }
  return File(path).readAsBytes();
}

Future<String> _encodeReference(({String path, bool prefix}) data) async {
  final encoded = await File(
    data.path,
  ).openRead().transform(base64.encoder).join();
  return data.prefix
      ? 'data:${mimeFromPath(data.path)};base64,$encoded'
      : encoded;
}

List<MediaResult> parseOpenAiMediaImages(
  Map<String, dynamic> response, {
  required String mime,
}) {
  final rows = response['data'];
  if (rows is! List) {
    throw const MediaFailure(
      MediaFailureKind.invalidResponse,
      'Image data missing',
    );
  }
  final results = <MediaResult>[];
  for (final row in rows.whereType<Map>()) {
    final rawBytes = row['b64_json'];
    final rawUrl = row['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    final remote =
        url != null &&
        (url.scheme == 'https' || url.scheme == 'http') &&
        url.host.isNotEmpty;
    if ((rawBytes is! String || rawBytes.isEmpty) && !remote) continue;
    results.add(
      MediaResult(
        mime: mime,
        base64: rawBytes is String && rawBytes.isNotEmpty ? rawBytes : null,
        url: remote ? url : null,
        revisedPrompt: row['revised_prompt'] as String?,
      ),
    );
  }
  if (results.isEmpty) {
    throw const MediaFailure(
      MediaFailureKind.invalidResponse,
      'Provider returned no images',
    );
  }
  return results;
}
