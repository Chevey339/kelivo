import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class DashScopeVideoAdapter implements MediaAdapter {
  const DashScopeVideoAdapter({this.gatewayPath});

  // TokenDance gives Wan3 and HappyHorse separate task namespaces.
  final String? gatewayPath;

  static bool _modern(String model) =>
      model.startsWith('wan3.') || model.startsWith('wan2.7');

  static bool _textOnly(String model) => model.contains('-t2v');

  static const _legacySizes = {
    '480p': {'16:9': '832*480', '9:16': '480*832', '1:1': '624*624'},
    '720p': {
      '16:9': '1280*720',
      '9:16': '720*1280',
      '1:1': '960*960',
      '4:3': '1088*832',
      '3:4': '832*1088',
    },
    '1080p': {
      '16:9': '1920*1080',
      '9:16': '1080*1920',
      '1:1': '1440*1440',
      '4:3': '1632*1248',
      '3:4': '1248*1632',
    },
  };

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    if (model.startsWith('happyhorse-')) {
      final image = model.endsWith('-i2v');
      return MediaCapabilities(
        aspectRatios: image
            ? const ['auto']
            : const ['16:9', '9:16', '1:1', '4:3', '3:4'],
        durations: [for (var seconds = 3; seconds <= 15; seconds++) seconds],
        resolutions: const ['720p', '1080p'],
        maxReferences: image ? 1 : 0,
        frameRoles: [if (image) MediaReferenceRole.firstFrame],
        requiresFirstFrame: image,
      );
    }
    final modern = _modern(model);
    final textOnly = _textOnly(model);
    final wan3 = model.startsWith('wan3.');
    final wan27 = model.startsWith('wan2.7');
    final wan26 = model.startsWith('wan2.6');
    final last = !textOnly && (modern || model.contains('kf2v'));
    return MediaCapabilities(
      aspectRatios: textOnly || wan3
          ? const ['auto', '16:9', '9:16', '1:1', '4:3', '3:4']
          : const ['auto'],
      ratiosByResolution: textOnly && !modern
          ? {
              for (final entry in _legacySizes.entries)
                entry.key: ['auto', ...entry.value.keys],
            }
          : const {},
      durations: switch (model) {
        _ when wan3 && gatewayPath != null => [
          for (var i = 2; i <= 30; i++) i,
          -1,
        ],
        _ when wan3 => List.generate(11, (index) => index + 5),
        _ when wan27 || wan26 && textOnly => List.generate(
          14,
          (index) => index + 2,
        ),
        _ when wan26 => const [5, 10, 15],
        _ when model.startsWith('wan2.5') => const [5, 10],
        _ => const [5],
      },
      resolutions: switch (model) {
        _ when wan26 || wan27 => const ['720p', '1080p'],
        _ when wan3 || model.startsWith('wan2.5') => const [
          '720p',
          '480p',
          '1080p',
        ],
        'wan2.2-t2v-plus' || 'wan2.2-i2v-plus' => const ['480p', '1080p'],
        'wan2.2-i2v-flash' ||
        'wan2.2-kf2v-flash' => const ['720p', '480p', '1080p'],
        'wanx2.1-t2v-plus' ||
        'wanx2.1-i2v-plus' ||
        'wanx2.1-kf2v-plus' => const ['720p'],
        _ => const ['720p', '480p'],
      },
      maxReferences: textOnly
          ? 0
          : last
          ? 2
          : 1,
      frameRoles: [
        if (!textOnly) MediaReferenceRole.firstFrame,
        if (last) MediaReferenceRole.lastFrame,
      ],
      requiresFirstFrame: model.contains('-i2v') || model.contains('kf2v'),
      supportsNegativePrompt: !wan3,
      supportsSeed: true,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final base = Uri.parse(context.provider.baseUrl);
    final api = '${base.origin}${gatewayPath ?? '/api/v1'}';
    final headers = context.headers(request.modelId);
    final model = apiModelId(context.provider, request.modelId);
    final normalized = model.toLowerCase();
    final happyHorse = normalized.startsWith('happyhorse-');
    final modern = _modern(normalized) || happyHorse;
    final keyframeEndpoint = !modern && normalized.contains('kf2v');
    final legacyText = _textOnly(normalized) && !modern;
    final autoRatio = request.aspectRatio == 'auto';
    final ratio = autoRatio ? '16:9' : request.aspectRatio;
    final resolution =
        request.resolution ??
        capabilities(context.provider, request.modelId).resolutions.first;
    final size = legacyText ? (_legacySizes[resolution]?[ratio]) : null;
    if (legacyText && size == null) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Unsupported Wan video size',
      );
    }
    final first = request.frame(MediaReferenceRole.firstFrame);
    final last = request.frame(MediaReferenceRole.lastFrame);
    final created = await context.jsonRequest(
      'POST',
      context.endpoint(
        gatewayPath != null
            ? 'video-synthesis'
            : keyframeEndpoint
            ? 'services/aigc/image2video/video-synthesis'
            : 'services/aigc/video-generation/video-synthesis',
        base: api,
      ),
      headers: {...headers, 'X-DashScope-Async': 'enable'},
      body: context.body(request, {
        'model': model,
        'input': {
          'prompt': request.prompt,
          if (request.negativePrompt case final value?
              when !normalized.startsWith('wan3.') && !happyHorse)
            'negative_prompt': value,
          if (modern && first != null)
            'media': [
              {
                'type': 'first_frame',
                'url': await mediaReferenceDataUri(first),
              },
              if (last != null)
                {
                  'type': 'last_frame',
                  'url': await mediaReferenceDataUri(last),
                },
            ],
          if (!modern && first != null)
            keyframeEndpoint ? 'first_frame_url' : 'img_url':
                await mediaReferenceDataUri(first),
          if (!modern && last != null)
            'last_frame_url': await mediaReferenceDataUri(last),
        },
        'parameters': {
          if (request.parameters['seed'] case final int seed) 'seed': seed,
          if (size != null)
            'size': size
          else
            'resolution': resolution.toUpperCase(),
          if (normalized.startsWith('wan3.'))
            'ratio': autoRatio ? 'adaptive' : ratio
          else if (modern && _textOnly(normalized))
            'ratio': ratio,
          if (request.durationSec case final value?
              when capabilities(
                    context.provider,
                    request.modelId,
                  ).durations.length >
                  1)
            'duration': value,
        },
      }),
    );
    final output = created['output'] as Map?;
    final taskId = Uri.encodeComponent(requireMediaTaskId(output?['task_id']));
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('tasks/$taskId', base: api),
        headers: headers,
      ),
      result: (data) {
        final output = data['output'] as Map?;
        final status = output?['task_status'];
        if (const {
          'FAILED',
          'CANCELED',
          'CANCELLED',
          'UNKNOWN',
        }.contains(status)) {
          failedMediaTask(output);
        }
        if (status != 'SUCCEEDED') return null;
        final url = mediaResultUri(output?['video_url']);
        if (url == null) {
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Video URL missing',
          );
        }
        final usage = data['usage'] as Map?;
        return [
          MediaResult(
            mime: 'video/mp4',
            url: url,
            durationMs: videoDurationMs(
              usage?['output_video_duration'] ?? request.durationSec,
            ),
          ),
        ];
      },
    );
  }
}
