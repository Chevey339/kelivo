import 'dart:typed_data';

import '../../models/media_creation.dart';

enum MediaReferenceRole { image, firstFrame, lastFrame }

class MediaReference {
  const MediaReference(this.path, {this.role = MediaReferenceRole.image});

  final String path;
  final MediaReferenceRole role;

  Map<String, Object?> toJson() => {'path': path, 'role': role.name};

  factory MediaReference.fromJson(Map<String, dynamic> json) => MediaReference(
    json['path'] as String,
    role: MediaReferenceRole.values.byName(json['role'] as String),
  );
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

  MediaRequest copyWith({int? count, List<MediaReference>? references}) =>
      MediaRequest(
        modelId: modelId,
        mode: mode,
        prompt: prompt,
        negativePrompt: negativePrompt,
        count: count ?? this.count,
        aspectRatio: aspectRatio,
        durationSec: durationSec,
        resolution: resolution,
        references: references ?? this.references,
        parameters: parameters,
      );

  Map<String, Object?> get storedParameters => {
    ...parameters,
    'count': count,
    'aspectRatio': aspectRatio,
    if (durationSec != null) 'durationSec': durationSec,
    if (resolution != null) 'resolution': resolution,
  };

  MediaReference? frame(MediaReferenceRole role) =>
      references.where((reference) => reference.role == role).firstOrNull;
}

class MediaCapabilities {
  const MediaCapabilities({
    required this.aspectRatios,
    this.maxPerRequest = 1,
    this.maxReferences = 0,
    this.nativeProgress = false,
    this.durations = const [],
    this.resolutions = const [],
    this.resolutionsWithLastFrame,
    this.frameRoles = const [],
    this.ratiosByResolution = const {},
    this.framesUseAutomaticRatio = false,
    this.requiresFirstFrame = false,
  });

  final List<String> aspectRatios;
  final int maxPerRequest;
  final int maxReferences;
  final bool nativeProgress;
  final List<int> durations;
  final List<String> resolutions;
  final List<String>? resolutionsWithLastFrame;
  final List<MediaReferenceRole> frameRoles;
  final Map<String, List<String>> ratiosByResolution;
  final bool framesUseAutomaticRatio;
  final bool requiresFirstFrame;

  List<String> ratiosFor(String? resolution) =>
      ratiosByResolution[resolution] ?? aspectRatios;

  List<String> resolutionsFor({required bool hasLastFrame}) =>
      (hasLastFrame ? resolutionsWithLastFrame : null) ?? resolutions;
}

class MediaResult {
  const MediaResult({
    required this.mime,
    this.bytes,
    this.base64,
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

class MediaTaskAccepted extends MediaEvent {
  const MediaTaskAccepted({this.cancelUrl, this.cancelHeaders = const {}});

  final Uri? cancelUrl;
  final Map<String, String> cancelHeaders;
}

enum MediaFailureKind {
  network,
  rateLimited,
  server,
  rejected,
  login,
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
  });

  final MediaFailureKind kind;
  final String message;
  final Duration? retryAfter;
  final int? statusCode;

  bool get retryable => switch (kind) {
    MediaFailureKind.network ||
    MediaFailureKind.rateLimited ||
    MediaFailureKind.server => true,
    _ => false,
  };

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'message': message,
    if (statusCode != null) 'statusCode': statusCode,
  };

  @override
  String toString() => message;
}
