import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import '../../../../utils/sandbox_path_resolver.dart';
import '../../custom_request_merger.dart';
import '../fal_batch_state.dart';
import '../media_model_overrides.dart';
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

  /// Project the settings used by preflight through the same wire precedence as a submission.
  static Map<String, dynamic> inputOptions(
    ProviderConfig provider,
    String id,
    Map<String, dynamic> params,
    Map<String, dynamic> extra, {
    bool includeDefaults = true,
  }) {
    final raw = provider.modelOverrides[id];
    final result = <String, dynamic>{
      for (final entry in params.entries)
        if (entry.key.startsWith('fal:')) entry.key.substring(4): entry.value,
      if (params['format'] != null) 'output_format': params['format'],
    };
    CustomRequestMerger.applyBody(result, customBody(provider, id));
    if (includeDefaults) {
      CustomRequestMerger.applyBody(
        result,
        MediaModelOverrides.fromJson(raw is Map ? raw['media'] : null).extra,
      );
    }
    CustomRequestMerger.applyBody(result, extra);
    return result;
  }

  static bool transparentEdit(String upstream, Map inputs) =>
      inputs['background'] == 'transparent' &&
      (upstream == 'bytedance/seedream/v5/flash/edit' ||
          upstream == 'bytedance/seedream/v5/pro/edit');

  static int requestLimit(MediaCapabilities caps, int references, Map inputs) {
    final combined = caps.maxCombinedInputsAndOutputs;
    final multi = inputs['max_images'];
    if (combined == null || multi == null) return caps.outputLimit(references);
    final perGeneration = multi is int ? multi : int.tryParse(multi.toString());
    if (perGeneration == null || perGeneration < 1) return 0;
    return ((combined - references) ~/ perGeneration).clamp(
      0,
      caps.maxPerRequest,
    );
  }

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
      if (caps.acceptsPrompt && request.prompt.trim().isNotEmpty)
        'prompt': request.prompt,
      if (ratioField != null &&
          (request.aspectRatio != 'auto' || ratioField == 'resolution_mode'))
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
          if (field.constant && field.required)
            field.key: field.defaultValue
          else if (!field.constant &&
              request.parameters.containsKey(field.storageKey))
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
    if (transparentEdit(model, body)) {
      body.putIfAbsent('output_format', () => 'png');
      final refs = request.inputImages.toList();
      if (body['output_format'] != 'png' ||
          refs.length != 1 ||
          !await compute(
            _alphaReference,
            SandboxPathResolver.resolveForIo(refs.single.path),
          )) {
        throw const MediaFailure(
          MediaFailureKind.parameters,
          'Transparent output requires PNG and one reference image with an alpha channel.',
        );
      }
    }
    if (caps.alternativePrompt case final alternate?) {
      if (!caps.validPromptAlternatives(body['prompt'], body[alternate])) {
        throw MediaFailure(
          MediaFailureKind.parameters,
          'Provide either prompt or $alternate.',
        );
      }
    }
    final generations = video ? 1 : body['num_images'] ?? request.count;
    if (generations is! int ||
        generations < 1 ||
        generations > requestLimit(caps, request.inputImages.length, body)) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Too many input and output images.',
      );
    }
    final fields = contract is Map && contract['id'] == model
        ? contract['fields']
        : null;
    for (final field in caps.platformOptions) {
      if (!field.readOnly &&
          field.type != MediaParameterType.image &&
          body[field.key] != null) {
        try {
          field.checkWireValue(body[field.key]);
        } on FormatException {
          throw MediaFailure(
            MediaFailureKind.parameters,
            'Invalid fal input: ${field.key}',
          );
        }
      }
    }
    if (fields is Map) {
      for (final entry in fields.entries) {
        final value = body[entry.key];
        if (entry.value is Map &&
            entry.value['required'] == true &&
            (!body.containsKey(entry.key) ||
                value == null && entry.value['nullable'] != true ||
                entry.value['setting'] != true &&
                    (value is List && value.isEmpty || value == ''))) {
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
    final maxImages = body['max_images'];
    final limit = video
        ? 1
        : body['limit_generations'] == false
        ? null
        : generations * (maxImages is int && maxImages > 0 ? maxImages : 1);
    late FalResultLocation location;
    late FalCompletedOutput completed;
    yield* pollMediaTask(
      context,
      outputEvent: (_) => completed,
      beforeResult: (data) {
        if (data['status'] != 'COMPLETED') return null;
        location = FalResultLocation(
          model: model,
          submission: endpoint,
          result: data['response_url'] == null
              ? response
              : _taskUrl(context, endpoint, data['response_url'], task),
          limit: limit,
          lastFrame: video && body['return_last_frame'] == true,
        );
        return FalResultAvailable(location);
      },
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
        completed = await _completed(context, request, location, headers);
        return completed.results;
      },
    );
  }

  Future<FalCompletedOutput> recover(
    MediaContext context,
    MediaRequest request,
    FalPendingResult pending,
  ) async {
    final model = apiModelId(context.provider, request.modelId);
    final location = pending.location;
    final submission = context.endpoint(model);
    if (model != location.model ||
        mediaResultUri(location.result.toString()) == null ||
        location.result.origin != submission.origin ||
        FalResultLocation.address(submission) !=
            FalResultLocation.address(location.submission)) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'The original fal result endpoint is unavailable.',
      );
    }
    try {
      final output = await _completed(
        context,
        request,
        location,
        context.headers(
          request.modelId,
          auth: {'Authorization': 'Key ${context.apiKey}'},
        ),
      );
      if (pending.files != null && output.results.length != pending.files) {
        throw const MediaFailure(
          MediaFailureKind.invalidResponse,
          'The original fal result files changed.',
        );
      }
      return output;
    } on MediaFailure catch (e) {
      if (e.statusCode != 404 && e.statusCode != 410) rethrow;
      throw MediaFailure(
        MediaFailureKind.download,
        'The original fal result is unavailable. Use Generate again to start a new batch.',
        statusCode: e.statusCode,
      );
    }
  }

  Future<FalCompletedOutput> _completed(
    MediaContext context,
    MediaRequest request,
    FalResultLocation location,
    Map<String, String> headers,
  ) async {
    final data = await context.jsonRequest(
      'GET',
      location.result,
      headers: headers,
    );
    final limit = location.limit;
    final lastFrame = location.lastFrame;
    final video = mode == MediaMode.video;
    final field = knownModel(context.provider, request.modelId)?.outputField;
    final value = field != null
        ? data[field]
        : data[video ? 'videos' : 'images'] ?? data[video ? 'video' : 'image'];
    final rows = value is List
        ? value.whereType<Map>()
        : [if (value is Map) value];
    final results = <MediaResult>[
      for (final row in limit == null ? rows : rows.take(limit))
        if (_result(row, video: video) case final result?) result,
    ];
    if (results.isEmpty) {
      throw const MediaFailure(
        MediaFailureKind.invalidResponse,
        'Provider returned no media.',
      );
    }
    final frame = data['last_frame'];
    if (lastFrame && results.isNotEmpty && frame is Map) {
      if (_result(frame, video: false) case final image?) results.add(image);
    }
    return FalCompletedOutput(
      results,
      location,
      draftId: data['draft_id'] is String ? data['draft_id'] as String : null,
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
    var offset = 0;
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
      encoded = raw;
      offset = comma + 1;
    } else {
      url = mediaResultUri(raw);
      if (url == null) return null;
    }
    return MediaResult(
      mime: mime,
      url: url,
      base64: encoded,
      base64Offset: offset,
      mode: video ? MediaMode.video : MediaMode.image,
      width: (row?['width'] as num?)?.toInt(),
      height: (row?['height'] as num?)?.toInt(),
      durationMs: videoDurationMs(row?['duration']),
    );
  }
}

class FalCompletedOutput extends MediaOutput {
  const FalCompletedOutput(super.results, this.location, {this.draftId});
  final FalResultLocation location;
  final String? draftId;
}

// Inspect compressed file metadata on a worker; no full-size pixel buffer is needed.
Future<bool> _alphaReference(String? path) async {
  if (path == null) return false;
  final file = File(path);
  final handle = await file.open();
  try {
    final prefix = await handle.read(26);
    if (prefix.length < 26 || prefix[0] == 0xff && prefix[1] == 0xd8) {
      return false;
    }
    if (prefix[0] == 0x89 &&
        prefix[1] == 0x50 &&
        (prefix[25] == 4 || prefix[25] == 6)) {
      return true;
    }
  } finally {
    await handle.close();
  }
  final bytes = await file.readAsBytes();
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  return switch (info) {
    img.PngInfo() =>
      info.colorType == 4 || info.colorType == 6 || info.transparency != null,
    img.WebPInfo() => info.hasAlpha,
    img.GifInfo() => info.frames.any((f) => f.colorMap?.transparent != null),
    _ => false,
  };
}
