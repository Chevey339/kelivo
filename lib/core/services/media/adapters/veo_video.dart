import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import 'google_media_route.dart';
import 'gemini_images.dart';
import '../gemini_media_models.dart';

class VeoVideoAdapter implements MediaAdapter {
  const VeoVideoAdapter();

  static bool retiredOnVertex(String model) => const {
    'veo-2.0-generate-001',
    'veo-3.0-generate-001',
    'veo-3.0-fast-generate-001',
  }.contains(geminiMediaName(model));

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final name = geminiMediaName(apiModelId(provider, modelId));
    final supportsLast = name.contains('veo-3.1');
    return MediaCapabilities(
      aspectRatios: const ['16:9', '9:16'],
      durations: const [4, 6, 8],
      resolutions: [
        '720p',
        '1080p',
        if (provider.vertexAI == true && name == 'veo-3.1-generate-001') '4k',
      ],
      maxReferences: supportsLast ? 2 : 1,
      supportsNegativePrompt: true,
      supportsSeed: true,
      frameRoles: [
        MediaReferenceRole.firstFrame,
        if (supportsLast) MediaReferenceRole.lastFrame,
      ],
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final provider = context.provider;
    final vertex = provider.vertexAI == true;
    final model = GeminiImagesAdapter.modelName(provider, request.modelId);
    final route = await GoogleMediaRoute.resolve(context);
    final GoogleMediaRoute(:base, :auth) = route;

    final first = request.frame(MediaReferenceRole.firstFrame);
    final last = request.frame(MediaReferenceRole.lastFrame);
    final headers = context.headers(request.modelId, auth: auth);
    final resource = 'models/${Uri.encodeComponent(model)}';
    final launched = await context.jsonRequest(
      'POST',
      context.endpoint('$resource:predictLongRunning', base: base),
      headers: headers,
      body: context.body(request, {
        'instances': [
          {
            'prompt': request.prompt,
            if (first != null) 'image': await _encodedImage(first),
            if (last != null) 'lastFrame': await _encodedImage(last),
          },
        ],
        'parameters': {
          'sampleCount': 1,
          if (request.aspectRatio != 'auto') 'aspectRatio': request.aspectRatio,
          if (request.durationSec case final seconds?)
            'durationSeconds': seconds,
          if (request.resolution case final resolution?)
            'resolution': resolution,
          if (request.negativePrompt case final negative?)
            'negativePrompt': negative,
          if (request.parameters['seed'] case final int seed) 'seed': seed,
        },
      }),
    );
    final operation = requireMediaTaskId(launched['name']);
    final operationParts = operation.split('/');
    if (!operationParts.every(GoogleMediaRoute.segment.hasMatch)) {
      throw const MediaFailure(
        MediaFailureKind.invalidResponse,
        'Invalid Veo task name',
      );
    }
    yield* pollMediaTask(
      context,
      initial: launched,
      poll: () => vertex
          ? context.jsonRequest(
              'POST',
              context.endpoint('$resource:fetchPredictOperation', base: base),
              headers: headers,
              body: {'operationName': operation},
            )
          : context.jsonRequest(
              'GET',
              context.endpoint(operation, base: base),
              headers: headers,
            ),
      progress: (data) =>
          mediaPercent((data['metadata'] as Map?)?['progressPercent']),
      result: (data) {
        if (data['done'] != true) return null;
        final response = data['response'] as Map?;
        final generated = response?['generateVideoResponse'] as Map?;
        final entries =
            (response?['videos'] ?? generated?['generatedSamples']) as List?;
        final record = entries?.whereType<Map>().firstOrNull;
        final video = (record?['video'] as Map?) ?? record;
        final bytes = video?['bytesBase64Encoded'];
        final url = route.resultUri(video?['gcsUri'] ?? video?['uri']);
        if (bytes is! String && url == null) {
          final count =
              generated?['raiMediaFilteredCount'] ??
              response?['raiMediaFilteredCount'];
          if (count is num && count > 0) {
            throw filteredMediaFailure(
              'Content filtered',
              generated?['raiMediaFilteredReasons'] ??
                  response?['raiMediaFilteredReasons'],
            );
          }
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Veo video unavailable',
          );
        }
        return [
          MediaResult(
            mime: 'video/mp4',
            base64: bytes is String ? bytes : null,
            url: url,
            downloadHeaders: url == null
                ? const {}
                : route.resultHeaders(url, vertex: vertex, headers: headers),
            durationMs: videoDurationMs(request.durationSec),
          ),
        ];
      },
    );
  }

  static Future<Map<String, String>> _encodedImage(MediaReference image) async {
    final data = await googleImageInput(image);
    return {'mimeType': data.mime, 'bytesBase64Encoded': data.base64};
  }
}
