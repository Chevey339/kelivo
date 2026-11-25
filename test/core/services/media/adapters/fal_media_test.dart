import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/fal_media.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/media/fal_model_discovery.dart';
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
    'fal starts disabled and supports manual models alongside its initial catalog',
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
      expect(trimmed.models, ['personal/image']);
      expect(trimmed.isModelEnabled(id), isFalse);
      final resolver = ModelSpecResolver.instance;
      expect(resolver.spec(trimmed, id).displayName, 'FLUX.2 Pro');
      expect(resolver.spec(trimmed, id).type, ModelType.image);
      expect(
        resolver.spec(trimmed, 'minimax/h3-max/text-to-video').type,
        ModelType.video,
      );
      expect(resolver.spec(trimmed, 'personal/image').type, ModelType.image);
    },
  );

  test(
    'discovery keeps credentials on the official catalog and follows each cursor once',
    () async {
      final calls = <Uri>[];
      final client = MockClient((request) async {
        calls.add(request.url);
        expect(request.headers['authorization'], 'Key fixture');
        final page = calls.length;
        return videoJson({
          'models': [
            {
              'endpoint_id': 'studio/model-$page',
              'metadata': {
                'display_name': 'Model $page',
                'category': page == 1 ? 'text-to-image' : 'text-to-video',
                'status': 'active',
              },
            },
          ],
          'has_more': true,
          'next_cursor': 'same',
        });
      });
      final official = ProviderConfig.defaultsFor(
        'fal',
      ).copyWith(apiKey: 'fixture');
      final list = await FalModelDiscovery.forProvider(
        client,
        official,
      ).listModels();
      expect(calls.map((uri) => uri.host), everyElement('api.fal.ai'));
      expect(calls.last.queryParameters['cursor'], 'same');
      expect(list.map((m) => m.type), [ModelType.image, ModelType.video]);
      final proxy = official.copyWith(baseUrl: 'https://my-relay.example');
      expect(FalModelDiscovery.forProvider(client, proxy).apiKey, isEmpty);
      client.close();
    },
  );

  test(
    'a discovered editing endpoint submits its declared fields and accepts a single output image',
    () async {
      const id = 'studio/new-editor';
      final provider = ProviderConfig.defaultsFor('fal').copyWith(
        models: [id],
        modelOverrides: {
          id: {
            'falEndpoint': {
              'id': id,
              'category': 'image-to-image',
              'name': 'Studio editor',
              'fields': {
                'input_image_url': {'required': true},
                'resolution': {
                  'choices': ['1K', '2K'],
                },
                'aspect_ratio': {
                  'choices': ['auto', '4:3'],
                },
                'output_format': {
                  'choices': ['jpeg', 'png'],
                },
              },
            },
          },
        },
      );
      final folder = await Directory.systemTemp.createTemp('fal-catalog-edit');
      addTearDown(() => folder.delete(recursive: true));
      final ref = await File('${folder.path}/ref.png').writeAsBytes([1]);
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/$id');
          expect(jsonDecode(request.body), {
            'prompt': 'Ink drawing',
            'resolution': '2K',
            'aspect_ratio': '4:3',
            'input_image_url': 'data:image/png;base64,AQ==',
            'output_format': 'png',
          });
          return videoJson({'request_id': 'one', 'status': 'COMPLETED'});
        }
        return videoJson({
          'image': {'url': 'https://cdn.example.test/ink.png'},
        });
      });
      final events = await const FalMediaAdapter(MediaMode.image)
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'Ink drawing',
              aspectRatio: '4:3',
              references: [MediaReference(ref.path)],
              parameters: const {'size': '2K', 'format': 'png'},
            ),
          )
          .toList();
      expect(
        events.whereType<MediaOutput>().single.results.single.url!.path,
        '/ink.png',
      );
      client.close();
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
