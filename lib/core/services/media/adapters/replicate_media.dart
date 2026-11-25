import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../utils/sandbox_path_resolver.dart';
import '../../../providers/settings_provider.dart';
import '../../api/chat_api_helpers.dart';
import '../../api/stream/stream_chunk.dart' show mimeTypeFromImageUri;
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';
import '../replicate_models.dart';
import 'native_image_size.dart';

class ReplicateMediaAdapter implements MediaAdapter {
  const ReplicateMediaAdapter(this.model);
  final ReplicateMediaModel model;

  @override
  MediaCapabilities capabilities(ProviderConfig provider, String modelId) =>
      model.capabilities;

  Future<String> _inputFile(
    MediaContext context,
    MediaRequest request,
    MediaReference reference,
  ) async {
    final path = SandboxPathResolver.resolveForIo(reference.path);
    if (path == null) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Reference file unavailable',
      );
    }
    if (await File(path).length() <= 256 * 1024) {
      return mediaReferenceDataUri(reference);
    }
    final upload = http.MultipartRequest('POST', context.endpoint('files'));
    upload.headers.addAll(
      context.headers(request.modelId, json: false)
        ..removeWhere((key, _) => key.toLowerCase() == 'content-type'),
    );
    upload.files.add(
      await http.MultipartFile.fromPath(
        'content',
        path,
        contentType: MediaType.parse(mimeFromPath(path)),
      ),
    );
    final data = await readMediaJson(await context.send(upload));
    final url = mediaResultUri((data['urls'] as Map?)?['get']);
    if (url == null) {
      throw const MediaFailure(
        MediaFailureKind.invalidResponse,
        'Uploaded file URL missing',
      );
    }
    return url.toString();
  }

  @override
  Stream<MediaEvent> generate(
    MediaContext context,
    MediaRequest request,
  ) async* {
    final headers = context.headers(request.modelId);
    final input = <String, dynamic>{
      'prompt': request.prompt,
      if (request.aspectRatio != 'auto') 'aspect_ratio': request.aspectRatio,
      if (request.parameters['seed'] case final int seed) 'seed': seed,
      if (request.parameters['format'] case final String fmt)
        'output_format': fmt == 'jpeg' ? 'jpg' : fmt,
    };
    if (model == ReplicateMediaModel.seedancePro) {
      if (request.durationSec != null) input['duration'] = request.durationSec;
      if (request.resolution != null) input['resolution'] = request.resolution;
      for (final role in [
        MediaReferenceRole.firstFrame,
        MediaReferenceRole.lastFrame,
      ]) {
        if (request.frame(role) case final ref?) {
          input[role == MediaReferenceRole.firstFrame
              ? 'image'
              : 'last_frame_image'] = await _inputFile(
            context,
            request,
            ref,
          );
        }
      }
    } else {
      final refs = [
        for (final ref in request.inputImages)
          await _inputFile(context, request, ref),
      ];
      switch (model) {
        case ReplicateMediaModel.nanoBanana:
        case ReplicateMediaModel.nanoBananaPro:
          if (refs.isNotEmpty) input['image_input'] = refs;
          if (request.parameters['size'] case final String size) {
            input['resolution'] = size;
          }
        case ReplicateMediaModel.fluxKontext:
          if (refs.isNotEmpty) input['input_image'] = refs.single;
        case ReplicateMediaModel.fluxDev:
        case ReplicateMediaModel.fluxSchnell:
          if (refs.isNotEmpty) input['image'] = refs.single;
          input['num_outputs'] = request.count;
        case ReplicateMediaModel.seedancePro:
          break;
      }
    }
    final created = await context.jsonRequest(
      'POST',
      context.endpoint('models/${model.id}/predictions'),
      headers: headers,
      body: context.body(request, {'input': input}),
    );
    final id = Uri.encodeComponent(requireMediaTaskId(created['id']));
    final task = context.endpoint('predictions/$id');
    yield* pollMediaTask(
      context,
      initial: created,
      accepted: MediaTaskAccepted(
        cancelUrl: context.endpoint('predictions/$id/cancel'),
        cancelMethod: 'POST',
        cancelHeaders: headers,
      ),
      poll: () => context.jsonRequest('GET', task, headers: headers),
      result: (data) {
        switch (data['status']) {
          case 'starting':
          case 'processing':
            return null;
          case 'canceled':
          case 'failed':
          case 'aborted':
            failedMediaTask(data['error']);
          case 'succeeded':
            final output = data['output'];
            return [
              for (final item in output is List ? output : [output])
                if (mediaResultUri(item) case final url?)
                  MediaResult(
                    mime: model == ReplicateMediaModel.seedancePro
                        ? 'video/mp4'
                        : mimeTypeFromImageUri(url.toString()) ??
                              imageMime(request.parameters['format']),
                    url: url,
                    downloadHeaders: url.origin == task.origin
                        ? headers
                        : const {},
                    durationMs: videoDurationMs(request.durationSec),
                  ),
            ];
          default:
            throw const MediaFailure(
              MediaFailureKind.invalidResponse,
              'Unknown prediction status',
            );
        }
      },
    );
  }
}
