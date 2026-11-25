import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/xai_media.dart';
import 'package:Kelivo/core/services/media/media_adapter.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  const model = 'grok-imagine-image';
  const adapter = XaiImageAdapter();
  test(
    'xAI 2.0 sends each selected source to the multi-image editing endpoint in order',
    () async {
      const id = 'grok-imagine-image-2.0';
      final provider = videoProvider('https://api.x.ai/v1', id);
      final folder = await Directory.systemTemp.createTemp('kelivo-xai-edit');
      addTearDown(() => folder.delete(recursive: true));
      final inputs = [
        for (final value in ['first', 'second'])
          MediaReference(
            (await File('${folder.path}/$value.png').writeAsString(value)).path,
          ),
      ];
      expect(adapter.capabilities(provider, id).maxReferences, 5);
      final client = MockClient((r) async {
        expect(r.url.path, '/v1/images/edits');
        final data = jsonDecode(r.body) as Map;
        expect(data.containsKey('image'), isFalse);
        expect(data['images'], [
          for (final value in ['first', 'second'])
            {
              'type': 'image_url',
              'url':
                  'data:image/png;base64,${base64Encode(utf8.encode(value))}',
            },
        ]);
        return videoJson({
          'data': [
            {'url': 'https://result.test/result.jpg'},
          ],
        });
      });
      await adapter
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'combine',
              references: inputs,
            ),
          )
          .drain<void>();
    },
  );
  for (final oauth in [null, OAuthProvider.grok]) {
    test('xAI image edit routes to the proper endpoint for $oauth', () async {
      final directory = await Directory.systemTemp.createTemp(
        'grok-image-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final reference = await File(
        '${directory.path}/reference.png',
      ).writeAsString('pixels');
      final client = MockClient((request) async {
        expect(
          request.url.host,
          oauth == null ? 'api.x.ai' : 'cli-chat-proxy.grok.com',
        );
        expect(request.url.path, '/v1/images/edits');
        final body = jsonDecode(request.body) as Map;
        expect(body['aspect_ratio'], '9:16');
        expect(body['n'], 2);
        expect(body['image'], {
          'type': 'image_url',
          'url': 'data:image/png;base64,cGl4ZWxz',
        });
        return http.Response(
          '{"data":[{"url":"https://result.test/image.jpg","revised_prompt":"Detail"}]}',
          200,
        );
      });
      final events = await adapter
          .generate(
            MediaContext(
              provider: ProviderConfig(
                id: 'provider',
                name: 'xAI',
                baseUrl: 'https://api.x.ai/v1',
                apiKey: 'fixture',
                enabled: true,
                models: const [model],
                oauthProvider: oauth,
              ),
              client: client,
              apiKey: 'fixture',
              cancelToken: CancelToken(),
              requestId: 'test',
            ),
            MediaRequest(
              modelId: model,
              mode: MediaMode.image,
              prompt: 'Colorize the reference',
              count: 2,
              aspectRatio: '9:16',
              references: [MediaReference(reference.path)],
            ),
          )
          .toList();
      final result = (events.single as MediaOutput).results.single;
      expect(result.url?.host, 'result.test');
      expect(result.revisedPrompt, 'Detail');
    });
  }

  for (final oauth in [null, OAuthProvider.grok]) {
    test('Grok video polls the proper media origin under $oauth', () async {
      const model = 'grok-imagine-video-1.5';
      final provider = videoProvider(
        'https://api.x.ai/v1',
        model,
      ).copyWith(oauthProvider: oauth);
      var attempts = 0;
      final client = MockClient((request) async {
        expect(
          request.url.host,
          oauth == null ? 'api.x.ai' : 'cli-chat-proxy.grok.com',
        );
        if (request.method == 'POST') {
          expect(request.url.path, '/v1/videos/generations');
          final body = jsonDecode(request.body) as Map;
          expect(body['duration'], 8);
          expect(body['resolution'], '720p');
          return videoJson({'request_id': 'video-job'});
        }
        expect(request.url.path, '/v1/videos/video-job');
        if (attempts++ == 0) {
          return videoJson({
            'error': {'code': 'overload'},
          }, 503);
        }
        return videoJson({
          'status': 'done',
          'video': {'url': 'https://vidgen.x.ai/clip.mp4', 'duration': 7.9},
        });
      });
      final events = await const XaiVideoAdapter()
          .generate(videoContext(provider, client), videoRequest(model))
          .toList();
      expect(attempts, 2);
      final result = events.whereType<MediaOutput>().single.results.single;
      expect(result.durationMs, 7900);
      expect(result.downloadHeaders, isEmpty);
    });
  }
}
