import '../../../models/media_creation.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../fal_model_catalog.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import 'native_image_size.dart';

class FalMediaAdapter implements MediaAdapter {
  const FalMediaAdapter(this.mode);

  final MediaMode mode;

  static FalModel? knownModel(ProviderConfig provider, String id) =>
      falModels[apiModelId(provider, id)];

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      knownModel(provider, modelId)?.capabilities ??
      (mode == MediaMode.video
          ? const MediaCapabilities(
              aspectRatios: ['auto', '16:9', '9:16', '1:1'],
              durations: [5, 10],
              maxReferences: 1,
              frameRoles: [MediaReferenceRole.firstFrame],
            )
          : const MediaCapabilities(
              aspectRatios: standardImageRatios,
              maxPerRequest: 4,
              maxReferences: 1,
              supportsSeed: true,
              formats: ['jpeg', 'png'],
            ));

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final segments = model.split('/');
    if (segments.length < 2 ||
        !segments.every(RegExp(r'^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$').hasMatch)) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Invalid fal model ID',
      );
    }
    final details = knownModel(context.provider, request.modelId);
    final caps = capabilities(context.provider, request.modelId);
    final video = mode == MediaMode.video;
    final first = request.frame(MediaReferenceRole.firstFrame);
    final last = request.frame(MediaReferenceRole.lastFrame);
    final ratioField = details == null
        ? video
              ? 'aspect_ratio'
              : 'image_size'
        : details.ratioField;
    final size = request.parameters['size'];
    final imageSize = imageDimensions(
      request.aspectRatio,
      size == '4K'
          ? 4096
          : size == '2K'
          ? 2048
          : 1024,
    );
    final update = <String, dynamic>{
      'prompt': request.prompt,
      if (ratioField != null && request.aspectRatio != 'auto')
        ratioField: ratioField == 'image_size'
            ? {'width': imageSize.width, 'height': imageSize.height}
            : request.aspectRatio,
      if (ratioField == 'image_size' &&
          request.aspectRatio == 'auto' &&
          size is String)
        'image_size': 'auto_$size',
      if (request.count > 1 && !video) 'num_images': request.count,
      if (request.negativePrompt case final value?) 'negative_prompt': value,
      if (request.parameters['format'] case final String format)
        'output_format': format,
      if (request.parameters['seed'] case final int seed) 'seed': seed,
      if (request.durationSec case final duration?)
        'duration': details?.durationAsString == true ? '$duration' : duration,
      if (request.resolution case final resolution?)
        'resolution': details?.resolutionUppercase == true
            ? resolution.toUpperCase()
            : resolution,
      if (first != null)
        (details?.firstFrameField ?? 'image_url'): await mediaReferenceDataUri(
          first,
        ),
      if (last != null) 'end_image_url': await mediaReferenceDataUri(last),
      if (details?.requiresPromptExpansion == true)
        'prompt_expansion_mode': 'balanced',
      for (final field in caps.platformOptions)
        if (field.type != MediaParameterType.image &&
            request.parameters[field.key] != null)
          field.key: request.parameters[field.key],
      for (final ref in request.references)
        if (ref.role == MediaReferenceRole.platform && ref.parameterKey != null)
          ref.parameterKey!: await mediaReferenceDataUri(ref),
    };
    if (!video && request.inputImages.isNotEmpty) {
      final refs = [
        for (final ref in request.inputImages) await mediaReferenceDataUri(ref),
      ];
      final field = details?.imageField ?? 'image_urls';
      update[field] = field == 'image_url' ? refs.first : refs;
    }
    final endpoint = context.endpoint(model);
    final headers = context.headers(
      request.modelId,
      auth: {'Authorization': 'Key ${context.apiKey}'},
    );
    final created = await context.jsonRequest(
      'POST',
      endpoint,
      headers: headers,
      body: context.body(request, update),
    );
    final id = Uri.encodeComponent(requireMediaTaskId(created['request_id']));
    final task = '${segments.take(2).join('/')}/requests/$id';
    final status = _taskUrl(
      context,
      endpoint,
      created['status_url'],
      '$task/status',
    );
    final response = _taskUrl(context, endpoint, created['response_url'], task);
    final cancellation = _taskUrl(
      context,
      endpoint,
      created['cancel_url'],
      '$task/cancel',
    );
    yield* pollMediaTask(
      context,
      accepted: MediaTaskAccepted(
        cancelUrl: cancellation,
        cancelHeaders: headers,
        cancelMethod: 'PUT',
      ),
      poll: () => context.jsonRequest('GET', status, headers: headers),
      initial: created,
      progress: (data) => mediaPercent(data['progress']),
      result: (data) async {
        final state = data['status'];
        if (const {
          'FAILED',
          'CANCELED',
          'CANCELLED',
          'ERROR',
        }.contains(state)) {
          failedMediaTask(data['error'] ?? data);
        }
        if (state != 'COMPLETED') return null;
        final resultUrl = data['response_url'] == null
            ? response
            : _taskUrl(context, endpoint, data['response_url'], task);
        final output = await context.jsonRequest(
          'GET',
          resultUrl,
          headers: headers,
        );
        if (video) {
          final row = output['video'] as Map?;
          final result = _result(row, video: true);
          return result == null ? [] : [result];
        }
        return [
          for (final row
              in (output['images'] as List? ?? const []).whereType<Map>())
            if (_result(row, video: false) case final result?) result,
        ];
      },
    );
  }

  Uri _taskUrl(
    MediaContext context,
    Uri endpoint,
    Object? raw,
    String fallback,
  ) {
    if (raw == null) return context.endpoint(fallback);
    final url = raw is String ? mediaResultUri(raw) : null;
    if (url == null || url.origin != endpoint.origin) {
      throw const MediaFailure(
        MediaFailureKind.invalidResponse,
        'Invalid fal queue URL',
      );
    }
    return url;
  }

  MediaResult? _result(Map? row, {required bool video}) {
    final raw = row?['url'];
    final url = mediaResultUri(raw);
    final mime =
        row?['content_type'] as String? ?? (video ? 'video/mp4' : 'image/png');
    final data = raw is String ? Uri.tryParse(raw)?.data : null;
    if (url == null && (data == null || !data.isBase64)) return null;
    return MediaResult(
      mime: data?.mimeType ?? mime,
      url: url,
      base64: data?.contentText,
      width: (row?['width'] as num?)?.toInt(),
      height: (row?['height'] as num?)?.toInt(),
      durationMs: videoDurationMs(row?['duration']),
    );
  }
}
