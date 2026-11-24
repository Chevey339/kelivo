import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/utils/provider_url.dart';
import 'package:Kelivo/core/services/media/media_adapter_resolver.dart';
import 'package:Kelivo/core/services/media/media_models.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/media/tokendance_media_protocol.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'video_fixture.dart';
import 'package:Kelivo/core/services/media/media_model_overrides.dart';

const resolver = MediaAdapterResolver();

Future<List<MediaEvent>> generate(
  ProviderConfig cfg,
  MediaRequest req,
  Future<http.Response> Function(http.Request) handler,
) {
  final adapter = resolver.resolve(cfg, req.mode, modelId: req.modelId)!;
  return adapter.generate(videoContext(cfg, MockClient(handler)), req).toList();
}

MediaResult output(List<MediaEvent> events) =>
    events.whereType<MediaOutput>().single.results.single;

MediaRequest imageRequest(String id, [List<MediaReference> refs = const []]) =>
    MediaRequest(
      modelId: id,
      mode: MediaMode.image,
      prompt: 'Shift the light to the left',
      references: refs,
    );

void main() {
  test(
    'overrides honor the chosen transport while Ark aliases can request an encodable last frame',
    () {
      MediaCapabilities configured(MediaApiProtocol protocol, MediaMode mode) {
        const id = 'private-media';
        final cfg = videoProvider('https://relay.test/v1', id).copyWith(
          modelOverrides: {
            id: {'mediaGeneration': {}},
          },
        );
        final adapter = resolver.resolve(
          cfg,
          mode,
          modelId: id,
          protocol: protocol,
        )!;
        return const MediaModelOverrides(
          firstFrame: true,
          lastFrame: true,
          maxPerRequest: 8,
          formats: ['webp'],
          aspectRatios: ['3:2'],
        ).apply(adapter.capabilities(cfg, id), video: mode == MediaMode.video);
      }

      expect(
        configured(MediaApiProtocol.arkVideo, MediaMode.video).frameRoles,
        contains(MediaReferenceRole.lastFrame),
      );
      expect(
        configured(MediaApiProtocol.openAiVideo, MediaMode.video).frameRoles,
        isNot(contains(MediaReferenceRole.lastFrame)),
      );
      final chat = configured(MediaApiProtocol.chatImage, MediaMode.image);
      expect(chat.maxPerRequest, 1);
      expect(chat.formats, isEmpty);
      expect(chat.aspectRatios, ['auto']);
      const wan = 'wan2.7-r2v-2026-06-12';
      expect(
        resolver.resolve(
          videoProvider(
            'https://dashscope.aliyuncs.com/compatible-mode/v1',
            wan,
          ),
          MediaMode.video,
          modelId: wan,
        ),
        isNull,
      );
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  late File input;
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp(
      'kelivo-creation-protocol',
    );
    input = await File('${dir.path}/ref.png').writeAsBytes([1, 2, 3]);
    addTearDown(() => dir.delete(recursive: true));
  });

  test(
    'Google and chat gateways expose Gemini outputs in chat and Creation; vision-only stays in chat',
    () async {
      const ids = [
        'gemini-2.5-flash-image',
        'google/gemini-3.1-flash-image-preview',
        'gemini-nano-banana-2.1',
      ];
      for (final id in ids) {
        for (final cfg in [
          ProviderConfig.defaultsFor(
            'Gemini',
          ).copyWith(enabled: true, models: [id]),
          videoProvider('https://relay.example/v1', id),
          videoProvider('https://tokendance.space/gateway/v1', id),
        ]) {
          final choice = resolveMediaModel(cfg, id, MediaMode.image);
          expect(
            choice?.spec.type,
            ModelType.chat,
            reason: '${cfg.baseUrl} $id',
          );
          expect(choice?.spec.output, contains(Modality.image));
          expect(resolveMediaModel(cfg, id, MediaMode.video), isNull);
        }
      }
      final vision = videoProvider(
        'https://relay.example/v1',
        'gemini-3-flash',
      );
      expect(
        resolveMediaModel(vision, 'gemini-3-flash', MediaMode.image),
        isNull,
      );
      const id = 'gemini-2.5-flash-image';
      final disabled = vision.copyWith(
        models: [id],
        modelOverrides: {
          id: {
            'output': ['text'],
          },
        },
      );
      expect(resolveMediaModel(disabled, id, MediaMode.image), isNull);
      expect(
        TokenDanceMediaProtocol.advertised(id, [
          'openai:chat-completions',
          'gemini:generate-content',
        ]),
        TokenDanceMediaProtocol.geminiImage,
      );
      expect(
        TokenDanceMediaProtocol.advertised('gemini-3-flash', [
          'gemini:generate-content',
        ]),
        TokenDanceMediaProtocol.nonMedia,
      );
    },
  );

  test(
    'compatible image chat honors the configured path, reference and different response shapes',
    () async {
      const id = 'google/gemini-3.1-flash-image';
      final cfg = videoProvider(
        'https://relay.example/prefix/v1',
        id,
      ).copyWith(chatPath: '/chat/custom');
      final events = await generate(
        cfg,
        imageRequest(id, [MediaReference(input.path)]),
        (req) async {
          expect(req.url.path, '/prefix/v1/chat/custom');
          final body = jsonDecode(req.body);
          expect(body['model'], id);
          expect(
            body['messages'][0]['content'][1]['image_url']['url'],
            'data:image/png;base64,AQID',
          );
          return videoJson({
            'choices': [
              {
                'message': {
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:image/png;base64,AQID'},
                    },
                    {
                      'type': 'text',
                      'text': '![result](https://cdn.example/extra.webp)',
                    },
                  ],
                  'images': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'https://cdn.example/extra.webp'},
                    },
                  ],
                },
              },
            ],
          });
        },
      );
      final images = events.whereType<MediaOutput>().single.results;
      expect(images, hasLength(2));
      expect(images.first.base64, 'AQID');
      expect(images.last.mime, 'image/webp');
      expect(images.last.downloadHeaders, isEmpty);
    },
  );

  test(
    'TokenDance Gemini uses its native namespace and only returns model image parts',
    () async {
      const id = 'gemini-nano-banana-2.1';
      final cfg = videoProvider('https://tokendance.space/gateway/v1', id);
      final result = output(
        await generate(cfg, imageRequest(id, [MediaReference(input.path)]), (
          req,
        ) async {
          expect(req.url.path, '/gateway/v1beta/models/$id:generateContent');
          expect(req.headers['x-goog-api-key'], 'fixture-key');
          final body = jsonDecode(req.body);
          expect(body['contents'][0]['parts'][1]['inlineData']['data'], 'AQID');
          return videoJson({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'thought': true,
                      'fileData': {
                        'mimeType': 'image/jpeg',
                        'fileUri': 'https://cdn.example/thought.jpg',
                      },
                    },
                    {
                      'file_data': {
                        'mime_type': 'image/png',
                        'file_uri': 'https://cdn.example/final.png',
                      },
                    },
                  ],
                },
              },
            ],
          });
        }),
      );
      expect(result.url?.path, '/final.png');
      expect(result.downloadHeaders, isEmpty);
    },
  );

  test(
    'BytePlus accepts dated endpoint aliases and native SeedEdit inputs; Wan3 supports official durations',
    () async {
      const id = 'seededit-3-0-i2i-250628';
      final cfg = ProviderConfig.defaultsFor('BytePlus').copyWith(
        enabled: true,
        models: [id],
        modelOverrides: {
          id: {'apiModelId': 'ep-my-endpoint'},
        },
      );
      expect(
        resolveMediaModel(
          cfg,
          id,
          MediaMode.image,
        )?.capabilities.requiresReference,
        true,
      );
      await generate(cfg, imageRequest(id, [MediaReference(input.path)]), (
        req,
      ) async {
        expect(req.url.path, '/api/v3/images/generations');
        expect(jsonDecode(req.body), containsPair('model', 'ep-my-endpoint'));
        expect(jsonDecode(req.body), containsPair('size', 'adaptive'));
        expect(jsonDecode(req.body)['image'], 'data:image/png;base64,AQID');
        return videoJson({
          'data': [
            {'url': 'https://cdn.example/out.png'},
          ],
        });
      });
      for (final role in ['t2v', 'i2v']) {
        final name = 'doubao-seedance-1-0-lite-$role-250428';
        final caps = resolveMediaModel(
          cfg.copyWith(models: [name]),
          name,
          MediaMode.video,
        )!.capabilities;
        expect(caps.requiresFirstFrame, role == 'i2v');
        expect(caps.maxReferences, role == 'i2v' ? 2 : 0);
      }
      final wan = videoProvider(
        'https://my-workspace.maas.aliyuncs.com/compatible-mode/v1',
        'wan3.0-video',
      );
      expect(
        resolveMediaModel(
          wan,
          'wan3.0-video',
          MediaMode.video,
        )!.capabilities.durations,
        containsAll([2, 30, -1]),
      );
    },
  );

  test(
    'ModelScope submits multiple edit inputs once and polls the image task',
    () async {
      const id = 'Qwen/Qwen-Image-Edit-2509';
      final cfg = ProviderConfig.defaultsFor(
        'ModelScope',
      ).copyWith(enabled: true);
      final ref = MediaReference(input.path);
      expect(
        resolveMediaModel(cfg, id, MediaMode.image)!.capabilities.maxReferences,
        3,
      );
      final paths = <String>[];
      final image = output(
        await generate(cfg, imageRequest(id, [ref, ref]), (req) async {
          paths.add(req.url.path);
          if (req.method == 'POST') {
            expect(req.headers['x-modelscope-async-mode'], 'true');
            expect(jsonDecode(req.body)['image_url'], [
              'data:image/png;base64,AQID',
              'data:image/png;base64,AQID',
            ]);
            return videoJson({'task_id': 'job-1'});
          }
          expect(req.headers['x-modelscope-task-type'], 'image_generation');
          return videoJson(
            paths.length == 2
                ? {'task_status': 'RUNNING'}
                : {
                    'task_status': 'SUCCEED',
                    'output_images': ['https://cdn.example/art.png'],
                  },
          );
        }),
      );
      expect(paths, [
        '/v1/images/generations',
        '/v1/tasks/job-1',
        '/v1/tasks/job-1',
      ]);
      expect(image.url?.path, '/art.png');
      expect(image.downloadHeaders, isEmpty);
    },
  );

  test(
    'New API override submits JSON video with frame and consumes the documented success envelope',
    () async {
      const id = 'custom-video';
      final cfg = videoProvider('https://relay.example/proxy/v1', id).copyWith(
        modelOverrides: {
          id: {
            'type': 'video',
            'media': {'protocol': 'newApiVideo'},
          },
        },
      );
      expect(resolveMediaModel(cfg, id, MediaMode.video), isNotNull);
      var creates = 0;
      final result = output(
        await generate(
          cfg,
          videoRequest(
            id,
            seconds: 5,
            frames: [
              MediaReference(input.path, role: MediaReferenceRole.firstFrame),
            ],
          ),
          (req) async {
            if (req.method == 'POST') {
              creates++;
              expect(req.url.path, '/proxy/v1/video/generations');
              final body = jsonDecode(req.body);
              expect(body['image'], 'data:image/png;base64,AQID');
              expect([body['width'], body['height']], [1280, 720]);
              return videoJson({'task_id': 'job', 'status': 'queued'});
            }
            expect(req.url.path, '/proxy/v1/video/generations/job');
            return videoJson({
              'status': 'completed',
              'url': 'https://cdn.example/out.mp4',
              'metadata': {'duration': 5},
              'error': {'code': 0},
            });
          },
        ),
      );
      expect(creates, 1);
      expect(result.durationMs, 5000);
      expect(result.downloadHeaders, isEmpty);
    },
  );

  test(
    'Gemini Omni uses Interactions, filters out inputs and thoughts, and limits first/last interpolation',
    () async {
      const id = 'gemini-omni-1.2-flash';
      final cfg = ProviderConfig.defaultsFor(
        'Gemini',
      ).copyWith(enabled: true, models: [id]);
      final caps = resolveMediaModel(cfg, id, MediaMode.video)!.capabilities;
      expect(caps.durationsFor(hasLastFrame: false).last, 15);
      expect(caps.durationsFor(hasLastFrame: true).last, 10);
      final events = await generate(
        cfg,
        videoRequest(
          id,
          frames: [
            MediaReference(input.path, role: MediaReferenceRole.firstFrame),
            MediaReference(input.path, role: MediaReferenceRole.lastFrame),
          ],
        ),
        (req) async {
          expect(req.headers['api-revision'], '2026-05-20');
          if (req.method == 'POST') {
            expect(req.url.path, '/v1beta/interactions');
            final body = jsonDecode(req.body);
            expect(body['background'], true);
            expect(body['response_format']['duration'], '8s');
            expect((body['input'] as List).map((p) => p['type']), [
              'image',
              'image',
              'text',
            ]);
            return videoJson({'id': 'int-1', 'status': 'in_progress'});
          }
          expect(req.url.path, '/v1beta/interactions/int-1');
          final content = [
            {'type': 'video', 'data': 'AAEC'},
          ];
          return videoJson({
            'status': 'completed',
            'steps': [
              {'type': 'user_input', 'content': content},
              {'type': 'thought', 'content': content},
              {
                'type': 'model_output',
                'content': [
                  {'type': 'video', 'data': 'AQID'},
                ],
              },
            ],
          });
        },
      );
      expect(
        events.whereType<MediaTaskAccepted>().single.cancelUrl?.path,
        '/v1beta/interactions/int-1/cancel',
      );
      expect(output(events).base64, 'AQID');
    },
  );

  test(
    'Replicate discovers native image/video models, uploads large files then polls the original prediction',
    () async {
      const id = 'bytedance/seedance-1-pro';
      final cfg = ProviderConfig.defaultsFor(
        'Replicate',
      ).copyWith(enabled: true);
      expect(resolveMediaModel(cfg, id, MediaMode.video), isNotNull);
      expect(
        ModelSpecResolver.instance.spec(cfg, 'google/nano-banana').type,
        ModelType.image,
      );
      await input.writeAsBytes(List.filled(300000, 1));
      final paths = <String>[];
      final events = await generate(
        cfg,
        videoRequest(
          id,
          seconds: 5,
          frames: [
            MediaReference(input.path, role: MediaReferenceRole.firstFrame),
          ],
        ),
        (req) async {
          paths.add(req.url.path);
          if (req.url.path == '/v1/files') {
            expect(
              req.headers['content-type'],
              startsWith('multipart/form-data'),
            );
            expect(req.bodyBytes.length, greaterThan(300000));
            return videoJson({
              'urls': {'get': 'https://api.replicate.com/v1/files/f1'},
            });
          }
          if (req.method == 'POST') {
            final body = jsonDecode(req.body);
            expect(
              body['input']['image'],
              'https://api.replicate.com/v1/files/f1',
            );
            return videoJson({'id': 'p1', 'status': 'starting'});
          }
          return videoJson({
            'status': 'succeeded',
            'output': 'https://replicate.delivery/video.mp4',
          });
        },
      );
      expect(paths, [
        '/v1/files',
        '/v1/models/bytedance/seedance-1-pro/predictions',
        '/v1/predictions/p1',
      ]);
      expect(events.whereType<MediaTaskAccepted>().single.cancelMethod, 'POST');
      expect(output(events).downloadHeaders, isEmpty);
      final flux = output(
        await generate(cfg, imageRequest('black-forest-labs/flux-schnell'), (
          req,
        ) async {
          expect(jsonDecode(req.body)['input']['num_outputs'], 1);
          return videoJson({
            'id': 'p2',
            'status': 'succeeded',
            'output': ['https://replicate.delivery/frame.webp'],
          });
        }),
      );
      expect(flux.mime, 'image/webp');
    },
  );

  test(
    'New API unwraps task DTOs and retrieves private results on the original gateway',
    () async {
      const id = 'cogvideox-3';
      final cfg = videoProvider('https://relay.example/v1', id).copyWith(
        modelOverrides: {
          id: {
            'media': {'protocol': 'newApiVideo'},
          },
        },
      );
      var requests = 0;
      final video = output(
        await generate(cfg, videoRequest(id, seconds: 5), (req) async {
          requests++;
          return switch (requests) {
            1 => videoJson({
              'code': 'success',
              'data': {'task_id': 'p'},
            }),
            2 => videoJson({
              'code': 'success',
              'data': {'task_id': 'p', 'status': 'processing'},
            }),
            3 => videoJson({
              'code': 'success',
              'data': {'task_id': 'p', 'status': 'IN_PROGRESS'},
            }),
            _ => videoJson({
              'code': 'success',
              'data': {
                'task_id': 'p',
                'status': 'SUCCESS',
                'result_url': '/v1/videos/p/content',
              },
            }),
          };
        }),
      );
      expect(requests, 4);
      expect(
        video.url?.toString(),
        'https://relay.example/v1/videos/p/content',
      );
      expect(video.downloadHeaders['authorization'], 'Bearer fixture-key');
    },
  );

  test(
    'official Google resource names and Vertex global Interactions use the right routes',
    () async {
      const id = 'google/gemini-3.1-flash-image';
      final google = ProviderConfig.defaultsFor(
        'Gemini',
      ).copyWith(enabled: true, models: [id]);
      await generate(google, imageRequest(id), (req) async {
        expect(
          req.url.path,
          '/v1beta/models/gemini-3.1-flash-image:generateContent',
        );
        return videoJson({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'inlineData': {'data': 'AAEC', 'mimeType': 'image/png'},
                  },
                ],
              },
            },
          ],
        });
      });
      const video = 'gemini-omni-1.2-flash';
      final vertex = google.copyWith(
        vertexAI: true,
        projectId: 'proj',
        location: 'global',
        models: [video],
      );
      expect(resolveMediaModel(vertex, video, MediaMode.video), isNotNull);
      expect(
        resolveMediaModel(
          vertex.copyWith(location: 'europe-west1'),
          video,
          MediaMode.video,
        ),
        isNull,
      );
      await generate(vertex, videoRequest(video), (req) async {
        expect(
          req.url.toString(),
          'https://aiplatform.googleapis.com/v1/projects/proj/locations/global/interactions',
        );
        expect(req.headers['authorization'], 'Bearer fixture-key');
        expect(req.headers.containsKey('x-goog-api-key'), false);
        return videoJson({
          'id': 'one',
          'status': 'completed',
          'steps': [
            {
              'type': 'model_output',
              'content': [
                {'type': 'video', 'data': 'AQID'},
              ],
            },
          ],
        });
      });
    },
  );

  test(
    'Z.AI GLM Image sends its native sizes; CogVideoX uses its async result and frame fields',
    () async {
      const image = 'glm-image', video = 'cogvideox-3';
      final cfg = videoProvider(
        'https://api.z.ai/api/paas/v4',
        video,
      ).copyWith(models: [image, video]);
      expect(
        resolveMediaModel(
          cfg,
          image,
          MediaMode.image,
        )?.capabilities.maxReferences,
        0,
      );
      expect(
        resolveMediaModel(
          cfg,
          video,
          MediaMode.video,
        )?.capabilities.maxReferences,
        2,
      );
      await generate(
        cfg,
        const MediaRequest(
          mode: MediaMode.image,
          modelId: image,
          prompt: 'A lake',
          aspectRatio: '3:2',
        ),
        (req) async {
          expect(req.url.path, '/api/paas/v4/images/generations');
          expect(jsonDecode(req.body), {
            'model': image,
            'prompt': 'A lake',
            'size': '1568x1056',
          });
          return videoJson({
            'data': [
              {'url': 'https://example.test/img.jpg'},
            ],
          });
        },
      );
      const gif = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
      await input.writeAsBytes(base64Decode(gif));
      final result = output(
        await generate(
          cfg,
          videoRequest(
            video,
            seconds: 5,
            frames: [
              MediaReference(input.path, role: MediaReferenceRole.firstFrame),
              MediaReference(input.path, role: MediaReferenceRole.lastFrame),
            ],
          ),
          (req) async {
            if (req.method == 'POST') {
              expect(req.url.path, '/api/paas/v4/videos/generations');
              final frames = jsonDecode(req.body)['image_url'] as List;
              expect(frames, hasLength(2));
              expect(
                frames,
                everyElement(startsWith('data:image/jpeg;base64,')),
              );
              expect(jsonDecode(req.body)['quality'], 'speed');
              return videoJson({'id': 'task', 'task_status': 'SUCCESS'});
            }
            expect(req.url.path, '/api/paas/v4/async-result/task');
            return videoJson({
              'task_status': 'SUCCESS',
              'video_result': [
                {
                  'url': 'https://example.test/vid.mp4',
                  'cover_image_url': 'https://example.test/cover.jpg',
                },
              ],
            });
          },
        ),
      );
      expect(result.previewUrl?.path, '/cover.jpg');
    },
  );

  test(
    'ModelScope switches reference shapes and polls its dedicated video task',
    () async {
      final cfg = ProviderConfig.defaultsFor(
        'ModelScope',
      ).copyWith(enabled: true);
      const multi = 'Qwen/Qwen-Image-Edit-2509',
          single = 'Qwen/Qwen-Image-Edit',
          clip = 'MiniMax/MiniMax-H3';
      for (final name in [multi, single]) {
        await generate(cfg, imageRequest(name, [MediaReference(input.path)]), (
          r,
        ) async {
          if (r.method == 'POST') {
            final ref = jsonDecode(r.body)['image_url'];
            expect(
              ref,
              name == multi
                  ? ['data:image/png;base64,AQID']
                  : 'data:image/png;base64,AQID',
            );
            return videoJson({'task_id': 'image'});
          }
          return videoJson({
            'task_status': 'SUCCEED',
            'output_images': ['https://cdn.test/art.png'],
          });
        });
      }
      expect(
        resolveMediaModel(
          cfg,
          'Qwen/Qwen-Image-2.1',
          MediaMode.image,
        )!.capabilities.maxReferences,
        10,
      );
      expect(
        resolveMediaModel(cfg, clip, MediaMode.video)!.capabilities.durations,
        [3, 5, 10],
      );
      final video = output(
        await generate(
          cfg,
          MediaRequest(
            mode: MediaMode.video,
            modelId: clip,
            prompt: 'Wide shot',
            aspectRatio: '3:5',
            durationSec: 5,
            references: [
              MediaReference(input.path, role: MediaReferenceRole.firstFrame),
            ],
          ),
          (r) async {
            if (r.method == 'POST') {
              expect(r.url.path, '/v1/videos/generations');
              expect(jsonDecode(r.body)['media'], [
                {'type': 'image', 'url': 'data:image/png;base64,AQID'},
              ]);
              expect(jsonDecode(r.body)['size'], '768x1280');
              return videoJson({'task_id': 'v'});
            }
            expect(r.headers['x-modelscope-task-type'], 'video_generation');
            return videoJson({
              'task_status': 'SUCCEED',
              'outputs': {'url': 'https://cdn.test/clip.mp4'},
            });
          },
        ),
      );
      expect(video.url?.path, '/clip.mp4');
    },
  );

  test(
    'Nano Banana chat preserves thinking and native URLs while custom gateways keep the model namespace',
    () {
      const id = 'google/gemini-nano-banana-2.1';
      final cfg = ProviderConfig.defaultsFor(
        'Gemini',
      ).copyWith(enabled: true, models: [id]);
      final spec = resolveMediaModel(cfg, id, MediaMode.image)!.spec;
      expect(spec.type, ModelType.chat);
      expect(
        spec.input,
        containsAll([Modality.image, Modality.video, Modality.pdf]),
      );
      expect(spec.reasoning.levels, contains(ReasoningLevel.medium));
      expect(spec.reasoning.defaultLevel, ReasoningLevel.medium);
      expect(
        resolveRequestUrl(cfg, modelId: id),
        endsWith('/models/gemini-nano-banana-2.1:streamGenerateContent'),
      );
      expect(
        resolveRequestUrl(
          cfg.copyWith(baseUrl: 'https://relay.test/v1beta'),
          modelId: id,
          stream: false,
        ),
        endsWith('/models/google/gemini-nano-banana-2.1:generateContent'),
      );
      final openRouter = videoProvider('https://openrouter.ai/api/v1', id);
      expect(
        resolveMediaModel(
          openRouter,
          id,
          MediaMode.image,
        )!.capabilities.maxReferences,
        14,
      );
    },
  );

  test('rejected creation never tries a second paid route', () async {
    const id = 'gemini-2.5-flash-image';
    final cfg = videoProvider('https://relay.example/v1', id);
    var posts = 0;
    await expectLater(
      generate(cfg, imageRequest(id), (req) async {
        posts++;
        return videoJson({
          'error': {'code': 'unsupported_model'},
        }, 404);
      }),
      throwsA(
        isA<MediaFailure>().having(
          (e) => e.kind,
          'kind',
          MediaFailureKind.unavailable,
        ),
      ),
    );
    expect(posts, 1);
  });
}
