import '../../../models/media_creation.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_request.dart';
import '../openrouter_media_catalog.dart';
import 'openai_videos.dart';
import 'native_image_size.dart';

class OpenRouterMediaAdapter implements MediaAdapter {
  const OpenRouterMediaAdapter(this.mode, this.model);
  final MediaMode mode;
  final OpenRouterMediaModel? model;

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      model?.capabilities ?? const MediaCapabilities(aspectRatios: ['auto']);

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final video = mode == MediaMode.video;
    final params = request.parameters;
    final headers = context.headers(request.modelId);
    final response = await context.jsonRequest(
      'POST',
      context.endpoint(video ? 'videos' : 'images'),
      headers: headers,
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (request.aspectRatio != 'auto') 'aspect_ratio': request.aspectRatio,
        if (params['seed'] case final int seed) 'seed': seed,
        if (video) ...{
          if (request.durationSec case final value?) 'duration': value,
          if (request.resolution case final value?) 'resolution': value,
          if (params['generate_audio'] case final bool value)
            'generate_audio': value,
        } else ...{
          'response_format': 'url',
          if (request.count > 1) 'n': request.count,
          if (params['size'] case final String size) 'resolution': size,
          if (params['quality'] case final String quality) 'quality': quality,
          if (params['format'] case final String format)
            'output_format': format,
          if (params['background'] case final String background)
            'background': background,
        },
        if (request.inputImages.isNotEmpty)
          (video ? 'frame_images' : 'input_references'): [
            for (final image in request.inputImages)
              {
                'type': 'image_url',
                'image_url': {'url': await mediaReferenceDataUri(image)},
                if (video)
                  'frame_type': image.role == MediaReferenceRole.lastFrame
                      ? 'last_frame'
                      : 'first_frame',
              },
          ],
      }),
    );
    if (video) {
      yield* pollOpenAiVideo(context, request, response, headers);
    } else {
      yield MediaOutput(
        parseOpenAiMediaImages(response, mime: imageMime(params['format'])),
      );
    }
  }
}
