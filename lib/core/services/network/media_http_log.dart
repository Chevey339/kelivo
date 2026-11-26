import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../logging/log_payload_elider.dart';
import '../logging/log_redactor.dart';
import 'request_logger.dart';

/// Formatting for the common request log. A media response may be a short
/// poll, a signed download URL, or hundreds of MB of pixels in JSON or binary.
abstract final class MediaHttpLog {
  static const maxBodyBytes = 32 * 1024;
  static final _largeRequests = Expando<String>();
  static final _ids = Expando<int>();
  static void started(http.BaseRequest request, int id) => _ids[request] = id;
  static int? requestId(http.BaseRequest? request) =>
      request == null ? null : _ids[request];

  /// Provider-declared errors can arrive inside an otherwise successful HTTP
  /// response. The generation record keeps its own compact, safe summary.
  static String? failure(Object? detail) =>
      RequestLogger.enabled && detail != null ? _json(detail) : null;
  static final _urls = RegExp(
    r'''https?://[^\s<>"']+|/[^\s<>"'?]*\?[^\s<>"']+''',
    caseSensitive: false,
  );
  static const _publicQuery = {
    'model',
    'endpoint_id',
    'limit',
    'expand',
    'category',
    'status',
    'alt',
    'page',
    'page_size',
    'task_id',
    'request_id',
  };
  static const _publicHeaders = {
    'accept',
    'content-type',
    'content-length',
    'content-encoding',
    'user-agent',
    'date',
    'server',
    'retry-after',
    'request-id',
    'x-request-id',
    'x-fal-request-id',
    'x-dashscope-request-id',
    'x-tt-logid',
    'cf-ray',
    'traceparent',
    'x-dashscope-async',
    'x-modelscope-async-mode',
  };
  static const _encodedFields = {'b64_json', 'b64', 'partial_image_b64'};

  static String url(Uri uri) {
    final clean = uri.removeFragment().replace(userInfo: '');
    if (!clean.hasQuery) return LogRedactor.redactText(clean.toString());
    try {
      return LogRedactor.redactText(
        clean
            .replace(
              queryParameters: {
                for (final e in clean.queryParametersAll.entries)
                  e.key: _publicQuery.contains(e.key.toLowerCase())
                      ? e.value
                      : '…',
              },
            )
            .toString(),
      );
    } on FormatException {
      return clean.toString().split('?').first;
    }
  }

  static String text(String value) {
    if (value.length > 2048) return '<${value.length} characters>';
    final clean = LogPayloadElider.elide(value).replaceAllMapped(_urls, (m) {
      final uri = Uri.tryParse(m[0]!);
      return uri == null ? '<URL>' : url(uri);
    });
    return LogRedactor.redactText(clean);
  }

  static Map<String, String> headers(Map<String, String> values) => {
    for (final entry in values.entries)
      entry.key: switch (entry.key.toLowerCase()) {
        'location' => switch (Uri.tryParse(entry.value)) {
          final uri? => url(uri),
          null => '<URL>',
        },
        final name when _publicHeaders.contains(name) => text(entry.value),
        _ => '<redacted>',
      },
  };

  /// The adapter already has the structured parameters before serialization.
  /// Keep only a small summary when decoding the wire body would copy an image.
  static void describeRequest(
    http.BaseRequest request,
    Map<String, dynamic>? body,
  ) {
    if (RequestLogger.enabled &&
        body != null &&
        request is http.Request &&
        request.bodyBytes.length > maxBodyBytes) {
      _largeRequests[request] = _json(body);
    }
  }

  static void copyDescription(http.BaseRequest source, http.Request target) {
    final summary = _largeRequests[source];
    if (summary != null) _largeRequests[target] = summary;
  }

  static String requestBody(
    http.BaseRequest request,
    Uint8List bytes,
    String? type,
  ) {
    if (request is http.MultipartRequest) {
      return _json({
        'fields': request.fields,
        'files': [
          for (final file in request.files.take(32))
            {
              'field': file.field,
              'type': file.contentType.toString(),
              'bytes': file.length,
            },
        ],
      });
    }
    return _largeRequests[request] ??
        describeBytes(
          bytes.length,
          type,
          bytes.length <= maxBodyBytes ? bytes : null,
        );
  }

  /// Download and cancel callers normally discard a rejected body. Let the
  /// transport log small provider explanations without waiting for a file.
  static Future<void> discard(http.StreamedResponse response) async {
    if (!RequestLogger.enabled ||
        requestId(response.request) == null ||
        (!RequestLogger.saveOutput && response.statusCode < 400) ||
        (response.contentLength ?? 0) > maxBodyBytes ||
        !canReadText(response.headers['content-type'])) {
      await response.stream.listen(null).cancel();
      return;
    }
    final iterator = StreamIterator(response.stream);
    final elapsed = Stopwatch()..start();
    var count = 0;
    try {
      while (count <= maxBodyBytes) {
        final remaining = const Duration(seconds: 1) - elapsed.elapsed;
        if (remaining <= Duration.zero ||
            !await iterator.moveNext().timeout(remaining)) {
          break;
        }
        count += iterator.current.length;
      }
    } catch (_) {
      // The caller already has the HTTP status; a diagnostic read is optional.
    } finally {
      await iterator.cancel();
    }
  }

  static bool canReadText(String? type) {
    final mime = type?.split(';').first.trim().toLowerCase() ?? '';
    return mime.isEmpty ||
        mime.startsWith('text/') ||
        mime.endsWith('json') ||
        mime.endsWith('xml') ||
        mime == 'application/x-ndjson';
  }

  static String describeBytes(int length, String? type, Uint8List? bytes) {
    final mime = type?.split(';').first.trim().toLowerCase() ?? '';
    final summary = '<${mime.isEmpty ? 'body' : mime}, $length bytes>';
    if (bytes == null || !canReadText(type)) return summary;
    try {
      final content = utf8.decode(bytes).trim();
      if (content.isEmpty) return summary;
      if (content.startsWith('{') || content.startsWith('[')) {
        return _json(jsonDecode(content));
      }
      if (mime.endsWith('xml')) {
        // Object stores return XML on a failed signed download. Other nodes
        // can contain the signing material or base64, so select error fields.
        final root = XmlDocument.parse(content).rootElement;
        final error = root.name.local == 'Error'
            ? root
            : root.getElement('Error');
        if (error != null) {
          return _json({
            for (final name in ['Code', 'Message', 'RequestId'])
              if (error.getElement(name) case final element?)
                name: element.innerText,
          });
        }
        return summary;
      }
      if (mime == 'text/event-stream') {
        return const LineSplitter()
            .convert(content)
            .map((line) {
              if (!line.startsWith('data:')) return text(line);
              final data = line.substring(5).trim();
              return data == '[DONE]'
                  ? line
                  : 'data: ${_json(jsonDecode(data))}';
            })
            .join('\n');
      }
      // A missing Content-Type is common for JSON. Arbitrary file bytes
      // which happen to be valid UTF-8 must still stay out of the log.
      if (mime.startsWith('text/') &&
          !content.contains(RegExp(r'[\x00-\x08\x0e-\x1f]'))) {
        return text(content);
      }
    } on XmlException {
      return summary;
    } on FormatException {
      // Binary, incomplete JSON, or a malformed event stream.
    }
    return summary;
  }

  static String _json(Object? value) {
    var nodes = 160;
    Object? visit(Object? node, [String key = '', int depth = 0]) {
      nodes--;
      if (depth >= 10 || nodes < 0) return '<omitted>';
      if (node is Map) {
        final result = <String, Object?>{};
        for (final e in node.entries) {
          if (nodes <= 0) {
            result['…'] = '<more fields>';
            break;
          }
          final name = e.key.toString();
          result[text(name)] = visit(e.value, name.toLowerCase(), depth + 1);
        }
        return result;
      }
      if (node is List) {
        final result = <Object?>[];
        for (final entry in node) {
          if (nodes <= 0) {
            result.add('<more items>');
            break;
          }
          result.add(visit(entry, key, depth + 1));
        }
        return result;
      }
      if (node is String) {
        if (key == 'key' || key == 'token') return '<redacted>';
        if ((key == 'url' ||
                key.endsWith('_url') ||
                key == 'uri' ||
                key == 'href') &&
            node.length <= 2048 &&
            !node.startsWith('data:') &&
            node.contains('?')) {
          final uri = Uri.tryParse(node);
          return uri == null ? '<URL>' : url(uri);
        }
        if (const {'metadata', 'parameters', 'extra'}.contains(key) &&
            node.length <= maxBodyBytes &&
            (node.startsWith('{') || node.startsWith('['))) {
          try {
            return visit(jsonDecode(node), key, depth + 1);
          } on FormatException {
            // Some relays use a plain string for this field.
          }
        }
        final rawImage =
            const {
              'image',
              'images',
              'video',
              'videos',
              'audio',
              'image_url',
              'image_urls',
              'input_reference',
              'input_references',
              'image_bytes',
            }.contains(key) &&
            !node.startsWith('https://') &&
            !node.startsWith('http://');
        if (rawImage ||
            key == 'data' ||
            _encodedFields.contains(key) ||
            key.contains('base64') ||
            node.startsWith('data:')) {
          return '<inline data, ${node.length} characters>';
        }
        return text(node);
      }
      return node;
    }

    return LogRedactor.redactBody(jsonEncode(visit(value)));
  }
}

/// Counts the original wire bytes and retains at most one small textual body.
/// This is a passive observer; callers keep their original response stream.
class MediaResponseLog {
  MediaResponseLog(this.contentType, int? expectedLength)
    : _bytes =
          MediaHttpLog.canReadText(contentType) &&
              (expectedLength ?? 0) <= MediaHttpLog.maxBodyBytes
          ? BytesBuilder()
          : null;
  final String? contentType;
  BytesBuilder? _bytes;
  int _length = 0;

  void add(Uint8List chunk) {
    _length += chunk.length;
    if (_length > MediaHttpLog.maxBodyBytes) _bytes = null;
    _bytes?.add(chunk);
  }

  String? finish({required bool complete}) {
    if (_length == 0) return null;
    return MediaHttpLog.describeBytes(
      _length,
      contentType,
      complete ? _bytes?.takeBytes() : null,
    );
  }
}
