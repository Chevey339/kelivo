import 'dart:convert';

import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../../api/providers/google_vertex.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class VeoVideoAdapter implements MediaAdapter {
  const VeoVideoAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final supportsLast = apiModelId(provider, modelId).contains('veo-3.1');
    return MediaCapabilities(
      aspectRatios: const ['16:9', '9:16'],
      durations: const [4, 6, 8],
      resolutions: const ['720p', '1080p'],
      maxReferences: supportsLast ? 2 : 1,
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
    final model = apiModelId(
      provider,
      request.modelId,
    ).replaceFirst(RegExp(r'^models/'), '');
    final String base;
    final Map<String, String> auth;
    if (vertex) {
      final project = _project(provider);
      final location = (provider.location ?? '').trim();
      final region = location.isEmpty ? 'us-central1' : location;
      if (project.isEmpty ||
          !_resourceSegment.hasMatch(project) ||
          !_resourceSegment.hasMatch(region)) {
        throw const MediaFailure(
          MediaFailureKind.parameters,
          'Vertex AI needs a project and region',
        );
      }
      final token = (provider.serviceAccountJson ?? '').trim().isEmpty
          ? context.apiKey
          : await maybeVertexAccessToken(
              provider,
            ).timeout(const Duration(seconds: 45));
      if (token == null || token.isEmpty) {
        throw const MediaFailure(
          MediaFailureKind.login,
          'Vertex AI credentials unavailable',
        );
      }
      final host = region == 'global'
          ? 'aiplatform.googleapis.com'
          : '$region-aiplatform.googleapis.com';
      base =
          'https://$host/v1/projects/$project/locations/$region/publishers/google';
      auth = {'Authorization': 'Bearer $token'};
    } else {
      base = provider.baseUrl;
      auth = {'x-goog-api-key': context.apiKey};
    }

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
        },
      }),
    );
    final operation = requireMediaTaskId(launched['name']);
    final operationParts = operation.split('/');
    if (!operationParts.every(_resourceSegment.hasMatch)) {
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
        final url = _videoUri(video?['gcsUri'] ?? video?['uri']);
        if (bytes is! String && url == null) {
          if ((response?['raiMediaFilteredCount'] as num? ?? 0) > 0) {
            throw const MediaFailure(
              MediaFailureKind.rejected,
              'Content filtered',
            );
          }
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Veo video unavailable',
          );
        }
        final origin = Uri.parse(base).origin;
        final attachAuth =
            url != null &&
            (vertex ? shouldAttachVertexMediaAuth(url) : url.origin == origin);
        return MediaResult(
          mime: 'video/mp4',
          base64: bytes is String ? bytes : null,
          url: url,
          downloadHeaders: attachAuth ? auth : const {},
          durationMs: videoDurationMs(request.durationSec),
        );
      },
    );
  }

  static final _resourceSegment = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$');

  static String _project(ProviderConfig provider) {
    final project = (provider.projectId ?? '').trim();
    if (project.isNotEmpty) return project;
    try {
      if (jsonDecode(provider.serviceAccountJson ?? '') case {
        'project_id': final String id,
      }) {
        return id.trim();
      }
    } on FormatException {
      // Project can also be set explicitly in the provider.
    }
    return '';
  }

  static Future<Map<String, String>> _encodedImage(MediaReference image) async {
    final data = await mediaReferenceDataUri(image);
    final semicolon = data.indexOf(';');
    final comma = data.indexOf(',');
    return {
      'mimeType': data.substring(5, semicolon),
      'bytesBase64Encoded': data.substring(comma + 1),
    };
  }

  static Uri? _videoUri(Object? value) {
    if (value is! String) return null;
    final gs = Uri.tryParse(value);
    if (gs != null &&
        gs.scheme == 'gs' &&
        gs.host.isNotEmpty &&
        gs.path.length > 1) {
      return Uri(
        scheme: 'https',
        host: 'storage.googleapis.com',
        pathSegments: [
          'storage',
          'v1',
          'b',
          gs.host,
          'o',
          gs.pathSegments.join('/'),
        ],
        queryParameters: {'alt': 'media'},
      );
    }
    return mediaResultUri(value);
  }
}
