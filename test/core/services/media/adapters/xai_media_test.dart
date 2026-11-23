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

void main() {
  const model = 'grok-imagine-image';
  const adapter = XaiImageAdapter();
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
}
