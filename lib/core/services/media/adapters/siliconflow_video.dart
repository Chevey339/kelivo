import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class SiliconFlowVideoAdapter implements MediaAdapter {
  const SiliconFlowVideoAdapter();

  static bool _isMiniMax(String model) =>
      model.toLowerCase().endsWith('minimax-h3');

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    if (_isMiniMax(model)) {
      return MediaCapabilities(
        aspectRatios: const ['16:9', '9:16', '1:1', '4:3', '3:4', '21:9'],
        durations: List.generate(11, (index) => index + 5),
        resolutions: const ['768p', '480p'],
        maxReferences: 2,
        frameRoles: const [
          MediaReferenceRole.firstFrame,
          MediaReferenceRole.lastFrame,
        ],
      );
    }
    final imageToVideo = model.contains('i2v');
    return MediaCapabilities(
      aspectRatios: const ['16:9', '9:16', '1:1'],
      maxReferences: imageToVideo ? 1 : 0,
      frameRoles: [if (imageToVideo) MediaReferenceRole.firstFrame],
      requiresFirstFrame: imageToVideo,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final modern = _isMiniMax(model);
    final headers = context.headers(request.modelId);
    final first = request.frame(MediaReferenceRole.firstFrame);
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('video/submit'),
      headers: headers,
      body: context.body(request, {
        'model': model,
        'prompt': request.prompt,
        if (modern) ...{
          if (request.durationSec case final value?) 'duration': value,
          if (request.resolution case final value?) 'resolution': value,
          if (request.aspectRatio != 'auto') 'ratio': request.aspectRatio,
          if (request.references.isNotEmpty)
            'images': [
              for (final reference in request.references)
                {
                  'role': reference.role == MediaReferenceRole.lastFrame
                      ? 'last_frame'
                      : 'first_frame',
                  'url': await mediaReferenceDataUri(reference),
                },
            ],
        } else ...{
          'image_size': switch (request.aspectRatio) {
            '9:16' => '720x1280',
            '1:1' => '960x960',
            _ => '1280x720',
          },
          if (first != null) 'image': await mediaReferenceDataUri(first),
        },
      }),
    );
    final requestId = requireMediaTaskId(created['requestId']);
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'POST',
        context.endpoint('video/status'),
        headers: headers,
        body: {'requestId': requestId},
      ),
      result: (data) {
        final status = data['status'];
        if (status == 'Failed') failedMediaTask(data['reason']);
        if (status != 'Succeed') return null;
        final results = data['results'] as Map?;
        final video = (results?['videos'] as List?)
            ?.whereType<Map>()
            .firstOrNull;
        final url = mediaResultUri(video?['url']);
        if (url == null) {
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Video URL missing',
          );
        }
        return [
          MediaResult(
            mime: 'video/mp4',
            url: url,
            previewUrl: mediaResultUri(video?['cover_url']),
            durationMs: videoDurationMs(
              video?['duration'] ?? request.durationSec,
            ),
          ),
        ];
      },
    );
  }
}
