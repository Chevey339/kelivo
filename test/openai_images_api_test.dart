import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAiConfig(String baseUrl, {bool useResponseApi = false}) {
  return ProviderConfig(
    id: 'OpenAITest',
    enabled: true,
    name: 'OpenAITest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
  );
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}/v1';
}

Future<List<int>> _readBytes(HttpRequest request) async {
  final chunks = <int>[];
  await for (final chunk in request) {
    chunks.addAll(chunk);
  }
  return chunks;
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

void main() {
  group('OpenAI Images API', () {
    test('routes image model without input images to generations', () async {
      late Uri requestUri;
      late Map<String, dynamic> requestBody;
      late String? authorization;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestUri = request.uri;
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'url': 'https://example.com/generated.png'},
            ],
            'usage': {'input_tokens': 3, 'output_tokens': 5},
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server)),
        modelId: 'gpt-image-2',
        messages: const [
          {'role': 'user', 'content': 'draw a tabby cat'},
        ],
      ).toList();

      expect(requestUri.path, '/v1/images/generations');
      expect(authorization, 'Bearer test-key');
      expect(requestBody['model'], 'gpt-image-2');
      expect(requestBody['prompt'], 'draw a tabby cat');
      expect(chunks, hasLength(1));
      expect(
        chunks.single.content,
        '![image](https://example.com/generated.png)',
      );
      expect(chunks.single.usage?.totalTokens, 8);
    });

    test(
      'routes image models to Images API even when Responses is enabled',
      () async {
        late Uri requestUri;
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestUri = request.uri;
          requestBody =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': [
                {'url': 'https://example.com/generated.png'},
              ],
            }),
          );
          await request.response.close();
        });

        await ChatApiService.sendMessageStream(
          config: _openAiConfig(_baseUrl(server), useResponseApi: true),
          modelId: 'gpt-image-2',
          messages: const [
            {'role': 'user', 'content': 'generate an empty image'},
          ],
        ).toList();

        expect(requestUri.path, '/v1/images/generations');
        expect(requestBody['model'], 'gpt-image-2');
        expect(requestBody.containsKey('input'), isFalse);
        expect(requestBody.containsKey('stream'), isFalse);
      },
    );

    test('routes Agnes image models to generations', () async {
      late Uri requestUri;
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestUri = request.uri;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'url': 'https://example.com/agnes-generated.png'},
            ],
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server), useResponseApi: true),
        modelId: 'agnes-image-2.1-flash',
        messages: const [
          {'role': 'user', 'content': 'draw a clean app icon'},
        ],
      ).toList();

      expect(requestUri.path, '/v1/images/generations');
      expect(requestBody['model'], 'agnes-image-2.1-flash');
      expect(requestBody['prompt'], 'draw a clean app icon');
      expect(chunks.single.content, contains('agnes-generated.png'));
    });

    test('can disable Images API routing for image models', () async {
      late Uri requestUri;
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestUri = request.uri;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'chat route'},
              },
            ],
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server)),
        modelId: 'gpt-image-2',
        messages: const [
          {'role': 'user', 'content': 'draw a cat'},
        ],
        allowImagesApiRouting: false,
        stream: false,
      ).toList();

      expect(requestUri.path, '/v1/chat/completions');
      expect(requestBody['model'], 'gpt-image-2');
      expect(chunks.single.content, 'chat route');
    });

    test(
      'can disable Images API routing for image models with input images',
      () async {
        late Uri requestUri;
        late String contentType;
        late Map<String, dynamic> requestBody;
        final tempDir = await Directory.systemTemp.createTemp(
          'kelivo_openai_image_chat_route_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final inputImage = File('${tempDir.path}/source.png');
        await inputImage.writeAsBytes(const [1, 2, 3, 4]);

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestUri = request.uri;
          contentType = request.headers.contentType?.mimeType ?? '';
          requestBody =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'chat route with image'},
                },
              ],
            }),
          );
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _openAiConfig(_baseUrl(server)),
          modelId: 'gpt-image-2',
          messages: const [
            {'role': 'user', 'content': 'describe this image'},
          ],
          userImagePaths: [inputImage.path],
          allowImagesApiRouting: false,
          stream: false,
        ).toList();

        expect(requestUri.path, '/v1/chat/completions');
        expect(contentType, ContentType.json.mimeType);
        expect(requestBody['model'], 'gpt-image-2');
        expect(chunks.single.content, 'chat route with image');
      },
    );

    test('routes image model with input image to edits multipart', () async {
      late Uri requestUri;
      late String contentType;
      late String requestBody;
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_openai_image_edit_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final inputImage = File('${tempDir.path}/source.png');
      await inputImage.writeAsBytes(const [1, 2, 3, 4]);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestUri = request.uri;
        contentType = request.headers.contentType?.mimeType ?? '';
        requestBody = latin1.decode(await _readBytes(request));
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'url': 'https://example.com/edited.png'},
            ],
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server)),
        modelId: 'gpt-image-2',
        messages: const [
          {'role': 'user', 'content': 'make the background blue'},
        ],
        userImagePaths: [inputImage.path],
      ).toList();

      expect(requestUri.path, '/v1/images/edits');
      expect(contentType, 'multipart/form-data');
      expect(requestBody, contains('name="model"'));
      expect(requestBody, contains('gpt-image-2'));
      expect(requestBody, contains('name="prompt"'));
      expect(requestBody, contains('make the background blue'));
      expect(requestBody, contains('name="image[]"'));
      expect(requestBody, contains('content-type: image/png'));
      expect(requestBody, contains('filename="source.png"'));
      expect(chunks.single.content, '![image](https://example.com/edited.png)');
    });

    test('sets jpeg content type for jpg image edit uploads', () async {
      late String requestBody;
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_openai_jpeg_edit_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final inputImage = File('${tempDir.path}/source.jpg');
      await inputImage.writeAsBytes(const [1, 2, 3, 4]);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = latin1.decode(await _readBytes(request));
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'url': 'https://example.com/edited.jpg'},
            ],
          }),
        );
        await request.response.close();
      });

      await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server)),
        modelId: 'gpt-image-2',
        messages: const [
          {'role': 'user', 'content': 'make it cinematic'},
        ],
        userImagePaths: [inputImage.path],
      ).toList();

      expect(requestBody, contains('filename="source.jpg"'));
      expect(requestBody, contains('content-type: image/jpeg'));
    });

    test('routes structured user input images to edits multipart', () async {
      late Uri requestUri;
      late String contentType;
      late String requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestUri = request.uri;
        contentType = request.headers.contentType?.mimeType ?? '';
        requestBody = latin1.decode(await _readBytes(request));
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'url': 'https://example.com/structured-edit.png'},
            ],
          }),
        );
        await request.response.close();
      });

      await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server)),
        modelId: 'gpt-image-2',
        messages: const [
          {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'make the background blue'},
              {
                'type': 'input_image',
                'input_image': {
                  'type': 'base64',
                  'media_type': 'image/png',
                  'data': ['AQIDBA=='],
                },
              },
            ],
          },
        ],
      ).toList();

      expect(requestUri.path, '/v1/images/edits');
      expect(contentType, 'multipart/form-data');
      expect(requestBody, contains('name="prompt"'));
      expect(requestBody, contains('make the background blue'));
      expect(requestBody, contains('name="image[]"'));
      expect(requestBody, contains('content-type: image/png'));
    });

    test('rejects dall-e-3 edits before sending a request', () async {
      await expectLater(
        ChatApiService.sendMessageStream(
          config: _openAiConfig('http://127.0.0.1:9/v1'),
          modelId: 'dall-e-3',
          messages: const [
            {'role': 'user', 'content': 'edit this image'},
          ],
          userImagePaths: const ['/tmp/source.png'],
        ).toList(),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('does not support image edits'),
          ),
        ),
      );
    });

    test('saves base64 image responses with requested output format', () async {
      late Map<String, dynamic> requestBody;
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_openai_b64_output_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPathProvider;
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {
                'b64_json': base64Encode(const [1, 2, 3, 4]),
              },
            ],
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server)),
        modelId: 'gpt-image-2',
        messages: const [
          {'role': 'user', 'content': 'draw a tabby cat'},
        ],
        extraBody: const {'output_format': 'webp'},
      ).toList();

      final imagePath = RegExp(
        r'!\[image\]\(([^)]+)\)',
      ).firstMatch(chunks.single.content)!.group(1)!;
      expect(requestBody['output_format'], 'webp');
      expect(imagePath.endsWith('.webp'), isTrue);
      expect(await File(imagePath).readAsBytes(), const [1, 2, 3, 4]);
    });

    test(
      'throws instead of rendering null when base64 image save fails',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kelivo_openai_b64_failure_',
        );
        final previousPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
        addTearDown(() async {
          PathProviderPlatform.instance = previousPathProvider;
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          await request.drain<void>();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': [
                {'b64_json': 'not valid base64'},
              ],
            }),
          );
          await request.response.close();
        });

        await expectLater(
          ChatApiService.sendMessageStream(
            config: _openAiConfig(_baseUrl(server)),
            modelId: 'gpt-image-2',
            messages: const [
              {'role': 'user', 'content': 'draw a tabby cat'},
            ],
          ).toList(),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('Failed to save OpenAI Images API base64 image'),
            ),
          ),
        );
      },
    );

    test(
      'uses the latest assistant image as edit input for follow-up turns',
      () async {
        late Uri requestUri;
        late String contentType;
        late String requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestUri = request.uri;
          contentType = request.headers.contentType?.mimeType ?? '';
          requestBody = latin1.decode(await _readBytes(request));
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': [
                {'url': 'https://example.com/follow-up-edit.png'},
              ],
            }),
          );
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _openAiConfig(_baseUrl(server)),
          modelId: 'gpt-image-2',
          messages: const [
            {'role': 'user', 'content': 'draw a tabby cat'},
            {
              'role': 'assistant',
              'content': '![image](data:image/png;base64,AQIDBA==)',
            },
            {'role': 'user', 'content': 'make it realistic'},
          ],
        ).toList();

        expect(requestUri.path, '/v1/images/edits');
        expect(contentType, 'multipart/form-data');
        expect(requestBody, contains('name="image[]"'));
        expect(requestBody, contains('make it realistic'));
        expect(requestBody, isNot(contains('draw a tabby cat')));
        expect(requestBody, isNot(contains('Original image request:')));
        expect(requestBody, isNot(contains('Edit request:')));
        expect(
          chunks.single.content,
          '![image](https://example.com/follow-up-edit.png)',
        );
      },
    );

    test(
      'throws useful exception on non-success Images API response',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          await request.drain<void>();
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'bad image request'}));
          await request.response.close();
        });

        expect(
          ChatApiService.sendMessageStream(
            config: _openAiConfig(_baseUrl(server)),
            modelId: 'gpt-image-2',
            messages: const [
              {'role': 'user', 'content': 'draw'},
            ],
          ).toList(),
          throwsA(
            isA<HttpException>().having(
              (error) => error.message,
              'message',
              contains('HTTP 400'),
            ),
          ),
        );
      },
    );
  });

  group('OpenAI Responses image generation', () {
    test('renders partial image when completed output is empty', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_openai_responses_partial_image_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPathProvider;
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.headers.set('Transfer-Encoding', 'chunked');

        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.output_item.added',
            'item': {'id': 'ig_1', 'type': 'image_generation_call', 'status': 'in_progress'},
            'output_index': 0,
          })}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.image_generation_call.partial_image',
            'item_id': 'ig_1',
            'output_index': 0,
            'output_format': 'png',
            'partial_image_b64': base64Encode(const [1, 2, 3, 4]),
          })}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.output_item.done',
            'item': {
              'id': 'msg_1',
              'type': 'message',
              'status': 'completed',
              'content': [
                {'type': 'output_text', 'text': ''},
              ],
              'role': 'assistant',
            },
            'output_index': 1,
          })}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'response': {
              'output': [],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            },
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(_baseUrl(server), useResponseApi: true),
        modelId: 'gpt-5.5',
        messages: const [
          {'role': 'user', 'content': 'draw a puppy'},
        ],
      ).toList();

      final content = chunks.map((chunk) => chunk.content).join();
      final imagePath = RegExp(
        r'!\[image\]\(([^)]+)\)',
      ).firstMatch(content)!.group(1)!;
      expect(content, contains('![image]('));
      expect(imagePath.endsWith('.png'), isTrue);
      expect(await File(imagePath).readAsBytes(), const [1, 2, 3, 4]);
      expect(chunks.last.isDone, isTrue);
    });
  });
}
