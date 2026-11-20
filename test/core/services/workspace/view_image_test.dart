import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/network/pinned_tls_socket.dart';
import 'package:Kelivo/core/services/api/tool_result_content.dart';
import 'package:Kelivo/core/services/tool_image.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

// The download worker must pass the checked public IP to the transport.
final class _FixtureImageSockets extends IOOverrides {
  _FixtureImageSockets(this.fixturePort);

  final int fixturePort;

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
  }) {
    if (host is! InternetAddress ||
        host.address != '8.8.8.8' ||
        port != fixturePort) {
      throw StateError('Unexpected image download destination');
    }
    return super.socketStartConnect(InternetAddress.loopbackIPv4, port);
  }
}

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
    expect(
      function['parameters']['properties']['path']['description'],
      contains('HTTP(S) image URL'),
    );
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

  group('public image URLs', () {
    late HttpServer server;
    late List<String> requests;
    late String origin;
    late Uint8List png;
    late Completer<void> received;

    setUp(() async {
      requests = [];
      received = Completer<void>();
      final image = img.Image(width: 9, height: 5);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      png = img.encodePng(image);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin = 'http://8.8.8.8:${server.port}';
      server.listen((request) async {
        final response = request.response;
        requests.add(request.uri.path);
        try {
          switch (request.uri.path) {
            case '/redirect':
              response.statusCode = HttpStatus.found;
              response.headers
                ..set(HttpHeaders.locationHeader, '/image.bin')
                ..add(HttpHeaders.setCookieHeader, 'test_cookie=value');
            case '/image.bin':
              expect(
                request.headers.value(HttpHeaders.hostHeader),
                '8.8.8.8:${server.port}',
              );
              for (final header in [
                HttpHeaders.cookieHeader,
                HttpHeaders.authorizationHeader,
                HttpHeaders.refererHeader,
              ]) {
                expect(request.headers.value(header), isNull);
              }
              response.headers.contentType = ContentType.binary;
              response.add(png);
            case '/private':
              response.statusCode = HttpStatus.found;
              response.headers.set(
                HttpHeaders.locationHeader,
                'http://localhost:${server.port}/image.bin',
              );
            case '/loop':
              response.statusCode = HttpStatus.found;
              response.headers.set(HttpHeaders.locationHeader, '/loop');
            case '/declared-large':
              response.contentLength = ToolImage.maxFileBytes + 1;
              response.add([0]);
              await response.flush();
              return;
            case '/streamed-large':
              final chunk = Uint8List(1024 * 1024);
              for (var i = 0; i < 21; i++) {
                response.add(chunk);
              }
            case '/pending':
              received.complete();
              return;
            default:
              response.statusCode = HttpStatus.notFound;
          }
          await response.close();
        } on IOException {
          // Size and cancellation checks can close the client mid-response.
        }
      });
    });

    tearDown(() => server.close(force: true));

    // Exercise the real HTTP reader without making external requests. The
    // connection must already be pinned to the fixture's public IP.
    Future<T> withFixtureSocket<T>(Future<T> Function() action) =>
        IOOverrides.runWithIOOverrides(
          action,
          _FixtureImageSockets(server.port),
        );

    test('follows a redirect and returns a replayable snapshot', () async {
      final result = await withFixtureSocket(
        () => view(' $origin/redirect ', ctx: context(sandboxed: true)),
      );
      expect(requests, ['/redirect', '/image.bin']);
      expect(result.metadata!['workspace']['status'], 'ok');
      expect(result.metadata!['workspace']['path'], '$origin/redirect');
      expect(result.metadata!['workspace']['files'], isEmpty);
      final snapshot = mcpResultImageUris(
        readMcpResultMetadata(result.metadata),
      ).single;
      expect(snapshot, startsWith('kelivo-file:///images/view_image_'));

      await server.close(force: true);
      final media = await ToolResultContent.read(
        'view_image',
        result.content,
        metadata: result.metadata,
      );
      final decoded = img.decodePng(
        Uri.parse(media.imageUrls.single).data!.contentAsBytes(),
      )!;
      expect((decoded.width, decoded.height), (9, 5));
      expect(decoded.getPixel(0, 0).r, 255);
    });

    test(
      'uses the workspace switch and checks the redirect destination',
      () async {
        await withFixtureSocket(() async {
          final disabled = await view(
            '$origin/image.bin',
            ctx: context(disabled: true),
          );
          expect(jsonDecode(disabled.content)['error'], 'tool_disabled');
          expect(requests, isEmpty);

          final result = await view('$origin/private');
          expect(
            jsonDecode(result.content)['message'],
            contains('public address'),
          );
          expect(result.metadata, isNot(contains(kMcpResultMetadataKey)));
          expect(requests, ['/private']);
        });
      },
    );

    test('bounds downloads and reports HTTP failures', () async {
      await withFixtureSocket(() async {
        for (final (path, message) in [
          ('/missing', 'HTTP 404'),
          ('/declared-large', '20 MiB'),
          ('/streamed-large', '20 MiB'),
          ('/loop', 'redirected too many times'),
        ]) {
          final result = await view('$origin$path');
          expect(jsonDecode(result.content)['message'], contains(message));
          expect(result.metadata, isNot(contains(kMcpResultMetadataKey)));
        }
        expect(requests.where((path) => path == '/loop'), hasLength(4));
      });
    });

    test('generation cancellation closes a pending image request', () async {
      final stop = Completer<void>();
      final cancellation = ToolCallCancellation(
        isCancelled: () => stop.isCompleted,
        cancelled: stop.future,
      );
      final pending = withFixtureSocket(
        () => cancellation.run(() => view('$origin/pending')),
      );
      await received.future;
      stop.complete();
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(
        jsonDecode(result.content)['message'],
        contains('tool_call_cancelled'),
      );
      expect(result.metadata, isNot(contains(kMcpResultMetadataKey)));
      expect(cancellation.listenerCount, 0);
    });

    test('honors global proxy routing and its bypass list', () async {
      final originalOverrides = HttpOverrides.current;
      addTearDown(() => HttpOverrides.global = originalOverrides);
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      await settings.setGlobalProxyHost('127.0.0.1');
      await settings.setGlobalProxyPort('9000');
      await settings.setGlobalProxyEnabled(true);
      settings.applyGlobalProxyOverridesIfNeeded();

      await withFixtureSocket(() async {
        final routed = await view('$origin/image.bin');
        expect(
          jsonDecode(routed.content)['message'],
          contains('direct connection'),
        );
        expect(requests, isEmpty);

        await settings.setGlobalProxyBypass('8.8.8.8');
        settings.applyGlobalProxyOverridesIfNeeded();
        final exempt = await view('$origin/image.bin');
        expect(exempt.metadata!['workspace']['status'], 'ok');
        expect(requests, ['/image.bin']);
      });
    });
  });

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

  test('cancelling a pending TLS handshake closes the TCP peer', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final peer = server.first;
    final task = await startPinnedTlsSocket(
      InternetAddress.loopbackIPv4,
      server.port,
      'localhost',
    );
    final failed = expectLater(task.socket, throwsA(isA<SocketException>()));
    addTearDown(task.cancel);
    final socket = await peer;
    addTearDown(socket.destroy);
    final handshake = Completer<void>();
    final disconnected = Completer<void>();
    socket.listen((bytes) {
      if (!handshake.isCompleted) handshake.complete();
    }, onDone: disconnected.complete);

    await handshake.future.timeout(const Duration(seconds: 2));
    task.cancel();
    await failed;
    await disconnected.future.timeout(const Duration(seconds: 2));
  });

  test('keeps scheme-like relative filenames as local paths', () async {
    const name = 'https:thumbnail.png';
    await File(
      p.join(workspace.path, name),
    ).writeAsBytes(img.encodePng(img.Image(width: 2, height: 3)));
    final result = await view(name, ctx: context(sandboxed: true));
    expect(result.metadata!['workspace']['status'], 'ok');
    expect(result.metadata!['workspace']['path'], '/workspace/$name');
  }, skip: Platform.isWindows);

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

  test('rejects disabled tools and paths escaping sandbox zones', () async {
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
      'path_outside',
    );
  }, skip: Platform.isWindows);

  test('rejects oversized input before decoding', () async {
    final file = File(p.join(workspace.path, 'huge.png'));
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(ToolImage.maxFileBytes + 1);
    await handle.close();
    expect(() => ToolImage.read(file.path), throwsA(isA<ToolImageException>()));
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
      final image = await ToolImage.read(file.path);
      expect(image.width, ToolImage.maxLongEdge);
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
    final image = await ToolImage.read(file.path);
    expect((image.width, image.height), (ToolImage.maxLongEdge, 1));
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
    final result = await ToolImage.read(file.path);
    final decoded = img.decodePng(result.bytes)!;
    expect(decoded.numFrames, 1);
    expect(decoded.getPixel(0, 0).r, 255);
    expect(decoded.getPixel(0, 0).b, 0);
  });
}
