import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/dashscope_images.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final id in [
    'qwen-image-plus',
    'wan2.6-image',
    'wan2.6-t2i',
    'wan2.5-t2i-preview',
  ]) {
    test('$id uses its native route and returns the result list', () async {
      const adapter = DashScopeImagesAdapter();
      final provider = ProviderConfig.defaultsFor('Aliyun');
      final async = id.startsWith('wan');
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.method == 'GET') {
          expect(request.url.path, '/api/v1/tasks/task-1');
          return videoJson({
            'output': {
              'task_status': 'SUCCEEDED',
              'results': [
                {'url': 'https://cdn.example.test/image1.png'},
                {'url': 'https://cdn.example.test/image2.png'},
              ],
            },
          });
        }
        final path = switch (id) {
          'wan2.6-image' || 'wan2.6-t2i' => 'image-generation/generation',
          'wan2.5-t2i-preview' => 'text2image/image-synthesis',
          _ => 'multimodal-generation/generation',
        };
        expect(request.url.path, '/api/v1/services/aigc/$path');
        expect(request.headers['x-dashscope-async'], async ? 'enable' : null);
        final body = jsonDecode(request.body) as Map;
        expect(body['model'], id);
        expect(body['parameters']['seed'], 42);
        if (id == 'wan2.5-t2i-preview') {
          expect(body['input'], {
            'prompt': 'A garden',
            'negative_prompt': 'Blur',
          });
        } else {
          expect(body['input'], {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'text': 'A garden'},
                ],
              },
            ],
          });
        }
        if (async) {
          return videoJson({
            'output': {'task_id': 'task-1'},
          });
        }
        return videoJson({
          'output': {
            'choices': [
              {
                'message': {
                  'content': [
                    {'image': 'https://cdn.example.test/image.png'},
                  ],
                },
              },
            ],
          },
        });
      });
      final events = await adapter
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'A garden',
              negativePrompt: 'Blur',
              aspectRatio: '16:9',
              count: async ? 2 : 1,
              parameters: const {'seed': 42},
            ),
          )
          .toList();
      expect(calls, async ? 2 : 1);
      expect(
        events.whereType<MediaOutput>().single.results,
        hasLength(async ? 2 : 1),
      );
    });
  }
  test('legacy Wan edit endpoints carry their reference image', () async {
    const adapter = DashScopeImagesAdapter();
    final provider = ProviderConfig.defaultsFor('Aliyun');
    final folder = await Directory.systemTemp.createTemp('wan-edit-fixture');
    addTearDown(() => folder.delete(recursive: true));
    final file = await File(
      '${folder.path}/reference.png',
    ).writeAsBytes([1, 2]);
    for (final id in ['wan2.5-i2i-preview', 'wanx2.1-imageedit']) {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/v1/services/aigc/image2image/image-synthesis',
          );
          expect(request.headers['x-dashscope-async'], 'enable');
          final body = jsonDecode(request.body) as Map;
          expect(
            body['input'],
            id.startsWith('wanx')
                ? {
                    'prompt': 'Rainy garden',
                    'function': 'description_edit',
                    'base_image_url': 'data:image/png;base64,AQI=',
                  }
                : {
                    'prompt': 'Rainy garden',
                    'images': ['data:image/png;base64,AQI='],
                  },
          );
          return videoJson({
            'output': {'task_id': 'job'},
          });
        }
        return videoJson({
          'output': {
            'task_status': 'SUCCEEDED',
            'results': [
              {'url': 'https://cdn.example.test/result.png'},
            ],
          },
        });
      });
      final events = await adapter
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'Rainy garden',
              references: [MediaReference(file.path)],
            ),
          )
          .toList();
      expect(events.whereType<MediaOutput>().single.results, hasLength(1));
    }
  });
}
