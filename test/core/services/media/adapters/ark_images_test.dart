import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/ark_images.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Seedream Lite keeps 3K and 4K aspect sizes within the API pixel range',
    () async {
      const id = 'doubao-seedream-5-0-lite';
      final provider = ProviderConfig.defaultsFor('ByteDance');
      for (final size in ['3K', '4K']) {
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          final sides = (body['size'] as String)
              .split('x')
              .map(int.parse)
              .toList();
          final area = sides.first * sides.last;
          expect(area, lessThanOrEqualTo(4096 * 4096));
          expect(area, greaterThanOrEqualTo(size == '3K' ? 9000000 : 16000000));
          expect(sides.first / sides.last, closeTo(1.5, 0.02));
          return videoJson({
            'data': [
              {'url': 'https://cdn.example.test/1.png'},
            ],
          });
        });
        await const ArkImagesAdapter()
            .generate(
              videoContext(provider, client),
              MediaRequest(
                modelId: id,
                mode: MediaMode.image,
                prompt: 'A forest',
                aspectRatio: '3:2',
                parameters: {'size': size},
              ),
            )
            .drain<void>();
      }
    },
  );

  test('Seedream uses its native group and reference fields', () async {
    const adapter = ArkImagesAdapter();
    const id = 'doubao-seedream-4-5-251128';
    final provider = ProviderConfig.defaultsFor('ByteDance');
    final directory = await Directory.systemTemp.createTemp('seedream-fixture');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/reference.png',
    ).writeAsBytes([1, 2]);
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v3/images/generations');
      expect(jsonDecode(request.body), {
        'model': id,
        'prompt': 'An orchid',
        'size': '2K',
        'image': 'data:image/png;base64,AQI=',
        'sequential_image_generation': 'auto',
        'sequential_image_generation_options': {'max_images': 2},
        'watermark': false,
        'response_format': 'url',
      });
      return videoJson({
        'data': [
          {'url': 'https://cdn.example.test/1.png'},
          {'url': 'https://cdn.example.test/2.png'},
        ],
      });
    });
    final events = await adapter
        .generate(
          videoContext(provider, client),
          MediaRequest(
            modelId: id,
            mode: MediaMode.image,
            prompt: 'An orchid',
            count: 2,
            parameters: const {'size': '2K', 'watermark': false},
            references: [MediaReference(file.path)],
          ),
        )
        .toList();
    expect(events.whereType<MediaOutput>().single.results, hasLength(2));
    expect(adapter.capabilities(provider, id).maxCombinedInputsAndOutputs, 15);
  });

  test('Seedream 5.5 requests PNG for transparency', () async {
    const id = 'doubao-seedream-5-5-261028';
    final provider = ProviderConfig.defaultsFor('ByteDance');
    final client = MockClient((request) async {
      final payload = jsonDecode(request.body) as Map;
      expect(payload['background'], 'transparent');
      expect(payload['output_format'], 'png');
      expect(payload, isNot(contains('sequential_image_generation')));
      return videoJson({
        'data': [
          {'url': 'https://cdn.example.test/1.png'},
        ],
      });
    });
    final events = await const ArkImagesAdapter()
        .generate(
          videoContext(provider, client),
          const MediaRequest(
            modelId: id,
            mode: MediaMode.image,
            prompt: 'An orchid',
            parameters: {'background': 'transparent'},
          ),
        )
        .toList();
    expect(
      events.whereType<MediaOutput>().single.results.single.mime,
      'image/png',
    );
  });
}
