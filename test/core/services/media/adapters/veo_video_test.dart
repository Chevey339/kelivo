import 'dart:convert';

import 'package:Kelivo/core/services/media/adapters/veo_video.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  test('Vertex Veo uses a region-bound predict and fetch operation', () async {
    const model = 'veo-3.1-generate-001';
    final provider =
        videoProvider(
          'https://generativelanguage.googleapis.com/v1beta',
          model,
        ).copyWith(
          vertexAI: true,
          projectId: 'fixture-project',
          location: 'us-central1',
        );
    const operation =
        'projects/fixture-project/locations/us-central1/publishers/google/models/veo-3.1-generate-001/operations/job';
    final client = MockClient((request) async {
      expect(request.url.host, 'us-central1-aiplatform.googleapis.com');
      expect(request.headers['authorization'], 'Bearer fixture-key');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map;
      if (request.url.path.endsWith(':predictLongRunning')) {
        expect(body['instances'], [
          {'prompt': 'Sunlight on a garden'},
        ]);
        expect(body['parameters']['durationSeconds'], 8);
        return videoJson({'name': operation});
      }
      expect(request.url.path, endsWith(':fetchPredictOperation'));
      expect(body, {'operationName': operation});
      return videoJson({
        'done': true,
        'response': {
          'videos': [
            {'gcsUri': 'gs://bucket/one/clip.mp4', 'mimeType': 'video/mp4'},
          ],
        },
      });
    });
    final events = await const VeoVideoAdapter()
        .generate(videoContext(provider, client), videoRequest(model))
        .toList();
    final result = events.whereType<MediaOutput>().single.results.single;
    expect(
      result.url?.toString(),
      'https://storage.googleapis.com/storage/v1/b/bucket/o/one%2Fclip.mp4?alt=media',
    );
    expect(result.downloadHeaders['Authorization'], 'Bearer fixture-key');
  });
}
