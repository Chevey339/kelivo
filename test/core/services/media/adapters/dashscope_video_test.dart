import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/services/media/adapters/dashscope_video.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  for (final (ratio, size) in [
    ('auto', '1280*720'),
    ('1:1', '960*960'),
    ('4:3', '1088*832'),
  ]) {
    test('Wan 2.6 text-to-video maps $ratio to its exact 720p size', () async {
      const model = 'wan2.6-t2v';
      final provider = videoProvider(
        'https://dashscope.aliyuncs.com/compatible-mode/v1',
        model,
      );
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          final parameters =
              (jsonDecode(request.body) as Map)['parameters'] as Map;
          expect(parameters['size'], size);
          expect(parameters.containsKey('resolution'), isFalse);
          return videoJson({
            'output': {'task_id': 'clip'},
          });
        }
        return videoJson({
          'output': {
            'task_status': 'SUCCEEDED',
            'video_url': 'https://results.test/video.mp4',
          },
        });
      });
      final events = await const DashScopeVideoAdapter()
          .generate(
            videoContext(provider, client),
            MediaRequest(
              modelId: model,
              mode: MediaMode.video,
              prompt: 'A garden',
              resolution: '720p',
              aspectRatio: ratio,
              durationSec: 8,
            ),
          )
          .toList();
      expect(events.last, isA<MediaOutput>());
    });
  }

  for (final model in ['wan3.0-video', 'wan2.6-i2v', 'wan2.2-kf2v-flash']) {
    test(
      'DashScope $model uses native paths and the appropriate input fields',
      () async {
        final provider = videoProvider(
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
          model,
        );
        final root = await Directory.systemTemp.createTemp('kelivo-wan');
        addTearDown(() => root.delete(recursive: true));
        final image = await File(
          '${root.path}/initial.png',
        ).writeAsString('frame');
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            final path = model.contains('kf2v')
                ? 'image2video'
                : 'video-generation';
            expect(
              request.url.path,
              '/api/v1/services/aigc/$path/video-synthesis',
            );
            expect(request.headers['x-dashscope-async'], 'enable');
            final body = jsonDecode(request.body) as Map;
            final input = body['input'] as Map;
            expect(body['parameters']['resolution'], '720P');
            if (model.contains('3.0')) {
              expect(input['media'], [
                {
                  'type': 'first_frame',
                  'url': 'data:image/png;base64,ZnJhbWU=',
                },
              ]);
            } else {
              final field = model.contains('kf2v')
                  ? 'first_frame_url'
                  : 'img_url';
              expect(input[field], 'data:image/png;base64,ZnJhbWU=');
            }
            return videoJson({
              'output': {'task_id': 'wai'},
            });
          }
          expect(request.url.path, '/api/v1/tasks/wai');
          return videoJson({
            'output': {
              'task_status': 'SUCCEEDED',
              'video_url': 'https://results.test/video.mp4',
            },
            'usage': {'output_video_duration': 7.5},
          });
        });
        final events = await const DashScopeVideoAdapter()
            .generate(
              videoContext(provider, client),
              videoRequest(
                model,
                frames: [
                  MediaReference(
                    image.path,
                    role: MediaReferenceRole.firstFrame,
                  ),
                ],
              ),
            )
            .toList();
        expect(
          events.whereType<MediaOutput>().single.results.single.durationMs,
          7500,
        );
      },
    );
  }
}
