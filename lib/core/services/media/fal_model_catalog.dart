import 'package:json_schema/json_schema.dart';

import 'adapters/native_image_size.dart';
import 'media_request.dart';

const falCreationCategories = {
  'text-to-image',
  'image-to-image',
  'text-to-video',
  'image-to-video',
};
final _falIdSegment = RegExp(r'^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$');
bool isFalEndpointId(String id) =>
    id.contains('/') && id.split('/').every(_falIdSegment.hasMatch);

const _imageFields = [
  'image_urls',
  'input_image_urls',
  'reference_image_urls',
  'image_url',
  'input_image_url',
  'reference_image_url',
  'model_image',
];
const _firstFrameFields = [
  'start_image_url',
  'first_frame_url',
  'first_frame_image_url',
  'first_image_url',
  'image_url',
  'input_image_url',
];
const _lastFrameFields = [
  'end_image_url',
  'last_frame_url',
  'last_frame_image_url',
  'last_image_url',
];
final falInputFields = <String>{
  'prompt',
  ..._imageFields,
  ..._firstFrameFields,
  ..._lastFrameFields,
  'aspect_ratio',
  'image_size',
  'num_images',
  'duration',
  'resolution',
  'output_format',
  'negative_prompt',
  'seed',
  'mask_url',
  'generate_audio',
};

/// Curated models retain their hand-tested limits. Newly selected endpoints
/// describe their own wire fields; an alias must never reuse another ID's schema.
FalModel? resolveFalModel(String id, Object? override) {
  final known = falModels[id];
  if (known != null) return known;
  final raw = override is Map ? override['falEndpoint'] : null;
  if (raw is! Map ||
      raw['id'] != id ||
      !falCreationCategories.contains(raw['category'])) {
    return null;
  }
  final fields = raw['fields'];
  if (fields is! Map) return null;
  final category = raw['category'] as String;
  final video = category.endsWith('-to-video');
  final imageInput = category.startsWith('image-');
  Map field(String key) => fields[key] is Map ? fields[key] as Map : const {};
  List<Object?> values(String key) =>
      field(key)['choices'] is List ? field(key)['choices'] as List : const [];
  final ratio = fields.containsKey('aspect_ratio')
      ? 'aspect_ratio'
      : field('image_size')['object'] == true
      ? 'image_size'
      : null;
  final ratios = ratio == 'image_size'
      ? standardImageRatios
      : [
          'auto',
          ...values(
            'aspect_ratio',
          ).whereType<String>().where((v) => v.contains(':')),
        ];
  final genericInput = fields.isEmpty && imageInput ? 'image_url' : null;
  final extraImages = <String>{
    if (!video)
      ...[..._firstFrameFields, ..._lastFrameFields].where(fields.containsKey),
    ...fields.keys.whereType<String>().where(
      (key) => field(key)['imageInput'] == true,
    ),
  };
  final image =
      _imageFields.where(fields.containsKey).firstOrNull ??
      extraImages.firstOrNull ??
      genericInput;
  final first =
      _firstFrameFields.where(fields.containsKey).firstOrNull ?? genericInput;
  final last = _lastFrameFields.where(fields.containsKey).firstOrNull;
  final duration = field('duration');
  final durationValues = <int, Object>{};
  for (final value in values('duration')) {
    final match = RegExp(r'^([0-9]+)s?$').firstMatch(value.toString());
    final seconds = int.tryParse(match?.group(1) ?? '');
    if (seconds != null && seconds > 0 && value != null) {
      durationValues[seconds] = value;
    }
  }
  if (durationValues.isEmpty &&
      duration['min'] is int &&
      duration['max'] is int) {
    final min = (duration['min'] as int).clamp(1, 120);
    final max = (duration['max'] as int).clamp(1, 120);
    for (var seconds = min; seconds <= max; seconds++) {
      durationValues[seconds] = seconds;
    }
  }
  int boundedInt(Object? value, int fallback) =>
      value is int ? value.clamp(1, 16) : fallback;
  final array =
      image != null &&
      (field(image)['array'] == true || image.endsWith('_urls'));
  // Some official schemas document the limit without declaring maxItems.
  final defaultLimit = switch (id) {
    'fal-ai/veo3.1/reference-to-video' => 3,
    'bytedance/seedream/v5/pro/edit' => 10,
    _ => 16,
  };
  final imageLimit = image == null
      ? 0
      : array
      ? boundedInt(field(image)['maxItems'], defaultLimit)
      : 1;
  final frameModel = video && first != null;
  final minImages =
      !frameModel &&
          image != null &&
          (imageInput || field(image)['required'] == true)
      ? boundedInt(field(image)['minItems'], 1)
      : 0;
  final resolutions = values('resolution').whereType<String>().toList();
  final automaticSizes = values('image_size')
      .whereType<String>()
      .where((value) => RegExp(r'^auto_\d+(?:\.\d+)?K$').hasMatch(value))
      .map((value) => value.substring(5))
      .toList();
  return FalModel(
    raw['name'] is String ? raw['name'] as String : id,
    MediaCapabilities(
      aspectRatios: ratios,
      fixedAspectRatio: ratio == null,
      maxPerRequest: boundedInt(field('num_images')['max'], 1),
      maxReferences: frameModel ? (last == null ? 1 : 2) : imageLimit,
      requiresReference: minImages > 0,
      minimumReferences: minImages,
      acceptsPrompt: raw['output'] == null || fields.containsKey('prompt'),
      requiresPrompt:
          raw['output'] == null || field('prompt')['required'] == true,
      alternativePrompt: field('prompt')['alternative'] as String?,
      exclusivePrompts: field('prompt')['exclusive'] == true,
      requiresFirstFrame:
          frameModel &&
          (imageInput ||
              field(first)['required'] == true ||
              last != null && field(last)['required'] == true),
      requiresLastFrame:
          frameModel && last != null && field(last)['required'] == true,
      frameRoles: [
        if (video && first != null) MediaReferenceRole.firstFrame,
        if (video && first != null && last != null)
          MediaReferenceRole.lastFrame,
      ],
      durations: durationValues.keys.toList(),
      resolutions: video ? resolutions : const [],
      sizes: video
          ? const []
          : resolutions.isNotEmpty
          ? resolutions
          : automaticSizes,
      formats: values('output_format').whereType<String>().toList(),
      supportsSeed: fields.containsKey('seed'),
      supportsNegativePrompt: fields.containsKey('negative_prompt'),
      platformOptions: [
        for (final key in extraImages)
          if (key != image && (!video || key != first && key != last))
            MediaParameter(
              key,
              MediaParameterType.image,
              required: field(key)['required'] == true,
            ),
        if (fields.containsKey('mask_url'))
          MediaParameter(
            'mask_url',
            MediaParameterType.image,
            required: field('mask_url')['required'] == true,
          ),
        if (fields.containsKey('generate_audio'))
          const MediaParameter('generate_audio', MediaParameterType.boolean),
      ],
    ),
    video: video,
    imageField: image ?? 'image_url',
    imageArray: array,
    outputField: raw['output'] is String ? raw['output'] as String : null,
    durationValues: durationValues,
    firstFrameField: first ?? 'image_url',
    lastFrameField: last ?? 'end_image_url',
    ratioField: ratio,
    durationAsString: duration['string'] == true,
    imageResolutionField: !video && resolutions.isNotEmpty,
  );
}

class FalModel {
  const FalModel(
    this.name,
    this.capabilities, {
    this.ratioField = 'image_size',
    this.imageField = 'image_urls',
    this.imageArray,
    this.outputField,
    this.durationValues = const {},
    this.video = false,
    this.firstFrameField = 'image_url',
    this.lastFrameField = 'end_image_url',
    this.imageResolutionField = false,
    this.resolutionUppercase = false,
    this.durationAsString = false,
    this.requiresPromptExpansion = false,
  });

  // Settings and models reuse the same compact map until fal publishes a new schema.
  static final _compiledSchemas = Expando<JsonSchema>();
  static JsonSchema? _validator(Object? definition) {
    if (definition is! Map) return null;
    final cached = _compiledSchemas[definition];
    if (cached != null) return cached;
    try {
      return _compiledSchemas[definition] = JsonSchema.create(definition);
    } catch (_) {
      // An invalid imported constraint cannot block other models. Its field
      // stays unset until a refresh supplies a usable definition.
      return _compiledSchemas[definition] = JsonSchema.create(false);
    }
  }

  MediaCapabilities withSavedSettings(String id, Object? override) {
    final endpoint = override is Map ? override['falEndpoint'] : null;
    final options = endpoint is Map && endpoint['id'] == id
        ? endpoint['additionalSettings']
        : null;
    if (options is! Map) return capabilities;
    final builtIn = {
      for (final option in capabilities.platformOptions) option.key: option,
    };
    final parameters = <MediaParameter>[];
    final fields = endpoint['fields'];
    for (final entry in options.entries) {
      final key = entry.key;
      final data = entry.value;
      if (key is! String || data is! Map || key == ratioField) continue;
      final original = builtIn.remove(key);
      final type =
          MediaParameterType.values
              .where((t) => t.name == data['type'])
              .firstOrNull ??
          MediaParameterType.json;
      final choices = data['choices'];
      final declared = choices is List
          ? choices.whereType<Object>().toList()
          : const <Object>[];
      // Some native endpoints document an enum as a string in OpenAPI.
      final useNativeChoices =
          type == MediaParameterType.string &&
          original?.type == MediaParameterType.enumeration;
      num? number(String name) => data[name] is num ? data[name] as num : null;
      parameters.add(
        MediaParameter(
          key,
          useNativeChoices ? MediaParameterType.enumeration : type,
          title: data['title'] is String ? data['title'] as String : key,
          description: data['description'] is String
              ? data['description'] as String
              : null,
          storageKey: original?.storageKey ?? 'fal:$key',
          choices: useNativeChoices ? original!.choices : declared,
          defaultValue: data.containsKey('default')
              ? data['default']
              : original?.defaultValue,
          minimum: number('minimum'),
          maximum: number('maximum'),
          exclusiveMinimum: number('exclusiveMinimum'),
          exclusiveMaximum: number('exclusiveMaximum'),
          multipleOf: number('multipleOf'),
          step: number('multipleOf') ?? original?.step,
          required:
              fields is Map &&
              fields[key] is Map &&
              fields[key]['required'] == true,
          readOnly: data['readOnly'] == true,
          constant: data['constant'] == true,
          schema: _validator(data['schema']),
          availableWithLastFrame: original?.availableWithLastFrame ?? true,
        ),
      );
    }
    // Typed image slots (e.g. masks) are already built from the input contract.
    if (fields is Map) {
      parameters.addAll(
        builtIn.values.where((option) => fields.containsKey(option.key)),
      );
    }
    List<String> choices(String key) {
      final raw = fields is Map ? fields[key] : null;
      return raw is Map && raw['choices'] is List
          ? (raw['choices'] as List).whereType<String>().toList()
          : const [];
    }

    final prompt = fields is Map && fields['prompt'] is Map
        ? fields['prompt'] as Map
        : const {};
    final formats = choices('output_format');
    final sizes = choices(
      'image_size',
    ).where((v) => v.startsWith('auto_')).map((v) => v.substring(5)).toList();
    return MediaCapabilities.withModelSettings(
      capabilities,
      parameters,
      aspectRatios:
          ratioField == 'resolution_mode' &&
              choices('resolution_mode').isNotEmpty
          ? choices('resolution_mode')
          : null,
      acceptsPrompt: fields is Map ? fields.containsKey('prompt') : null,
      requiresPrompt: fields is Map ? prompt['required'] == true : null,
      alternativePrompt: prompt['alternative'] as String?,
      exclusivePrompts: prompt['exclusive'] == true,
      maxCombinedInputsAndOutputs: options['max_images'] is Map
          ? (options['max_images'] as Map)['combinedImageLimit'] as int?
          : null,
      formats: formats.isEmpty ? null : formats,
      sizes: !video && ratioField == 'image_size' && sizes.isNotEmpty
          ? sizes
          : null,
      supportsSeed: fields is Map ? fields.containsKey('seed') : null,
      supportsNegativePrompt: fields is Map
          ? fields.containsKey('negative_prompt')
          : null,
    );
  }

  final String name;
  final MediaCapabilities capabilities;
  final String? ratioField;
  final String imageField, firstFrameField, lastFrameField;
  final bool? imageArray;
  final String? outputField;
  final Map<int, Object> durationValues;
  final bool video,
      imageResolutionField,
      resolutionUppercase,
      durationAsString,
      requiresPromptExpansion;
}

const _auto = ['auto'];
const _jpegPng = ['jpeg', 'png'];
const _videoRatios = ['auto', '16:9', '9:16', '1:1', '4:3', '3:4', '21:9'];
const _frames = [MediaReferenceRole.firstFrame, MediaReferenceRole.lastFrame];
const _audio = MediaParameter(
  'generate_audio',
  MediaParameterType.boolean,
  defaultValue: true,
);
const _promptExpansion = MediaParameter(
  'prompt_expansion_mode',
  MediaParameterType.enumeration,
  choices: ['disabled', 'balanced', 'quality'],
  defaultValue: 'balanced',
);
const _bitrate = MediaParameter(
  'bitrate_mode',
  MediaParameterType.enumeration,
  choices: ['standard', 'high'],
  defaultValue: 'standard',
);
const _seedreamEnhance = MediaParameter(
  'enhance_prompt_mode',
  MediaParameterType.enumeration,
  choices: ['standard', 'fast'],
  defaultValue: 'standard',
);
const _acceleration = MediaParameter(
  'acceleration',
  MediaParameterType.enumeration,
  choices: ['none', 'regular', 'high'],
  defaultValue: 'none',
);
const _h3Audio = MediaParameter('target_audio_url', MediaParameterType.string);
const _seedanceDurations = [
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
];
const _h3Durations = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

/// Catalog based on the public model bank and each fal model's API schema.
const falModels = <String, FalModel>{
  'fal-ai/nano-banana': FalModel(
    'Nano Banana',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 4,
      supportsSeed: true,
      formats: imageFormats,
    ),
    ratioField: 'aspect_ratio',
  ),
  'fal-ai/nano-banana/edit': FalModel(
    'Nano Banana Edit',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 4,
      maxReferences: 10,
      requiresReference: true,
      supportsSeed: true,
      formats: imageFormats,
    ),
    ratioField: 'aspect_ratio',
  ),
  'fal-ai/bytedance/seedream/v4/text-to-image': FalModel(
    'Seedream 4',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 6,
      supportsSeed: true,
      sizes: ['2K', '4K'],
      platformOptions: [_seedreamEnhance],
    ),
  ),
  'fal-ai/bytedance/seedream/v4/edit': FalModel(
    'Seedream 4 Edit',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 6,
      maxReferences: 10,
      maxCombinedInputsAndOutputs: 15,
      requiresReference: true,
      supportsSeed: true,
      sizes: ['2K', '4K'],
      platformOptions: [_seedreamEnhance],
    ),
  ),
  'fal-ai/flux-2-pro': FalModel(
    'FLUX.2 Pro',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      supportsSeed: true,
      formats: _jpegPng,
    ),
  ),
  'fal-ai/flux-kontext/dev': FalModel(
    'FLUX.1 Kontext Dev',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 4,
      maxReferences: 1,
      requiresReference: true,
      supportsSeed: true,
      formats: _jpegPng,
      platformOptions: [
        MediaParameter(
          'num_inference_steps',
          MediaParameterType.integer,
          minimum: 10,
          maximum: 50,
          defaultValue: 28,
        ),
        MediaParameter(
          'guidance_scale',
          MediaParameterType.number,
          minimum: 1,
          maximum: 20,
          step: 0.5,
          defaultValue: 2.5,
        ),
        _acceleration,
      ],
    ),
    ratioField: 'resolution_mode',
    imageField: 'image_url',
  ),
  'fal-ai/flux/schnell': FalModel(
    'FLUX.1 Schnell',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 4,
      supportsSeed: true,
      formats: _jpegPng,
      platformOptions: [
        MediaParameter(
          'num_inference_steps',
          MediaParameterType.integer,
          minimum: 1,
          maximum: 12,
          defaultValue: 4,
        ),
        _acceleration,
      ],
    ),
  ),
  'fal-ai/flux/krea': FalModel(
    'FLUX.1 Krea',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 4,
      supportsSeed: true,
      formats: _jpegPng,
      platformOptions: [
        MediaParameter(
          'num_inference_steps',
          MediaParameterType.integer,
          minimum: 1,
          maximum: 50,
          defaultValue: 28,
        ),
        MediaParameter(
          'guidance_scale',
          MediaParameterType.number,
          minimum: 1,
          maximum: 20,
          step: 0.5,
          defaultValue: 4.5,
        ),
        _acceleration,
      ],
    ),
  ),
  'fal-ai/flux-pro/v1/fill': FalModel(
    'FLUX.1 Pro Fill',
    MediaCapabilities(
      aspectRatios: _auto,
      maxPerRequest: 4,
      maxReferences: 1,
      requiresReference: true,
      supportsSeed: true,
      formats: _jpegPng,
      platformOptions: [
        MediaParameter('mask_url', MediaParameterType.image, required: true),
        MediaParameter(
          'enhance_prompt',
          MediaParameterType.boolean,
          defaultValue: false,
        ),
      ],
    ),
    ratioField: null,
    imageField: 'image_url',
  ),
  'fal-ai/qwen-image': FalModel(
    'Qwen Image',
    MediaCapabilities(
      aspectRatios: standardImageRatios,
      maxPerRequest: 4,
      supportsSeed: true,
      supportsNegativePrompt: true,
      formats: _jpegPng,
      platformOptions: [
        MediaParameter(
          'guidance_scale',
          MediaParameterType.number,
          minimum: 1,
          maximum: 20,
          step: 0.1,
          defaultValue: 2.5,
        ),
        MediaParameter(
          'turbo',
          MediaParameterType.boolean,
          defaultValue: false,
        ),
      ],
    ),
  ),
  'fal-ai/qwen-image-edit': FalModel(
    'Qwen Image Edit',
    MediaCapabilities(
      aspectRatios: _auto,
      maxPerRequest: 4,
      maxReferences: 1,
      requiresReference: true,
      supportsSeed: true,
      supportsNegativePrompt: true,
      formats: _jpegPng,
      platformOptions: [_acceleration],
    ),
    ratioField: null,
    imageField: 'image_url',
  ),
  'fal-ai/kling-video/v2.6/pro/text-to-video': FalModel(
    'Kling 2.6 Pro',
    MediaCapabilities(
      aspectRatios: ['auto', '16:9', '9:16', '1:1'],
      durations: [5, 10],
      supportsNegativePrompt: true,
      platformOptions: [_audio],
    ),
    video: true,
    ratioField: 'aspect_ratio',
    durationAsString: true,
  ),
  'fal-ai/kling-video/v2.6/pro/image-to-video': FalModel(
    'Kling 2.6 Pro Image to Video',
    MediaCapabilities(
      aspectRatios: _auto,
      durations: [5, 10],
      maxReferences: 2,
      frameRoles: _frames,
      requiresFirstFrame: true,
      supportsNegativePrompt: true,
      platformOptions: [_audio],
    ),
    video: true,
    ratioField: null,
    durationAsString: true,
    firstFrameField: 'start_image_url',
  ),
  'bytedance/seedance-2.5/text-to-video': FalModel(
    'Seedance 2.5',
    MediaCapabilities(
      aspectRatios: _videoRatios,
      durations: _seedanceDurations,
      resolutions: ['720p', '480p', '1080p', '4k'],
      platformOptions: [_audio, _bitrate],
    ),
    video: true,
    ratioField: 'aspect_ratio',
    durationAsString: true,
  ),
  'bytedance/seedance-2.5/image-to-video': FalModel(
    'Seedance 2.5 Image to Video',
    MediaCapabilities(
      aspectRatios: _auto,
      durations: _seedanceDurations,
      resolutions: ['720p', '480p', '1080p', '4k'],
      maxReferences: 2,
      frameRoles: _frames,
      requiresFirstFrame: true,
      platformOptions: [_audio, _bitrate],
    ),
    video: true,
    ratioField: null,
    durationAsString: true,
  ),
  'minimax/h3-max/text-to-video': FalModel(
    'MiniMax H3 Max',
    MediaCapabilities(
      aspectRatios: _videoRatios,
      durations: _h3Durations,
      resolutions: ['768p', '480p', '1080p'],
      supportsSeed: true,
      platformOptions: [_promptExpansion, _h3Audio],
    ),
    video: true,
    ratioField: 'aspect_ratio',
    resolutionUppercase: true,
    requiresPromptExpansion: true,
  ),
  'minimax/h3-max/image-to-video': FalModel(
    'MiniMax H3 Max Image to Video',
    MediaCapabilities(
      aspectRatios: _auto,
      durations: _h3Durations,
      resolutions: ['768p', '480p', '1080p'],
      maxReferences: 2,
      frameRoles: _frames,
      requiresFirstFrame: true,
      supportsSeed: true,
      platformOptions: [_promptExpansion, _h3Audio],
    ),
    video: true,
    ratioField: null,
    resolutionUppercase: true,
    requiresPromptExpansion: true,
  ),
};
