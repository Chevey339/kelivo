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
      resolveFalModel(apiModelId(provider, id), provider.modelOverrides[id]);

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final upstream = apiModelId(provider, modelId);
    final overrides = provider.modelOverrides[modelId];
    final model = resolveFalModel(upstream, overrides);
    if (model != null) return model.withSavedSettings(upstream, overrides);
    return mode == MediaMode.video
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
          );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final segments = model.split('/');
    if (!isFalEndpointId(model)) {
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
    final kilo = size is String && size.endsWith('K')
        ? double.tryParse(size.substring(0, size.length - 1))
        : null;
    final imageSize = imageDimensions(
      request.aspectRatio,
      kilo != null && kilo.isFinite && kilo > 0 && kilo <= 16
          ? (kilo * 1024).round()
          : 1024,
    );
    final update = <String, dynamic>{
      if (caps.acceptsPrompt) 'prompt': request.prompt,
      if (ratioField != null && request.aspectRatio != 'auto')
        ratioField: ratioField == 'image_size'
            ? {'width': imageSize.width, 'height': imageSize.height}
            : request.aspectRatio,
      if (ratioField == 'image_size' &&
          request.aspectRatio == 'auto' &&
          size is String &&
          details?.imageResolutionField != true)
        'image_size': 'auto_$size',
      if (details?.imageResolutionField == true && size is String)
        'resolution': size,
      if (request.count > 1 && !video) 'num_images': request.count,
      if (request.negativePrompt case final value?) 'negative_prompt': value,
      if (request.parameters['format'] case final String format)
        'output_format': format,
      if (request.parameters['seed'] case final int seed) 'seed': seed,
      if (request.durationSec case final duration?)
        'duration':
            details?.durationValues[duration] ??
            (details?.durationAsString == true ? '$duration' : duration),
      if (request.resolution case final resolution?)
        'resolution': details?.resolutionUppercase == true
            ? resolution.toUpperCase()
            : resolution,
      if (first != null)
        (details?.firstFrameField ?? 'image_url'): await mediaReferenceDataUri(
          first,
        ),
      if (last != null)
        (details?.lastFrameField ?? 'end_image_url'):
            await mediaReferenceDataUri(last),
      if (details?.requiresPromptExpansion == true)
        'prompt_expansion_mode': 'balanced',
      for (final field in caps.platformOptions)
        if (!field.readOnly && field.type != MediaParameterType.image)
          if (request.parameters.containsKey(field.storageKey))
            field.key: request.parameters[field.storageKey]
          else if (field.required && field.defaultValue != null)
            field.key: field.defaultValue,
      for (final ref in request.references)
        if (ref.role == MediaReferenceRole.platform && ref.parameterKey != null)
          ref.parameterKey!: await mediaReferenceDataUri(ref),
    };
    if ((!video || caps.usesReferenceImages) &&
        request.inputImages.isNotEmpty) {
      final field = details?.imageField ?? 'image_urls';
      if (details?.imageArray ?? field.endsWith('_urls')) {
        update[field] = [
          for (final ref in request.inputImages)
            await mediaReferenceDataUri(ref),
        ];
      } else {
        update[field] = await mediaReferenceDataUri(request.inputImages.first);
      }
    }
    final body = context.body(request, update);
    final override = context.provider.modelOverrides[request.modelId];
    final contract = override is Map ? override['falEndpoint'] : null;
    final fields = contract is Map && contract['id'] == model
        ? contract['fields']
        : null;
    if (fields is Map) {
      for (final entry in fields.entries) {
        final value = body[entry.key];
        if (entry.value is Map &&
            entry.value['required'] == true &&
            (value == null || value is List && value.isEmpty || value == '')) {
          throw MediaFailure(
            MediaFailureKind.parameters,
            'Missing required fal input: ${entry.key}',
          );
        }
      }
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
      body: body,
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
      // Seedream's max_images is the number of files per generation; num_images
      // controls the number of independent generations in the request.
      filesPerGeneration: !video && body['max_images'] is int
          ? body['max_images'] as int
          : 1,
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
        final verifiedField = details?.outputField;
        final result = verifiedField != null
            ? output[verifiedField]
            : output[video ? 'videos' : 'images'] ??
                  output[video ? 'video' : 'image'];
        return [
          for (final row
              in result is List
                  ? result.whereType<Map>()
                  : [if (result is Map) result])
            if (_result(row, video: video) case final result?) result,
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
    if (raw is! String) return null;
    String? encoded;
    Uri? url;
    var mime =
        row?['content_type'] as String? ?? (video ? 'video/mp4' : 'image/png');
    if (raw.startsWith('data:')) {
      final comma = raw.indexOf(',');
      if (comma < 0 || comma + 1 == raw.length) return null;
      // Parse the header only. The file store decodes the payload off the UI isolate.
      final header = Uri.tryParse(raw.substring(0, comma + 1))?.data;
      if (header == null || !header.isBase64) return null;
      mime = header.mimeType;
      encoded = raw.substring(comma + 1);
    } else {
      url = mediaResultUri(raw);
      if (url == null) return null;
    }
    return MediaResult(
      mime: mime,
      url: url,
      base64: encoded,
      width: (row?['width'] as num?)?.toInt(),
      height: (row?['height'] as num?)?.toInt(),
      durationMs: videoDurationMs(row?['duration']),
    );
  }
}
