import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/media/media_adapter.dart';
import 'package:Kelivo/core/services/media/media_adapter_resolver.dart';
import 'package:Kelivo/core/services/media/media_models.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/media/openrouter_media_catalog.dart';
import 'package:Kelivo/core/services/model_spec/model_list_metadata_cache.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  const base = 'https://tokendance.space/gateway/v1';
  const resolver = MediaAdapterResolver();

  test(
    'H3 submits JSON, polls the same task and downloads without a provider key',
    () async {
      const id = 'minimax-h3';
      final cfg = videoProvider(base, id);
      final choice = resolveMediaModel(cfg, id, MediaMode.video)!;
      expect(choice.capabilities.durations, List.generate(12, (i) => i + 4));
      expect(choice.capabilities.resolutions, ['768p', '480p', '2K']);
      expect(
        resolver
            .capabilities(cfg, MediaMode.video, 'minimax-h3-max')!
            .resolutions,
        isNot(contains('2K')),
      );
      final saved = videoRequest(id);
      final request = saved.withCurrentVideoOptions(choice.capabilities);
      expect(request.resolution, '768p');
      var posts = 0, polls = 0;
      final client = MockClient((r) async {
        expect(r.headers['authorization'], 'Bearer fixture-key');
        if (r.method == 'POST') {
          posts++;
          expect(r.url.path, '/gateway/minimax/v2/video_generation');
          expect(jsonDecode(r.body), {
            'model': id,
            'content': [
              {'type': 'text', 'text': saved.prompt},
            ],
            'resolution': '768P',
            'duration': 8,
            'ratio': '16:9',
          });
          return videoJson({'task_id': 'task/a'});
        }
        expect(
          r.url.toString(),
          'https://tokendance.space/gateway/minimax/v2/query/video_generation/task%2Fa',
        );
        return ++polls == 1
            ? videoJson({
                'task': {'status': 'running'},
              })
            : videoJson({
                'task': {
                  'status': 'succeeded',
                  'content': {'url': 'https://cdn.example/v.mp4'},
                },
              });
      });
      final events = await resolver
          .resolve(cfg, MediaMode.video, modelId: id)!
          .generate(videoContext(cfg, client), request)
          .toList();
      final output = events.whereType<MediaOutput>().single.results.single;
      expect((posts, polls), (1, 2));
      expect(output.url!.host, 'cdn.example');
      expect(output.downloadHeaders, isEmpty);
    },
  );

  test(
    'TokenDance puts both Kling image models in Images and hides workflows needing other input types',
    () {
      for (final id in [
        'kling-image-4.0',
        'kling-image-4.0-long-image',
        'seedream-5.5',
        'qwen-image-2.1-turbo',
      ]) {
        final cfg = videoProvider(base, id);
        expect(
          resolveMediaModel(cfg, id, MediaMode.image),
          isNotNull,
          reason: id,
        );
        expect(resolveMediaModel(cfg, id, MediaMode.video), isNull, reason: id);
      }
      for (final id in [
        'kling-tts',
        'kling-avatar-image2video',
        'kling-effects',
        'happyhorse-1.0-video-edit',
      ]) {
        final cfg = videoProvider(base, id);
        expect(resolveMediaModel(cfg, id, MediaMode.video), isNull, reason: id);
        expect(resolveMediaModel(cfg, id, MediaMode.image), isNull, reason: id);
      }
      final flash = resolver.capabilities(
        videoProvider(base, 'kling-4.0-flash'),
        MediaMode.video,
        'kling-4.0-flash',
      )!;
      expect(flash.durations.last, 20);
      expect(flash.resolutions, ['720p']);
      expect(flash.frameRoles, [MediaReferenceRole.firstFrame]);
    },
  );

  test(
    'catalog protocols route renamed models after refresh and after restoring the cache',
    () async {
      const id = 'movie-alias';
      final cfg = videoProvider(
        base,
        id,
      ).copyWith(id: 'media-protocol-test', models: [id, 'portrait', 'asr']);
      final refresh = await ModelListMetadataCache.instance.startRefresh(cfg);
      await refresh([
        (
          id: id,
          json: {
            'supported_protocols': [
              'kling:text2video-v2',
              'kling:image2video-v2',
            ],
          },
        ),
        (
          id: 'portrait',
          json: {
            'supported_protocols': [
              'ark:image-generations',
              'openai:image-generations',
            ],
          },
        ),
        (
          id: 'asr',
          json: {
            'supported_protocols': ['dashscope:multimodal-generation'],
          },
        ),
      ]);
      expect(ModelSpecResolver.instance.spec(cfg, id).type, ModelType.video);
      expect(resolveMediaModel(cfg, 'portrait', MediaMode.image), isNotNull);
      expect(resolveMediaModel(cfg, 'asr', MediaMode.image), isNull);
      final cache = ModelListMetadataCache();
      await cache.ensureLoaded();
      expect(
        cache.lookup(cfg, id)?.mediaProtocol?.wireName,
        'kling:text2video-v2',
      );
      final client = MockClient((r) async {
        if (r.method == 'POST') {
          expect(r.url.path, '/gateway/kling/v2/text2video');
          expect(jsonDecode(r.body)['model_name'], id);
          return videoJson({
            'data': {'id': 'k'},
          });
        }
        return videoJson({
          'data': [
            {
              'status': 'succeeded',
              'outputs': [
                {'type': 'video', 'url': 'https://cdn.test/video'},
              ],
            },
          ],
        });
      });
      final remote = await resolver
          .resolve(cfg, MediaMode.video, modelId: id)!
          .generate(videoContext(cfg, client), videoRequest(id))
          .last;
      expect(remote, isA<MediaOutput>());
    },
  );

  test(
    'frame and reference payloads match MiniMax, Kling and Wan relay protocols',
    () async {
      final dir = await Directory.systemTemp.createTemp('relay-reference');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/frame.png').writeAsBytes([1, 2, 3]);
      const text = 'move';
      for (final (id, mode, path) in [
        ('minimax-h3', MediaMode.video, '/gateway/minimax/v2/video_generation'),
        ('kling-3.0-turbo', MediaMode.video, '/gateway/kling/v1/image2video'),
        ('kling-3.0-omni', MediaMode.video, '/gateway/kling/v1/omni-video'),
        (
          'kling-image-4.0',
          MediaMode.image,
          '/gateway/kling/v2/image-generation',
        ),
        (
          'kling-image-4.0-long-image',
          MediaMode.image,
          '/gateway/kling/v2/long-image-generation',
        ),
        (
          'wan3.0-video',
          MediaMode.video,
          '/gateway/alibaba/wan3/v1/video-synthesis',
        ),
        (
          'happyhorse-1.1-i2v',
          MediaMode.video,
          '/gateway/alibaba/happyhorse/v1/video-synthesis',
        ),
        ('seedance-2.5', MediaMode.video, '/gateway/ark/v3/generations/tasks'),
        ('seedream-5.5', MediaMode.image, '/gateway/ark/v3/images/generations'),
      ]) {
        final cfg = videoProvider(base, id), image = mode == MediaMode.image;
        final request = MediaRequest(
          modelId: id,
          mode: mode,
          prompt: text,
          references: [
            MediaReference(
              file.path,
              role: image
                  ? MediaReferenceRole.image
                  : MediaReferenceRole.firstFrame,
            ),
          ],
        );
        final client = MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, path, reason: id);
            final body = jsonDecode(r.body);
            if (id.startsWith('kling')) {
              final input = (body['contents'] as List).last;
              expect(input['url'], 'AQID');
              expect(
                input['type'],
                image
                    ? (id.endsWith('-long-image')
                          ? 'style_refer_image'
                          : 'refer_image')
                    : 'first_frame',
              );
              if (id.endsWith('long-image')) {
                expect(body['settings']['skill'], 'webpage');
              }
              return videoJson({
                'data': {'id': 'task'},
              });
            }
            if (id.startsWith('wan') || id.startsWith('happyhorse')) {
              expect(body['input']['media'].single, {
                'type': 'first_frame',
                'url': 'data:image/png;base64,AQID',
              });
              expect(r.headers['x-dashscope-async'], 'enable');
              return videoJson({
                'output': {'task_id': 'task'},
              });
            }
            if (id.startsWith('seedream')) {
              expect(body['image'], 'data:image/png;base64,AQID');
              return videoJson({
                'data': [
                  {'url': 'https://cdn.test/image'},
                ],
              });
            }
            expect(
              body['content'].last['image_url']['url'],
              'data:image/png;base64,AQID',
            );
            if (id.startsWith('minimax')) {
              expect(body, isNot(contains('ratio')));
              return videoJson({'task_id': 'task'});
            }
            return videoJson({'id': 'task'});
          }
          if (id.startsWith('kling')) {
            expect(r.url.path, '$path/task');
            return videoJson({
              'data': [
                {
                  'status': 'succeeded',
                  'outputs': [
                    {
                      'type': image ? 'image' : 'video',
                      'url': 'https://cdn.test/result',
                    },
                  ],
                },
              ],
            });
          }
          if (id.startsWith('wan') || id.startsWith('happyhorse')) {
            expect(
              r.url.path,
              path.replaceFirst('video-synthesis', 'tasks/task'),
            );
            return videoJson({
              'output': {
                'task_status': 'SUCCEEDED',
                'video_url': 'https://cdn.test/result',
              },
            });
          }
          if (id.startsWith('minimax')) {
            return videoJson({
              'task': {
                'status': 'succeeded',
                'content': {'url': 'https://cdn.test/result'},
              },
            });
          }
          expect(r.url.path, '$path/task');
          return videoJson({
            'status': 'succeeded',
            'content': {'video_url': 'https://cdn.test/result'},
          });
        });
        expect(
          await resolver
              .resolve(cfg, mode, modelId: id)!
              .generate(videoContext(cfg, client), request)
              .last,
          isA<MediaOutput>(),
          reason: id,
        );
      }
    },
  );

  test(
    'OpenRouter catalog drives media controls and JSON image edits',
    () async {
      const id = 'example/portrait';
      final cfg = videoProvider('https://openrouter.ai/api/v1', id);
      final catalog = await fetchOpenRouterMediaModels(
        MockClient((r) async {
          expect(r.url.path, '/api/v1/images/models');
          return videoJson({
            'data': [
              {
                'id': id,
                'supported_parameters': {
                  'n': {'type': 'range', 'max': 3},
                  'resolution': {
                    'values': ['1K', '2K'],
                  },
                  'aspect_ratio': {
                    'values': ['1:1'],
                  },
                  'input_references': {'max': 2},
                },
              },
            ],
          });
        }),
        Uri.parse(cfg.baseUrl),
        {},
        MediaMode.image,
      );
      final entry = catalog![id]!;
      final refresh = await ModelListMetadataCache.instance.startRefresh(cfg);
      await refresh([
        (id: id, json: {'openrouter_media': entry.toJson()}),
      ]);
      final choice = resolveMediaModel(cfg, id, MediaMode.image)!;
      expect(choice.capabilities.sizes, ['1K', '2K']);
      expect(choice.capabilities.maxPerRequest, 3);
      expect(choice.capabilities.maxReferences, 2);
      final dir = await Directory.systemTemp.createTemp('openrouter-edit');
      addTearDown(() => dir.delete(recursive: true));
      final ref = await File('${dir.path}/input.png').writeAsBytes([4]);
      final client = MockClient((r) async {
        expect(r.url.path, '/api/v1/images');
        final body = jsonDecode(r.body);
        expect(
          body['input_references'].single['image_url']['url'],
          'data:image/png;base64,BA==',
        );
        expect(body['resolution'], '2K');
        expect(body['n'], 2);
        return videoJson({
          'data': [
            {'b64_json': 'BA=='},
            {'url': 'https://cdn.example/image'},
          ],
        });
      });
      final event =
          await resolver
                  .resolve(cfg, MediaMode.image, modelId: id)!
                  .generate(
                    videoContext(cfg, client),
                    MediaRequest(
                      modelId: id,
                      mode: MediaMode.image,
                      prompt: 'edit',
                      count: 2,
                      parameters: {'size': '2K'},
                      references: [MediaReference(ref.path)],
                    ),
                  )
                  .last
              as MediaOutput;
      expect(event.results.length, 2);
    },
  );

  test(
    'OpenRouter and Sora relays isolate download credentials and handle different result URLs',
    () async {
      const id = 'example/movie';
      for (final (base, link, kind, auth) in [
        (
          'https://openrouter.ai/api/v1',
          'https://openrouter.ai/api/v1/videos/t/content?index=0',
          'unsigned_urls',
          true,
        ),
        (
          'https://openrouter.ai/api/v1',
          'https://cdn.example/signed',
          'urls',
          false,
        ),
        (
          'https://relay.example/v1',
          'https://cdn.example/signed',
          'url',
          false,
        ),
        (
          'https://relay.example/v1',
          'https://cdn.example/signed',
          'metadata',
          false,
        ),
      ]) {
        final cfg = videoProvider(base, id);
        final router = Uri.parse(base).host == 'openrouter.ai';
        final client = MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.toString(), '$base/videos');
            if (router) expect(jsonDecode(r.body), containsPair('duration', 8));
            return videoJson({'id': 't', 'status': 'pending'});
          }
          expect(r.url.toString(), '$base/videos/t');
          return videoJson({
            'status': 'completed',
            kind: kind == 'metadata'
                ? {'url': link}
                : kind == 'url'
                ? link
                : [link],
          });
        });
        final events = await resolver
            .resolve(cfg, MediaMode.video, modelId: id)!
            .generate(videoContext(cfg, client), videoRequest(id))
            .toList();
        final out = events.whereType<MediaOutput>().single.results.single;
        expect(out.url.toString(), link);
        expect(out.downloadHeaders.containsKey('authorization'), auth);
      }
    },
  );

  test('missing routes and upstream failures are terminal', () async {
    expect(
      mediaResponseFailure({}, statusCode: 404).kind,
      MediaFailureKind.unavailable,
    );
    final cfg = videoProvider(base, 'minimax-h3');
    var submits = 0;
    final stream = resolver
        .resolve(cfg, MediaMode.video, modelId: 'minimax-h3')!
        .generate(
          videoContext(
            cfg,
            MockClient((r) async {
              if (r.method == 'POST') {
                submits++;
                return videoJson({'task_id': 't'});
              }
              return videoJson({
                'task': {
                  'status': 'failed',
                  'error': {'code': 'content_policy_violation'},
                },
              });
            }),
          ),
          videoRequest('minimax-h3'),
        );
    await expectLater(
      stream.last,
      throwsA(
        isA<MediaFailure>().having(
          (e) => e.kind,
          'kind',
          MediaFailureKind.rejected,
        ),
      ),
    );
    expect(submits, 1);
  });

  test(
    'malformed supplementary catalogs leave the regular model list usable',
    () async {
      for (final response in ['[]', 'null', '{"data":{}}']) {
        final catalog = await fetchOpenRouterMediaModels(
          MockClient((_) async => http.Response(response, 200)),
          Uri.parse('https://openrouter.ai/api/v1'),
          {},
          MediaMode.image,
        );
        expect(catalog, isNull);
      }
    },
  );

  test(
    'the reference picker and request validation share long image limits',
    () {
      const id = 'kling-image-4.0-long-image';
      final caps = resolver.capabilities(
        videoProvider(base, id),
        MediaMode.image,
        id,
      )!;
      expect(caps.referenceLimits(const {}), (min: 0, max: 2));
      expect(caps.referenceLimits(const {'skill': 'ecommerce'}), (
        min: 1,
        max: 3,
      ));
      final tts = videoProvider(base, 'kling-tts');
      expect(
        ModelSpecResolver.instance.spec(tts, 'kling-tts').type,
        ModelType.other,
      );
    },
  );

  test(
    'refreshing supplementary OpenRouter catalogs preserves chat models, handles partial outages and filters unsupported inputs',
    () async {
      const omni = 'google/gemini-omni-test';
      const edit = 'krea/k3-edit';
      const vector = 'recraft/only-svg';
      final cfg = videoProvider(
        'https://openrouter.ai/api/v1',
        omni,
      ).copyWith(id: 'router-catalog', models: [omni, edit, vector]);
      final cache = ModelListMetadataCache.instance;
      final rows = <String, Map>{
        omni: {
          'id': omni,
          'architecture': {
            'input_modalities': ['text', 'image', 'video'],
            'output_modalities': ['text', 'video'],
          },
        },
      };
      var videoStatus = 200;
      final client = MockClient((r) async {
        if (r.url.path.endsWith('videos/models')) {
          return videoJson({
            'data': [
              {
                'id': omni,
                'supported_resolutions': ['720p'],
                'supported_durations': [-1, 3, 4, 5],
                'supported_frame_images': ['first_frame'],
              },
            ],
          }, videoStatus);
        }
        return videoJson({
          'data': [
            {
              'id': edit,
              'supported_parameters': {
                'input_references': {'min': 1, 'max': 8},
              },
            },
            {
              'id': vector,
              'supported_parameters': {
                'output_format': {
                  'values': ['svg'],
                },
              },
            },
          ],
        });
      });
      Future<void> refresh() async {
        await mergeOpenRouterMediaCatalogs(
          client,
          Uri.parse(cfg.baseUrl),
          {},
          rows,
          cached: (mode) => cache.openRouterCatalog(cfg, mode),
        );
        await (await cache.startRefresh(cfg))(
          rows.entries.map((r) => (id: r.key, json: r.value)),
        );
      }

      await refresh();
      expect(ModelSpecResolver.instance.spec(cfg, omni).type, ModelType.chat);
      expect(
        ModelSpecResolver.instance.spec(cfg, omni).input,
        contains(Modality.video),
      );
      expect(
        resolveMediaModel(cfg, omni, MediaMode.video)!.capabilities.durations,
        [3, 4, 5, -1],
      );
      expect(
        resolveMediaModel(
          cfg,
          edit,
          MediaMode.image,
        )!.capabilities.referenceLimits({}),
        (min: 1, max: 8),
      );
      expect(resolveMediaModel(cfg, vector, MediaMode.image), isNull);
      videoStatus = 503;
      rows.clear();
      await refresh();
      expect(rows.containsKey(omni), isTrue);
      expect(
        cache.openRouterCatalog(cfg, MediaMode.video).keys,
        contains(omni),
      );
    },
  );
}
