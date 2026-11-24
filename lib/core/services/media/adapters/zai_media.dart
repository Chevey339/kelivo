import 'dart:convert';
import 'package:downsize/downsize.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class ZaiImagesAdapter implements MediaAdapter {
  const ZaiImagesAdapter();

  static const sizes = {
    '1:1': '1280x1280',
    '3:2': '1568x1056',
    '2:3': '1056x1568',
    '4:3': '1472x1088',
    '3:4': '1088x1472',
    '16:9': '1728x960',
    '9:16': '960x1728',
  };

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      MediaCapabilities(
        aspectRatios: ['auto', ...sizes.keys],
        qualities: [
          'hd',
          if (Uri.tryParse(provider.baseUrl)?.host != 'open.bigmodel.cn')
            'standard',
        ],
      );

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final data = await context.jsonRequest(
      'POST',
      context.endpoint('images/generations'),
      headers: context.headers(request.modelId),
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (sizes[request.aspectRatio] case final pixels?) 'size': pixels,
        if (request.parameters['quality'] case final String quality)
          'quality': quality,
      }),
    );
    yield MediaOutput(parseOpenAiMediaImages(data, mime: 'image/png'));
  }
}

// CogVideoX accepts JPEG/PNG frames up to 5 MB. Preserve acceptable originals.
String _frameDataUri(Uint8List bytes) {
  const limit = 5000000;
  final format = image.findDecoderForData(bytes)?.format;
  if (format == null) {
    throw const MediaFailure(
      MediaFailureKind.parameters,
      'Unsupported video frame',
    );
  }
  if (bytes.length <= limit &&
      (format == image.ImageFormat.jpg || format == image.ImageFormat.png)) {
    final mime = format == image.ImageFormat.jpg ? 'jpeg' : 'png';
    return 'data:image/$mime;base64,${base64Encode(bytes)}';
  }
  final jpeg = Downsize().compress(
    Config(data: bytes, quality: 90, maxLongEdge: 3840, maxSize: limit / 1024),
  );
  if (jpeg == null || jpeg.length > limit) {
    throw const MediaFailure(
      MediaFailureKind.referenceTooLarge,
      'Video frame exceeds 5 MB',
    );
  }
  return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
}

class ZaiVideoAdapter implements MediaAdapter {
  const ZaiVideoAdapter();

  static const _sizes = {
    '720p': {'16:9': '1280x720', '9:16': '720x1280'},
    '1080p': {'16:9': '1920x1080', '9:16': '1080x1920'},
    '1024p': {'1:1': '1024x1024'},
    '4K': {'16:9': '3840x2160'},
  };

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      MediaCapabilities(
        aspectRatios: const ['auto', '16:9', '9:16', '1:1'],
        resolutions: _sizes.keys.toList(),
        ratiosByResolution: {
          for (final entry in _sizes.entries)
            entry.key: entry.value.keys.toList(),
        },
        durations: const [5, 10],
        maxReferences: 2,
        frameRoles: const [
          MediaReferenceRole.firstFrame,
          MediaReferenceRole.lastFrame,
        ],
        platformOptions: [
          const MediaParameter('with_audio', MediaParameterType.boolean),
          MediaParameter(
            'quality',
            MediaParameterType.enumeration,
            choices: ['speed', 'quality'],
            availableWithLastFrame:
                Uri.tryParse(provider.baseUrl)?.host == 'open.bigmodel.cn',
          ),
        ],
      );

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final frames = [
      for (final role in [
        MediaReferenceRole.firstFrame,
        MediaReferenceRole.lastFrame,
      ])
        if (request.frame(role) case final ref?)
          await compute(_frameDataUri, await readMediaReference(ref)),
    ];
    final headers = context.headers(request.modelId);
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('videos/generations'),
      headers: headers,
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (frames.isNotEmpty)
          'image_url': frames.length == 1 ? frames.single : frames,
        if (_sizes[request.resolution]?[request.aspectRatio] case final size?)
          'size': size,
        if (request.durationSec case final duration?) 'duration': duration,
        if (request.parameters['with_audio'] case final bool audio)
          'with_audio': audio,
        if (frames.length == 2 &&
            Uri.tryParse(context.provider.baseUrl)?.host != 'open.bigmodel.cn')
          'quality': 'speed'
        else if (request.parameters['quality'] case final String quality)
          'quality': quality,
      }),
    );
    if (created['task_status'] == 'FAIL') failedMediaTask(created['error']);
    final id = Uri.encodeComponent(requireMediaTaskId(created['id']));
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('async-result/$id'),
        headers: headers,
      ),
      result: (data) {
        switch (data['task_status']) {
          case 'PROCESSING':
            return null;
          case 'FAIL':
            failedMediaTask(data['error']);
          case 'SUCCESS':
            return [
              for (final row
                  in (data['video_result'] as List? ?? const [])
                      .whereType<Map>())
                if (mediaResultUri(row['url']) case final url?)
                  MediaResult(
                    mime: 'video/mp4',
                    url: url,
                    previewUrl: mediaResultUri(row['cover_image_url']),
                    durationMs: videoDurationMs(request.durationSec),
                  ),
            ];
          default:
            throw const MediaFailure(
              MediaFailureKind.invalidResponse,
              'Unknown video task status',
            );
        }
      },
    );
  }
}
