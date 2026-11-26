import '../../../providers/settings_provider.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import 'gemini_images.dart';
import 'google_media_route.dart';

class GeminiOmniVideoAdapter implements MediaAdapter {
  const GeminiOmniVideoAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final maxSeconds =
        GeminiImagesAdapter.modelName(provider, modelId).contains('omni-1.1-')
        ? 10
        : 15;
    return MediaCapabilities(
      aspectRatios: const ['16:9', '9:16'],
      durations: [for (var i = 3; i <= maxSeconds; i++) i],
      durationsWithLastFrame: [for (var i = 3; i <= 10; i++) i],
      resolutions: const ['720p', '360p', '1080p', '4k'],
      maxReferences: 2,
      frameRoles: const [
        MediaReferenceRole.firstFrame,
        MediaReferenceRole.lastFrame,
      ],
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final route = await GoogleMediaRoute.resolve(
      context,
      apiBase: context.nativeBase('v1beta'),
      interactions: true,
    );
    final headers = context.headers(
      request.modelId,
      auth: route.auth,
      extra: const {'Api-Revision': '2026-05-20'},
    );
    final inputs = <Map<String, dynamic>>[];
    for (final role in [
      MediaReferenceRole.firstFrame,
      MediaReferenceRole.lastFrame,
    ]) {
      final frame = request.frame(role);
      if (frame == null) continue;
      final image = await googleImageInput(frame);
      inputs.add({
        'type': 'image',
        'mime_type': image.mime,
        'data': image.base64,
      });
    }
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('interactions', base: route.base),
      headers: headers,
      body: context.body(request, {
        'model': GeminiImagesAdapter.modelName(
          context.provider,
          request.modelId,
        ),
        'input': inputs.isEmpty
            ? request.prompt
            : [
                ...inputs,
                {'type': 'text', 'text': request.prompt},
              ],
        'background': true,
        'response_format': {
          'type': 'video',
          if (request.durationSec case final duration?)
            'duration': '${duration}s',
          if (request.resolution case final resolution?)
            'resolution': resolution,
          if (request.aspectRatio != 'auto')
            'aspect_ratio': request.aspectRatio,
        },
      }),
    );
    final id = Uri.encodeComponent(requireMediaTaskId(created['id']));
    final task = context.endpoint('interactions/$id', base: route.base);
    yield* pollMediaTask(
      context,
      initial: created,
      accepted: MediaTaskAccepted(
        cancelUrl: context.endpoint(
          'interactions/$id/cancel',
          base: route.base,
        ),
        cancelMethod: 'POST',
        cancelHeaders: headers,
      ),
      poll: () => context.jsonRequest('GET', task, headers: headers),
      result: (data) {
        switch (data['status']) {
          case 'in_progress':
          case 'queued':
            return null;
          case 'completed':
            return [
              for (final step
                  in (data['steps'] as List? ?? const []).whereType<Map>())
                if (step['type'] == 'model_output')
                  for (final part
                      in (step['content'] as List? ?? const [])
                          .whereType<Map>())
                    if (part['type'] == 'video')
                      if (part['data'] case final String bytes
                          when bytes.isNotEmpty)
                        MediaResult(
                          mime: 'video/mp4',
                          base64: bytes,
                          durationMs: videoDurationMs(request.durationSec),
                        )
                      else if (route.resultUri(part['uri']) case final url?)
                        MediaResult(
                          mime: 'video/mp4',
                          url: url,
                          downloadHeaders: route.resultHeaders(
                            url,
                            vertex: context.provider.vertexAI == true,
                            headers: headers,
                          ),
                          durationMs: videoDurationMs(request.durationSec),
                        ),
            ];
          case 'cancelled':
          case 'failed':
            failedMediaTask(data['error']);
          default:
            throw const MediaFailure(
              MediaFailureKind.invalidResponse,
              'Unexpected interaction status',
            );
        }
      },
    );
  }
}
