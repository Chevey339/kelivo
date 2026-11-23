import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class ArkVideoAdapter implements MediaAdapter {
  const ArkVideoAdapter();

  static bool _is25(String model) =>
      model.contains('seedance-2-5') || model.contains('seedance-2.5');

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    final textOnly = model.endsWith('-t2v');
    final v2 = model.contains('seedance-2');
    final pro15 = model.contains('seedance-1-5');
    final limitedResolution =
        model.contains('2-0-fast') ||
        model.contains('2-0-mini') ||
        (_is25(model) && model.contains('flash'));
    final last =
        !textOnly &&
        (v2 || pro15 || model.contains('lite-i2v') || model.startsWith('ep-'));
    return MediaCapabilities(
      aspectRatios: const ['auto', '16:9', '9:16', '1:1', '4:3', '3:4', '21:9'],
      durations: v2
          ? List.generate(12, (index) => index + 4)
          : pro15
          ? List.generate(9, (index) => index + 4)
          : const [5, 10],
      resolutions: [
        '720p',
        '480p',
        if (!limitedResolution) '1080p',
        if (v2 && !limitedResolution) '4k',
      ],
      maxReferences: textOnly
          ? 0
          : last
          ? 2
          : 1,
      frameRoles: [
        if (!textOnly) MediaReferenceRole.firstFrame,
        if (last) MediaReferenceRole.lastFrame,
      ],
      requiresFirstFrame: model.endsWith('-i2v'),
      framesUseAutomaticRatio: _is25(model),
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final headers = context.headers(request.modelId);
    final model = apiModelId(context.provider, request.modelId);
    const path = 'contents/generations/tasks';
    final created = await context.jsonRequest(
      'POST',
      context.endpoint(path),
      headers: headers,
      body: context.body(request, {
        'model': model,
        'content': [
          {'type': 'text', 'text': request.prompt},
          for (final reference in request.references)
            {
              'type': 'image_url',
              'image_url': {'url': await mediaReferenceDataUri(reference)},
              'role': reference.role == MediaReferenceRole.lastFrame
                  ? 'last_frame'
                  : 'first_frame',
            },
        ],
        if (_is25(model.toLowerCase()) && request.references.isNotEmpty)
          'ratio': 'adaptive'
        else if (request.aspectRatio != 'auto')
          'ratio': request.aspectRatio,
        if (request.resolution case final value?) 'resolution': value,
        if (request.durationSec case final value?) 'duration': value,
      }),
    );
    final id = Uri.encodeComponent(requireMediaTaskId(created['id']));
    final task = context.endpoint('$path/$id');
    yield* pollMediaTask(
      context,
      accepted: MediaTaskAccepted(cancelUrl: task, cancelHeaders: headers),
      poll: () => context.jsonRequest('GET', task, headers: headers),
      progress: (data) => mediaPercent(data['progress']),
      result: (data) {
        final status = data['status'];
        if (const {
          'failed',
          'canceled',
          'cancelled',
          'expired',
        }.contains(status)) {
          failedMediaTask(data['error']);
        }
        if (status != 'succeeded') return null;
        final content = data['content'] as Map?;
        final url = mediaResultUri(content?['video_url']);
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
            previewUrl: mediaResultUri(
              content?['first_frame_url'] ?? content?['cover_url'],
            ),
            durationMs: videoDurationMs(
              data['duration'] ?? request.durationSec,
            ),
          ),
        ];
      },
    );
  }
}
