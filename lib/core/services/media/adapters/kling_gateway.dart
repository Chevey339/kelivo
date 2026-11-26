import '../../../models/media_creation.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import '../tokendance_media_protocol.dart';
import 'native_image_size.dart';

/// TokenDance exposes Kling's versioned task protocol with a shared poll shape
/// for image, long-image, and video jobs.
class KlingGatewayAdapter implements MediaAdapter {
  const KlingGatewayAdapter(this.protocol);

  final TokenDanceMediaProtocol protocol;
  MediaMode get mode => protocol.mode!;

  static ({int min, int max}) _longImageBounds(Map<String, dynamic> options) =>
      options['skill'] == 'ecommerce' ? (min: 1, max: 3) : (min: 0, max: 2);

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final model = apiModelId(provider, modelId).toLowerCase();
    if (mode == MediaMode.image) {
      if (protocol == TokenDanceMediaProtocol.klingLongImage) {
        return const MediaCapabilities(
          aspectRatios: ['auto'],
          sizes: ['1K', '2K'],
          maxReferences: 3,
          referenceBounds: _longImageBounds,
          platformOptions: [
            MediaParameter(
              'skill',
              MediaParameterType.enumeration,
              choices: ['webpage', 'ecommerce'],
              defaultValue: 'webpage',
            ),
          ],
        );
      }
      return const MediaCapabilities(
        aspectRatios: standardImageRatios,
        sizes: ['2K', '4K', '8K'],
        maxPerRequest: 9,
        maxReferences: 10,
      );
    }
    final flash = model.endsWith('-flash');
    final turbo = model.endsWith('-turbo');
    final v4 = protocol == TokenDanceMediaProtocol.klingV2;
    final longest = flash
        ? 20
        : v4
        ? 30
        : 15;
    return MediaCapabilities(
      aspectRatios: const ['16:9', '9:16', '1:1'],
      resolutions: ['720p', if (!flash) '1080p', if (!v4 && !turbo) '4k'],
      durations: [for (var seconds = 3; seconds <= longest; seconds++) seconds],
      maxReferences: flash || turbo ? 1 : 2,
      frameRoles: [
        MediaReferenceRole.firstFrame,
        if (!flash && !turbo) MediaReferenceRole.lastFrame,
      ],
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final images = request.inputImages.toList();
    final video = mode == MediaMode.video;
    final longImage = protocol == TokenDanceMediaProtocol.klingLongImage;
    final omni = protocol == TokenDanceMediaProtocol.klingOmni;
    final webpage = longImage && request.parameters['skill'] != 'ecommerce';
    final bounds = _longImageBounds(request.parameters);
    if (longImage &&
        (images.length < bounds.min || images.length > bounds.max)) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Invalid reference count for Kling long image',
      );
    }
    final endpoint = switch (mode) {
      MediaMode.image =>
        longImage ? 'long-image-generation' : 'image-generation',
      MediaMode.video when omni => 'omni-video',
      MediaMode.video => images.isEmpty ? 'text2video' : 'image2video',
    };
    final version = !video || protocol == TokenDanceMediaProtocol.klingV2
        ? 'v2'
        : 'v1';
    final path = '/gateway/kling/$version/$endpoint';
    final headers = context.headers(request.modelId);
    final data = await context.jsonRequest(
      'POST',
      context.endpoint(path),
      headers: headers,
      body: context.body(request, {
        'model_name': model,
        if (endpoint == 'text2video')
          'prompt': request.prompt
        else
          'contents': [
            {'type': 'prompt', 'text': request.prompt},
            for (final (i, image) in images.indexed)
              {
                'type': video
                    ? (image.role == MediaReferenceRole.lastFrame
                          ? 'last_frame'
                          : 'first_frame')
                    : webpage
                    ? (i == 0 ? 'style_refer_image' : 'subject_refer_image')
                    : 'refer_image',
                if (!video) 'id': 'image${i + 1}',
                'url': await mediaReferenceBase64(image),
              },
          ],
        'settings': {
          if (!longImage && request.aspectRatio != 'auto')
            'aspect_ratio': request.aspectRatio,
          if (video) ...{
            'duration': request.durationSec ?? 5,
            'resolution': request.resolution ?? '720p',
          } else ...{
            'resolution':
                (request.parameters['size'] as String? ??
                        (longImage ? '1K' : '2K'))
                    .toLowerCase(),
            if (longImage)
              'skill': webpage ? 'webpage' : 'ecommerce'
            else
              'n': request.count,
          },
        },
      }),
    );
    _checkCode(data);
    final created = data['data'];
    final taskId = created is Map ? created['id'] : null;
    final task = Uri.encodeComponent(
      requireMediaTaskId(taskId is int ? taskId.toString() : taskId),
    );
    yield* pollMediaTask(
      context,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('$path/$task'),
        headers: headers,
      ),
      result: (response) {
        _checkCode(response);
        final data = response['data'];
        final row = data is List ? data.firstOrNull : data;
        if (row is Map) {
          switch (row['status']) {
            case 'submitted' ||
                'processing' ||
                'queued' ||
                'running' ||
                'pending':
              return null;
            case 'failed' || 'cancelled' || 'canceled' || 'expired':
              failedMediaTask(row['message']);
            case 'succeeded':
              final outputs = row['outputs'];
              if (outputs is List) {
                final results = [
                  for (final out in outputs.whereType<Map>())
                    if (!video || out['type'] == 'video')
                      if (mediaResultUri(out['url']) case final url?)
                        MediaResult(
                          mime: video ? 'video/mp4' : 'image/png',
                          url: url,
                          durationMs: video
                              ? videoDurationMs(
                                  out['duration'] ?? request.durationSec,
                                )
                              : null,
                        ),
                ];
                if (results.isNotEmpty) return results;
              }
          }
        }
        throw const MediaFailure(
          MediaFailureKind.invalidResponse,
          'Invalid Kling task result',
        );
      },
    );
  }

  static void _checkCode(Map<String, dynamic> data) {
    if (data['code'] case final int code when code != 0) {
      throw mediaResponseFailure(data);
    }
  }
}
