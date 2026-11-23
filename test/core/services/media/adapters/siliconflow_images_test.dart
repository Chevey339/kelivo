import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/siliconflow_images.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches documented aspect sizes by site and model', () async {
    const adapter = SiliconFlowImagesAdapter();
    for (final fixture in [
      (
        provider: ProviderConfig.defaultsFor('SiliconFlow'),
        id: 'Kwai-Kolors/Kolors',
        ratio: '3:4',
        size: '960x1280',
      ),
      (
        provider: ProviderConfig.defaultsFor('SiliconFlow'),
        id: 'Qwen/Qwen-Image',
        ratio: '16:9',
        size: '1664x928',
      ),
      (
        provider: ProviderConfig.defaultsFor(
          'SiliconFlow',
        ).copyWith(baseUrl: 'https://api.siliconflow.com/v1'),
        id: 'black-forest-labs/FLUX.2-pro',
        ratio: '16:9',
        size: '1024x576',
      ),
    ]) {
      expect(
        adapter.capabilities(fixture.provider, fixture.id).aspectRatios,
        contains(fixture.ratio),
      );
      final client = MockClient((request) async {
        expect(jsonDecode(request.body)['image_size'], fixture.size);
        return videoJson({
          'images': [
            {'url': 'https://cdn.example.test/result.png'},
          ],
        });
      });
      await adapter
          .generate(
            videoContext(fixture.provider, client),
            MediaRequest(
              modelId: fixture.id,
              mode: MediaMode.image,
              prompt: 'A tree',
              aspectRatio: fixture.ratio,
            ),
          )
          .drain<void>();
    }
  });

  test(
    'Qwen edit maps reference slots and CFG without requesting image_size',
    () async {
      const adapter = SiliconFlowImagesAdapter();
      const id = 'Qwen/Qwen-Image-Edit-2509';
      final provider = ProviderConfig.defaultsFor('SiliconFlow');
      final folder = await Directory.systemTemp.createTemp(
        'siliconflow-fixture',
      );
      addTearDown(() => folder.delete(recursive: true));
      final references = [
        for (var i = 1; i <= 3; i++)
          MediaReference(
            (await File('${folder.path}/$i.png').writeAsBytes([i])).path,
          ),
      ];
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/images/generations');
        expect(jsonDecode(request.body), {
          'model': id,
          'prompt': 'Make it darker',
          'seed': 7,
          'cfg': 4.5,
          'num_inference_steps': 20,
          'image': 'data:image/png;base64,AQ==',
          'image2': 'data:image/png;base64,Ag==',
          'image3': 'data:image/png;base64,Aw==',
        });
        return videoJson({
          'images': [
            {'url': 'https://cdn.example.test/image.png'},
          ],
        });
      });
      final events = await adapter
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'Make it darker',
              references: references,
              parameters: const {
                'seed': 7,
                'num_inference_steps': 20,
                'cfg': 4.5,
              },
            ),
          )
          .toList();
      expect(
        events.whereType<MediaOutput>().single.results.single.url?.path,
        '/image.png',
      );
      expect(adapter.capabilities(provider, id).requiresReference, isTrue);
    },
  );
}
