import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/api/tool_result_content.dart';
import 'package:Kelivo/core/services/workspace/host_file_tools.dart';
import 'package:Kelivo/core/services/workspace/workspace_image.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

void main() {
  late Directory tmp;
  late PathProviderPlatform originalPaths;
  late Directory workspace;
  late Directory session;
  late Directory skills;
  late WorkspaceToolsService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('view_image_');
    workspace = Directory(p.join(tmp.path, 'workspace'))..createSync();
    session = Directory(p.join(tmp.path, 'session'))..createSync();
    skills = Directory(p.join(tmp.path, 'skills'))..createSync();
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(tmp.path);
    SandboxPathResolver.debugSetDirs(docsDir: tmp.path);
    service = WorkspaceToolsService();
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await tmp.delete(recursive: true);
  });

  WorkspaceToolContext context({
    bool sandboxed = false,
    bool disabled = false,
  }) {
    return WorkspaceToolContext(
      workspace: Workspace(
        id: 'w',
        name: 'test',
        kind: WorkspaceKind.managed,
        disabledTools: disabled ? {'view_image'} : {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      binding: const WorkspaceBinding(workspaceId: 'w'),
      paths: sandboxed
          ? WorkspacePaths.sandboxed(
              workspaceHostRoot: workspace.path,
              sessionHostDir: session.path,
              skillsHostDir: skills.path,
            )
          : WorkspacePaths.native(
              workspaceHostRoot: workspace.path,
              sessionHostDir: session.path,
              skillsHostDir: skills.path,
            ),
      sessionDir: session,
      outputsDir: Directory(p.join(session.path, 'outputs')),
    );
  }

  Future<ClientToolResult> view(
    Object? path, {
    WorkspaceToolContext? ctx,
  }) async => ClientToolResult.fromHandler(
    await service.handle(ctx ?? context(), 'view_image', {
      'path': path,
    }, toolCallId: 'view'),
  );

  test('schema is explicit, path-only, and follows the workspace switch', () {
    final function = service
        .buildToolDefinitions(context())
        .map((d) => d['function'] as Map)
        .singleWhere((f) => f['name'] == 'view_image');
    expect(function['strict'], false);
    expect(function['parameters']['required'], ['path']);
    expect((function['parameters']['properties'] as Map).keys, ['path']);
    expect(function['parameters']['additionalProperties'], false);
    expect(
      service
          .buildToolDefinitions(context(disabled: true))
          .map((d) => (d['function'] as Map)['name']),
      isNot(contains('view_image')),
    );
  });

  for (final sandboxed in [false, true]) {
    test(
      'reads ${sandboxed ? 'sandbox' : 'native'} image and snapshots its pixels',
      () async {
        final file = File(p.join(workspace.path, '图 (1).png'));
        final original = img.Image(width: 20, height: 10);
        img.fill(original, color: img.ColorRgb8(255, 0, 0));
        await file.writeAsBytes(img.encodePng(original));
        final result = await view(
          sandboxed ? '/workspace/图 (1).png' : file.path,
          ctx: context(sandboxed: sandboxed),
        );
        expect(result.metadata!['workspace']['status'], 'ok');
        final uri = mcpResultImageUris(
          readMcpResultMetadata(result.metadata),
        ).single;
        expect(uri, startsWith('kelivo-file:///images/view_image_'));
        await file.delete();
        final media = await ToolResultContent.read(
          'view_image',
          result.content,
          metadata: result.metadata,
        );
        final decoded = img.decodeImage(
          Uri.parse(media.imageUrls.single).data!.contentAsBytes(),
        )!;
        expect((decoded.width, decoded.height), (20, 10));
        expect(decoded.getPixel(0, 0).r, 255);
      },
    );
  }

  test('reads chat attachments using the same sandbox path mapping', () async {
    final file = File(p.join(session.path, 'sample.bin'));
    await file.writeAsBytes(img.encodePng(img.Image(width: 2, height: 3)));
    final result = await view(
      '/chat/sample.bin',
      ctx: context(sandboxed: true),
    );
    expect(result.metadata!['workspace']['status'], 'ok');
    expect(result.metadata!['workspace']['path'], '/chat/sample.bin');
  });

  test(
    'rejects invalid arguments, missing/corrupt files and directories',
    () async {
      for (final path in [null, 123, '', ' ', 'missing.png', workspace.path]) {
        final result = await view(path);
        expect(
          result.metadata!['workspace']['status'],
          'error',
          reason: '$path',
        );
        expect(result.metadata, isNot(contains(kMcpResultMetadataKey)));
      }
      final invalid = File(p.join(workspace.path, 'invalid.png'))
        ..writeAsStringSync('not an image');
      expect(
        jsonDecode((await view(invalid.path)).content)['error'],
        'view_image_failed',
      );
    },
  );

  test(
    'rejects disabled tools and paths escaping sandbox zones',
    () async {
      expect(
        jsonDecode(
          (await view('x.png', ctx: context(disabled: true))).content,
        )['error'],
        'tool_disabled',
      );
      final ctx = context(sandboxed: true);
      for (final path in [
        '/workspace/../outside.png',
        '/etc/passwd',
        '/workspace/a\u0000.png',
      ]) {
        expect(
          jsonDecode((await view(path, ctx: ctx)).content)['error'],
          'path_error',
        );
      }
      await Link(p.join(workspace.path, 'link.png')).create('/etc/hosts');
      expect(
        jsonDecode(
          (await view('/workspace/link.png', ctx: ctx)).content,
        )['error'],
        'path_error',
      );
    },
    skip: Platform.isWindows,
  );

  test('rejects oversized input before decoding', () async {
    final file = File(p.join(workspace.path, 'huge.png'));
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(WorkspaceImage.maxFileBytes + 1);
    await handle.close();
    expect(
      () => WorkspaceImage.read(file.path),
      throwsA(isA<HostFileException>()),
    );
  });

  test(
    'path errors never load image links embedded in the rejected path',
    () async {
      final private = File(p.join(tmp.path, 'private.png'));
      final bytes = img.encodePng(img.Image(width: 2, height: 2));
      await private.writeAsBytes(bytes);
      final result = await view(
        '/invalid/![](${private.path})',
        ctx: context(sandboxed: true),
      );
      expect(jsonDecode(result.content)['error'], 'path_error');
      expect(result.metadata!['workspace']['status'], 'error');
      final media = await ToolResultContent.read(
        'view_image',
        result.content,
        metadata: result.metadata,
      );
      expect(media.imageUrls, isEmpty);
      expect(media.text, result.content);
      expect(
        jsonEncode(media.responsesOutput),
        isNot(contains(base64Encode(bytes))),
      );
    },
  );

  test(
    'resizes large images and normalizes BMP into supported image bytes',
    () async {
      final file = File(p.join(workspace.path, 'wide.bmp'));
      await file.writeAsBytes(
        img.encodeBmp(img.Image(width: 3000, height: 30)),
      );
      final image = await WorkspaceImage.read(file.path);
      expect(image.width, WorkspaceImage.maxLongEdge);
      expect(image.height, 20);
      expect(image.mime, 'image/png');
      expect(img.decodePng(image.bytes), isNotNull);
    },
  );

  test('only explicit image tools load local image results', () async {
    final path = File(p.join(workspace.path, 'test.png'))
      ..writeAsBytesSync([1, 2, 3]);
    final result = await ToolResultContent.read('shell', '![](${path.path})');
    expect(result.imageUrls, isEmpty);
    expect(result.text, contains(path.path));
    final untyped = await ToolResultContent.read(
      'view_image',
      '![](${path.path})',
    );
    expect(untyped.imageUrls, isEmpty);
    expect(untyped.text, '![](${path.path})');
  });

  test(
    'successful results read only their snapshot metadata, not extra links',
    () async {
      final source = File(p.join(workspace.path, 'source.png'));
      await source.writeAsBytes(img.encodePng(img.Image(width: 2, height: 2)));
      final result = await view(source.path);
      final private = File(p.join(tmp.path, 'other.png'));
      final privateBytes = img.encodePng(img.Image(width: 3, height: 3));
      await private.writeAsBytes(privateBytes);
      final media = await ToolResultContent.read(
        'view_image',
        '${result.content}\n![](${private.path})',
        metadata: result.metadata,
      );
      expect(media.imageUrls, hasLength(1));
      expect(
        media.imageUrls.single,
        isNot(contains(base64Encode(privateBytes))),
      );
      expect(media.text, contains('![](${private.path})'));
      final failed = await ToolResultContent.read(
        'view_image',
        result.content,
        metadata: {
          ...result.metadata!,
          'workspace': {'tool': 'view_image', 'status': 'error'},
        },
      );
      expect(failed.imageUrls, isEmpty);
      expect(failed.text, result.content);
    },
  );

  test('very thin images retain at least one pixel after resizing', () async {
    final file = File(p.join(workspace.path, 'thin.png'));
    await file.writeAsBytes(img.encodePng(img.Image(width: 5000, height: 1)));
    final image = await WorkspaceImage.read(file.path);
    expect((image.width, image.height), (2048, 1));
    expect(img.decodeImage(image.bytes), isNotNull);
  });

  test(
    'cleared snapshots report unavailability instead of a successful image',
    () async {
      final result = await ToolResultContent.read(
        'view_image',
        'Image (8 x 4).\n![](${tmp.path}/missing.png)',
        metadata: {
          ...const WorkspaceToolMetadata(
            tool: 'view_image',
            status: 'ok',
          ).toJson(),
          kMcpResultMetadataKey: mcpResultMetadata(['${tmp.path}/missing.png']),
        },
      );
      expect(result.imageUrls, isEmpty);
      expect(result.text, contains('unavailable'));
    },
  );

  test('animated GIFs return only the first frame', () async {
    final first = img.Image(width: 3, height: 2);
    img.fill(first, color: img.ColorRgb8(255, 0, 0));
    final second = img.Image(width: 3, height: 2);
    img.fill(second, color: img.ColorRgb8(0, 0, 255));
    first.addFrame(second);
    final file = File(p.join(workspace.path, 'animated.gif'));
    await file.writeAsBytes(
      img.GifEncoder(
        quantizerType: img.QuantizerType.octree,
        numColors: 2,
      ).encode(first),
    );
    final gif = img.decodeGif(await file.readAsBytes(), frame: 0)!;
    expect(gif.getPixel(0, 0).r, 255, reason: 'fixture first frame');
    final result = await WorkspaceImage.read(file.path);
    final decoded = img.decodePng(result.bytes)!;
    expect(decoded.numFrames, 1);
    expect(decoded.getPixel(0, 0).r, 255);
    expect(decoded.getPixel(0, 0).b, 0);
  });
}
