import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../utils/sandbox_path_resolver.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class OpenAiVideosAdapter implements MediaAdapter {
  const OpenAiVideosAdapter();

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) {
    final sora = apiModelId(provider, modelId).toLowerCase();
    final isSora = sora.startsWith('sora-');
    return MediaCapabilities(
      aspectRatios: isSora
          ? const ['16:9', '9:16']
          : const ['16:9', '9:16', '1:1'],
      durations: isSora ? const [4, 8, 12] : const [5, 6, 8, 10, 12, 15],
      resolutions: [
        '720p',
        if (!isSora || sora.startsWith('sora-2-pro')) '1080p',
      ],
      maxReferences: 1,
      frameRoles: const [MediaReferenceRole.firstFrame],
      nativeProgress: true,
    );
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final model = apiModelId(context.provider, request.modelId);
    final authHeaders = context.headers(request.modelId, json: false);
    final extra = request.parameters['extra'];
    final payload = context.body(request, {
      'model': model,
      'prompt': request.prompt,
      if (request.durationSec case final duration?)
        'seconds': duration.toString(),
      if (_size(model, request) case final size?) 'size': size,
      if (request.negativePrompt != null || extra is Map && extra.isNotEmpty)
        'metadata': {
          if (request.negativePrompt case final negative?)
            'negative_prompt': negative,
          if (extra is Map) ...Map<String, dynamic>.from(extra),
        },
    }, includeExtra: false);
    final submitted = http.MultipartRequest('POST', context.endpoint('videos'))
      ..headers.addAll(authHeaders)
      ..headers.removeWhere((name, _) => name.toLowerCase() == 'content-type')
      ..fields.addAll(
        payload.map(
          (key, value) =>
              MapEntry(key, value is String ? value : jsonEncode(value)),
        ),
      );
    if (request.frame(MediaReferenceRole.firstFrame) case final reference?) {
      final path = SandboxPathResolver.resolveForIo(reference.path);
      if (path == null) {
        throw const MediaFailure(
          MediaFailureKind.parameters,
          'First frame unavailable',
        );
      }
      submitted.files.add(
        await http.MultipartFile.fromPath(
          'input_reference',
          path,
          contentType: MediaType.parse(mimeFromPath(path)),
        ),
      );
    }
    final created = await readMediaJson(await context.send(submitted));
    final id = Uri.encodeComponent(requireMediaTaskId(created['id']));
    yield* pollMediaTask(
      context,
      initial: created,
      poll: () => context.jsonRequest(
        'GET',
        context.endpoint('videos/$id'),
        headers: authHeaders,
      ),
      progress: (data) => mediaPercent(data['progress']),
      result: (data) {
        final status = data['status'];
        if (const {'failed', 'cancelled', 'expired'}.contains(status)) {
          failedMediaTask(data['error']);
        }
        if (status != 'completed' && status != 'succeeded') return null;
        final dimensions = (data['size']?.toString() ?? _size(model, request))
            ?.split('x')
            .map(int.tryParse)
            .toList();
        final meta = data['metadata'];
        return MediaResult(
          mime: 'video/mp4',
          url: context.endpoint('videos/$id/content'),
          downloadHeaders: authHeaders,
          previewUrl: mediaResultUri(
            meta is Map ? meta['thumbnail_url'] : null,
          ),
          durationMs: videoDurationMs(data['seconds'] ?? request.durationSec),
          width: dimensions?.length == 2 ? dimensions!.first : null,
          height: dimensions?.length == 2 ? dimensions!.last : null,
        );
      },
    );
  }

  static String? _size(String model, MediaRequest request) {
    final ratio = request.aspectRatio;
    if (ratio == 'auto') return null;
    final larger = request.resolution == '1080p';
    final sora = model.toLowerCase().startsWith('sora-');
    final landscape = larger ? (sora ? '1792x1024' : '1920x1080') : '1280x720';
    final portrait = larger ? (sora ? '1024x1792' : '1080x1920') : '720x1280';
    return switch (ratio) {
      '16:9' => landscape,
      '9:16' => portrait,
      '1:1' => larger ? '1080x1080' : '720x720',
      _ => null,
    };
  }
}
