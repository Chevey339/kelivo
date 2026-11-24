import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../../api/providers/openai/chat_completions_api.dart';
import '../../api/stream/stream_chunk.dart' show mimeTypeFromImageUri;
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import '../gemini_media_models.dart';
import 'gemini_images.dart';

/// Image-output chat models on OpenAI-compatible gateways.
class ChatCompletionImagesAdapter implements MediaAdapter {
  const ChatCompletionImagesAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final gemini = isGeminiImageModel(apiModelId(provider, modelId));
    return MediaCapabilities(
      aspectRatios: const ['auto'],
      fixedAspectRatio: true,
      maxReferences: gemini
          ? const GeminiImagesAdapter()
                .capabilities(provider, modelId)
                .maxReferences
          : 1,
    );
  }

  static final _markdownImage = RegExp(
    r'!\[[^\]]*\]\(<?((?:https?://|data:image/)[^\s)>]+)>?\)',
  );

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': request.prompt},
      for (final ref in request.inputImages)
        {
          'type': 'image_url',
          'image_url': {'url': await mediaReferenceDataUri(ref)},
        },
    ];
    final chatPath = context.provider.chatPath ?? '/chat/completions';
    final payload = await context.jsonRequest(
      'POST',
      context.endpoint(chatPath.replaceFirst(RegExp(r'^/+'), '')),
      headers: context.headers(request.modelId),
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'messages': [
          {
            'role': 'user',
            'content': content.length == 1 ? request.prompt : content,
          },
        ],
        'stream': false,
      }),
    );
    final images = <String, MediaResult>{};
    void add(String source, String mime) {
      if (images.containsKey(source) || !mime.startsWith('image/')) return;
      final url = mediaResultUri(source);
      if (url != null) {
        images[source] = MediaResult(mime: mime, url: url);
      } else if (source.startsWith('data:image/')) {
        final comma = source.indexOf(',');
        if (comma > 0 &&
            source.substring(0, comma).endsWith(';base64') &&
            comma + 1 < source.length) {
          images[source] = MediaResult(
            mime: mime,
            base64: source.substring(comma + 1),
          );
        }
      }
    }

    for (final choice
        in (payload['choices'] as List? ?? const []).whereType<Map>()) {
      if (choice['message'] case final Map<String, dynamic> message) {
        final output = openaiVisibleOutputFromMessage(message);
        final attachments = openaiVisibleOutputFromMessage({
          'content': message['images'],
        });
        for (final image in [...output.images, ...attachments.images]) {
          add(image.uri, image.mimeType);
        }
        for (final match in _markdownImage.allMatches(output.content)) {
          final source = match.group(1)!;
          add(source, mimeTypeFromImageUri(source) ?? 'image/png');
        }
      }
    }
    yield MediaOutput(images.values.toList());
  }
}
