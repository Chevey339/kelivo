import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

ProviderConfig _vertexClaudeConfig() {
  return ProviderConfig(
    id: 'VertexClaudeMediaTest',
    enabled: true,
    name: 'VertexClaudeMediaTest',
    apiKey: 'vertex-secret-token',
    baseUrl: 'https://aiplatform.googleapis.com',
    providerType: ProviderKind.google,
    vertexAI: true,
    location: 'global',
    projectId: 'test-project',
  );
}

/// Routes allowlisted Google media hosts through [mediaPort]; fails API hosts fast.
class _VertexMediaHttpOverrides extends HttpOverrides {
  _VertexMediaHttpOverrides({this.mediaPort});

  final int? mediaPort;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = const Duration(milliseconds: 500);
    client.badCertificateCallback = (_, __, ___) => true;
    client.findProxy = (uri) {
      final host = uri.host.toLowerCase();
      final isMediaHost =
          host == 'storage.googleapis.com' ||
          host == 'googleapis.com' ||
          host.endsWith('.googleapis.com') ||
          host == 'googleusercontent.com' ||
          host.endsWith('.googleusercontent.com') ||
          host == 'storage.cloud.google.com';
      // Keep aiplatform chat calls out of the media proxy so downloads stay
      // observable; they fail fast via connectionFactory below.
      if (mediaPort != null &&
          isMediaHost &&
          !host.contains('aiplatform.googleapis.com')) {
        return 'PROXY 127.0.0.1:$mediaPort';
      }
      return 'DIRECT';
    };
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      final host = uri.host.toLowerCase();
      if (host.contains('aiplatform.googleapis.com')) {
        return Future<ConnectionTask<Socket>>.error(
          const SocketException('blocked vertex chat endpoint in test'),
        );
      }
      if (proxyHost != null && proxyPort != null) {
        return Socket.startConnect(proxyHost, proxyPort);
      }
      return Socket.startConnect(uri.host, uri.port);
    };
    return client;
  }
}

Future<HttpHeaders?> _captureVertexClaudeMediaDownloadHeaders({
  required String mediaUrl,
  int? mediaProxyPort,
  required HttpServer mediaServer,
}) async {
  HttpHeaders? mediaHeaders;
  mediaServer.listen((request) async {
    mediaHeaders = request.headers;
    request.response.statusCode = HttpStatus.ok;
    request.response.add(const [1, 2, 3, 4]);
    await request.response.close();
  });

  try {
    await HttpOverrides.runZoned(
      () async {
        await ChatApiService.sendMessageStream(
          config: _vertexClaudeConfig(),
          modelId: 'claude-sonnet-4@20250514',
          messages: [
            {
              'role': 'user',
              'content': 'look',
              multimodalInternalMediaPathsKey: [
                encodeInternalMediaRef(uri: mediaUrl, mime: 'image/png'),
              ],
            },
          ],
          stream: false,
        ).toList();
      },
      createHttpClient: (context) {
        return _VertexMediaHttpOverrides(
          mediaPort: mediaProxyPort,
        ).createHttpClient(context);
      },
    );
  } catch (_) {
    // Vertex chat endpoint is intentionally blocked after media download.
  }

  // Give the listen handler a tick if the download raced the catch path.
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return mediaHeaders;
}

void main() {
  group('Vertex media auth allowlist helper', () {
    test(
      'allows googleapis / googleusercontent / storage.cloud.google.com',
      () {
        expect(
          ChatApiService.shouldAttachVertexMediaAuthForTest(
            Uri.parse('https://storage.googleapis.com/bucket/obj'),
          ),
          isTrue,
        );
        expect(
          ChatApiService.shouldAttachVertexMediaAuthForTest(
            Uri.parse('https://aiplatform.googleapis.com/v1/foo'),
          ),
          isTrue,
        );
        expect(
          ChatApiService.shouldAttachVertexMediaAuthForTest(
            Uri.parse('https://googleapis.com/foo'),
          ),
          isTrue,
        );
        expect(
          ChatApiService.shouldAttachVertexMediaAuthForTest(
            Uri.parse('https://lh3.googleusercontent.com/a/image'),
          ),
          isTrue,
        );
        expect(
          ChatApiService.shouldAttachVertexMediaAuthForTest(
            Uri.parse('https://googleusercontent.com/a'),
          ),
          isTrue,
        );
        expect(
          ChatApiService.shouldAttachVertexMediaAuthForTest(
            Uri.parse('https://storage.cloud.google.com/bucket/obj'),
          ),
          isTrue,
        );
      },
    );

    test('rejects http even on allowlisted Google hosts', () {
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('http://storage.googleapis.com/bucket/obj'),
        ),
        isFalse,
      );
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('http://lh3.googleusercontent.com/a/image'),
        ),
        isFalse,
      );
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('http://storage.cloud.google.com/bucket/obj'),
        ),
        isFalse,
      );
    });

    test('rejects broad google.com and unrelated hosts', () {
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('https://www.google.com/img.png'),
        ),
        isFalse,
      );
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('https://example.com/img.png'),
        ),
        isFalse,
      );
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('https://evilgoogleapis.com/img.png'),
        ),
        isFalse,
      );
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('https://googleapis.com.evil.com/img.png'),
        ),
        isFalse,
      );
      expect(
        ChatApiService.shouldAttachVertexMediaAuthForTest(
          Uri.parse('file:///tmp/img.png'),
        ),
        isFalse,
      );
    });
  });

  group('Claude image mime normalization helper', () {
    test('maps image/jpg to image/jpeg and lowercases', () {
      expect(
        ChatApiService.normalizeClaudeImageMimeForTest('image/jpg'),
        'image/jpeg',
      );
      expect(
        ChatApiService.normalizeClaudeImageMimeForTest(' IMAGE/JPG '),
        'image/jpeg',
      );
      expect(
        ChatApiService.normalizeClaudeImageMimeForTest('image/png'),
        'image/png',
      );
      expect(
        ChatApiService.normalizeClaudeImageMimeForTest('IMAGE/JPEG'),
        'image/jpeg',
      );
    });
  });

  group('Vertex remote media download auth', () {
    test(
      'external http(s) host under Vertex does not attach auth headers',
      () async {
        final mediaServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() async {
          await mediaServer.close(force: true);
        });

        final mediaUrl =
            'http://${mediaServer.address.address}:${mediaServer.port}/external.png';
        final mediaHeaders = await _captureVertexClaudeMediaDownloadHeaders(
          mediaUrl: mediaUrl,
          mediaServer: mediaServer,
        );

        expect(mediaHeaders, isNotNull);
        expect(mediaHeaders!.value('authorization'), isNull);
        expect(mediaHeaders.value('x-goog-user-project'), isNull);
      },
    );

    test(
      'http://storage.googleapis.com under Vertex does not attach auth headers',
      () async {
        final mediaServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() async {
          await mediaServer.close(force: true);
        });

        // Cleartext allowlisted hosts must never carry Vertex credentials.
        const mediaUrl = 'http://storage.googleapis.com/bucket/photo.png';
        final mediaHeaders = await _captureVertexClaudeMediaDownloadHeaders(
          mediaUrl: mediaUrl,
          mediaProxyPort: mediaServer.port,
          mediaServer: mediaServer,
        );

        expect(mediaHeaders, isNotNull);
        expect(mediaHeaders!.value('authorization'), isNull);
        expect(mediaHeaders.value('x-goog-user-project'), isNull);
      },
    );
  });

  group('Vertex Claude image/jpg media_type', () {
    test(
      'image/jpg supplemental mime is accepted and normalized like Claude',
      () async {
        // Vertex Claude writes media_type via _normalizeClaudeImageMime; full
        // HTTPS aiplatform capture is awkward in-unit, so assert the shared
        // wire normalization and that image/jpg remains a supported alias.
        expect(
          ChatApiService.normalizeClaudeImageMimeForTest('image/jpg'),
          'image/jpeg',
        );

        final dir = await Directory.systemTemp.createTemp('kelivo_vertex_jpg_');
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });
        final file = File('${dir.path}/shot.jpg');
        await file.writeAsBytes(const [1, 2, 3, 4]);

        // Official Claude path exercises the same normalizer + media_type write
        // contract that Vertex Claude uses for Anthropic image blocks.
        Map<String, dynamic>? requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((request) async {
          requestBody =
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'id': 'msg_1',
              'content': [
                {'type': 'text', 'text': 'ok'},
              ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
          await request.response.close();
        });

        await ChatApiService.sendMessageStream(
          config: ProviderConfig(
            id: 'ClaudeJpgAliasTest',
            enabled: true,
            name: 'ClaudeJpgAliasTest',
            apiKey: 'test-key',
            baseUrl: 'http://${server.address.address}:${server.port}',
            providerType: ProviderKind.claude,
          ),
          modelId: 'claude-sonnet-4-6',
          messages: [
            {
              'role': 'user',
              'content': 'photo',
              multimodalInternalMediaPathsKey: [
                encodeInternalMediaRef(uri: file.path, mime: 'image/jpg'),
              ],
            },
          ],
          stream: false,
        ).toList();

        final body = requestBody;
        expect(body, isNotNull);
        final messages = (body!['messages'] as List).cast<Map>();
        final parts = (messages.single['content'] as List).cast<Map>();
        final image = parts.firstWhere((part) => part['type'] == 'image');
        expect(image['source']['media_type'], 'image/jpeg');
        expect(jsonEncode(body), isNot(contains('"media_type":"image/jpg"')));
      },
    );
  });
}
