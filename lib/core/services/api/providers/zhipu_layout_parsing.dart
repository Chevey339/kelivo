import '../../network/provider_http_exception.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../models/token_usage.dart';
import '../../../providers/settings_provider.dart';
import '../chat_api_helpers.dart';
import '../stream/stream_chunk.dart';
import '../stream/stream_chunk_emit.dart';
import '../stream/stream_chunk_ids.dart';

const String officialGlmOcrModelId = 'glm-ocr';

/// Official GLM-OCR uses `/layout_parsing` with `{model, file}`, not Chat Completions.
bool shouldUseZhipuLayoutParsing(ProviderConfig config, String modelId) {
  return isOfficialZhipuHost(config) &&
      isOfficialGlmOcrModel(apiModelId(config, modelId));
}

bool isOfficialZhipuHost(ProviderConfig config) {
  final host = Uri.tryParse(config.baseUrl.trim())?.host.toLowerCase() ?? '';
  return host == 'open.bigmodel.cn';
}

bool isOfficialGlmOcrModel(String modelId) {
  return modelId.trim().toLowerCase() == officialGlmOcrModelId;
}

Stream<StreamChunk> sendZhipuLayoutParsingStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  List<String>? userImagePaths,
  Map<String, String>? extraHeaders,
}) async* {
  final file = await _resolveLayoutParsingFile(
    messages: messages,
    userImagePaths: userImagePaths,
  );
  final body = <String, dynamic>{'model': officialGlmOcrModelId, 'file': file};
  final response = await client.post(
    _layoutParsingUrl(config),
    headers: customHeaders(
      config,
      modelId,
      baseHeaders: <String, String>{
        'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
        'Content-Type': 'application/json',
      },
      assistantHeaders: extraHeaders,
    ),
    body: jsonEncode(body),
  );
  final decoded = _decodeLayoutParsingResponse(response);
  final ids = StreamChunkIds('finish');
  yield* emitText(_mdResultsFromResponse(decoded), ids: ids);
  final usage = _usageFromResponse(decoded);
  yield* emitFinish(
    ids: ids,
    usage: usage,
    totalTokens: usage?.totalTokens ?? 0,
  );
}

Uri _layoutParsingUrl(ProviderConfig config) {
  final rawBase = config.baseUrl.endsWith('/')
      ? config.baseUrl.substring(0, config.baseUrl.length - 1)
      : config.baseUrl;
  return Uri.parse('$rawBase/layout_parsing');
}

Future<String> _resolveLayoutParsingFile({
  required List<Map<String, dynamic>> messages,
  List<String>? userImagePaths,
}) async {
  for (final path in userImagePaths ?? const <String>[]) {
    final encoded = await _encodeLayoutParsingFile(path);
    if (encoded != null) return encoded;
  }
  for (var i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() != 'user') continue;
    final encoded = await _encodeLayoutParsingFileFromContent(
      messages[i]['content'],
    );
    if (encoded != null) return encoded;
  }
  throw const HttpException('GLM-OCR requires an image or PDF file.');
}

Future<String?> _encodeLayoutParsingFileFromContent(dynamic content) async {
  if (content is List) {
    for (final part in content) {
      if (part is! Map) continue;
      final type = (part['type'] ?? '').toString();
      if (type != 'image_url' && type != 'input_image' && type != 'image') {
        continue;
      }
      final image = part['image_url'] ?? part['input_image'];
      final source = image is Map
          ? (image['url'] ?? image['image_url'] ?? '').toString()
          : image?.toString() ?? '';
      final encoded = await _encodeLayoutParsingFile(source);
      if (encoded != null) return encoded;
    }
    return null;
  }
  final raw = (content ?? '').toString().trim();
  if (raw.startsWith('http://') ||
      raw.startsWith('https://') ||
      raw.startsWith('data:')) {
    return raw;
  }
  return null;
}

Future<String?> _encodeLayoutParsingFile(String source) async {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:')) {
    return trimmed;
  }
  return tryEncodeBase64DataUrl(trimmed);
}

Map<String, dynamic> _decodeLayoutParsingResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ProviderHttpException(response, response.body);
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    throw const FormatException('GLM-OCR returned a non-object body.');
  }
  return decoded.cast<String, dynamic>();
}

String _mdResultsFromResponse(Map<String, dynamic> response) {
  final raw = response['md_results'];
  if (raw is String) return raw.trim();
  if (raw is List) {
    return [
      for (final item in raw)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ].join('\n\n');
  }
  return '';
}

TokenUsage? _usageFromResponse(Map<String, dynamic> response) {
  final usage = response['usage'];
  if (usage is! Map) return null;
  final prompt = _asInt(usage['prompt_tokens']);
  final completion = _asInt(usage['completion_tokens']);
  final total = _asInt(usage['total_tokens']);
  if (prompt == 0 && completion == 0 && total == 0) return null;
  return TokenUsage(
    promptTokens: prompt,
    completionTokens: completion,
    totalTokens: total > 0 ? total : prompt + completion,
  );
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
