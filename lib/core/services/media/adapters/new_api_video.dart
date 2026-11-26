import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

/// The JSON video task API exposed by New API gateways.
class NewApiVideoAdapter implements MediaAdapter {
  const NewApiVideoAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      const MediaCapabilities(
        aspectRatios: ['16:9', '9:16', '1:1'],
        frameRoles: [MediaReferenceRole.firstFrame],
        maxReferences: 1,
        supportsSeed: true,
        durations: [5, 10],
        resolutions: ['720p', '1080p'],
      );

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final headers = context.headers(request.modelId);
    final first = request.frame(MediaReferenceRole.firstFrame);
    final resolution = request.resolution ?? '720p';
    final shortSide = int.tryParse(
      resolution.replaceFirst(RegExp(r'[pP]$'), ''),
    );
    final aspect =
        (request.aspectRatio == 'auto' ? '16:9' : request.aspectRatio).split(
          ':',
        );
    final x = int.tryParse(aspect.first);
    final y = aspect.length == 2 ? int.tryParse(aspect.last) : null;
    if (shortSide == null ||
        shortSide <= 0 ||
        x == null ||
        x <= 0 ||
        y == null ||
        y <= 0) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Invalid video dimensions',
      );
    }
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('video/generations'),
      headers: headers,
      allowZeroErrorCode: true,
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (request.durationSec case final seconds?) 'duration': seconds,
        'width': x > y ? (shortSide * x / y).round() : shortSide,
        'height': y > x ? (shortSide * y / x).round() : shortSide,
        if (request.parameters['seed'] case final int seed) 'seed': seed,
        if (first != null) 'image': await mediaReferenceDataUri(first),
      }),
    );
    final submission = _task(created);
    final id = Uri.encodeComponent(
      requireMediaTaskId(submission['task_id'] ?? submission['id']),
    );
    final task = context.endpoint('video/generations/$id');
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        task,
        headers: headers,
        allowZeroErrorCode: true,
      ),
      initial: submission['status'] == null ? null : created,
      result: (response) {
        final data = _task(response);
        switch (data['status']?.toString().toLowerCase()) {
          case 'completed':
          case 'success':
          case 'succeeded':
            final raw = data['url'] ?? data['result_url'];
            final url =
                raw is String && raw.startsWith('/') && !raw.startsWith('//')
                ? mediaResultUri(task.resolve(raw).toString())
                : mediaResultUri(raw);
            if (url == null) {
              throw const MediaFailure(
                MediaFailureKind.invalidResponse,
                'Video URL missing',
              );
            }
            final meta = data['metadata'] as Map?;
            return [
              MediaResult(
                mime: 'video/mp4',
                url: url,
                downloadHeaders: url.origin == task.origin ? headers : const {},
                durationMs: videoDurationMs(
                  meta?['duration'] ?? request.durationSec,
                ),
              ),
            ];
          case 'failure':
          case 'failed':
          case 'cancelled':
          case 'canceled':
            failedMediaTask(data['error'] ?? data['fail_reason']);
          case 'not_start':
          case 'processing':
          case 'queued':
          case 'submitted':
          case 'in_progress':
            return null;
          default:
            throw const MediaFailure(
              MediaFailureKind.invalidResponse,
              'Unknown video task status',
            );
        }
      },
    );
  }

  static Map<String, dynamic> _task(Map<String, dynamic> response) {
    if (!response.containsKey('code')) return response;
    if (response case {
      'code': 'success',
      'data': final Map<String, dynamic> task,
    }) {
      return task;
    }
    throw mediaResponseFailure(response);
  }
}
