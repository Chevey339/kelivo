import 'dart:async' show Completer;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/media_repository.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/media_file_store.dart';
import 'package:Kelivo/core/services/media/media_generation_runner.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/network/media_http_log.dart';
import 'package:Kelivo/core/services/network/request_logger.dart';
import 'package:Kelivo/features/settings/logs/request_log_parser.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

class _DirectHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HttpServer server;
  late MediaGenerationRunner runner;
  late Uri base;
  const secret = 'private-ticket-do-not-log';
  final poster = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aSzcAAAAASUVORK5CYII=',
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-media-http-log-');
    final previous = PathProviderPlatform.instance;
    final docs = SandboxPathResolver.docsDir,
        support = SandboxPathResolver.supportDir;
    PathProviderPlatform.instance = _Paths(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path);
    final db = AppDatabase(NativeDatabase.memory());
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    runner = MediaGenerationRunner(
      repository: MediaRepository(db),
      files: MediaFileStore(
        directory: () async => Directory('${root.path}/generations'),
      ),
      delay: (_) async {},
    );
    await RequestLogger.setEnabled(true);
    RequestLogger.saveOutput = false;
    addTearDown(() async {
      await runner.shutdown();
      runner.dispose();
      await server.close(force: true);
      await db.close();
      await RequestLogger.setEnabled(false);
      RequestLogger.saveOutput = false;
      PathProviderPlatform.instance = previous;
      SandboxPathResolver.debugSetDirs(docsDir: docs, supportDir: support);
      await root.delete(recursive: true);
    });
  });

  Future<GenerationStatus> generate({bool withFrame = false}) async {
    final frame = File('${root.path}/private-frame-name.png');
    if (withFrame) await frame.writeAsBytes(poster);
    return HttpOverrides.runZoned(() async {
      final ticket = await runner.enqueue(
        provider: ProviderConfig(
          id: 'local',
          name: 'local',
          enabled: true,
          baseUrl: '$base/v1',
          apiKey: 'private-provider-key',
          providerType: ProviderKind.openai,
          models: const ['sora-2'],
        ),
        request: MediaRequest(
          modelId: 'sora-2',
          mode: MediaMode.video,
          prompt: 'A blue paper boat',
          aspectRatio: '16:9',
          durationSec: 4,
          resolution: '720p',
          references: [
            if (withFrame)
              MediaReference(frame.path, role: MediaReferenceRole.firstFrame),
          ],
        ),
      );
      return ticket.completed;
    }, createHttpClient: _DirectHttp().createHttpClient);
  }

  Future<String> logContaining(String marker) async {
    final file = File('${root.path}/logs/logs.txt');
    for (var attempt = 0; attempt < 150; attempt++) {
      if (await file.exists()) {
        final text = await file.readAsString();
        if (text.contains(marker)) return text;
      }
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    fail('No media request log containing $marker');
  }

  test(
    'the request viewer shows upload, poll, redirect, video and cover, with bounded payloads',
    () async {
      RequestLogger.saveOutput = true;
      final video = [
        0,
        0,
        0,
        12,
        ...ascii.encode('ftypmp42'),
        ...ascii.encode('RAW-VIDEO-BYTES'),
        ...Uint8List(512 * 1024),
      ];
      server.listen((req) async {
        final res = req.response;
        await req.drain<void>();
        res.headers.contentType = ContentType.json;
        switch (req.uri.path) {
          case '/v1/videos':
            res.write(jsonEncode({'id': 'my-job', 'status': 'queued'}));
          case '/v1/videos/my-job':
            res.write(
              jsonEncode({
                'status': 'completed',
                'metadata': {
                  'thumbnail_url': '$base/cover.png?custom_ticket=$secret',
                  'result_url': '/download/movie.mp4?ticket=$secret',
                },
              }),
            );
          case '/v1/videos/my-job/content':
            res.statusCode = 302;
            res.headers.set('location', '/movie.mp4?custom_ticket=$secret');
          case '/movie.mp4':
            res.headers.contentType = ContentType('video', 'mp4');
            res.contentLength = video.length;
            res.add(video);
          case '/cover.png':
            res.headers.contentType = ContentType('image', 'png');
            res.add(poster);
          default:
            res.statusCode = 404;
        }
        await res.close();
      });
      expect(await generate(withFrame: true), GenerationStatus.succeeded);
      final text = await logContaining('image/png, ${poster.length} bytes');
      final entries = RequestLogParser.parse(text);
      final byPath = {for (final e in entries) e.uri!.path: e};
      expect(
        byPath.keys,
        containsAll([
          '/v1/videos',
          '/v1/videos/my-job',
          '/v1/videos/my-job/content',
          '/movie.mp4',
          '/cover.png',
        ]),
      );
      expect(byPath['/v1/videos']!.method, 'POST');
      final form = jsonDecode(byPath['/v1/videos']!.requestBody!);
      expect(form['fields']['model'], 'sora-2');
      expect(form['files'].single['field'], 'input_reference');
      expect(form['files'].single['bytes'], poster.length);
      expect(byPath['/v1/videos/my-job/content']!.statusCode, 302);
      expect(
        byPath['/movie.mp4']!.responseBody,
        contains('${video.length} bytes'),
      );
      expect(byPath['/v1/videos/my-job']!.responseBody, contains('completed'));
      for (final value in [
        secret,
        'private-provider-key',
        'RAW-VIDEO-BYTES',
        'private-frame-name',
        base64Encode(poster),
      ]) {
        expect(text, isNot(contains(value)));
      }
      expect(text.length, lessThan(16 * 1024));
    },
  );

  test(
    'HTTP and provider-declared errors are visible without saving successful outputs',
    () async {
      var run = 0;
      server.listen((req) async {
        await req.drain<void>();
        final res = req.response;
        res.headers.contentType = ContentType.json;
        if (req.method == 'POST' && ++run == 1) {
          res.statusCode = 422;
          res.write(
            '{"error":{"code":"wrong_size","message":"unsupported resolution"}}',
          );
        } else if (req.method == 'POST') {
          res.write(
            '{"id":"logical-error","status":"queued","detail":"success-output-marker"}',
          );
        } else {
          res.write(
            '{"status":"failed","error":{"code":"render_error","message":"could not encode frames"}}',
          );
        }
        await res.close();
      });
      expect(await generate(), GenerationStatus.failed);
      expect(await generate(), GenerationStatus.failed);
      final text = await logContaining('could not encode frames');
      final entries = RequestLogParser.parse(text);
      expect(
        entries.singleWhere((e) => e.statusCode == 422).responseBody,
        contains('unsupported resolution'),
      );
      final failed = entries.singleWhere(
        (e) => e.uri?.path == '/v1/videos/logical-error',
      );
      expect(failed.statusCode, 200);
      expect(failed.errors.join(), contains('render_error'));
      expect(text, isNot(contains('success-output-marker')));
    },
  );

  test(
    'download rejection body is recorded when the caller discards it',
    () async {
      server.listen((req) async {
        await req.drain<void>();
        final res = req.response;
        res.headers.contentType = ContentType.json;
        if (req.method == 'POST') {
          res.write('{"id":"denied-download","status":"completed"}');
        } else {
          res.statusCode = 403;
          res.write('{"error":"link has expired"}');
        }
        await res.close();
      });
      expect(await generate(), GenerationStatus.failed);
      final entries = RequestLogParser.parse(
        await logContaining('link has expired'),
      );
      final download = entries.singleWhere((e) => e.statusCode == 403);
      expect(download.uri?.path, '/v1/videos/denied-download/content');
      expect(download.responseBody, contains('link has expired'));
    },
  );

  test(
    'remote cancellation uses the same request log as the active video task',
    () async {
      const model = 'doubao-seedance-1-0-pro';
      final poll = Completer<void>(), release = Completer<void>();
      server.listen((req) async {
        await req.drain<void>();
        final res = req.response;
        res.headers.contentType = ContentType.json;
        if (req.method == 'POST') {
          res.write('{"id":"cancel-me"}');
        } else if (req.method == 'GET') {
          if (!poll.isCompleted) poll.complete();
          await release.future;
          res.write('{"status":"running"}');
        } else if (req.method == 'DELETE') {
          res.write('{"cancelled":true}');
        }
        await res.close();
      });
      try {
        await HttpOverrides.runZoned(() async {
          final ticket = await runner.enqueue(
            provider: ProviderConfig(
              id: 'ark-relay',
              name: 'relay',
              baseUrl: '$base/v1',
              enabled: true,
              apiKey: 'private-provider-key',
              providerType: ProviderKind.openai,
              models: const [model],
              modelOverrides: const {
                model: {
                  'media': {'protocol': 'arkVideo'},
                },
              },
            ),
            request: const MediaRequest(
              modelId: model,
              mode: MediaMode.video,
              prompt: 'Cancel this local test',
              durationSec: 5,
              resolution: '720p',
            ),
          );
          await poll.future.timeout(const Duration(seconds: 5));
          await runner.cancel(ticket.batchId);
          expect(await ticket.completed, GenerationStatus.cancelled);
          final entries = RequestLogParser.parse(
            await logContaining('DELETE '),
          );
          expect(
            entries.singleWhere((e) => e.method == 'DELETE').uri?.path,
            endsWith('/tasks/cancel-me'),
          );
        }, createHttpClient: _DirectHttp().createHttpClient);
      } finally {
        release.complete();
      }
    },
  );

  test('object store XML errors keep the cause and omit signing material', () {
    final bytes = utf8.encode(
      '<Error><Code>AccessDenied</Code><Message>Expired link</Message>'
      '<SignatureProvided>$secret</SignatureProvided></Error>',
    );
    final record = MediaHttpLog.describeBytes(
      bytes.length,
      'application/xml',
      bytes,
    );
    expect(jsonDecode(record), {
      'Code': 'AccessDenied',
      'Message': 'Expired link',
    });
  });

  test(
    'Gemini filtering is logged on the successful HTTP request with response saving off',
    () async {
      server.listen((req) async {
        await req.drain<void>();
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
        );
        await req.response.close();
      });
      await HttpOverrides.runZoned(() async {
        const model = 'gemini-2.5-flash-image';
        final ticket = await runner.enqueue(
          provider: ProviderConfig(
            id: 'gemini-test',
            name: 'Gemini',
            enabled: true,
            baseUrl: base.toString(),
            apiKey: 'private-provider-key',
            providerType: ProviderKind.google,
            models: const [model],
          ),
          request: const MediaRequest(
            modelId: model,
            mode: MediaMode.image,
            prompt: 'A paper boat',
          ),
        );
        expect(await ticket.completed, GenerationStatus.failed);
      }, createHttpClient: _DirectHttp().createHttpClient);
      final entry = RequestLogParser.parse(
        await logContaining('SAFETY'),
      ).single;
      expect(entry.statusCode, 200);
      expect(entry.errors.join(), contains('SAFETY'));
    },
  );

  test('disabled request logging leaves no media request file', () async {
    await RequestLogger.setEnabled(false);
    server.listen((req) async {
      await req.drain<void>();
      req.response.statusCode = 400;
      await req.response.close();
    });
    expect(await generate(), GenerationStatus.failed);
    expect(await File('${root.path}/logs/logs.txt').exists(), isFalse);
  });

  test(
    'large inline requests still expose parameters and chunked responses never log partial media',
    () {
      final inline =
          'data:image/png;base64,${'A' * (MediaHttpLog.maxBodyBytes * 2)}';
      final body = {
        'image': inline,
        'model': 'example',
        'resolution': '1080p',
        'watermark': false,
      };
      final request = http.Request('POST', base)..body = jsonEncode(body);
      MediaHttpLog.describeRequest(request, body);
      final description = jsonDecode(
        MediaHttpLog.requestBody(
          request,
          request.bodyBytes,
          'application/json',
        ),
      );
      expect(description['model'], 'example');
      expect(description['watermark'], false);
      expect(description['image'], isNot(contains('AAAA')));
      final capture = MediaResponseLog('application/json', null);
      for (final chunk in [
        utf8.encode('{"b64_json":"'),
        Uint8List.fromList(ascii.encode('A' * 40000)),
        utf8.encode('"}'),
      ]) {
        capture.add(chunk);
      }
      expect(
        capture.finish(complete: true),
        matches(r'^<application/json, \d+ bytes>$'),
      );
    },
  );
}
