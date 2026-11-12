import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/api/tool_result_content.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late File image;
  late String dataUrl;
  late String markdown;
  late Map<String, dynamic> metadata;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mcp_result_images_');
    await Directory('${directory.path}/images').create();
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(directory.path);
    SandboxPathResolver.debugSetDirs(docsDir: directory.path);
    image = File('${directory.path}/images/mcp_img_drawing (1).png');
    final bytes = img.encodePng(img.Image(width: 2, height: 3));
    await image.writeAsBytes(bytes);
    dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
    markdown = 'Drawing\n![](${encodeMarkdownImageDestination(image.path)})';
    metadata = {
      kMcpResultMetadataKey: mcpResultMetadata([image.path]),
    };
  });

  test(
    'missing sources do not create another empty restoration result',
    () async {
      final entry = ChatContextImage(
        identity: const ContextImageIdentity('a', 'tool:drawing'),
        uri: image.path,
        source: ContextImageSource.tool,
        label: 'drawing',
      );
      final context = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [entry],
      );
      await image.delete();
      final body = await context.project({
        'input': [
          {
            'role': 'user',
            'content': [
              {'type': 'input_image', 'image_url': entry.reference},
            ],
          },
        ],
      });
      expect(jsonEncode(body), contains('unavailable'));
      expect(jsonEncode(body), isNot(contains('Use view_image')));
      expect(context.readImage(entry.handle).metadata, isNull);
    },
  );

  test(
    'adding an MCP image again retains the snapshot path boundary',
    () async {
      final private = await File(
        '${directory.path}/images/upload.png',
      ).writeAsBytes(await image.readAsBytes());
      final entry = ChatContextImage(
        identity: const ContextImageIdentity('a', 'tool:untrusted'),
        uri: private.path,
        source: ContextImageSource.tool,
        label: 'untrusted',
      );
      final context = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [entry],
      );
      expect(await context.attachmentPath(entry.handle), isNull);
    },
  );

  test(
    'explicit MIME survives local materialization and independent restoration',
    () async {
      final photo = await File(
        '${directory.path}/upload',
      ).writeAsBytes(img.encodeJpg(img.Image(width: 3, height: 2)));
      final entry = ChatContextImage(
        identity: const ContextImageIdentity('u', 'part:0'),
        uri: photo.path,
        mime: 'image/jpg',
        source: ContextImageSource.user,
        label: 'photo',
      );
      final context = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [entry],
        targetMessageId: 'a',
      );
      Map<String, dynamic> body(String ref) => {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': ref.substring(ref.indexOf(',') + 1),
                },
              },
            ],
          },
        ],
      };
      final sent = await context.project(body(entry.reference));
      expect(
        sent['messages'][0]['content'][0]['source']['media_type'],
        'image/jpeg',
      );
      final restored = context.readImage(entry.handle);
      final refs = context.toolReferences(
        'view_image',
        [entry.uri],
        restored.metadata,
        'read',
      );
      final independent = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [context.images.last],
      );
      final replay = await independent.project(body(refs.single));
      expect(
        replay['messages'][0]['content'][0]['source']['media_type'],
        'image/jpeg',
      );
      expect(
        replay['messages'][0]['content'][0]['source']['data'],
        sent['messages'][0]['content'][0]['source']['data'],
      );
    },
  );

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await directory.delete(recursive: true);
  });

  test(
    'stored MCP metadata cannot attach client files outside its snapshots',
    () async {
      for (final path in [
        '${directory.path}/private.png',
        '${directory.path}/mcp_img_private.png',
        '${directory.path}/images/private.png',
      ]) {
        final file = File(path);
        await file.writeAsString('private image bytes');
        for (final uri in [
          path,
          file.uri.toString(),
          SandboxPathResolver.canonicalize(path),
        ]) {
          final result = await ToolResultContent.read(
            'view_drawing',
            '![]($uri)',
            metadata: {
              kMcpResultMetadataKey: mcpResultMetadata([uri]),
            },
          );
          expect(result.imageUrls, isEmpty);
          expect(result.text, contains('unavailable'));
        }
      }
    },
  );

  test(
    'snapshot symlinks cannot attach files outside the image directory',
    () async {
      final private = File('${directory.path}/mcp_img_private.png');
      await private.writeAsString('private image bytes');
      final link = Link('${directory.path}/images/mcp_img_link.png');
      await link.create(private.path);
      final result = await ToolResultContent.read(
        'view_drawing',
        '![](${link.path})',
        metadata: {
          kMcpResultMetadataKey: mcpResultMetadata([link.path]),
        },
      );
      expect(result.imageUrls, isEmpty);
    },
    skip: Platform.isWindows
        ? 'Windows symlinks need elevated privileges'
        : false,
  );

  test(
    'stored HTTP image replay does not accumulate unreferenced snapshots',
    () async {
      final bytes = await image.readAsBytes();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(bytes);
        await request.response.close();
      });
      final uri = 'http://127.0.0.1:${server.port}/drawing.png';
      for (var replay = 0; replay < 3; replay++) {
        final result = await ToolResultContent.read(
          'view_drawing',
          '![]($uri)',
          metadata: {
            kMcpResultMetadataKey: mcpResultMetadata([uri]),
          },
        );
        expect(result.imageUrls, [dataUrl]);
        expect(result.text, isEmpty);
      }
      expect(requests, 3);
      expect(await Directory('${directory.path}/images').list().length, 1);
    },
  );

  test(
    'URL replay snapshots the first bytes per occurrence across requests',
    () async {
      final first = await image.readAsBytes();
      final second = img.encodePng(img.Image(width: 5, height: 5));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(requests == 1 ? first : second);
        await request.response.close();
      });
      final uri = 'http://127.0.0.1:${server.port}/changing.png';
      final concurrent = await Future.wait([
        McpImageSnapshot.readDataUrl(uri, cacheKey: 'first-occurrence'),
        McpImageSnapshot.readDataUrl(uri, cacheKey: 'first-occurrence'),
      ]);
      expect(concurrent, [dataUrl, dataUrl]);
      expect(
        await McpImageSnapshot.readDataUrl(uri, cacheKey: 'first-occurrence'),
        dataUrl,
      );
      expect(requests, 1);
      expect(
        await McpImageSnapshot.readDataUrl(uri, cacheKey: 'new-occurrence'),
        isNot(dataUrl),
      );
      expect(requests, 2);
    },
  );

  test(
    'restoring an old URL reuses its original snapshot at the new occurrence',
    () async {
      final bytes = await image.readAsBytes();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var fetches = 0;
      server.listen((request) async {
        fetches++;
        request.response.add(
          fetches == 1 ? bytes : img.encodePng(img.Image(width: 9, height: 9)),
        );
        await request.response.close();
      });
      final original = ChatContextImage(
        identity: const ContextImageIdentity('old', 'tool:first'),
        uri: 'http://127.0.0.1:${server.port}/changing.png',
        source: ContextImageSource.tool,
        label: 'drawing',
      );
      final context = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [original],
        targetMessageId: 'new',
      );
      Map<String, dynamic> body(String ref) => {
        'input': [
          {
            'type': 'function_call_output',
            'call_id': 'c',
            'output': [
              {'type': 'input_image', 'image_url': ref},
            ],
          },
        ],
      };
      final first = await context.project(body(original.reference));
      final recalled = context.readImage(original.handle);
      await context.run(() async* {
        final result = await ToolResultContent.read(
          'view_image',
          recalled.content,
          metadata: recalled.metadata,
          toolCallId: 'second',
        );
        final restored = await context.project(body(result.imageUrls.single));
        expect(
          (restored['input'] as List).single['output'],
          (first['input'] as List).single['output'],
        );
        expect(context.images.last.materializationKey, original.key);
        yield 0;
      }).drain<void>();
      expect(fetches, 1);
      final restarted = RequestImageContext(
        settings: const ImageContextSettings(),
        images: List.of(context.images),
      );
      expect(
        (await restarted.project(body(context.images.last.reference)))['input'],
        first['input'],
      );
      expect(fetches, 1);
    },
  );

  for (final name in ['view_drawing', 'svguess__view_drawing', 'view_image']) {
    test('MCP $name sends only its structured images', () async {
      final extra = File('${directory.path}/private.png');
      await extra.writeAsBytes(img.encodePng(img.Image(width: 4, height: 5)));
      final result = await ToolResultContent.read(
        name,
        '$markdown\n![](${extra.path})',
        metadata: metadata,
      );
      expect(result.imageUrls, [dataUrl]);
      expect(result.text, 'Drawing\n\n![](${extra.path})');
      expect(result.text, isNot(contains(image.path)));
    });
  }

  test('text and image-less metadata never authorize image reads', () async {
    for (final metadata in [
      null,
      {kMcpResultMetadataKey: mcpResultMetadata([])},
    ]) {
      final result = await ToolResultContent.read(
        'view_drawing',
        markdown,
        metadata: metadata,
      );
      expect(result.imageUrls, isEmpty);
      expect(result.text, markdown);
    }
  });

  test(
    'workspace errors and other tools cannot bypass view_image validation',
    () async {
      for (final workspace in [
        {'tool': 'view_image', 'status': 'error'},
        {'tool': 'read_file', 'status': 'ok'},
        'invalid',
      ]) {
        final result = await ToolResultContent.read(
          'view_image',
          markdown,
          metadata: {...metadata, 'workspace': workspace},
        );
        expect(result.imageUrls, isEmpty);
        expect(result.text, markdown);
      }
    },
  );

  test(
    'text-only models omit MCP images without reading their bytes',
    () async {
      await image.delete();
      final result = await ToolResultContent.read(
        'view_drawing',
        markdown,
        metadata: metadata,
        canImageInput: false,
      );
      expect(result.imageUrls, isEmpty);
      expect(result.text, contains('does not support image input'));
      expect(result.text, isNot(contains(image.path)));
      expect(result.text, isNot(contains('unavailable')));
    },
  );

  test(
    'missing MCP image files produce an explicit unavailable result',
    () async {
      await image.delete();
      final result = await ToolResultContent.read(
        'view_drawing',
        markdown,
        metadata: metadata,
      );
      expect(result.imageUrls, isEmpty);
      expect(result.text, contains('unavailable'));
      expect(result.text, isNot(contains(image.path)));
    },
  );
}
