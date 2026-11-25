import '../../../models/media_creation.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class ModelScopeImagesAdapter implements MediaAdapter {
  const ModelScopeImagesAdapter();

  // ModelScope's Qwen Image aspect ratios map to its documented pixel sizes.
  static const _sizes = {
    '1:1': '1328x1328',
    '16:9': '1664x928',
    '9:16': '928x1664',
    '4:3': '1472x1140',
    '3:4': '1140x1472',
    '3:2': '1584x1056',
    '2:3': '1056x1584',
  };

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final id = apiModelId(provider, modelId).toLowerCase();
    final edit = id.contains('edit') || id.contains('kontext');
    final unified = id.contains('qwen-image-2.1');
    final multiple =
        id.contains('qwen') && edit && RegExp(r'25(?:09|11)').hasMatch(id);
    return MediaCapabilities(
      aspectRatios: [
        'auto',
        if (id.contains('qwen-image') && !edit) ..._sizes.keys,
      ],
      maxReferences: unified
          ? 10
          : edit
          ? multiple
                ? 3
                : 1
          : 0,
      requiresReference: edit,
      supportsNegativePrompt: true,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final headers = context.headers(request.modelId);
    final refs = [
      for (final ref in request.inputImages) await mediaReferenceDataUri(ref),
    ];
    final base = context.nativeBase('v1');
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('images/generations', base: base),
      headers: {...headers, 'X-ModelScope-Async-Mode': 'true'},
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (request.negativePrompt case final String negative)
          'negative_prompt': negative,
        if (_sizes[request.aspectRatio] case final size?) 'size': size,
        if (refs.isNotEmpty)
          'image_url':
              capabilities(context.provider, request.modelId).maxReferences == 1
              ? refs.single
              : refs,
      }),
    );
    yield* _pollModelScope(context, request, created, headers);
  }
}

class ModelScopeVideoAdapter implements MediaAdapter {
  const ModelScopeVideoAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final id = apiModelId(provider, modelId).toLowerCase();
    final imageInput = !id.contains('t2v');
    return MediaCapabilities(
      aspectRatios: const ['auto', '5:3', '3:5'],
      durations: id.contains('minimax')
          ? const [3, 5, 10]
          : id.contains('ltx-2.3')
          ? const [1, 2, 3, 4, 5, 10]
          : const [1, 2, 3, 4, 5],
      maxReferences: imageInput ? 1 : 0,
      frameRoles: [if (imageInput) MediaReferenceRole.firstFrame],
      requiresFirstFrame: id.contains('i2v'),
      supportsNegativePrompt: true,
      supportsSeed: true,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final headers = context.headers(request.modelId);
    final first = request.frame(MediaReferenceRole.firstFrame);
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('videos/generations', base: context.nativeBase('v1')),
      headers: headers,
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (request.negativePrompt case final String negative)
          'negative_prompt': negative,
        if (request.parameters['seed'] case final int seed) 'seed': seed,
        if (request.durationSec case final seconds?) 'duration': seconds,
        if (request.aspectRatio == '5:3') 'size': '1280x768',
        if (request.aspectRatio == '3:5') 'size': '768x1280',
        if (first != null)
          'media': [
            {'type': 'image', 'url': await mediaReferenceDataUri(first)},
          ],
      }),
    );
    yield* _pollModelScope(context, request, created, headers);
  }
}

Stream<MediaEvent> _pollModelScope(
  MediaContext context,
  MediaRequest request,
  Map<String, dynamic> created,
  Map<String, String> headers,
) async* {
  if (created['status'] == 'FAILED') failedMediaTask(created['errors']);
  final video = request.mode == MediaMode.video;
  final base = context.nativeBase('v1');
  final id = Uri.encodeComponent(requireMediaTaskId(created['task_id']));
  yield* pollMediaTask(
    context,
    poll: () => context.jsonRequest(
      'GET',
      context.endpoint('tasks/$id', base: base),
      headers: {
        ...headers,
        'X-ModelScope-Task-Type': video
            ? 'video_generation'
            : 'image_generation',
      },
    ),
    result: (data) {
      switch (data['task_status']) {
        case 'SUCCEED':
          if (video) {
            final url = mediaResultUri((data['outputs'] as Map?)?['url']);
            if (url == null) {
              throw const MediaFailure(
                MediaFailureKind.invalidResponse,
                'Video result missing',
              );
            }
            return [
              MediaResult(
                mime: 'video/mp4',
                url: url,
                durationMs: videoDurationMs(request.durationSec),
              ),
            ];
          }
          return [
            for (final value in data['output_images'] as List? ?? const [])
              if (mediaResultUri(value) case final url?)
                MediaResult(mime: 'image/png', url: url),
          ];
        case 'FAILED':
        case 'CANCELED':
          failedMediaTask(data['errors'] ?? data['message']);
        case 'PENDING':
        case 'PROCESSING':
        case 'RUNNING':
          return null;
        default:
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Unknown ModelScope task status',
          );
      }
    },
  );
}
