import 'adapters/native_image_size.dart';
import 'media_request.dart';

class FalModel {
  const FalModel(
    this.name,
    this.capabilities, {
    this.ratioField = 'image_size',
    this.imageField = 'image_urls',
    this.video = false,
    this.firstFrameField = 'image_url',
    this.resolutionUppercase = false,
    this.durationAsString = false,
    this.requiresPromptExpansion = false,
  });

  final String name;
  final MediaCapabilities capabilities;
  final String? ratioField;
  final String imageField, firstFrameField;
  final bool video,
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
