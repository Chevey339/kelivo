import '../../../support/fal_catalog_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/media_repository.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/media_file_store.dart';
import 'package:Kelivo/core/services/media/media_adapter.dart';
import 'package:Kelivo/core/services/media/media_generation_runner.dart';
import 'package:Kelivo/core/services/media/media_adapter_resolver.dart';
import 'package:Kelivo/core/services/media/adapters/veo_video.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/utils/kelivo_file_uri.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

class _HeldEnqueueRepository extends MediaRepository {
  _HeldEnqueueRepository(super.database);

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> enqueue(
    GenerationBatchRowsCompanion batch, {
    GenerationTopicRowsCompanion? topic,
  }) async {
    entered.complete();
    await release.future;
    await super.enqueue(batch, topic: topic);
  }
}

class _RejectDeleteRepository extends MediaRepository {
  _RejectDeleteRepository(super.database);

  @override
  Future<void> deleteBatch(String id) async => throw StateError('write failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Encode(image.encodePng(image.Image(width: 12, height: 8)));
  const model = 'gpt-image-2';
  late AppDatabase database;
  late MediaRepository repository;
  late MediaFileStore files;
  late Directory root;
  ProviderConfig provider(String id) => ProviderConfig(
    id: id,
    name: id,
    baseUrl: 'https://example.test/v1',
    apiKey: 'fixture-key',
    enabled: true,
    models: const [model],
    providerType: ProviderKind.openai,
  );
  const request = MediaRequest(
    modelId: model,
    mode: MediaMode.image,
    prompt: 'An orange cat',
    count: 12,
    aspectRatio: '3:2',
  );
  String success(int count) => jsonEncode({
    'data': [
      for (var index = 0; index < count; index++) {'b64_json': png},
    ],
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = MediaRepository(database);
    root = await Directory.systemTemp.createTemp('kelivo-creation-');
    files = MediaFileStore(
      directory: () async => Directory(p.join(root.path, 'generations')),
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'a saved public fal endpoint without a verified result never submits a data-only job',
    () async {
      const id = 'fal-ai/sam-3/image-rle';
      final config = ProviderConfig.defaultsFor('fal').copyWith(
        id: 'OpenAI - fal',
        enabled: true,
        models: [id],
        modelOverrides: {
          id: {
            'falEndpoint': {'id': id, 'output': 'images'},
          },
        },
      );
      final methods = <String>[];
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        clientFactory: (_, _) => MockClient((request) async {
          methods.add(request.method);
          return http.Response(
            jsonEncode({
              'models': [
                falCatalogFixture(
                  id: id,
                  category: 'image-to-image',
                  inputs: {},
                  requiredInputs: [],
                  outputs: {
                    'rle': {'type': 'array'},
                  },
                ),
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(runner.dispose);
      final job = await runner.enqueue(
        provider: config,
        request: const MediaRequest(
          modelId: id,
          mode: MediaMode.image,
          prompt: 'Isolate the cat',
        ),
      );
      expect(await job.completed, GenerationStatus.failed);
      expect(methods, ['GET']);
    },
  );

  test(
    'large chunked JSON and declared oversized responses respect the transport boundary',
    () async {
      final inline = 'b' * (380 * 1024);
      final bytes = utf8.encode(jsonEncode({'data': inline}));
      final result = await readMediaJson(
        http.StreamedResponse(
          Stream.fromIterable([
            for (var offset = 0; offset < bytes.length; offset += 8192)
              bytes.sublist(offset, (offset + 8192).clamp(0, bytes.length)),
          ]),
          200,
        ),
      );
      expect(result['data'], inline);
      final oversized = http.StreamedResponse(
        const Stream.empty(),
        200,
        contentLength: maxMediaResponseBytes + 1,
      );
      await expectLater(readMediaJson(oversized), throwsA(isA<MediaFailure>()));
    },
  );

  test(
    'cold start removes unpublished generation files and retains committed artwork and references',
    () async {
      const id = 'interrupted';
      const referenced = 'bbbbbbbb-1111-4444-8888-111111111111.png';
      await repository.enqueue(
        GenerationBatchRowsCompanion.insert(
          id: id,
          providerId: 'p',
          modelId: model,
          mode: MediaMode.image,
          prompt: 'circle',
          // A restored row may contain request metadata that cannot be replayed.
          paramsJson: '{"count":"invalid"}',
          referencesJson: jsonEncode([
            {'path': 'kelivo-file:///generations/$id/$referenced'},
          ]),
          status: GenerationStatus.interrupted,
          source: GenerationSource.workbench,
          createdAt: DateTime.now(),
        ),
      );
      final batch = await Directory(
        p.join(root.path, 'generations', id),
      ).create(recursive: true);
      const kept = 'faaaaaaa-1aaa-4aaa-8aaa-111111111111.png';
      const orphan = 'aaaaaaaa-1111-4444-8888-111111111111.png';
      for (final name in [
        kept,
        referenced,
        orphan,
        'unfinished.part.mp4',
        'refs/0.png',
        'thumbs/$orphan',
        'notes.txt',
      ]) {
        final file = File(p.join(batch.path, name));
        await file.parent.create(recursive: true);
        await file.writeAsString('example');
      }
      await repository.addItem(
        GenerationItemRow(
          id: 'retained',
          batchId: id,
          ordinal: 0,
          mode: MediaMode.image,
          path: 'kelivo-file:///generations/$id/$kept',
          mime: 'image/png',
          byteSize: 7,
          status: GenerationItemStatus.ready,
          favorite: false,
          createdAt: DateTime.now(),
        ),
      );
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
      );
      await runner.initialized;
      final interrupted = (await repository.batch(id))!;
      // Chat cards recognize malformed saved requests as a formatting error.
      expect(() => MediaRequest.fromBatch(interrupted), throwsFormatException);
      expect(
        () =>
            MediaRequest.fromBatch(interrupted.copyWith(referencesJson: '[]')),
        throwsFormatException,
      );
      expect(await File(p.join(batch.path, kept)).exists(), isTrue);
      expect(await File(p.join(batch.path, referenced)).exists(), isTrue);
      expect(await File(p.join(batch.path, 'refs/0.png')).exists(), isTrue);
      expect(await File(p.join(batch.path, 'notes.txt')).exists(), isTrue);
      for (final name in [orphan, 'unfinished.part.mp4', 'thumbs/$orphan']) {
        expect(await File(p.join(batch.path, name)).exists(), isFalse);
      }
      await runner.shutdown();
      runner.dispose();
    },
  );

  test(
    'retrying the original H3 404 preserves the prompt and records the supported resolution',
    () async {
      const id = 'minimax-h3';
      const prompt = 'Run through a park';
      final cfg = provider(
        'test-relay',
      ).copyWith(baseUrl: 'https://tokendance.space/gateway/v1', models: [id]);
      await repository.enqueue(
        GenerationBatchRowsCompanion.insert(
          id: 'old-h3',
          errorJson: const Value(
            '{"statusCode":404,"request":{"host":"tokendance.space","method":"POST","route":"/…/…/videos"}}',
          ),
          providerId: cfg.id,
          modelId: id,
          mode: MediaMode.video,
          prompt: prompt,
          paramsJson:
              '{"aspectRatio":"16:9","durationSec":5,"resolution":"720p"}',
          referencesJson: '[]',
          status: GenerationStatus.failed,
          source: GenerationSource.workbench,
          createdAt: DateTime.now(),
        ),
      );
      var submissions = 0;
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        delay: (_) async {},
        clientFactory: (_, _) => MockClient((r) async {
          if (r.url.host == 'cdn.test') {
            expect(r.headers.containsKey('authorization'), isFalse);
            return http.Response.bytes([
              0,
              0,
              0,
              24,
              ...ascii.encode('ftypisom'),
            ], 200);
          }
          if (r.method == 'POST') {
            submissions++;
            final body = jsonDecode(r.body);
            expect(r.url.path, '/gateway/minimax/v2/video_generation');
            expect(body['resolution'], '768P');
            expect(body['duration'], 5);
            expect(body['content'].first['text'], prompt);
            return http.Response('{"task_id":"job"}', 200);
          }
          return http.Response(
            '{"task":{"status":"succeeded","content":{"url":"https://cdn.test/video"}}}',
            200,
          );
        }),
      );
      addTearDown(runner.shutdown);
      expect(
        await (await runner.retry('old-h3', cfg))!.completed,
        GenerationStatus.succeeded,
      );
      final batch = (await repository.batch('old-h3'))!;
      expect(jsonDecode(batch.paramsJson)['resolution'], '768p');
      expect(
        (await repository.itemsForBatch(batch.id)).single.mime,
        'video/mp4',
      );
      await repository.enqueue(
        GenerationBatchRowsCompanion.insert(
          id: 'old-relay',
          providerId: cfg.id,
          modelId: id,
          errorJson: const Value(
            '{"statusCode":404,"request":{"host":"another.test","method":"POST","route":"/…/videos"}}',
          ),
          mode: MediaMode.video,
          prompt: prompt,
          paramsJson:
              '{"aspectRatio":"16:9","durationSec":5,"resolution":"720p"}',
          referencesJson: '[]',
          status: GenerationStatus.failed,
          source: GenerationSource.workbench,
          createdAt: DateTime.now(),
        ),
      );
      await expectLater(
        runner.retry('old-relay', cfg),
        throwsA(isA<MediaFailure>()),
      );
      expect(
        jsonDecode(
          (await repository.batch('old-relay'))!.paramsJson,
        )['resolution'],
        '720p',
      );
      expect(submissions, 1);
    },
  );

  test(
    'a retry keeps its output ordinals after another artwork is deleted',
    () async {
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        clientFactory: (_, _) => MockClient((sent) async {
          expect(jsonDecode(sent.body)['n'], 2);
          requested.complete();
          return response.future;
        }),
      );
      addTearDown(() {
        if (!response.isCompleted) response.complete(http.Response('', 400));
        runner.dispose();
      });
      await runner.initialized;
      final date = DateTime(2026);
      await repository.enqueue(
        GenerationBatchRowsCompanion.insert(
          id: 'retry-slots',
          providerId: 'retry-provider',
          modelId: model,
          mode: MediaMode.image,
          prompt: 'A test',
          paramsJson: jsonEncode(request.copyWith(count: 3).storedParameters),
          referencesJson: '[]',
          status: GenerationStatus.partial,
          source: GenerationSource.workbench,
          createdAt: date,
        ),
      );
      await repository.addItem(
        GenerationItemRow(
          id: 'remaining-item',
          batchId: 'retry-slots',
          ordinal: 1,
          mode: MediaMode.image,
          path: 'kelivo-file:///generations/retry-slots/remaining.png',
          mime: 'image/png',
          byteSize: 1,
          favorite: false,
          status: GenerationItemStatus.ready,
          createdAt: date,
        ),
      );
      final ticket = (await runner.retry(
        'retry-slots',
        provider('retry-provider'),
      ))!;
      await requested.future.timeout(const Duration(seconds: 5));
      const slots = (first: 2, end: 4, next: 2);
      expect(runner.resultSlotsFor('retry-slots'), slots);
      await repository.deleteItem('remaining-item');
      expect(runner.resultSlotsFor('retry-slots'), slots);
      response.complete(http.Response(success(2), 200));
      expect(await ticket.completed, GenerationStatus.succeeded);
      expect(
        (await repository.itemsForBatch(
          'retry-slots',
        )).map((item) => item.ordinal),
        [2, 3],
      );
    },
  );

  for (final status in [null, 502, 504]) {
    test(
      'an uncertain generation response ($status) does not submit a second billable job',
      () async {
        var calls = 0;
        final runner = MediaGenerationRunner(
          repository: repository,
          files: files,
          delay: (_) async {},
          clientFactory: (_, _) => MockClient((r) async {
            calls++;
            if (status != null) return http.Response('Gateway failure', status);
            throw http.ClientException('Response lost', r.url);
          }),
        );
        addTearDown(runner.shutdown);
        final cfg = provider(
          'router-loss',
        ).copyWith(baseUrl: 'https://openrouter.ai/api/v1');
        final ticket = await runner.enqueue(
          provider: cfg,
          request: const MediaRequest(
            modelId: model,
            mode: MediaMode.image,
            prompt: 'Lake',
          ),
        );
        expect(await ticket.completed, GenerationStatus.failed);
        final failure = jsonDecode(
          (await repository.batch(ticket.batchId))!.errorJson!,
        );
        expect(failure['automaticRetry'], isFalse);
        expect(failure['statusCode'], status);
        expect(calls, 1);
      },
    );
  }

  test(
    'failed generation diagnostics retain only allowlisted request fields',
    () async {
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        clientFactory: (_, _) => MockClient((sent) async {
          expect(sent.headers['authorization'], 'Bearer fixture-key');
          final body = jsonDecode(sent.body) as Map;
          expect(body['prompt'], 'An orange cat');
          return http.Response(
            '{"error":{"code":"private-error-code","message":"response-private-value"}}',
            400,
          );
        }),
      );
      addTearDown(runner.dispose);
      final saved = <String>[];
      final subscription = runner.mediaOutputsSaved.listen(saved.add);
      addTearDown(subscription.cancel);
      final ticket = await runner.enqueue(
        provider: provider('diagnostics'),
        request: request,
      );
      expect(await ticket.completed, GenerationStatus.failed);
      await Future<void>.delayed(Duration.zero);
      expect(saved, isEmpty);
      final error = (await repository.batch(ticket.batchId))!.errorJson!;
      expect(error, isNot(contains('fixture-key')));
      expect(error, isNot(contains('An orange cat')));
      expect(error, isNot(contains('response-private-value')));
      expect(error, isNot(contains('private-error-code')));
      expect(jsonDecode(error)['request'], {
        'method': 'POST',
        'host': 'example.test',
        'route': '/v1/images/generations',
        'body': {'n': 10, 'size': '1536x1024'},
      });
      expect(jsonDecode(error)['response'], {
        'status': 400,
        'body': {'kind': 'parameters'},
      });
    },
  );

  test(
    'one logical batch retries a rate limit, splits the count and saves files',
    () async {
      final counts = <int>[];
      final delays = <Duration>[];
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        delay: (value) async => delays.add(value),
        clientFactory: (_, _) => MockClient((sent) async {
          expect(sent.url.path, '/v1/images/generations');
          expect(sent.headers['authorization'], 'Bearer fixture-key');
          final body = jsonDecode(sent.body) as Map;
          expect(body['size'], '1536x1024');
          final count = body['n'] as int;
          counts.add(count);
          if (counts.length == 1) {
            return http.Response(
              '{"error":{"code":"rate_limit"}}',
              429,
              headers: {'retry-after': '3'},
            );
          }
          return http.Response(success(count), 200);
        }),
      );
      addTearDown(runner.dispose);
      final saved = <String>[];
      final subscription = runner.mediaOutputsSaved.listen(saved.add);
      addTearDown(subscription.cancel);
      final ticket = await runner.enqueue(
        provider: provider('first'),
        request: request,
      );
      expect(await ticket.completed, GenerationStatus.succeeded);
      await Future<void>.delayed(Duration.zero);
      expect(saved, ['first']);
      expect(counts, [10, 10, 2]);
      expect(delays, [const Duration(seconds: 3)]);
      final stored = await repository.itemsForBatch(ticket.batchId);
      expect(stored.length, 12);
      expect(
        stored.map((row) => row.ordinal),
        List.generate(12, (index) => index),
      );
      for (final item in stored) {
        expect(item.width, 12);
        expect(item.height, 8);
        expect(
          File(
            KelivoFileUri.resolveToAbsolute(item.path, root: root.path)!,
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            KelivoFileUri.resolveToAbsolute(
              item.thumbnailPath!,
              root: root.path,
            )!,
          ).existsSync(),
          isTrue,
        );
      }
    },
  );

  test(
    'per-provider and global caps hold across queued and cancelled work',
    () async {
      final waiting = <String, List<Completer<http.Response>>>{};
      final slotsFilled = Completer<void>();
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        clientFactory: (provider, token) => MockClient((_) {
          final gate = Completer<http.Response>();
          (waiting[provider.id] ??= []).add(gate);
          if (!slotsFilled.isCompleted &&
              waiting.values.fold(0, (n, jobs) => n + jobs.length) ==
                  MediaGenerationRunner.maxActive) {
            slotsFilled.complete();
          }
          return Future.any([
            gate.future,
            token.whenCancel.then<http.Response>((e) => throw e),
          ]);
        }),
      );
      addTearDown(runner.dispose);
      final tickets = <MediaGenerationTicket>[];
      for (final name in [
        'first',
        'first',
        'first',
        'second',
        'second',
        'third',
      ]) {
        tickets.add(
          await runner.enqueue(
            provider: provider(name),
            request: request.copyWith(count: 1),
          ),
        );
      }
      await slotsFilled.future.timeout(const Duration(seconds: 5));
      expect(waiting['first'], hasLength(2));
      expect(waiting['second'], hasLength(2));
      expect(waiting['third'], isNull);
      expect(
        (await repository.batch(tickets[2].batchId))!.status,
        GenerationStatus.queued,
      );
      await runner.cancel(tickets[0].batchId);
      expect(await tickets[0].completed, GenerationStatus.cancelled);
      for (final ticket in tickets.skip(1)) {
        await runner.cancel(ticket.batchId);
        expect(await ticket.completed, GenerationStatus.cancelled);
      }
    },
  );

  test('shutdown finishes work accepted while enqueue is writing', () async {
    final held = _HeldEnqueueRepository(database);
    final runner = MediaGenerationRunner(
      repository: held,
      files: files,
      clientFactory: (_, _) => throw StateError('No request should run'),
    );
    addTearDown(runner.dispose);
    final accepting = runner.enqueue(
      provider: provider('first'),
      request: request,
    );
    await held.entered.future;
    final closing = runner.shutdown();
    held.release.complete();
    final ticket = await accepting;
    await closing.timeout(const Duration(seconds: 3));
    expect(await ticket.completed, GenerationStatus.interrupted);
    expect(
      (await held.batch(ticket.batchId))?.status,
      GenerationStatus.interrupted,
    );
  });

  test('oversized combined references are rejected before copying', () async {
    final sources = <MediaReference>[];
    for (var index = 0; index < 2; index++) {
      final file = File(p.join(root.path, 'reference-$index.png'));
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(11 * 1024 * 1024);
      await handle.close();
      sources.add(MediaReference(file.path));
    }
    await expectLater(
      files.snapshotReferences('too-large', sources),
      throwsA(
        isA<MediaFailure>().having(
          (failure) => failure.kind,
          'kind',
          MediaFailureKind.referenceTooLarge,
        ),
      ),
    );
    expect(await Directory(p.join(root.path, 'generations')).exists(), isFalse);
  });

  test(
    'video content follows a signed redirect without forwarding auth',
    () async {
      var submits = 0;
      final gateway = provider('gateway').copyWith(models: ['sora-2']);
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        delay: (_) async {},
        clientFactory: (_, _) => MockClient((sent) async {
          if (sent.method == 'POST') {
            submits++;
            return http.Response('{"id":"video-job","status":"queued"}', 200);
          }
          if (sent.url.path == '/v1/videos/video-job') {
            return http.Response('{"status":"completed","seconds":"8"}', 200);
          }
          if (sent.url.path.endsWith('/content')) {
            expect(sent.headers['authorization'], 'Bearer fixture-key');
            return http.Response(
              '',
              302,
              headers: {'location': 'https://cdn.test/movie.mp4'},
            );
          }
          expect(sent.url.host, 'cdn.test');
          expect(sent.headers['authorization'], isNull);
          return http.Response.bytes([
            0,
            0,
            0,
            12,
            ...ascii.encode('ftypmp42'),
          ], 200);
        }),
      );
      addTearDown(runner.dispose);
      final ticket = await runner.enqueue(
        provider: gateway,
        request: const MediaRequest(
          modelId: 'sora-2',
          mode: MediaMode.video,
          prompt: 'A scene',
          aspectRatio: '16:9',
          durationSec: 8,
          resolution: '720p',
        ),
      );
      expect(await ticket.completed, GenerationStatus.succeeded);
      expect(submits, 1);
      final item = (await repository.itemsForBatch(ticket.batchId)).single;
      expect(item.mime, 'video/mp4');
      expect(item.path, endsWith('.mp4'));
      expect((item.width, item.height, item.durationMs), (1280, 720, 8000));
    },
  );

  test('QuickTime results keep the MOV container and MIME type', () async {
    final client = MockClient((_) async => fail('inline movie'));
    addTearDown(client.close);
    final item = await files.store(
      batchId: '45b9adc1-2a67-43c3-85df-3a7ab80ce22f',
      ordinal: 0,
      mode: MediaMode.video,
      result: MediaResult(
        mime: 'video/quicktime',
        base64: base64Encode([0, 0, 0, 12, ...ascii.encode('ftypqt  ')]),
      ),
      downloadClient: client,
      publish: (_) async {},
    );
    expect(item.mime, 'video/quicktime');
    expect(item.path, endsWith('.mov'));
  });

  test(
    'New API retries an interrupted result download without resubmitting its billable job',
    () async {
      const id = 'private-video';
      final cfg = provider('custom-new-api').copyWith(
        models: [id],
        modelOverrides: {
          id: {
            'type': 'video',
            'media': {'protocol': 'newApiVideo'},
          },
        },
      );
      final calls = <String>[];
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
        delay: (_) async {},
        clientFactory: (_, _) => MockClient((sent) async {
          calls.add('${sent.method} ${sent.url.path}');
          if (sent.url.path == '/v1/video/generations') {
            return http.Response(
              '{"task_id":"original","status":"queued"}',
              202,
            );
          }
          if (sent.url.path == '/v1/video/generations/original') {
            return http.Response(
              '{"code":"success","data":{"status":"SUCCESS","result_url":"/v1/videos/original/content","metadata":{"duration":5}}}',
              200,
            );
          }
          expect(sent.headers['authorization'], 'Bearer fixture-key');
          if (calls
                  .where((call) => call == 'GET /v1/videos/original/content')
                  .length ==
              1) {
            return http.Response('temporary', 503);
          }
          return http.Response.bytes([
            0,
            0,
            0,
            12,
            ...ascii.encode('ftypmp42'),
          ], 200);
        }),
      );
      addTearDown(runner.dispose);
      final ticket = await runner.enqueue(
        provider: cfg,
        request: const MediaRequest(
          mode: MediaMode.video,
          modelId: id,
          prompt: 'Clouds',
          aspectRatio: '16:9',
          durationSec: 5,
          resolution: '720p',
        ),
      );
      expect(await ticket.completed, GenerationStatus.succeeded);
      expect(calls, [
        'POST /v1/video/generations',
        'GET /v1/video/generations/original',
        'GET /v1/videos/original/content',
        'GET /v1/videos/original/content',
      ]);
      final item = (await repository.itemsForBatch(ticket.batchId)).single;
      expect(item.durationMs, 5000);
      expect(item.mime, 'video/mp4');
      expect(
        await File(
          KelivoFileUri.resolveToAbsolute(item.path, root: root.path)!,
        ).exists(),
        true,
      );
    },
  );

  test('remote poll errors do not submit a second generation job', () async {
    var submits = 0;
    var reads = 0;
    final delays = <Duration>[];
    final gateway = provider('gateway').copyWith(models: ['sora-2']);
    final runner = MediaGenerationRunner(
      repository: repository,
      files: files,
      delay: (duration) async => delays.add(duration),
      clientFactory: (_, _) => MockClient((sent) async {
        if (sent.method == 'POST') {
          submits++;
          return http.Response('{"id":"video-job","status":"queued"}', 200);
        }
        reads++;
        return http.Response('{"error":{"code":"overload"}}', 503);
      }),
    );
    addTearDown(runner.dispose);
    final ticket = await runner.enqueue(
      provider: gateway,
      request: const MediaRequest(
        modelId: 'sora-2',
        mode: MediaMode.video,
        prompt: 'A scene',
        aspectRatio: '16:9',
      ),
    );
    expect(await ticket.completed, GenerationStatus.failed);
    expect(submits, 1);
    expect(reads, 4);
    expect(delays.map((duration) => duration.inSeconds), [2, 1, 2, 4]);
    final details = jsonDecode(
      (await repository.batch(ticket.batchId))!.errorJson!,
    );
    final retries = (details['retries'] as List).cast<Map<String, dynamic>>();
    expect(retries.map((attempt) => attempt['status']), [503, 503, 503]);
    expect(retries.map((attempt) => attempt['waitMs']), [1000, 2000, 4000]);
  });

  test('retired hosts are excluded and Vertex AI retains Veo', () {
    const resolver = MediaAdapterResolver();
    final openai = provider(
      'openai',
    ).copyWith(baseUrl: 'https://api.openai.com/v1');
    expect(resolver.resolve(openai, MediaMode.video), isNull);
    final gemini = provider('gemini').copyWith(
      providerType: ProviderKind.google,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    );
    expect(resolver.resolve(gemini, MediaMode.video), isNull);
    expect(
      resolver.resolve(gemini.copyWith(vertexAI: true), MediaMode.video),
      isA<VeoVideoAdapter>(),
    );
  });

  test(
    'creation cleanup deletes finished batches before the date cutoff',
    () async {
      final runner = MediaGenerationRunner(
        repository: repository,
        files: files,
      );
      addTearDown(runner.dispose);
      await runner.initialized;
      final cutoff = DateTime(2026, 10, 2);
      final before = cutoff.subtract(const Duration(days: 1));
      final generations = await files.directory();
      for (final (id, date, status) in [
        ('older', before, GenerationStatus.succeeded),
        ('older-failed', before, GenerationStatus.failed),
        ('older-active', before, GenerationStatus.downloading),
        ('at-cutoff', cutoff, GenerationStatus.succeeded),
      ]) {
        await repository.enqueue(
          GenerationBatchRowsCompanion.insert(
            id: id,
            providerId: 'provider',
            modelId: model,
            mode: MediaMode.image,
            prompt: 'Fixture',
            paramsJson: '{}',
            referencesJson: '[]',
            status: status,
            source: GenerationSource.workbench,
            createdAt: date,
          ),
        );
        final folder = await Directory(
          p.join(generations.path, id, 'refs'),
        ).create(recursive: true);
        await File(p.join(folder.path, 'reference.png')).writeAsBytes([0]);
        if (status == GenerationStatus.succeeded) {
          await repository.addItem(
            GenerationItemRow(
              id: '$id-item',
              batchId: id,
              ordinal: 0,
              mode: MediaMode.image,
              path: 'kelivo-file:///generations/$id/artwork.png',
              mime: 'image/png',
              byteSize: 1,
              favorite: false,
              status: GenerationItemStatus.ready,
              createdAt: date,
            ),
          );
        }
      }
      expect(
        await StorageUsageService.clearCreationBatches(runner, cutoff: cutoff),
        2,
      );
      expect(await repository.itemsForBatch('older'), isEmpty);
      for (final id in ['older', 'older-failed']) {
        expect(await repository.batch(id), isNull);
        expect(await Directory(p.join(generations.path, id)).exists(), isFalse);
      }
      for (final id in ['older-active', 'at-cutoff']) {
        expect(await repository.batch(id), isNotNull);
        expect(await Directory(p.join(generations.path, id)).exists(), isTrue);
      }
      expect(
        await StorageUsageService.clearCreationBatches(runner, cutoff: cutoff),
        0,
      );
    },
  );

  test('unfinished rows are marked interrupted on startup', () async {
    for (final status in [
      GenerationStatus.queued,
      GenerationStatus.running,
      GenerationStatus.downloading,
      GenerationStatus.succeeded,
    ]) {
      await repository.enqueue(
        GenerationBatchRowsCompanion.insert(
          id: status.name,
          providerId: 'provider',
          modelId: model,
          mode: MediaMode.image,
          prompt: 'A test',
          paramsJson: '{}',
          referencesJson: '[]',
          status: status,
          source: GenerationSource.workbench,
          createdAt: DateTime.now(),
        ),
      );
    }
    final runner = MediaGenerationRunner(repository: repository, files: files);
    addTearDown(runner.dispose);
    await runner.initialized;
    for (final status in [
      GenerationStatus.queued,
      GenerationStatus.running,
      GenerationStatus.downloading,
    ]) {
      expect(
        (await repository.batch(status.name))!.status,
        GenerationStatus.interrupted,
      );
    }
    expect(
      (await repository.batch('succeeded'))!.status,
      GenerationStatus.succeeded,
    );
  });

  test('cleanup restores the files if the database delete fails', () async {
    final rejecting = _RejectDeleteRepository(database);
    final runner = MediaGenerationRunner(repository: rejecting, files: files);
    addTearDown(runner.dispose);
    await runner.initialized;
    final date = DateTime(2026);
    await repository.enqueue(
      GenerationBatchRowsCompanion.insert(
        id: 'protected',
        providerId: 'provider',
        modelId: model,
        mode: MediaMode.image,
        prompt: 'A test',
        paramsJson: '{}',
        referencesJson: '[]',
        status: GenerationStatus.succeeded,
        source: GenerationSource.workbench,
        createdAt: date,
      ),
    );
    final file = File(
      p.join((await files.directory()).path, 'protected', 'image.png'),
    );
    await file.create(recursive: true);
    await file.writeAsString('fixture artwork');
    await expectLater(
      StorageUsageService.clearCreationBatches(
        runner,
        cutoff: DateTime(2026, 10),
      ),
      throwsStateError,
    );
    expect(await repository.batch('protected'), isNotNull);
    expect(await file.readAsString(), 'fixture artwork');

    final folder = file.parent;
    final pending = await Directory(
      p.join(folder.parent.path, '.pending-deletions'),
    ).create();
    await folder.rename(p.join(pending.path, 'protected'));
    final removed = await Directory(
      p.join(pending.path, 'already-removed'),
    ).create();
    await runner.recoverBatchDeletions();
    expect(await file.readAsString(), 'fixture artwork');
    expect(await removed.exists(), isFalse);
  });
}
