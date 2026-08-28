import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../models/token_usage.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/multimodal_input_utils.dart';
import '../../../../utils/app_directories.dart';
import '../../../../utils/sandbox_path_resolver.dart';
import '../chat_api_helpers.dart';
import '../stream/stream_chunk.dart';
import '../stream/stream_chunk_emit.dart';
import '../stream/stream_chunk_ids.dart';

bool shouldUseOpenAIImagesApi(ProviderConfig config, String modelId) {
  final upstreamModelId = apiModelId(config, modelId).toLowerCase();
  return _supportsOpenAIImageGenerations(upstreamModelId);
}

bool _supportsOpenAIImageGenerations(String modelId) {
  final normalized = _unprefixedImageModelId(modelId);
  return normalized.startsWith('gpt-image-') ||
      normalized.startsWith('chatgpt-image-') ||
      normalized.startsWith('agnes-image-') ||
      normalized == 'sensenova-u1-fast' ||
      normalized == 'dall-e-2' ||
      normalized == 'dall-e-3';
}

bool _supportsOpenAIImageEdits(String modelId) {
  final normalized = _unprefixedImageModelId(modelId);
  return normalized.startsWith('gpt-image-') ||
      normalized.startsWith('chatgpt-image-') ||
      normalized == 'dall-e-2';
}

String _unprefixedImageModelId(String modelId) {
  final normalized = modelId.toLowerCase().trim();
  final slash = normalized.lastIndexOf('/');
  return slash >= 0 ? normalized.substring(slash + 1) : normalized;
}

Uri _openAIImagesUrl(ProviderConfig config, String path) {
  final rawBase = config.baseUrl.endsWith('/')
      ? config.baseUrl.substring(0, config.baseUrl.length - 1)
      : config.baseUrl;
  return Uri.parse('$rawBase$path');
}

Stream<StreamChunk> sendOpenAIImagesStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  List<String>? userImagePaths,
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
}) async* {
  final input = await _openAIImagesInput(messages, userImagePaths);
  final outputMime = _openAIImagesOutputMime(config, modelId, extraBody);
  final upstreamModelId = apiModelId(config, modelId);
  if (input.imageRefs.isNotEmpty &&
      !_supportsOpenAIImageEdits(upstreamModelId)) {
    throw UnsupportedError(
      'OpenAI Images API model $upstreamModelId does not support image edits with input images.',
    );
  }
  final response = input.imageRefs.isEmpty
      ? await _sendOpenAIImageGeneration(
          client,
          config,
          modelId,
          input.prompt,
          extraHeaders: extraHeaders,
          extraBody: extraBody,
        )
      : await _sendOpenAIImageEdit(
          client,
          config,
          modelId,
          input.prompt,
          input.imageRefs,
          extraHeaders: extraHeaders,
          extraBody: extraBody,
        );
  final images = await _openAIImagesFromResponse(
    response,
    outputMime: outputMime,
  );
  final usage = _openAIImagesUsage(response);
  final ids = StreamChunkIds('finish');
  yield* emitImages(images, ids: ids);
  yield* emitFinish(
    ids: ids,
    usage: usage,
    totalTokens: usage?.totalTokens ?? 0,
  );
}

Future<Map<String, dynamic>> _sendOpenAIImageGeneration(
  http.Client client,
  ProviderConfig config,
  String modelId,
  String prompt, {
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
}) async {
  final body = <String, dynamic>{
    'model': apiModelId(config, modelId),
    'prompt': prompt,
  };
  _applyOpenAIImagesExtraBody(body, config, modelId, extraBody);
  final response = await client.post(
    _openAIImagesUrl(config, '/images/generations'),
    headers: _openAIImagesJsonHeaders(
      config,
      modelId,
      extraHeaders: extraHeaders,
    ),
    body: jsonEncode(body),
  );
  return _decodeOpenAIImagesResponse(response);
}

Future<Map<String, dynamic>> _sendOpenAIImageEdit(
  http.Client client,
  ProviderConfig config,
  String modelId,
  String prompt,
  List<ImageRef> imageRefs, {
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
}) async {
  final allRemote = imageRefs.every((ref) => ref.kind == 'url');
  if (allRemote) {
    final body = <String, dynamic>{
      'model': apiModelId(config, modelId),
      'prompt': prompt,
      'images': [
        for (final ref in imageRefs) {'image_url': ref.src},
      ],
    };
    _applyOpenAIImagesExtraBody(body, config, modelId, extraBody);
    final response = await client.post(
      _openAIImagesUrl(config, '/images/edits'),
      headers: _openAIImagesJsonHeaders(
        config,
        modelId,
        extraHeaders: extraHeaders,
      ),
      body: jsonEncode(body),
    );
    return _decodeOpenAIImagesResponse(response);
  }

  if (imageRefs.any((ref) => ref.kind == 'url')) {
    throw const FormatException(
      'OpenAI image edits cannot mix remote image URLs with local image files.',
    );
  }

  final request = http.MultipartRequest(
    'POST',
    _openAIImagesUrl(config, '/images/edits'),
  );
  request.headers.addAll(
    _openAIImagesMultipartHeaders(config, modelId, extraHeaders: extraHeaders),
  );
  request.fields['model'] = apiModelId(config, modelId);
  request.fields['prompt'] = prompt;
  final body = <String, dynamic>{};
  _applyOpenAIImagesExtraBody(body, config, modelId, extraBody);
  for (final entry in body.entries) {
    if (entry.value == null) continue;
    request.fields[entry.key] = entry.value.toString();
  }
  for (final ref in imageRefs) {
    final file = await _tryOpenAIImageMultipartFile(ref);
    if (file != null) request.files.add(file);
  }
  final streamed = await client.send(request);
  final response = await http.Response.fromStream(streamed);
  return _decodeOpenAIImagesResponse(response);
}

Future<String> _lastOpenAIImagePrompt(
  List<Map<String, dynamic>> messages,
) async {
  for (int i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() != 'user') continue;
    final content = messages[i]['content'];
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is! Map) continue;
        final type = (part['type'] ?? '').toString();
        if (type == 'text' || type == 'input_text') {
          final text = (part['text'] ?? part['content'] ?? '').toString();
          if (text.trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln();
            buffer.write(text.trim());
          }
        }
      }
      final prompt = buffer.toString().trim();
      if (prompt.isNotEmpty) return prompt;
      continue;
    }
    final parsed = await parseTextAndImages(
      (content ?? '').toString(),
      allowRemoteImages: true,
      allowLocalImages: true,
      keepRemoteMarkdownText: false,
    );
    final prompt = parsed.text.trim();
    if (prompt.isNotEmpty) return prompt;
  }
  return '';
}

Future<_OpenAIImagesInput> _openAIImagesInput(
  List<Map<String, dynamic>> messages,
  List<String>? userImagePaths,
) async {
  final prompt = await _lastOpenAIImagePrompt(messages);
  final explicitPaths = (userImagePaths ?? const <String>[])
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toList(growable: false);

  // Prefer structured multimodal refs (with mime) from the last user message
  // even when bare userImagePaths are also provided.
  for (int i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() != 'user') continue;
    final message = messages[i];
    final internalMediaRefs = parseInternalMediaRefs(
      message[multimodalInternalMediaPathsKey],
    );
    if (internalMediaRefs.isNotEmpty) {
      // /images/edits only accepts image/* inputs; skip audio/video/octet-stream.
      return _OpenAIImagesInput(
        prompt: prompt,
        imageRefs: [
          for (final mediaRef in internalMediaRefs)
            if (isImageMime(mimeForInternalMediaRef(mediaRef)))
              _imageRefFromSource(mediaRef.uri, mime: mediaRef.mime),
        ],
      );
    }
    break;
  }

  // Bare userImagePaths only (no structured refs on the last user turn).
  if (explicitPaths.isNotEmpty) {
    return _OpenAIImagesInput(
      prompt: prompt,
      imageRefs: [for (final path in explicitPaths) _imageRefFromSource(path)],
    );
  }

  for (int i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() != 'user') continue;
    final message = messages[i];
    // Structured media paths were already handled above; continue with
    // content-list / markdown / prior-assistant fallbacks.
    final content = message['content'];
    if (content is List) {
      final structuredImages = _extractOpenAIImageRefs(content);
      if (structuredImages.isNotEmpty) {
        return _OpenAIImagesInput(prompt: prompt, imageRefs: structuredImages);
      }
    }

    final parsed = await parseTextAndImages(
      (content ?? '').toString(),
      allowRemoteImages: true,
      allowLocalImages: true,
      keepRemoteMarkdownText: false,
    );
    if (parsed.images.isNotEmpty) {
      return _OpenAIImagesInput(prompt: prompt, imageRefs: parsed.images);
    }

    final previousAssistantImage = _lastAssistantImageBefore(messages, i);
    if (previousAssistantImage == null) {
      return _OpenAIImagesInput(prompt: prompt);
    }

    return _OpenAIImagesInput(
      prompt: prompt,
      imageRefs: [previousAssistantImage],
    );
  }
  return _OpenAIImagesInput(prompt: prompt);
}

ImageRef? _lastAssistantImageBefore(
  List<Map<String, dynamic>> messages,
  int beforeIndex,
) {
  for (int i = beforeIndex - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() != 'assistant') continue;
    final images = _extractOpenAIImageRefs(messages[i]['content']);
    if (images.isNotEmpty) return images.last;
  }
  return null;
}

List<ImageRef> _extractOpenAIImageRefs(dynamic content) {
  if (content is List) {
    final refs = <ImageRef>[];
    for (final part in content) {
      if (part is! Map) continue;
      final type = (part['type'] ?? '').toString();
      if (type == 'image_url') {
        _addOpenAIStructuredImageRefs(refs, part['image_url']);
      } else if (type == 'input_image' || type == 'image') {
        _addOpenAIStructuredImageRefs(refs, part['image_url']);
        _addOpenAIStructuredImageRefs(refs, part['input_image']);
      }
    }
    return refs;
  }

  final raw = (content ?? '').toString();
  if (raw.isEmpty) return const <ImageRef>[];
  final refs = <ImageRef>[];
  // Markdown images only. Custom attachment markers are not recognized;
  // attachments arrive via userImagePaths / multimodalInternalMediaPathsKey.
  final markdownImage = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');
  for (final match in markdownImage.allMatches(raw)) {
    final source = (match.group(1) ?? '').trim();
    if (source.isNotEmpty) refs.add(_imageRefFromSource(source));
  }
  return refs;
}

void _addOpenAIStructuredImageRefs(List<ImageRef> refs, dynamic value) {
  if (value == null) return;
  if (value is List) {
    for (final item in value) {
      _addOpenAIStructuredImageRefs(refs, item);
    }
    return;
  }
  if (value is Map) {
    _addOpenAIStructuredImageRefs(refs, value['url'] ?? value['image_url']);
    final data = value['data'];
    if (data != null) {
      final type = (value['type'] ?? '').toString().trim().toLowerCase();
      final mime = (value['mime_type'] ?? value['media_type'] ?? 'image/png')
          .toString()
          .trim();
      _addOpenAIStructuredImageData(
        refs,
        data,
        isBase64: type == 'base64',
        mime: mime.isEmpty ? 'image/png' : mime,
      );
    }
    return;
  }
  final source = value.toString().trim();
  if (source.isNotEmpty) refs.add(_imageRefFromSource(source));
}

void _addOpenAIStructuredImageData(
  List<ImageRef> refs,
  dynamic data, {
  required bool isBase64,
  required String mime,
}) {
  if (data is List) {
    for (final item in data) {
      _addOpenAIStructuredImageData(refs, item, isBase64: isBase64, mime: mime);
    }
    return;
  }
  var source = data.toString().trim();
  if (source.isEmpty) return;
  if (isBase64 && !source.startsWith('data:')) {
    source = 'data:$mime;base64,$source';
  }
  refs.add(_imageRefFromSource(source));
}

ImageRef _imageRefFromSource(String source, {String? mime}) {
  if (source.startsWith('data:')) {
    return ImageRef('data', source, mime: mime);
  }
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return ImageRef('url', source, mime: mime);
  }
  return ImageRef('path', source, mime: mime);
}

Future<http.MultipartFile?> _tryOpenAIImageMultipartFile(ImageRef ref) async {
  if (ref.kind == 'data') {
    final mime = (ref.mime != null && ref.mime!.trim().isNotEmpty)
        ? ref.mime!.trim()
        : mimeFromDataUrl(ref.src);
    final commaIndex = ref.src.indexOf(',');
    final payload = commaIndex >= 0
        ? ref.src.substring(commaIndex + 1)
        : ref.src;
    return http.MultipartFile.fromBytes(
      'image[]',
      base64Decode(payload.replaceAll(RegExp(r'\s'), '')),
      filename: 'image.${AppDirectories.extFromMime(mime)}',
      contentType: _openAIImageMediaType(mime),
    );
  }
  try {
    final fixed = SandboxPathResolver.fix(ref.src);
    final file = File(fixed);
    if (!await file.exists()) return null;
    final mime = (ref.mime != null && ref.mime!.trim().isNotEmpty)
        ? ref.mime!.trim()
        : mimeFromPath(fixed);
    return http.MultipartFile.fromPath(
      'image[]',
      fixed,
      contentType: _openAIImageMediaType(mime),
    );
  } catch (_) {
    return null;
  }
}

MediaType _openAIImageMediaType(String mime) {
  final normalized = mime.trim().toLowerCase();
  if (normalized == 'image/jpeg' ||
      normalized == 'image/png' ||
      normalized == 'image/webp') {
    return MediaType.parse(normalized);
  }
  throw FormatException(
    'OpenAI image edits only support image/jpeg, image/png, and image/webp; got $mime.',
  );
}

Map<String, String> _openAIImagesJsonHeaders(
  ProviderConfig config,
  String modelId, {
  Map<String, String>? extraHeaders,
}) {
  return customHeaders(
    config,
    modelId,
    baseHeaders: <String, String>{
      'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
      'Content-Type': 'application/json',
    },
    assistantHeaders: extraHeaders,
  );
}

Map<String, String> _openAIImagesMultipartHeaders(
  ProviderConfig config,
  String modelId, {
  Map<String, String>? extraHeaders,
}) {
  final headers = customHeaders(
    config,
    modelId,
    baseHeaders: <String, String>{
      'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
    },
    assistantHeaders: extraHeaders,
  );
  headers.removeWhere((key, _) => key.toLowerCase() == 'content-type');
  return headers;
}

void _applyOpenAIImagesExtraBody(
  Map<String, dynamic> body,
  ProviderConfig config,
  String modelId,
  Map<String, dynamic>? extraBody,
) {
  final custom = customBody(config, modelId, assistantBody: extraBody);
  if (custom.isNotEmpty) body.addAll(custom);
}

String _openAIImagesOutputMime(
  ProviderConfig config,
  String modelId,
  Map<String, dynamic>? extraBody,
) {
  final body = <String, dynamic>{};
  _applyOpenAIImagesExtraBody(body, config, modelId, extraBody);
  final format = (body['output_format'] ?? '').toString().trim().toLowerCase();
  switch (format) {
    case '':
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    default:
      throw FormatException(
        'OpenAI Images API output_format must be png, jpeg, or webp; got $format.',
      );
  }
}

Map<String, dynamic> _decodeOpenAIImagesResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('HTTP ${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    throw const FormatException(
      'OpenAI Images API returned a non-object body.',
    );
  }
  return decoded.cast<String, dynamic>();
}

Future<List<({String uri, String mimeType})>> _openAIImagesFromResponse(
  Map<String, dynamic> response, {
  required String outputMime,
}) async {
  final data = response['data'];
  if (data is! List || data.isEmpty) {
    return const <({String uri, String mimeType})>[];
  }
  final images = <({String uri, String mimeType})>[];
  for (final item in data) {
    if (item is! Map) continue;
    final url = (item['url'] ?? '').toString().trim();
    if (url.isNotEmpty) {
      images.add((uri: url, mimeType: mimeTypeFromImageUri(url) ?? outputMime));
      continue;
    }
    final b64 = (item['b64_json'] ?? '').toString().trim();
    if (b64.isEmpty) continue;
    final path = await AppDirectories.saveBase64Image(outputMime, b64);
    if (path == null || path.isEmpty) {
      throw const FileSystemException(
        'Failed to save OpenAI Images API base64 image.',
      );
    }
    final uri = SandboxPathResolver.canonicalize(path);
    images.add((uri: uri, mimeType: outputMime));
  }
  return images;
}

TokenUsage? _openAIImagesUsage(Map<String, dynamic> response) {
  final usage = response['usage'];
  if (usage is! Map) return null;
  final input =
      (usage['input_tokens'] ?? usage['prompt_tokens'] ?? 0) as int? ?? 0;
  final output =
      (usage['output_tokens'] ?? usage['completion_tokens'] ?? 0) as int? ?? 0;
  return TokenUsage(
    promptTokens: input,
    completionTokens: output,
    totalTokens: input + output,
  );
}

class _OpenAIImagesInput {
  const _OpenAIImagesInput({required this.prompt, this.imageRefs = const []});

  final String prompt;
  final List<ImageRef> imageRefs;
}
