import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:json_schema/json_schema.dart';

import '../../models/media_creation.dart';
import '../../database/app_database.dart';
import '../../../utils/kelivo_file_uri.dart';
import 'fal_batch_state.dart';

enum MediaReferenceRole { image, firstFrame, lastFrame, platform }

class MediaReference {
  const MediaReference(
    this.path, {
    this.role = MediaReferenceRole.image,
    this.parameterKey,
  });

  final String path;
  final MediaReferenceRole role;
  final String? parameterKey;

  Map<String, Object?> toJson() => {
    'path': path,
    'role': role.name,
    if (parameterKey != null) 'parameterKey': parameterKey,
  };

  factory MediaReference.fromJson(Map<String, dynamic> json) {
    final role = MediaReferenceRole.values
        .where((value) => value.name == json['role'])
        .firstOrNull;
    if (role == null) {
      throw const FormatException('Invalid stored creation reference role');
    }
    return MediaReference(
      json['path'] as String,
      role: role,
      parameterKey: json['parameterKey'] as String?,
    );
  }
}

class MediaRequest {
  const MediaRequest({
    required this.modelId,
    required this.mode,
    required this.prompt,
    this.negativePrompt,
    this.count = 1,
    this.aspectRatio = 'auto',
    this.durationSec,
    this.resolution,
    this.references = const [],
    this.parameters = const {},
  });

  factory MediaRequest.fromBatch(GenerationBatchRow batch) {
    try {
      final params = jsonDecode(batch.paramsJson) as Map<String, dynamic>;
      params.remove(FalBatchState.key);
      final refs = [
        for (final row in jsonDecode(batch.referencesJson) as List)
          MediaReference.fromJson((row as Map).cast<String, dynamic>()),
      ];
      if (refs.any(
        (ref) => !KelivoFileUri.isGenerationFile(ref.path, batch.id),
      )) {
        throw const FormatException('Invalid stored creation reference');
      }
      return MediaRequest(
        modelId: batch.modelId,
        mode: batch.mode,
        prompt: batch.prompt,
        negativePrompt: batch.negativePrompt,
        count: params.remove('count') as int? ?? 1,
        aspectRatio: params.remove('aspectRatio') as String? ?? 'auto',
        durationSec: params.remove('durationSec') as int?,
        resolution: params.remove('resolution') as String?,
        parameters: params,
        references: refs,
      );
    } on TypeError {
      throw const FormatException('Invalid stored creation request');
    }
  }

  final String modelId;
  final MediaMode mode;
  final String prompt;
  final String? negativePrompt;
  final int count;
  final String aspectRatio;
  final int? durationSec;
  final String? resolution;
  final List<MediaReference> references;
  final Map<String, dynamic> parameters;

  MediaRequest copyWith({
    int? count,
    List<MediaReference>? references,
    Map<String, dynamic>? parameters,
  }) => MediaRequest(
    modelId: modelId,
    mode: mode,
    prompt: prompt,
    negativePrompt: negativePrompt,
    count: count ?? this.count,
    aspectRatio: aspectRatio,
    durationSec: durationSec,
    resolution: resolution,
    references: references ?? this.references,
    parameters: parameters ?? this.parameters,
  );

  Map<String, Object?> get storedParameters => {
    ...parameters,
    'count': count,
    'aspectRatio': aspectRatio,
    if (durationSec != null) 'durationSec': durationSec,
    if (resolution != null) 'resolution': resolution,
  };

  MediaRequest withCurrentVideoOptions(MediaCapabilities caps) {
    if (mode != MediaMode.video) return this;
    final resolutions = caps.resolutionsFor(
      hasLastFrame: frame(MediaReferenceRole.lastFrame) != null,
    );
    final size = resolution == null || resolutions.contains(resolution)
        ? resolution
        : resolutions.firstOrNull;
    final ratios = caps.ratiosFor(size);
    final ratio =
        caps.framesUseAutomaticRatio &&
            frame(MediaReferenceRole.firstFrame) != null
        ? 'auto'
        : ratios.contains(aspectRatio)
        ? aspectRatio
        : ratios.firstOrNull ?? aspectRatio;
    final durations = caps.durationsFor(
      hasLastFrame: frame(MediaReferenceRole.lastFrame) != null,
    );
    final seconds = durationSec == null || durations.contains(durationSec)
        ? durationSec
        : durations.firstOrNull;
    if (size == resolution && ratio == aspectRatio && seconds == durationSec) {
      return this;
    }
    return MediaRequest(
      modelId: modelId,
      mode: mode,
      prompt: prompt,
      negativePrompt: negativePrompt,
      count: count,
      aspectRatio: ratio,
      durationSec: seconds,
      resolution: size,
      references: references,
      parameters: parameters,
    );
  }

  MediaReference? frame(MediaReferenceRole role) =>
      references.where((reference) => reference.role == role).firstOrNull;

  Iterable<MediaReference> get inputImages => references.where(
    (reference) => reference.role != MediaReferenceRole.platform,
  );
}

class MediaCapabilities {
  const MediaCapabilities({
    required this.aspectRatios,
    this.maxPerRequest = 1,
    this.customImageEndpoint = false,
    this.protocolFrameRoles,
    this.fixedAspectRatio = false,
    this.maxReferences = 0,
    this.nativeProgress = false,
    this.durations = const [],
    this.durationsWithLastFrame,
    this.resolutions = const [],
    this.resolutionsWithLastFrame,
    this.frameRoles = const [],
    this.ratiosByResolution = const {},
    this.framesUseAutomaticRatio = false,
    this.requiresFirstFrame = false,
    this.requiresLastFrame = false,
    this.minimumReferences = 0,
    this.acceptsPrompt = true,
    bool? requiresPrompt,
    this.alternativePrompt,
    this.exclusivePrompts = false,
    this.requiresReference = false,
    this.referenceBounds,
    this.maxCombinedInputsAndOutputs,
    this.sizes = const [],
    this.qualities = const [],
    this.formats = const [],
    this.supportsNegativePrompt = false,
    this.supportsSeed = false,
    this.supportsTransparent = false,
    this.platformOptions = const [],
  }) : requiresPrompt = requiresPrompt ?? acceptsPrompt;

  MediaCapabilities.withModelSettings(
    MediaCapabilities base,
    this.platformOptions, {
    List<String>? aspectRatios,
    List<String>? formats,
    List<String>? sizes,
    bool? acceptsPrompt,
    bool? requiresPrompt,
    String? alternativePrompt,
    bool? exclusivePrompts,
    int? maxCombinedInputsAndOutputs,
    bool? supportsSeed,
    bool? supportsNegativePrompt,
  }) : aspectRatios = aspectRatios ?? base.aspectRatios,
       maxPerRequest = base.maxPerRequest,
       customImageEndpoint = base.customImageEndpoint,
       protocolFrameRoles = base.protocolFrameRoles,
       fixedAspectRatio = base.fixedAspectRatio,
       maxReferences = base.maxReferences,
       nativeProgress = base.nativeProgress,
       durations = base.durations,
       durationsWithLastFrame = base.durationsWithLastFrame,
       resolutions = base.resolutions,
       resolutionsWithLastFrame = base.resolutionsWithLastFrame,
       frameRoles = base.frameRoles,
       ratiosByResolution = base.ratiosByResolution,
       framesUseAutomaticRatio = base.framesUseAutomaticRatio,
       requiresFirstFrame = base.requiresFirstFrame,
       requiresLastFrame = base.requiresLastFrame,
       minimumReferences = base.minimumReferences,
       acceptsPrompt = acceptsPrompt ?? base.acceptsPrompt,
       requiresPrompt = requiresPrompt ?? base.requiresPrompt,
       alternativePrompt = alternativePrompt ?? base.alternativePrompt,
       exclusivePrompts = exclusivePrompts ?? base.exclusivePrompts,
       requiresReference = base.requiresReference,
       referenceBounds = base.referenceBounds,
       maxCombinedInputsAndOutputs =
           maxCombinedInputsAndOutputs ?? base.maxCombinedInputsAndOutputs,
       sizes = sizes ?? base.sizes,
       qualities = base.qualities,
       formats = formats ?? base.formats,
       supportsNegativePrompt =
           supportsNegativePrompt ?? base.supportsNegativePrompt,
       supportsSeed = supportsSeed ?? base.supportsSeed,
       supportsTransparent = base.supportsTransparent;

  final List<String> aspectRatios;
  final int maxPerRequest;
  // OpenAI-compatible relays can accept additional images, n, and optional
  // JSON parameters even when an unlisted model has conservative defaults.
  final bool customImageEndpoint;
  final bool fixedAspectRatio;
  final List<MediaReferenceRole>? protocolFrameRoles;
  List<MediaReferenceRole> get configurableFrameRoles =>
      protocolFrameRoles ?? frameRoles;
  bool get configurableFormat => customImageEndpoint || formats.isNotEmpty;
  int get configurableOutputs => customImageEndpoint ? 16 : maxPerRequest;
  int get configurableReferences =>
      customImageEndpoint && maxReferences > 0 ? 16 : maxReferences;
  final int maxReferences;
  final bool nativeProgress;
  final List<int> durations;
  final List<int>? durationsWithLastFrame;
  final List<String> resolutions;
  final List<String>? resolutionsWithLastFrame;
  final List<MediaReferenceRole> frameRoles;
  final Map<String, List<String>> ratiosByResolution;
  final bool framesUseAutomaticRatio;
  final bool requiresFirstFrame, requiresLastFrame;
  final int minimumReferences;
  final bool acceptsPrompt, requiresPrompt;
  final String? alternativePrompt;
  final bool exclusivePrompts;
  bool validPromptAlternatives(Object? primary, Object? alternate) {
    final hasPrompt = primary is String && primary.trim().isNotEmpty;
    final hasShots = alternate is List && alternate.isNotEmpty;
    return (hasPrompt || hasShots) &&
        !(exclusivePrompts && hasPrompt && hasShots);
  }

  bool get usesReferenceImages => maxReferences > 0 && frameRoles.isEmpty;
  final bool requiresReference;
  final ({int min, int max}) Function(Map<String, dynamic>)? referenceBounds;
  final int? maxCombinedInputsAndOutputs;
  final List<String> sizes, qualities, formats;
  final bool supportsNegativePrompt, supportsSeed, supportsTransparent;
  final List<MediaParameter> platformOptions;

  ({int min, int max}) referenceLimits(Map<String, dynamic> options) {
    final bounds = referenceBounds?.call(options);
    return (
      min: math.max(
        math.max(requiresReference ? 1 : 0, minimumReferences),
        bounds?.min ?? 0,
      ),
      max: math.min(maxReferences, bounds?.max ?? maxReferences),
    );
  }

  int outputLimit(int inputImages) => switch (maxCombinedInputsAndOutputs) {
    final limit? => math.min(maxPerRequest, limit - inputImages),
    null => maxPerRequest,
  };

  List<String> ratiosFor(String? resolution) =>
      ratiosByResolution[resolution] ?? aspectRatios;

  List<int> durationsFor({required bool hasLastFrame}) =>
      (hasLastFrame ? durationsWithLastFrame : null) ?? durations;

  List<String> resolutionsFor({required bool hasLastFrame}) =>
      (hasLastFrame ? resolutionsWithLastFrame : null) ?? resolutions;
}

enum MediaParameterType {
  enumeration,
  integer,
  number,
  boolean,
  string,
  image,
  array,
  object,
  json,
}

class MediaParameter {
  const MediaParameter(
    this.key,
    this.type, {
    this.choices = const [],
    this.availableWithLastFrame = true,
    this.minimum,
    this.maximum,
    this.step,
    this.defaultValue,
    this.required = false,
    this.title,
    this.description,
    this.readOnly = false,
    this.constant = false,
    this.schema,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    String? storageKey,
  }) : storageKey = storageKey ?? key;

  final String key, storageKey;
  final String? title, description;
  final bool readOnly, constant;
  final JsonSchema? schema;
  final num? exclusiveMinimum, exclusiveMaximum, multipleOf;
  final MediaParameterType type;
  final List<Object> choices;
  final bool availableWithLastFrame;
  final num? minimum, maximum, step;
  final Object? defaultValue;
  final bool required;

  Object? parseDraft(Object? raw) {
    if (raw == null || readOnly || constant) return null;
    final value = switch (type) {
      MediaParameterType.integer when raw is String => int.parse(raw.trim()),
      MediaParameterType.number when raw is String => num.parse(raw.trim()),
      MediaParameterType.array ||
      MediaParameterType.object ||
      MediaParameterType.json when raw is String => jsonDecode(raw),
      _ => raw,
    };
    checkWireValue(value);
    return value;
  }

  void checkWireValue(Object? value) {
    if (constant && value != defaultValue) {
      throw FormatException('Invalid constant for $key');
    }
    final valid = switch (type) {
      MediaParameterType.enumeration => choices.contains(value),
      MediaParameterType.boolean => value is bool,
      MediaParameterType.integer => value is int,
      MediaParameterType.number => value is num,
      MediaParameterType.array => value is List,
      MediaParameterType.object => value is Map,
      MediaParameterType.json => true,
      MediaParameterType.string || MediaParameterType.image => value is String,
    };
    if (!valid ||
        (schema != null && !schema!.validate(value).isValid) ||
        value is num &&
            (!value.isFinite ||
                minimum != null && value < minimum! ||
                maximum != null && value > maximum! ||
                exclusiveMinimum != null && value <= exclusiveMinimum! ||
                exclusiveMaximum != null && value >= exclusiveMaximum!)) {
      throw FormatException('Invalid value for $key');
    }
    final increment = multipleOf;
    if (value is num && increment != null && increment > 0) {
      final units = value / increment;
      if (!units.isFinite || (units - units.roundToDouble()).abs() > 1e-8) {
        throw FormatException('Invalid increment for $key');
      }
    }
  }

  static final _lastCheck = Expando<({String raw, bool valid})>();
  bool acceptsDraft(Object? raw) {
    final structured = raw is String && schema != null;
    final cached = structured ? _lastCheck[this] : null;
    if (cached != null && identical(cached.raw, raw)) return cached.valid;
    var valid = true;
    try {
      parseDraft(raw);
    } on FormatException {
      valid = false;
    }
    if (structured) _lastCheck[this] = (raw: raw, valid: valid);
    return valid;
  }
}

class MediaResult {
  const MediaResult({
    required this.mime,
    this.bytes,
    this.base64,
    this.base64Offset = 0,
    this.mode,
    this.url,
    this.revisedPrompt,
    this.previewUrl,
    this.downloadHeaders = const {},
    this.previewHeaders = const {},
    this.width,
    this.height,
    this.durationMs,
  }) : assert(bytes != null || base64 != null || url != null);

  final String mime;
  final Uint8List? bytes;
  final String? base64;
  final int base64Offset;
  final MediaMode? mode;
  final Uri? url;
  final String? revisedPrompt;
  final Uri? previewUrl;
  final Map<String, String> downloadHeaders;
  final Map<String, String> previewHeaders;
  final int? width;
  final int? height;
  final int? durationMs;
}

sealed class MediaEvent {
  const MediaEvent();
}

class MediaProgress extends MediaEvent {
  const MediaProgress(this.fraction);
  final double fraction;
}

class MediaPreview extends MediaEvent {
  const MediaPreview(this.base64);
  final String base64;
}

class MediaOutput extends MediaEvent {
  const MediaOutput(this.results);
  final List<MediaResult> results;
}

class FalResultAvailable extends MediaEvent {
  const FalResultAvailable(this.location);
  final FalResultLocation location;
}

class MediaTaskAccepted extends MediaEvent {
  const MediaTaskAccepted({
    this.cancelUrl,
    this.cancelMethod = 'DELETE',
    this.cancelHeaders = const {},
  });

  final Uri? cancelUrl;
  final String cancelMethod;
  final Map<String, String> cancelHeaders;
}

enum MediaFailureKind {
  network,
  rateLimited,
  server,
  rejected,
  login,
  unavailable,
  parameters,
  referenceTooLarge,
  download,
  invalidResponse,
}

class MediaFailure implements Exception {
  const MediaFailure(
    this.kind,
    this.message, {
    this.retryAfter,
    this.statusCode,
    this.automaticRetry = true,
  });

  final MediaFailureKind kind;
  final String message;
  final Duration? retryAfter;
  final int? statusCode;
  final bool automaticRetry;

  bool get retryable =>
      automaticRetry &&
      switch (kind) {
        MediaFailureKind.network ||
        MediaFailureKind.rateLimited ||
        MediaFailureKind.server => true,
        _ => false,
      };

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'message': message,
    if (statusCode != null) 'statusCode': statusCode,
    if (!automaticRetry) 'automaticRetry': false,
  };

  @override
  String toString() => message;
}
