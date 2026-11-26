import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/media/adapters/ark_video.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  test(
    'Seedance submits frame roles, polls by task ID and advertises cancellation',
    () async {
      const model = 'doubao-seedance-2-5-flash';
      final provider = videoProvider(
        'https://ark.cn-beijing.volces.com/api/v3',
        model,
      );
      final fixture = await Directory.systemTemp.createTemp('kelivo-ark');
      addTearDown(() => fixture.delete(recursive: true));
      final media = await File(
        '${fixture.path}/clip.png',
      ).writeAsString('frame');
      final frames = [
        MediaReference(media.path, role: MediaReferenceRole.firstFrame),
        MediaReference(media.path, role: MediaReferenceRole.lastFrame),
      ];
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v3/contents/generations/tasks');
          final body = jsonDecode(request.body) as Map;
          final images = (body['content'] as List).skip(1).cast<Map>();
          expect(images.map((part) => part['role']), [
            'first_frame',
            'last_frame',
          ]);
          expect(images.first['image_url'], {
            'url': 'data:image/png;base64,ZnJhbWU=',
          });
          expect(body['duration'], 8);
          expect(body['ratio'], 'adaptive');
          return videoJson({'id': 'task-1'});
        }
        expect(request.url.path, '/api/v3/contents/generations/tasks/task-1');
        return videoJson({
          'status': 'succeeded',
          'duration': 8,
          'content': {
            'video_url': 'https://delivery.test/movie.mp4',
            'first_frame_url': 'https://delivery.test/poster.jpg',
          },
        });
      });
      final events = await const ArkVideoAdapter()
          .generate(
            videoContext(provider, client),
            videoRequest(model, frames: frames),
          )
          .toList();
      expect(
        events.whereType<MediaTaskAccepted>().single.cancelUrl?.path,
        '/api/v3/contents/generations/tasks/task-1',
      );
      final result = events.whereType<MediaOutput>().single.results.single;
      expect(result.previewUrl?.path, '/poster.jpg');
      expect(result.downloadHeaders, isEmpty);
      expect(
        const ArkVideoAdapter().capabilities(provider, model).resolutions,
        ['720p', '480p'],
      );
    },
  );
}
