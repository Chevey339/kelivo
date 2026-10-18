import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
import 'package:Kelivo/core/services/tool_image.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  group('normalized snapshots', () {
    late Directory root;
    late PathProviderPlatform originalPaths;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('mcp_normalized_');
      await Directory('${root.path}/images').create();
      originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = FakePathProviderPlatform(root.path);
      SandboxPathResolver.debugSetDirs(docsDir: root.path);
    });
    tearDown(() async {
      PathProviderPlatform.instance = originalPaths;
      SandboxPathResolver.debugSetDirs();
      await root.delete(recursive: true);
    });

    for (final format in ['jpeg', 'bmp', 'long_png']) {
      test(
        'replay normalizes stored $format without rewriting history files',
        () async {
          final pixels = img.Image(
            width: format == 'long_png' ? 16 : 3,
            height: format == 'long_png' ? 9000 : 2,
          );
          final bytes = switch (format) {
            'jpeg' => img.encodeJpg(pixels),
            'bmp' => img.encodeBmp(pixels),
            _ => img.encodePng(pixels),
          };
          // Previously saved snapshots can have the wrong extension.
          final file = File('${root.path}/images/mcp_img_old.png');
          await file.writeAsBytes(bytes);
          String? previous;
          for (var replay = 0; replay < 2; replay++) {
            final result = (await McpImageSnapshot.readDataUrl(
              SandboxPathResolver.canonicalize(file.path),
            ))!;
            final data = Uri.parse(result).data!;
            expect(
              data.mimeType,
              format == 'jpeg' ? 'image/jpeg' : 'image/png',
            );
            final image = img.decodeImage(data.contentAsBytes())!;
            expect(image.width, lessThanOrEqualTo(ToolImage.maxLongEdge));
            expect(image.height, lessThanOrEqualTo(ToolImage.maxLongEdge));
            if (previous != null) expect(result, previous);
            previous = result;
          }
          expect(await file.readAsBytes(), bytes);
          expect(await Directory('${root.path}/images').list().length, 1);
        },
      );
    }

    test(
      'remote images use actual bytes on download and HTTP history replay',
      () async {
        final bytes = img.encodeBmp(img.Image(width: 16, height: 9000));
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add(bytes);
          await request.response.close();
        });
        final url = 'http://127.0.0.1:${server.port}/incorrect.jpg';
        final saved = (await McpImageSnapshot.download(url))!;
        expect(saved, endsWith('.png'));
        final local = await McpImageSnapshot.readDataUrl(saved);
        for (var replay = 0; replay < 2; replay++) {
          final remote = (await McpImageSnapshot.readDataUrl(url))!;
          expect(remote, local);
          final data = Uri.parse(remote).data!;
          expect(data.mimeType, 'image/png');
          expect(
            img.decodePng(data.contentAsBytes())!.height,
            ToolImage.maxLongEdge,
          );
        }
        expect(await Directory('${root.path}/images').list().length, 1);
      },
    );

    test(
      'save still accepts URL-safe and whitespace-separated base64',
      () async {
        final bytes = img.encodePng(img.Image(width: 3, height: 2));
        final uri = await McpImageSnapshot.save(
          ' \n${base64UrlEncode(bytes)}\n',
        );
        expect(uri, isNotNull);
        final data = Uri.parse(
          (await McpImageSnapshot.readDataUrl(uri!))!,
        ).data!;
        expect(data.mimeType, 'image/png');
        expect(data.contentAsBytes(), bytes);
      },
    );
  });

  test(
    'stopping generation aborts the historical image download before sending',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final connected = Completer<void>();
      final disconnected = Completer<void>();
      var providerRequests = 0;
      server.listen((request) async {
        if (request.uri.path != '/drawing.png') {
          providerRequests++;
          request.response.statusCode = 500;
          await request.response.close();
          return;
        }
        final socket = await request.response.detachSocket(writeHeaders: false);
        addTearDown(socket.destroy);
        socket.write(
          'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 1000\r\n\r\na',
        );
        await socket.flush();
        void disconnectedFromPeer() {
          if (!disconnected.isCompleted) disconnected.complete();
        }

        socket.listen(
          (_) {},
          onDone: disconnectedFromPeer,
          onError: (Object _) => disconnectedFromPeer(),
        );
        connected.complete();
      });
      const requestId = 'mcp-history-cancellation';
      final url = 'http://127.0.0.1:${server.port}/drawing.png';
      final generation = ChatApiService.sendMessageStream(
        config: ProviderConfig(
          id: 'mcp-images',
          name: 'mcp-images',
          enabled: true,
          apiKey: 'test',
          baseUrl: 'http://127.0.0.1:${server.port}',
          providerType: ProviderKind.openai,
          modelOverrides: {
            'gpt-4.1': {
              'input': ['text', 'image'],
              'abilities': ['tool'],
            },
          },
        ),
        modelId: 'gpt-4.1',
        requestId: requestId,
        stream: false,
        messages: [
          {'role': 'user', 'content': 'inspect'},
          {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'call_image',
                'type': 'function',
                'function': {'name': 'view_drawing', 'arguments': '{}'},
              },
            ],
          },
          {
            'role': 'tool',
            'name': 'view_drawing',
            'tool_call_id': 'call_image',
            'content': '![]($url)',
            'metadata': {
              kMcpResultMetadataKey: mcpResultMetadata([url]),
            },
          },
          {'role': 'user', 'content': 'describe again'},
        ],
      ).toList();
      final stopped = generation.then<void>((_) {}, onError: (Object _) {});
      await connected.future.timeout(const Duration(seconds: 3));
      ChatApiService.cancelRequest(requestId);
      await disconnected.future.timeout(const Duration(seconds: 3));
      await stopped.timeout(const Duration(seconds: 3));
      expect(providerRequests, 0);
    },
  );

  for (final cancel in [false, true]) {
    test(
      '${cancel ? 'cancellation' : 'timeout'} closes a stalled image connection',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final connected = Completer<void>();
        final disconnected = Completer<void>();
        server.listen((request) async {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          addTearDown(socket.destroy);
          socket.write(
            'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 1000\r\n\r\na',
          );
          await socket.flush();
          socket.listen(
            (_) {},
            onDone: () {
              if (!disconnected.isCompleted) disconnected.complete();
            },
            onError: (Object _) {
              if (!disconnected.isCompleted) disconnected.complete();
            },
          );
          connected.complete();
        });
        final cancellation = Completer<void>();
        final context = ToolCallCancellation(
          isCancelled: () => cancellation.isCompleted,
          cancelled: cancellation.future,
        );
        final download = context.run(
          () => McpImageSnapshot.download(
            'http://127.0.0.1:${server.port}/image.png',
            timeout: cancel
                ? const Duration(seconds: 10)
                : const Duration(milliseconds: 300),
          ),
        );
        final result = cancel
            ? expectLater(download, throwsStateError)
            : expectLater(download, completion(isNull));
        await connected.future.timeout(const Duration(seconds: 3));
        if (cancel) cancellation.complete();
        await result;
        await disconnected.future.timeout(const Duration(seconds: 3));
      },
    );
  }
}
