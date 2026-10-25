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
