import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../utils/sandbox_path_resolver.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_helpers.dart';
import '../custom_request_merger.dart';
import 'media_request.dart';

abstract interface class MediaAdapter {
  MediaCapabilities capabilities(ProviderConfig provider, String modelId);
  Stream<MediaEvent> generate(MediaContext context, MediaRequest request);
}

class MediaContext {
  const MediaContext({
    required this.provider,
    required this.client,
    required this.apiKey,
    required this.cancelToken,
    required this.requestId,
  });

  final ProviderConfig provider;
  final http.Client client;
  final String apiKey;
  final CancelToken cancelToken;
  final String requestId;

  Uri endpoint(String path, {String? base}) => Uri.parse(
    '${(base ?? provider.baseUrl).replaceFirst(RegExp(r'/+$'), '')}/$path',
  );

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
    Map<String, dynamic> generated,
  ) {
    final payload = {...generated};
    CustomRequestMerger.applyBody(
      payload,
      customBody(provider, request.modelId),
    );
    final extra = request.parameters['extra'];
    if (extra is Map) {
      CustomRequestMerger.applyBody(payload, Map<String, dynamic>.from(extra));
    }
    return payload;
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cancellation = cancelToken.cancelError;
    if (cancellation != null) throw cancellation;
    final response = await client.send(request);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    final body = await response.stream.bytesToString();
    throw mediaHttpFailure(response, body);
  }

  Future<Map<String, dynamic>> jsonRequest(
    String method,
    Uri url, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, url)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    return readMediaJson(await send(request));
  }
}

Future<Map<String, dynamic>> readMediaJson(
  http.StreamedResponse response,
) async {
  final payload = await response.stream.toBytes();
  final value = await compute(decodeMediaJson, payload);
  if (value['error'] != null) throw mediaResponseFailure(value['error']);
  return value;
}

Map<String, dynamic> decodeMediaJson(List<int> bytes) {
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a media response object');
  }
  return value;
}

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
        ].any(moderation.contains) =>
      MediaFailureKind.rejected,
    401 || 403 => MediaFailureKind.login,
    429 => MediaFailureKind.rateLimited,
    >= 500 => MediaFailureKind.server,
    400 || 404 || 405 || 415 || 422 => MediaFailureKind.parameters,
    _ => MediaFailureKind.invalidResponse,
  };
  // Provider errors can echo a signed link or a submitted credential. Store
  // only the protocol status and simple machine-readable error code.
  final safeCode =
      RegExp(r'^[a-z0-9_\-.]{1,80}$').hasMatch(code) && !code.startsWith('sk-')
      ? code
      : null;
  return MediaFailure(
    kind,
    [
      if (statusCode != null) 'HTTP $statusCode',
      if (safeCode != null) safeCode,
    ].join(' · '),
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

Future<String> mediaReferenceDataUri(MediaReference reference) async {
  final path = SandboxPathResolver.resolveForIo(reference.path);
  if (path == null) {
    throw const MediaFailure(
      MediaFailureKind.parameters,
      'Reference file unavailable',
    );
  }
  final bytes = await File(path).readAsBytes();
  return compute(_encodeReference, (name: path, bytes: bytes));
}

String _encodeReference(({String name, Uint8List bytes}) data) {
  final mime = mimeFromPath(data.name);
  return 'data:$mime;base64,${base64Encode(data.bytes)}';
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
