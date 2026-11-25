import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class MiniMaxVideoAdapter implements MediaAdapter {
  const MiniMaxVideoAdapter({this.apiPath = '/v2'});

  final String apiPath;

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    final shortest = model.contains('-max') ? 5 : 4;
    return MediaCapabilities(
      aspectRatios: const ['16:9', '9:16', '1:1', '4:3', '3:4', '21:9'],
      durations: [
        for (var seconds = shortest; seconds <= 15; seconds++) seconds,
      ],
      resolutions: [
        '768p',
        if (!model.endsWith('-mg')) '480p',
        if (model == 'minimax-h3' || model.endsWith('-mg')) '2K',
      ],
      maxReferences: 2,
      frameRoles: const [
        MediaReferenceRole.firstFrame,
        MediaReferenceRole.lastFrame,
      ],
      framesUseAutomaticRatio: true,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final headers = context.headers(request.modelId);
    final frames = request.inputImages;
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('$apiPath/video_generation'),
      headers: headers,
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'resolution': (request.resolution ?? '768p').toUpperCase(),
        'duration': request.durationSec ?? 6,
        if (frames.isEmpty)
          'ratio': request.aspectRatio == 'auto' ? '16:9' : request.aspectRatio,
        'content': [
          {'type': 'text', 'text': request.prompt},
          for (final frame in frames)
            {
              'type': 'image_url',
              'image_url': {'url': await mediaReferenceDataUri(frame)},
              'role': frame.role == MediaReferenceRole.lastFrame
                  ? 'last_frame'
                  : 'first_frame',
            },
        ],
      }),
    );
    _checkResponse(created);
    final id = Uri.encodeComponent(requireMediaTaskId(created['task_id']));
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('$apiPath/query/video_generation/$id'),
        headers: headers,
      ),
      result: (data) {
        _checkResponse(data);
        final task = data['task'];
        if (task is Map) {
          switch (task['status']) {
            case 'queued' || 'running':
              return null;
            case 'succeeded':
              final content = task['content'];
              final url = mediaResultUri(
                content is Map ? content['url'] : null,
              );
              if (url != null) {
                return [
                  MediaResult(
                    mime: 'video/mp4',
                    url: url,
                    durationMs: videoDurationMs(
                      task['duration'] ?? request.durationSec,
                    ),
                  ),
                ];
              }
            case 'failed' || 'cancelled' || 'expired':
              failedMediaTask(task['error']);
          }
        }
        throw const MediaFailure(
          MediaFailureKind.invalidResponse,
          'Invalid MiniMax video task',
        );
      },
    );
  }

  static void _checkResponse(Map<String, dynamic> data) {
    if (data['base_resp'] case {'status_code': final int code} when code != 0) {
      throw mediaResponseFailure(data['base_resp']);
    }
  }
}
