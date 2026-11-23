import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/fal_media.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completed-result retrieval retries without resubmitting or polling',
    () async {
      const id = 'fal-ai/nano-banana';
      final provider = ProviderConfig.defaultsFor('fal');
      final calls = <String>[];
      var resultAttempts = 0;
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          return videoJson({'request_id': 'job', 'status': 'IN_QUEUE'});
        }
        if (request.url.path.endsWith('/status')) {
          return videoJson({'status': 'COMPLETED'});
        }
        if (++resultAttempts == 1) return videoJson({'error': 'busy'}, 503);
        return videoJson({
          'images': [
            {'url': 'https://cdn.example.test/1.png'},
          ],
        });
      });
      final events = await const FalMediaAdapter(MediaMode.image)
          .generate(
            videoContext(provider, client),
            const MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'Draw a tree',
            ),
          )
          .toList();
      expect(calls, [
        'POST /fal-ai/nano-banana',
        'GET /fal-ai/nano-banana/requests/job/status',
        'GET /fal-ai/nano-banana/requests/job',
        'GET /fal-ai/nano-banana/requests/job',
      ]);
      expect(events.whereType<MediaOutput>().single.results, hasLength(1));
    },
  );

  test(
    'fal starts disabled with a local media catalog and refills removed models',
    () {
      const id = 'fal-ai/flux-2-pro';
      final initial = ProviderConfig.defaultsFor('fal');
      expect(initial.enabled, isFalse);
      expect(initial.baseUrl, 'https://queue.fal.run');
      expect(initial.avatar?.value, 'assets/icons/fal-color.svg');
      expect(initial.models, contains(id));
      final trimmed = initial.copyWith(
        models: ['personal/image'],
        disabledModels: const {id},
      );
      final refilled = trimmed.withBuiltInFalModels();
      expect(refilled.models.first, 'personal/image');
      expect(refilled.models, containsAll(initial.models));
      expect(refilled.isModelEnabled(id), isFalse);
      final resolver = ModelSpecResolver.instance;
      expect(resolver.spec(refilled, id).displayName, 'FLUX.2 Pro');
      expect(resolver.spec(refilled, id).type, ModelType.image);
      expect(
        resolver.spec(refilled, 'minimax/h3-max/text-to-video').type,
        ModelType.video,
      );
      expect(resolver.spec(refilled, 'personal/image').type, ModelType.image);
    },
  );

  test('queue uses declared status, result and cancel endpoints', () async {
    const id = 'fal-ai/flux/schnell';
    final provider = ProviderConfig.defaultsFor('fal');
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['authorization'], 'Key fixture-key');
      switch (request.url.path) {
        case '/$id':
          expect(jsonDecode(request.body), {
            'prompt': 'A forest',
            'image_size': {'width': 1024, 'height': 1024},
            'num_images': 2,
            'num_inference_steps': 6,
            'seed': 42,
            'output_format': 'png',
          });
          return videoJson({
            'request_id': 'test',
            'status': 'IN_QUEUE',
            'status_url':
                'https://queue.fal.run/fal-ai/flux/requests/test/status',
            'response_url': 'https://queue.fal.run/fal-ai/flux/requests/test',
            'cancel_url':
                'https://queue.fal.run/fal-ai/flux/requests/test/cancel',
          });
        case '/fal-ai/flux/requests/test/status':
          return videoJson({'status': 'COMPLETED'});
        case '/fal-ai/flux/requests/test':
          return videoJson({
            'images': [
              {
                'url': 'https://cdn.example.test/image1.png',
                'width': 1024,
                'height': 1024,
                'content_type': 'image/png',
              },
              {'url': 'https://cdn.example.test/image2.png'},
            ],
          });
        default:
          fail('Unexpected request: ${request.url}');
      }
    });
    final events = await const FalMediaAdapter(MediaMode.image)
        .generate(
          videoContext(provider, client),
          const MediaRequest(
            modelId: id,
            mode: MediaMode.image,
            prompt: 'A forest',
            aspectRatio: '1:1',
            count: 2,
            parameters: {'num_inference_steps': 6, 'seed': 42, 'format': 'png'},
          ),
        )
        .toList();
    expect(paths, [
      '/$id',
      '/fal-ai/flux/requests/test/status',
      '/fal-ai/flux/requests/test',
    ]);
    final accepted = events.whereType<MediaTaskAccepted>().single;
    expect(accepted.cancelMethod, 'PUT');
    expect(accepted.cancelUrl?.path, '/fal-ai/flux/requests/test/cancel');
    expect(events.whereType<MediaOutput>().single.results, hasLength(2));
  });

  test(
    'queue refuses a provider-supplied URL with a different origin',
    () async {
      final provider = ProviderConfig.defaultsFor('fal');
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.method, 'POST');
        return videoJson({
          'request_id': 'test',
          'status_url': 'https://elsewhere.test/status',
        });
      });
      await expectLater(
        const FalMediaAdapter(MediaMode.image).generate(
          videoContext(provider, client),
          const MediaRequest(
            modelId: 'fal-ai/flux/schnell',
            mode: MediaMode.image,
            prompt: 'A forest',
          ),
        ),
        emitsError(
          isA<MediaFailure>().having(
            (value) => value.kind,
            'kind',
            MediaFailureKind.invalidResponse,
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test(
    'Kling image-to-video sends the two frame URLs and string duration',
    () async {
      const id = 'fal-ai/kling-video/v2.6/pro/image-to-video';
      final provider = ProviderConfig.defaultsFor('fal');
      final folder = await Directory.systemTemp.createTemp('fal-media-fixture');
      addTearDown(() => folder.delete(recursive: true));
      final first = await File('${folder.path}/first.png').writeAsBytes([1]);
      final last = await File('${folder.path}/last.png').writeAsBytes([2]);
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'prompt': 'Grow a forest',
            'duration': '5',
            'start_image_url': 'data:image/png;base64,AQ==',
            'end_image_url': 'data:image/png;base64,Ag==',
            'generate_audio': false,
          });
          return videoJson({'request_id': 'test', 'status': 'COMPLETED'});
        }
        expect(request.url.path, '/fal-ai/kling-video/requests/test');
        return videoJson({
          'video': {'url': 'https://cdn.example.test/video.mp4', 'duration': 5},
        });
      });
      final events = await const FalMediaAdapter(MediaMode.video)
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: id,
              mode: MediaMode.video,
              prompt: 'Grow a forest',
              durationSec: 5,
              parameters: const {'generate_audio': false},
              references: [
                MediaReference(first.path, role: MediaReferenceRole.firstFrame),
                MediaReference(last.path, role: MediaReferenceRole.lastFrame),
              ],
            ),
          )
          .toList();
      expect(
        events.whereType<MediaOutput>().single.results.single.durationMs,
        5000,
      );
    },
  );
}
