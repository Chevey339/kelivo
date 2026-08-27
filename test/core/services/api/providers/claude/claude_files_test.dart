import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/api/providers/claude/claude_files.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/utils/kelivo_file_uri.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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

/// Minimal Files API: metadata from [meta], bytes from [bytes].
Future<HttpServer> _filesServer({
  required Map<String, dynamic> meta,
  required List<int> bytes,
  List<String>? requestLog,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    requestLog?.add(request.uri.path);
    if (request.uri.path.endsWith('/content')) {
      request.response.statusCode = HttpStatus.ok;
      request.response.add(bytes);
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(meta));
    }
    await request.response.close();
  });
  return server;
}

void main() {
  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_claude_files');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SandboxPathResolver.debugSetDirs(docsDir: tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    SandboxPathResolver.debugSetDirs();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('claudeGeneratedFileIds', () {
    test('reads the ids a container run left behind', () {
      final ids = claudeGeneratedFileIds(<String, dynamic>{
        'type': 'bash_code_execution_result',
        'stdout': 'chart.png\n',
        'return_code': 0,
        'content': [
          {'type': 'code_execution_output', 'file_id': 'file_1'},
          {'type': 'code_execution_output', 'file_id': 'file_2'},
        ],
      });

      expect(ids, <String>['file_1', 'file_2']);
    });

    test('a search or fetch result carries none', () {
      expect(
        claudeGeneratedFileIds(<String, dynamic>{
          'items': [
            {'url': 'https://example.com', 'title': 'Example'},
          ],
        }),
        isEmpty,
      );
      expect(claudeGeneratedFileIds('plain text'), isEmpty);
    });
  });

  group('downloadClaudeGeneratedFile', () {
    test('stores the file and names it as the container did', () async {
      final requests = <String>[];
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_1',
          'filename': 'chart.png',
          'mime_type': 'image/png',
          'size_bytes': 4,
          'downloadable': true,
        },
        bytes: const <int>[1, 2, 3, 4],
        requestLog: requests,
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      final file = await downloadClaudeGeneratedFile(
        client: client,
        base: 'http://${server.address.address}:${server.port}/v1',
        headers: const <String, String>{
          'x-api-key': 'sk-test',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        fileId: 'file_1',
      );

      expect(file, isNotNull);
      expect(file!.name, 'chart.png');
      expect(file.mime, 'image/png');
      // The message stores a managed reference, not an absolute device path.
      expect(KelivoFileUri.isKelivoFileUri(file.uri), isTrue);
      final saved = File('${tempDir.path}/upload/chart.png');
      expect(await saved.readAsBytes(), const <int>[1, 2, 3, 4]);
      expect(requests, <String>[
        '/v1/files/file_1',
        '/v1/files/file_1/content',
      ]);
    });

    test('a copy already stored is reused and the download dropped', () async {
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_1',
          'filename': 'chart.png',
          'mime_type': 'image/png',
          'size_bytes': 4,
          'downloadable': true,
        },
        bytes: const <int>[1, 2, 3, 4],
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      Future<GeneratedFile?> download() => downloadClaudeGeneratedFile(
        client: client,
        base: 'http://${server.address.address}:${server.port}/v1',
        headers: const <String, String>{'x-api-key': 'sk-test'},
        fileId: 'file_1',
      );

      final first = await download();
      final second = await download();

      expect(second!.uri, first!.uri);
      final stored = Directory(
        '${tempDir.path}/upload',
      ).listSync().map((entity) => entity.path.split('/').last).toList();
      // The streamed copy took a numbered name while it was being written and
      // must not survive next to the original.
      expect(stored, ['chart.png']);
    });

    test('a chart the API cannot type is still a chart', () async {
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_1',
          'filename': 'plot.png',
          'mime_type': 'application/octet-stream',
          'downloadable': true,
        },
        bytes: const <int>[7],
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      final file = await downloadClaudeGeneratedFile(
        client: client,
        base: 'http://${server.address.address}:${server.port}/v1',
        headers: const <String, String>{'x-api-key': 'sk-test'},
        fileId: 'file_1',
      );

      expect(file?.mime, 'image/png');
    });

    test('a data file keeps the type the API reported', () async {
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_2',
          'filename': 'report.csv',
          'mime_type': 'text/csv',
          'downloadable': true,
        },
        bytes: const <int>[8],
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      final file = await downloadClaudeGeneratedFile(
        client: client,
        base: 'http://${server.address.address}:${server.port}/v1',
        headers: const <String, String>{'x-api-key': 'sk-test'},
        fileId: 'file_2',
      );

      expect(file?.mime, 'text/csv');
    });

    test('an upload the API refuses to serve is skipped', () async {
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_1',
          'filename': 'data.csv',
          'mime_type': 'text/csv',
          'downloadable': false,
        },
        bytes: const <int>[1],
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      expect(
        await downloadClaudeGeneratedFile(
          client: client,
          base: 'http://${server.address.address}:${server.port}/v1',
          headers: const <String, String>{'x-api-key': 'sk-test'},
          fileId: 'file_1',
        ),
        isNull,
      );
    });

    test('a file past the attachment limit is left behind', () async {
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_1',
          'filename': 'huge.bin',
          'mime_type': 'application/octet-stream',
          'size_bytes': 501 * 1024 * 1024,
          'downloadable': true,
        },
        bytes: const <int>[1],
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      expect(
        await downloadClaudeGeneratedFile(
          client: client,
          base: 'http://${server.address.address}:${server.port}/v1',
          headers: const <String, String>{'x-api-key': 'sk-test'},
          fileId: 'file_1',
        ),
        isNull,
      );
    });

    test('a nameless file falls back to its id', () async {
      final server = await _filesServer(
        meta: <String, dynamic>{
          'id': 'file_1',
          'filename': '../escape',
          'mime_type': 'text/plain',
          'downloadable': true,
        },
        bytes: const <int>[9],
      );
      addTearDown(() => server.close(force: true));

      final client = http.Client();
      addTearDown(client.close);
      final file = await downloadClaudeGeneratedFile(
        client: client,
        base: 'http://${server.address.address}:${server.port}/v1',
        headers: const <String, String>{'x-api-key': 'sk-test'},
        fileId: 'file_1',
      );

      expect(file?.name, 'escape');
      expect(await File('${tempDir.path}/upload/escape').exists(), isTrue);
    });

    test('an unreachable Files API costs nothing but the file', () async {
      final client = http.Client();
      addTearDown(client.close);
      expect(
        await downloadClaudeGeneratedFile(
          client: client,
          base: 'http://127.0.0.1:1/v1',
          headers: const <String, String>{'x-api-key': 'sk-test'},
          fileId: 'file_1',
        ),
        isNull,
      );
    });
  });
}
