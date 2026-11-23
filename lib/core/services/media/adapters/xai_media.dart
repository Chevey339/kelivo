import '../../../models/provider_oauth.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class XaiImageAdapter implements MediaAdapter {
  const XaiImageAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      const MediaCapabilities(
        aspectRatios: [
          'auto',
          '1:1',
          '3:2',
          '2:3',
          '4:3',
          '3:4',
          '16:9',
          '9:16',
        ],
        maxPerRequest: 10,
        maxReferences: 1,
      );

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final base = context.provider.oauthProvider == OAuthProvider.grok
        ? grokMediaBaseUrl
        : null;
    final reference = request.references.firstOrNull;
    final url = context.endpoint(
      reference == null ? 'images/generations' : 'images/edits',
      base: base,
    );
    final payload = await context.jsonRequest(
      'POST',
      url,
      headers: context.headers(request.modelId),
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        'n': request.count,
        if (request.aspectRatio != 'auto') 'aspect_ratio': request.aspectRatio,
        if (request.parameters['resolution'] case final String resolution)
          'resolution': resolution,
        if (reference != null)
          'image': {
            'type': 'image_url',
            'url': await mediaReferenceDataUri(reference),
          },
      }),
    );
    yield MediaOutput(parseOpenAiMediaImages(payload, mime: 'image/jpeg'));
  }
}

class XaiVideoAdapter implements MediaAdapter {
  const XaiVideoAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    final highResolution = model.startsWith('grok-imagine-video-1.5');
    final acceptsLast = model == 'grok-imagine-video-1.5';
    return MediaCapabilities(
      aspectRatios: const [
        '16:9',
        'auto',
        '9:16',
        '1:1',
        '4:3',
        '3:4',
        '3:2',
        '2:3',
        '21:9',
        '5:2',
      ],
      durations: List.generate(15, (index) => index + 1),
      resolutions: ['480p', '720p', if (highResolution) '1080p'],
      resolutionsWithLastFrame: acceptsLast ? const ['720p', '480p'] : null,
      maxReferences: acceptsLast ? 2 : 1,
      frameRoles: [
        MediaReferenceRole.firstFrame,
        if (acceptsLast) MediaReferenceRole.lastFrame,
      ],
      framesUseAutomaticRatio: true,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final base = context.provider.oauthProvider == OAuthProvider.grok
        ? grokMediaBaseUrl
        : null;
    final first = request.frame(MediaReferenceRole.firstFrame);
    final last = request.frame(MediaReferenceRole.lastFrame);
    if (last != null && request.resolution == '1080p') {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Pinned first and last frames support up to 720p',
      );
    }
    final headers = context.headers(request.modelId);
    final submitted = await context.jsonRequest(
      'POST',
      context.endpoint('videos/generations', base: base),
      headers: headers,
      body: context.body(request, {
        'model': apiModelId(context.provider, request.modelId),
        'prompt': request.prompt,
        if (request.durationSec case final duration?) 'duration': duration,
        if (request.resolution case final resolution?) 'resolution': resolution,
        if (first == null && request.aspectRatio != 'auto')
          'aspect_ratio': request.aspectRatio,
        if (first != null) 'image': {'url': await mediaReferenceDataUri(first)},
        if (last != null)
          'last_frame': {'url': await mediaReferenceDataUri(last)},
      }),
    );
    final id = Uri.encodeComponent(requireMediaTaskId(submitted['request_id']));
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('videos/$id', base: base),
        headers: headers,
      ),
      result: (data) {
        final status = data['status'];
        if (status == 'failed' ||
            status == 'expired' ||
            status == 'cancelled') {
          failedMediaTask(data['error'] ?? data);
        }
        if (status != 'done') return null;
        final video = data['video'];
        final url = mediaResultUri(video is Map ? video['url'] : null);
        if (url == null) {
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Video URL missing',
          );
        }
        return MediaResult(
          mime: 'video/mp4',
          url: url,
          durationMs: videoDurationMs(video['duration'] ?? request.durationSec),
          previewUrl: mediaResultUri(video['cover_url']),
        );
      },
      progress: (data) => mediaPercent(data['progress']),
    );
  }
}
