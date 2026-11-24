import '../../../providers/settings_provider.dart';
import '../../../utils/provider_url.dart';
import '../../api/chat_api_helpers.dart';
import '../gemini_media_models.dart';
import '../media_adapter.dart';
import '../media_request.dart';
import 'google_media_route.dart';

class GeminiImagesAdapter implements MediaAdapter {
  const GeminiImagesAdapter({this.apiBasePath, this.compatibleBase = false});

  final String? apiBasePath;
  final bool compatibleBase;

  static bool available(ProviderConfig provider, String id) {
    final name = modelName(provider, id);
    if (provider.vertexAI == true) {
      return !retiredOnVertex(name) &&
          (!isNanoBanana21(name) || GoogleMediaRoute.globalAvailable(provider));
    }
    return Uri.tryParse(provider.baseUrl)?.host !=
            'generativelanguage.googleapis.com' ||
        !isImagen(name);
  }

  static bool isImagen(String model) => model.startsWith('imagen-');
  static bool retiredOnVertex(String model) =>
      model.startsWith('imagen-3.') || model.startsWith('imagen-4.');
  static String modelName(ProviderConfig config, String id) =>
      googleRequestModelId(config, apiModelId(config, id));

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final id = geminiMediaName(modelName(provider, modelId));
    final imagen = isImagen(id);
    return MediaCapabilities(
      aspectRatios: [
        'auto',
        '1:1',
        '16:9',
        '9:16',
        if (!imagen) ...['3:2', '2:3', '4:3', '3:4', '4:5', '5:4', '21:9'],
        if (imagen) ...['4:3', '3:4'],
        if (id.contains('nano-banana-2.1') ||
            id.startsWith('gemini-3.1-flash-image')) ...[
          '1:4',
          '4:1',
          '1:8',
          '8:1',
        ],
      ],
      maxPerRequest: imagen ? 4 : 1,
      maxReferences: imagen
          ? 0
          : id.startsWith('gemini-2.5')
          ? 3
          : 14,
      sizes: imagen
          ? id.startsWith('imagen-4.0-') && !id.contains('-fast-')
                ? const ['1K', '2K']
                : const []
          : id.startsWith('gemini-2.5') ||
                id.startsWith('gemini-3.1-flash-lite-image')
          ? const []
          : [
              '1K',
              '2K',
              '4K',
              if (id.startsWith('gemini-3.1-flash-image')) '512',
            ],
      formats: imagen ? const ['png', 'jpeg'] : const [],
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = modelName(context.provider, request.modelId);
    final route = await GoogleMediaRoute.resolve(
      context,
      globalByDefault: isNanoBanana21(model),
      apiBase: apiBasePath != null
          ? context.endpoint(apiBasePath!).toString()
          : compatibleBase
          ? context.nativeBase('v1beta')
          : null,
    );
    final imagen = isImagen(model);
    final resource = 'models/${Uri.encodeComponent(model)}';
    final size = request.parameters['size'];
    final format = request.parameters['format'];
    final headers = context.headers(request.modelId, auth: route.auth);
    final Map<String, dynamic> output;
    if (imagen) {
      output = await context.jsonRequest(
        'POST',
        context.endpoint('$resource:predict', base: route.base),
        headers: headers,
        body: context.body(request, {
          'instances': [
            {'prompt': request.prompt},
          ],
          'parameters': {
            'sampleCount': request.count,
            if (request.aspectRatio != 'auto')
              'aspectRatio': request.aspectRatio,
            if (size != null) 'sampleImageSize': size,
            if (format != null) 'outputOptions': {'mimeType': 'image/$format'},
          },
        }),
      );
      final predictions =
          (output['predictions'] as List?)?.whereType<Map>() ?? const [];
      final generated = [
        for (final value in predictions)
          if (value['bytesBase64Encoded'] case final String data
              when data.isNotEmpty)
            MediaResult(
              mime: value['mimeType'] as String? ?? 'image/png',
              base64: data,
            ),
      ];
      if (generated.isEmpty &&
          predictions.any((row) => row['raiFilteredReason'] != null)) {
        throw const MediaFailure(MediaFailureKind.rejected, 'Image filtered');
      }
      yield MediaOutput(generated);
      return;
    }

    final parts = <Map<String, dynamic>>[
      {'text': request.prompt},
    ];
    for (final reference in request.inputImages) {
      final image = await googleImageInput(reference);
      parts.add({
        'inlineData': {'mimeType': image.mime, 'data': image.base64},
      });
    }
    output = await context.jsonRequest(
      'POST',
      context.endpoint('$resource:generateContent', base: route.base),
      headers: headers,
      body: context.body(request, {
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'generationConfig': {
          'responseModalities': [
            if (geminiMediaName(model).startsWith('gemini-2.5')) 'TEXT',
            'IMAGE',
          ],
          if (size != null || request.aspectRatio != 'auto')
            'imageConfig': {
              if (request.aspectRatio != 'auto')
                'aspectRatio': request.aspectRatio,
              if (size != null) 'imageSize': size,
            },
        },
      }),
    );
    final candidates =
        (output['candidates'] as List?)?.whereType<Map>() ?? const [];
    final images = <MediaResult>[];
    for (final candidate in candidates) {
      final content = candidate['content'] as Map?;
      for (final part
          in (content?['parts'] as List? ?? const []).whereType<Map>()) {
        if (part['thought'] == true) continue;
        final inline = part['inlineData'] ?? part['inline_data'];
        if (inline case {'data': final String data} when data.isNotEmpty) {
          final mime = inline['mimeType'] ?? inline['mime_type'] ?? 'image/png';
          if (mime is String && mime.startsWith('image/')) {
            images.add(MediaResult(mime: mime, base64: data));
          }
        } else {
          final file = part['fileData'] ?? part['file_data'];
          if (file is! Map) continue;
          final url = route.resultUri(file['fileUri'] ?? file['file_uri']);
          final mime = file['mimeType'] ?? file['mime_type'];
          if (url != null && mime is String && mime.startsWith('image/')) {
            images.add(
              MediaResult(
                mime: mime,
                url: url,
                downloadHeaders: route.resultHeaders(
                  url,
                  vertex: context.provider.vertexAI == true,
                  headers: headers,
                ),
              ),
            );
          }
        }
      }
    }
    if (images.isEmpty &&
        ((output['promptFeedback'] as Map?)?['blockReason'] != null ||
            candidates.any(
              (row) => const {
                'SAFETY',
                'IMAGE_SAFETY',
                'IMAGE_PROHIBITED_CONTENT',
              }.contains(row['finishReason']),
            ))) {
      throw const MediaFailure(MediaFailureKind.rejected, 'Image filtered');
    }
    yield MediaOutput(images);
  }
}
