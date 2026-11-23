import 'dart:convert';

import 'package:Kelivo/core/services/media/adapters/openai_videos.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  test(
    'New API sends metadata as multipart and uses authenticated content',
    () async {
      const model = 'sora-2';
      var reads = 0;
      final provider = videoProvider('https://new-api.test/v1', model);
      final client = MockClient.streaming((request, body) async {
        final http.Response response;
        switch (request.method) {
          case 'POST':
            expect(request.url.path, '/v1/videos');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            final fields = await utf8.decoder.bind(body).join();
            expect(fields, contains('name="seconds"\r\n\r\n8'));
            expect(fields, contains('name="size"\r\n\r\n1280x720'));
            expect(
              fields,
              contains('name="metadata"\r\n\r\n{"motion":"slow"}'),
            );
            response = videoJson({'id': 'video-fixture', 'status': 'queued'});
          case 'GET':
            expect(request.url.path, '/v1/videos/video-fixture');
            response = reads++ == 0
                ? videoJson({'status': 'in_progress', 'progress': 44})
                : videoJson({
                    'status': 'completed',
                    'seconds': '8',
                    'size': '1280x720',
                  });
          default:
            throw StateError('Unexpected HTTP method');
        }
        return http.StreamedResponse(
          Stream.value(response.bodyBytes),
          response.statusCode,
        );
      });
      final events = await const OpenAiVideosAdapter()
          .generate(
            videoContext(provider, client),
            videoRequest(
              model,
              parameters: {
                'extra': {'motion': 'slow'},
              },
            ),
          )
          .toList();
      expect(events.whereType<MediaProgress>().single.fraction, .44);
      final result = events.whereType<MediaOutput>().single.results.single;
      expect(result.url?.path, '/v1/videos/video-fixture/content');
      expect(result.downloadHeaders['authorization'], 'Bearer fixture-key');
      expect(
        (result.width, result.height, result.durationMs),
        (1280, 720, 8000),
      );
    },
  );
}
