import 'dart:convert';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/gemini_images.dart';
import 'package:Kelivo/core/services/media/media_adapter_resolver.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flash Lite and Imagen Fast omit unsupported size choices', () {
    const adapter = GeminiImagesAdapter();
    final provider = ProviderConfig.defaultsFor('Gemini');
    expect(
      adapter.capabilities(provider, 'gemini-3.1-flash-lite-image').sizes,
      isEmpty,
    );
    expect(
      adapter.capabilities(provider, 'imagen-4.0-fast-generate-001').sizes,
      isEmpty,
    );
  });

  test('Gemini uses generateContent and extracts image parts', () async {
    const id = 'gemini-3.1-flash-image-preview';
    final provider = ProviderConfig.defaultsFor('Gemini');
    final client = MockClient((request) async {
      expect(request.url.path, '/v1beta/models/$id:generateContent');
      expect(request.headers['x-goog-api-key'], 'fixture-key');
      expect(jsonDecode(request.body), {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'draw a tree'},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'],
          'imageConfig': {'aspectRatio': '16:9', 'imageSize': '2K'},
        },
      });
      return videoJson({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'thought': true,
                  'inlineData': {'mimeType': 'image/png', 'data': 'BBBB'},
                },
                {'text': 'Here is the image'},
                {
                  'inlineData': {'mimeType': 'image/png', 'data': 'AAAA'},
                },
              ],
            },
          },
        ],
      });
    });
    final events = await const GeminiImagesAdapter()
        .generate(
          videoContext(provider, client),
          const MediaRequest(
            modelId: id,
            mode: MediaMode.image,
            prompt: 'draw a tree',
            aspectRatio: '16:9',
            parameters: {'size': '2K'},
          ),
        )
        .toList();
    expect(
      events.whereType<MediaOutput>().single.results.single.base64,
      'AAAA',
    );
  });

  test(
    'Imagen uses a compatible predict gateway and retired Google routes are excluded',
    () async {
      const id = 'imagen-4.0-generate-001';
      const resolver = MediaAdapterResolver();
      final google = ProviderConfig.defaultsFor('Gemini');
      expect(resolver.capabilities(google, MediaMode.image, id), isNull);
      expect(
        resolver.capabilities(
          google.copyWith(vertexAI: true),
          MediaMode.image,
          id,
        ),
        isNull,
      );
      final gateway = google.copyWith(
        baseUrl: 'https://models.example.test/v1beta',
      );
      final client = MockClient((request) async {
        expect(request.url.host, 'models.example.test');
        expect(request.url.path, '/v1beta/models/$id:predict');
        expect(request.headers['x-goog-api-key'], 'fixture-key');
        expect(jsonDecode(request.body)['parameters'], {
          'sampleCount': 2,
          'aspectRatio': '4:3',
          'sampleImageSize': '2K',
        });
        return videoJson({
          'predictions': [
            {'bytesBase64Encoded': 'AAAA'},
            {'bytesBase64Encoded': 'BBBB'},
          ],
        });
      });
      final events = await resolver
          .resolve(gateway, MediaMode.image, modelId: id)!
          .generate(
            videoContext(gateway, client),
            const MediaRequest(
              modelId: id,
              mode: MediaMode.image,
              prompt: 'Draw trees',
              count: 2,
              aspectRatio: '4:3',
              parameters: {'size': '2K'},
            ),
          )
          .toList();
      expect(events.whereType<MediaOutput>().single.results, hasLength(2));
    },
  );

  test('Gemini safety blocks produce the rejection category', () async {
    final provider = ProviderConfig.defaultsFor('Gemini');
    final client = MockClient(
      (_) async => videoJson({
        'promptFeedback': {'blockReason': 'SAFETY'},
      }),
    );
    await expectLater(
      const GeminiImagesAdapter().generate(
        videoContext(provider, client),
        const MediaRequest(
          modelId: 'gemini-2.5-flash-image',
          mode: MediaMode.image,
          prompt: 'A tree',
        ),
      ),
      emitsError(
        isA<MediaFailure>().having(
          (error) => error.kind,
          'kind',
          MediaFailureKind.rejected,
        ),
      ),
    );
  });
}
