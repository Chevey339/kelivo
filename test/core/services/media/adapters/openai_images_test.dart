import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/openai_images.dart';
import 'package:Kelivo/core/services/media/media_adapter.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _model = 'gpt-image-2';
const _adapter = OpenAiImagesAdapter();
const _image = MediaRequest(
  modelId: _model,
  mode: MediaMode.image,
  prompt: 'A watercolor tree',
  aspectRatio: '3:2',
);

MediaContext _context(
  String baseUrl,
  http.Client client, {
  OAuthProvider? oauth,
}) => MediaContext(
  provider: ProviderConfig(
    id: 'provider',
    name: 'Test Images',
    baseUrl: baseUrl,
    apiKey: 'fixture',
    enabled: true,
    models: const [_model],
    oauthProvider: oauth,
  ),
  client: client,
  apiKey: 'fixture',
  cancelToken: CancelToken(),
  requestId: 'media-turn-fixture',
);

void main() {
  test('official image stream emits partial and completed images', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/images/generations');
      expect(request.headers['authorization'], 'Bearer fixture');
      final body = jsonDecode(request.body) as Map;
      expect(body['size'], '1536x1024');
      expect(body['stream'], true);
      expect(body['partial_images'], 2);
      return http.Response(
        'data: {"type":"image_generation.partial_image","b64_json":"cHJldmlldw=="}\n\n'
        'data: {"type":"image_generation.completed","b64_json":"ZmluYWw="}\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final events = await _adapter
        .generate(_context('https://api.openai.com/v1', client), _image)
        .toList();
    expect(events, hasLength(2));
    expect((events.first as MediaPreview).base64, 'cHJldmlldw==');
    expect((events.last as MediaOutput).results.single.base64, 'ZmluYWw=');
  });

  test('stream moderation and incomplete streams produce typed errors', () async {
    for (final (data, kind) in [
      (
        'data: {"type":"error","error":{"code":"content_policy_violation"}}\n\n',
        MediaFailureKind.rejected,
      ),
      ('data: [DONE]\n\n', MediaFailureKind.invalidResponse),
    ]) {
      final client = MockClient(
        (_) async => http.Response(
          data,
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      );
      await expectLater(
        _adapter
            .generate(_context('https://api.openai.com/v1', client), _image)
            .toList(),
        throwsA(
          isA<MediaFailure>().having((failure) => failure.kind, 'kind', kind),
        ),
      );
    }
  });

  test('Codex edits use a JSON data URI and an image turn ID', () async {
    final directory = await Directory.systemTemp.createTemp('codex-image-test');
    addTearDown(() => directory.delete(recursive: true));
    final reference = await File(
      '${directory.path}/reference.png',
    ).writeAsString('pixels');
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        '${OAuthProvider.chatgpt.baseUrl}/images/edits',
      );
      expect(request.headers['x-codex-image-turn-id'], 'media-turn-fixture');
      final body = jsonDecode(request.body) as Map;
      expect(body['model'], _model);
      expect(body['images'], [
        {'image_url': 'data:image/png;base64,cGl4ZWxz'},
      ]);
      expect(body.containsKey('n'), isFalse);
      expect(body.containsKey('stream'), isFalse);
      return http.Response('{"data":[{"b64_json":"ZmluYWw="}]}', 200);
    });
    final events = await _adapter
        .generate(
          _context(
            OAuthProvider.chatgpt.baseUrl,
            client,
            oauth: OAuthProvider.chatgpt,
          ),
          _image.copyWith(references: [MediaReference(reference.path)]),
        )
        .toList();
    expect((events.single as MediaOutput).results.single.base64, 'ZmluYWw=');
  });

  test(
    'compatible edits send a multipart image and accept a result URL',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'compatible-image-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final reference = await File(
        '${directory.path}/reference.png',
      ).writeAsString('pixels');
      final client = MockClient.streaming((request, body) async {
        expect(request.url.path, '/v1/images/edits');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        final fields = await utf8.decoder.bind(body).join();
        expect(fields, contains('name="image[]"; filename="reference.png"'));
        expect(fields, contains('name="prompt"'));
        expect(fields, contains(_image.prompt));
        return http.StreamedResponse(
          Stream.value(
            utf8.encode('{"data":[{"url":"https://result.test/image.png"}]}'),
          ),
          200,
        );
      });
      final events = await _adapter
          .generate(
            _context('https://gateway.test/v1', client),
            _image.copyWith(references: [MediaReference(reference.path)]),
          )
          .toList();
      expect(
        (events.single as MediaOutput).results.single.url?.host,
        'result.test',
      );
    },
  );
}
