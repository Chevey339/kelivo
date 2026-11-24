import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../utils/sandbox_path_resolver.dart';
import '../../../models/provider_oauth.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../../api/stream/sse_framing.dart';
import '../media_adapter.dart';
import '../media_request.dart';

class OpenAiImagesAdapter implements MediaAdapter {
  const OpenAiImagesAdapter({this.generationOnly = false});

  final bool generationOnly;

  static bool _isGpt(String id) =>
      id.startsWith('gpt-image-') || id.startsWith('chatgpt-image-');

  static bool _isOfficial(ProviderConfig config) {
    final uri = Uri.tryParse(config.baseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'api.openai.com' &&
        uri.port == 443;
  }

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final id = apiModelId(provider, modelId).toLowerCase();
    final codex = provider.oauthProvider == OAuthProvider.chatgpt;
    final legacySquare = id == 'dall-e-2';
    final legacyWide = id == 'dall-e-3';
    final canOnlyGenerate =
        generationOnly ||
        legacyWide ||
        id.startsWith('agnes-image-') ||
        id == 'sensenova-u1-fast';
    final gpt = _isGpt(id);
    final ratios = legacySquare
        ? const ['1:1']
        : const ['auto', '1:1', '3:2', '2:3'];
    return MediaCapabilities(
      aspectRatios: ratios,
      maxPerRequest: codex || legacyWide ? 1 : 10,
      maxReferences: canOnlyGenerate
          ? 0
          : legacySquare || !_isGpt(id)
          ? 1
          : codex
          ? 5
          : 16,
      sizes: legacySquare
          ? const ['256x256', '512x512', '1024x1024']
          : legacyWide
          ? const ['1024x1024', '1792x1024', '1024x1792']
          : const ['1024x1024', '1536x1024', '1024x1536'],
      qualities: gpt ? const ['auto', 'low', 'medium', 'high'] : const [],
      formats: gpt ? const ['png', 'jpeg', 'webp'] : const [],
      supportsTransparent: gpt,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final codex = context.provider.oauthProvider == OAuthProvider.chatgpt;
    final legacySquare = model == 'dall-e-2';
    final legacyWide = model == 'dall-e-3';
    final ref = request.references;
    final editing = ref.isNotEmpty;
    final explicitSize = request.parameters['size'];
    final size =
        explicitSize ??
        switch (request.aspectRatio) {
          '1:1' => '1024x1024',
          '3:2' => legacyWide ? '1792x1024' : '1536x1024',
          '2:3' => legacyWide ? '1024x1792' : '1024x1536',
          _ => null,
        };
    final official = _isOfficial(context.provider);
    final gpt = _isGpt(model.toLowerCase());
    final body = context.body(request, {
      'model': model,
      'prompt': request.prompt,
      if (request.count != 1 || !codex) 'n': request.count,
      if (size != null) 'size': size,
      if (!official && !codex) ...{
        if (request.negativePrompt case final value?) 'negative_prompt': value,
        if (request.parameters['seed'] case final int value) 'seed': value,
      },
      if (request.parameters['quality'] case final String quality)
        'quality': quality,
      if (request.parameters['background'] case final String background)
        'background': background,
      if (request.parameters['background'] == 'transparent' &&
          request.parameters['format'] == 'jpeg')
        'output_format': 'png'
      else if (request.parameters['format'] case final String format)
        'output_format': format,
      if (legacySquare || legacyWide) 'response_format': 'b64_json',
      if (!codex && official && gpt && request.count == 1) ...{
        'stream': true,
        'partial_images': 2,
      },
    });
    final mime = switch (body['output_format']) {
      'jpeg' || 'jpg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      _ => 'image/png',
    };
    final url = context.endpoint(
      editing ? 'images/edits' : 'images/generations',
      base: codex ? OAuthProvider.chatgpt.baseUrl : null,
    );
    final http.BaseRequest httpRequest;
    if (editing && !(codex || official && gpt)) {
      final multipart = http.MultipartRequest('POST', url);
      multipart.headers.addAll(
        context.headers(request.modelId, json: false)
          ..removeWhere((key, _) => key.toLowerCase() == 'content-type'),
      );
      multipart.fields.addAll(
        body.map(
          (key, value) =>
              MapEntry(key, value is String ? value : jsonEncode(value)),
        ),
      );
      for (final reference in ref) {
        final path = SandboxPathResolver.resolveForIo(reference.path);
        if (path == null) {
          throw const MediaFailure(
            MediaFailureKind.parameters,
            'Reference file unavailable',
          );
        }
        multipart.files.add(
          await http.MultipartFile.fromPath(
            gpt ? 'image[]' : 'image',
            path,
            contentType: MediaType.parse(mimeFromPath(path)),
          ),
        );
      }
      httpRequest = multipart;
    } else {
      if (editing) {
        body['images'] = [
          for (final reference in ref)
            {'image_url': await mediaReferenceDataUri(reference)},
        ];
      }
      httpRequest = http.Request('POST', url)
        ..headers.addAll(
          context.headers(
            request.modelId,
            extra: {if (codex) 'x-codex-image-turn-id': context.requestId},
          ),
        )
        ..body = jsonEncode(body);
    }
    final response = await context.send(httpRequest, diagnosticBody: body);
    if (!((response.headers['content-type'] ?? '').contains(
      'text/event-stream',
    ))) {
      yield MediaOutput(
        parseOpenAiMediaImages(await readMediaJson(response), mime: mime),
      );
      return;
    }

    final completed = <MediaResult>[];
    await for (final event in parseSseEvents(response.stream)) {
      if (event.data.isEmpty || event.data == '[DONE]') continue;
      final data = await compute(decodeMediaEvent, event.data);
      final type = (data['type'] ?? event.event ?? '').toString();
      if (type == 'error' || data['error'] != null) {
        throw mediaResponseFailure(data['error'] ?? data);
      }
      final image = data['b64_json'];
      if (image is! String || image.isEmpty) continue;
      if (type.endsWith('.partial_image')) {
        yield MediaPreview(image);
      } else if (type.endsWith('.completed')) {
        completed.add(
          MediaResult(
            mime: mime,
            base64: image,
            revisedPrompt: data['revised_prompt'] as String?,
          ),
        );
      }
    }
    if (completed.isEmpty) {
      throw const MediaFailure(
        MediaFailureKind.invalidResponse,
        'Image stream ended before completion',
      );
    }
    yield MediaOutput(completed);
  }
}

Map<String, dynamic> decodeMediaEvent(String data) {
  final decoded = jsonDecode(data);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected an image stream event');
  }
  return decoded;
}
