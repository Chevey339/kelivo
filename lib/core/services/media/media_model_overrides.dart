import '../custom_request_merger.dart';
import '../../models/media_creation.dart';
import 'media_request.dart';

/// A model on a self-hosted gateway can use a different API from chat.
enum MediaApiProtocol {
  auto('Auto'),
  openAiImage('OpenAI Images', MediaMode.image),
  chatImage('OpenAI Chat Completions', MediaMode.image),
  geminiImage('Gemini generateContent', MediaMode.image),
  arkImage('Ark / Seedream', MediaMode.image),
  dashScopeImage('DashScope', MediaMode.image),
  modelScopeImage('ModelScope', MediaMode.image),
  openAiVideo('OpenAI Videos / Sora', MediaMode.video),
  modelScopeVideo('ModelScope', MediaMode.video),
  newApiVideo('New API /video/generations', MediaMode.video),
  arkVideo('Ark / Seedance', MediaMode.video),
  dashScopeVideo('DashScope', MediaMode.video),
  geminiVideo('Gemini Interactions', MediaMode.video);

  const MediaApiProtocol(this.label, [this.mode]);
  final String label;
  final MediaMode? mode;
}

class MediaModelOverrides {
  const MediaModelOverrides({
    this.protocol = MediaApiProtocol.auto,
    this.aspectRatios,
    this.maxPerRequest,
    this.maxReferences,
    this.sizes,
    this.durations,
    this.resolutions,
    this.firstFrame,
    this.lastFrame,
    this.negativePrompt,
    this.seed,
    this.transparent,
    this.formats,
    this.extra = const {},
  });

  final MediaApiProtocol protocol;
  final List<String>? aspectRatios, sizes, resolutions, formats;
  final List<int>? durations;
  final int? maxPerRequest, maxReferences;
  final bool? firstFrame, lastFrame, negativePrompt, seed, transparent;
  final Map<String, dynamic> extra;

  factory MediaModelOverrides.fromJson(Object? value) {
    if (value is! Map) return const MediaModelOverrides();
    return MediaModelOverrides(
      protocol:
          MediaApiProtocol.values
              .where((p) => p.name == value['protocol'])
              .firstOrNull ??
          MediaApiProtocol.auto,
      aspectRatios: _values<String>(value['aspectRatios'], keepEmpty: false),
      maxPerRequest: _boundedInt(value['maxPerRequest'], 1, 16),
      maxReferences: _boundedInt(value['maxReferences'], 0, 16),
      sizes: _values<String>(value['sizes']),
      durations: _values<int>(
        value['durations'],
      )?.where((n) => n == -1 || n > 0).toList(),
      resolutions: _values<String>(value['resolutions']),
      firstFrame: _flag(value['firstFrame']),
      lastFrame: _flag(value['lastFrame']),
      negativePrompt: _flag(value['negativePrompt']),
      seed: _flag(value['seed']),
      transparent: _flag(value['transparent']),
      formats: _values<String>(value['formats']),
      extra: value['extra'] is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(
              value['extra'] as Map<String, dynamic>,
            )
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    if (protocol != MediaApiProtocol.auto) 'protocol': protocol.name,
    if (aspectRatios != null) 'aspectRatios': aspectRatios,
    if (maxPerRequest != null) 'maxPerRequest': maxPerRequest,
    if (maxReferences != null) 'maxReferences': maxReferences,
    if (sizes != null) 'sizes': sizes,
    if (durations != null) 'durations': durations,
    if (resolutions != null) 'resolutions': resolutions,
    if (firstFrame != null) 'firstFrame': firstFrame,
    if (lastFrame != null) 'lastFrame': lastFrame,
    if (negativePrompt != null) 'negativePrompt': negativePrompt,
    if (seed != null) 'seed': seed,
    if (transparent != null) 'transparent': transparent,
    if (formats != null) 'formats': formats,
    if (extra.isNotEmpty) 'extra': extra,
  };

  MediaCapabilities apply(MediaCapabilities base, {required bool video}) {
    final first =
        base.requiresFirstFrame ||
        (firstFrame ?? base.frameRoles.contains(MediaReferenceRole.firstFrame));
    final last =
        first &&
        (lastFrame ?? base.frameRoles.contains(MediaReferenceRole.lastFrame));
    final ratios = aspectRatios ?? base.aspectRatios;
    return MediaCapabilities(
      aspectRatios: ratios,
      maxPerRequest: video ? 1 : maxPerRequest ?? base.maxPerRequest,
      maxReferences: video
          ? (last
                ? 2
                : first
                ? 1
                : 0)
          : (maxReferences ?? base.maxReferences).clamp(
              base.requiresReference ? 1 : 0,
              16,
            ),
      nativeProgress: base.nativeProgress,
      durations: durations ?? base.durations,
      durationsWithLastFrame: base.durationsWithLastFrame
          ?.where((durations ?? base.durations).contains)
          .toList(),
      resolutions: resolutions ?? base.resolutions,
      resolutionsWithLastFrame: base.resolutionsWithLastFrame
          ?.where((resolutions ?? base.resolutions).contains)
          .toList(),
      frameRoles: [
        if (first) MediaReferenceRole.firstFrame,
        if (last) MediaReferenceRole.lastFrame,
      ],
      ratiosByResolution: {
        for (final entry in base.ratiosByResolution.entries)
          entry.key: entry.value.where(ratios.contains).toList(),
      },
      framesUseAutomaticRatio: base.framesUseAutomaticRatio,
      requiresFirstFrame: base.requiresFirstFrame,
      requiresReference: base.requiresReference,
      referenceBounds: base.referenceBounds,
      maxCombinedInputsAndOutputs: base.maxCombinedInputsAndOutputs,
      sizes: sizes ?? base.sizes,
      qualities: base.qualities,
      formats: formats ?? base.formats,
      supportsNegativePrompt: negativePrompt ?? base.supportsNegativePrompt,
      supportsSeed: seed ?? base.supportsSeed,
      supportsTransparent: transparent ?? base.supportsTransparent,
      platformOptions: base.platformOptions,
    );
  }

  Map<String, dynamic> requestExtra(Map<String, dynamic> temporary) {
    final result = <String, dynamic>{};
    CustomRequestMerger.applyBody(result, extra);
    CustomRequestMerger.applyBody(result, temporary);
    return result;
  }

  static List<T>? _values<T>(Object? value, {bool keepEmpty = true}) {
    if (value is! List) return null;
    final values = value.whereType<T>().toSet().toList(growable: false);
    return values.isNotEmpty || keepEmpty ? values : null;
  }

  static int? _boundedInt(Object? value, int low, int high) =>
      value is int && value >= low && value <= high ? value : null;

  static bool? _flag(Object? value) => value is bool ? value : null;
}
