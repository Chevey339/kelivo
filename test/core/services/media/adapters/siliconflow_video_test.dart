import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/services/media/adapters/siliconflow_video.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  test(
    'MiniMax H3 uses role-based frames and polls SiliconFlow with POST',
    () async {
      const model = 'MiniMaxAI/MiniMax-H3';
      final provider = videoProvider('https://api.siliconflow.cn/v1', model);
      final root = await Directory.systemTemp.createTemp('kelivo-h3');
      addTearDown(() => root.delete(recursive: true));
      final frame = await File('${root.path}/final.png').writeAsString('frame');
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('/submit')) {
          expect(body['images'], [
            {'role': 'last_frame', 'url': 'data:image/png;base64,ZnJhbWU='},
          ]);
          expect(body['duration'], 5);
          return videoJson({'requestId': 'assigned'});
        }
        expect(request.url.path, '/v1/video/status');
        expect(body, {'requestId': 'assigned'});
        return videoJson({
          'status': 'Succeed',
          'results': {
            'videos': [
              {'url': 'https://results.test/video.mp4'},
            ],
          },
        });
      });
      final events = await const SiliconFlowVideoAdapter()
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: model,
              mode: MediaMode.video,
              prompt: 'A field',
              durationSec: 5,
              resolution: '768p',
              references: [
                MediaReference(frame.path, role: MediaReferenceRole.lastFrame),
              ],
            ),
          )
          .toList();
      expect(
        events.whereType<MediaOutput>().single.results.single.url?.host,
        'results.test',
      );
    },
  );
}
