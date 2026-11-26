import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/media_repository.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/adapters/fal_media.dart';
import 'package:Kelivo/core/services/media/fal_model_discovery.dart';
import 'package:Kelivo/core/services/media/fal_batch_state.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/media/media_file_store.dart';
import 'package:Kelivo/core/services/media/media_generation_runner.dart';
import 'package:Kelivo/features/media/providers/media_creation_controller.dart';
import 'package:Kelivo/features/media/widgets/creation_advanced_options.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/fal_catalog_fixture.dart';

const _builtin = 'fal-ai/flux/schnell';
const _edit = 'bytedance/seedream/v5/flash/edit';

Future<Map<String, dynamic>> _describe(String id) async {
  final row = falCatalogFixture(
    id: id,
    category: id == _edit ? 'image-to-image' : 'text-to-image',
    inputs: {
      'prompt': {'type': 'string'},
      if (id == _edit)
        'image_urls': {
          'type': 'array',
          'items': {'type': 'string'},
          'minItems': 1,
          'maxItems': 3,
        },
      'output_format': {
        'type': 'string',
        'enum': ['jpeg', 'png'],
        'default': 'jpeg',
      },
      'image_size': {
        'anyOf': [
          {'type': 'object'},
          {
            'type': 'string',
            'enum': ['auto_1K', 'auto_1.5K', 'auto_2K'],
          },
        ],
      },
      'watermark': {'type': 'boolean', 'default': false},
      if (id.contains('/v4/'))
        'max_images': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 6,
          'default': 1,
        },
      'sync_mode': {'type': 'boolean', 'default': false},
      'enable_safety_checker': {
        'type': 'boolean',
        'default': true,
        'description': 'Subject to account permissions.',
      },
      'background': {
        'type': 'string',
        'enum': ['opaque', 'transparent'],
        'default': 'opaque',
      },
      'num_inference_steps': {
        'type': 'integer',
        'minimum': 1,
        'maximum': 12,
        'default': 3,
      },
      'strength': {
        'anyOf': [
          {
            'type': 'number',
            'minimum': 0,
            'exclusiveMaximum': 1,
            'multipleOf': 0.25,
          },
          {'type': 'null'},
        ],
        'default': 0.5,
      },
      'loras': {
        'type': 'array',
        'items': {r'$ref': '#/components/schemas/LoraWeight'},
      },
      'version': {'type': 'string', 'const': '1.0'},
      'variant': {'type': 'string', 'default': 'balanced'},
      'format': {'type': 'string'},
      'automatic_feature': {'type': 'boolean', 'default': true},
      'locked': {'type': 'boolean', 'readOnly': true, 'default': true},
    },
    requiredInputs: [
      'prompt',
      'version',
      'variant',
      if (id == _edit) 'image_urls',
    ],
    outputs: {
      'images': {'type': 'array', 'items': falFileFixture},
    },
  );
  row['openapi']['components']['schemas']['LoraWeight'] = {
    'type': 'object',
    'required': ['path'],
    'properties': {
      'path': {'type': 'string'},
      'scale': {'type': 'number', 'minimum': 0, 'maximum': 4},
    },
  };
  row['openapi']['components']['schemas']['Input']['x-fal-order-properties'] = [
    'background',
    'watermark',
    'sync_mode',
    'enable_safety_checker',
  ];
  final client = MockClient((request) async {
    expect(request.url.queryParameters, {
      'endpoint_id': id,
      'expand': 'openapi-3.0',
    });
    return http.Response(
      jsonEncode({
        'models': [row],
      }),
      200,
    );
  });
  try {
    return (await FalModelDiscovery(client).lookup(id))!;
  } finally {
    client.close();
  }
}

Future<MediaCreationController> _controller(
  ProviderConfig config, {
  required Future<Map<String, dynamic>> Function(
    ProviderConfig,
    String,
    CancelToken,
  )
  fetch,
  MediaFileStore files = const MediaFileStore(),
  http.Client Function()? client,
}) async {
  final harness = await createBusinessTestHarness(
    initial: {BusinessKeyRegistry.creationAutoTitleKey: false},
  );
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  await settings.setProviderConfig(config.id, config);
  final runner = MediaGenerationRunner(
    repository: MediaRepository(harness.database),
    files: files,
    clientFactory: client == null ? null : (_, _) => client(),
    delay: (_) async {},
  );
  final media = MediaCreationController(
    runner: runner,
    settings: settings,
    preferences: harness.preferences,
    fetchFalEndpoint: fetch,
  );
  addTearDown(() async {
    media.dispose();
    await runner.shutdown();
    runner.dispose();
    settings.dispose();
  });
  media.selectModel(
    media
        .modelsFor(MediaMode.image)
        .firstWhere(
          (m) => m.spec.id == config.models.first && m.provider.id == config.id,
        ),
  );
  return media;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalog and built-in models expose typed, ordered controls alongside common controls',
    () async {
      for (final id in [_builtin, _edit]) {
        final description = await _describe(id);
        expect(description.containsKey('openapi'), isFalse);
        final provider = ProviderConfig.defaultsFor('fal').copyWith(
          models: [id],
          modelOverrides: {
            id: {'falEndpoint': description},
          },
        );
        final caps = const FalMediaAdapter(
          MediaMode.image,
        ).capabilities(provider, id);
        final fields = {for (final p in caps.platformOptions) p.key: p};
        expect(fields.length, caps.platformOptions.length);
        expect(fields.keys.take(4), [
          'background',
          'watermark',
          'sync_mode',
          'enable_safety_checker',
        ]);
        expect(fields.keys, isNot(contains('output_format')));
        expect(fields.keys, isNot(contains('image_size')));
        expect(caps.formats, containsAll(['jpeg', 'png']));
        expect(caps.sizes, contains('1.5K'));
        expect(fields['watermark']!.defaultValue, false);
        expect(fields['enable_safety_checker']!.defaultValue, true);
        expect(fields['locked']!.readOnly, true);
        expect(fields['strength']!.parseDraft('0'), 0);
        expect(fields['strength']!.acceptsDraft('1'), isFalse);
        expect(fields['strength']!.acceptsDraft('0.1'), isFalse);
        expect(fields['strength']!.parseDraft('0.25'), 0.25);
        expect(fields['version']!.constant, true);
        expect(fields['variant']!.required, true);
        for (final value in [
          '{}',
          '[4]',
          '[{"url":"first"}]',
          '[{"path":"first","scale":7}]',
        ]) {
          expect(fields['loras']!.acceptsDraft(value), false);
        }
        expect(fields['loras']!.parseDraft('[{"path":"first"}]'), [
          {'path': 'first'},
        ]);
        if (id == _builtin) {
          expect(
            fields['num_inference_steps']!.storageKey,
            'num_inference_steps',
          );
        }
      }
    },
  );

  testWidgets(
    'More hydrates existing built-ins on demand, remembers the fields and offers refresh',
    (tester) async {
      final data = await _describe(_builtin);
      final response = Completer<Map<String, dynamic>>();
      var calls = 0;
      final media = (await tester.runAsync(
        () => _controller(
          ProviderConfig.defaultsFor(
            'fal',
          ).copyWith(enabled: true, models: [_builtin]),
          fetch: (_, _, _) {
            calls++;
            return calls == 1 ? response.future : Future.value(data);
          },
        ),
      ))!;
      Widget app(bool open) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: media.settings),
          ChangeNotifierProvider.value(value: media),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: open
                ? const SingleChildScrollView(child: CreationAdvancedOptions())
                : const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(app(false));
      expect(calls, 0);
      await tester.pumpWidget(app(true));
      expect(calls, 1);
      expect(find.text('Additional Settings'), findsOneWidget);
      await tester.runAsync(() async {
        response.complete(data);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      Finder toggle(String id) => find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byType(IosSwitch),
      );
      expect(tester.widget<IosSwitch>(toggle('watermark')).value, false);
      expect(
        tester.widget<IosSwitch>(toggle('enable_safety_checker')).value,
        true,
      );
      expect(tester.widget<IosSwitch>(toggle('locked')).onChanged, isNull);
      expect(find.text('Subject to account permissions.'), findsOneWidget);
      await tester.ensureVisible(toggle('watermark'));
      await tester.tap(toggle('watermark'));
      await tester.pumpAndSettle();
      expect(media.parameters['fal:watermark'], true);
      await tester.pumpWidget(app(false));
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.widget<IosSwitch>(toggle('watermark')).value, true);
      final refresh = find.byTooltip('Refresh model settings');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'leaving a model while loading does not replace the saved settings of either model',
    () async {
      const other = 'fal-ai/flux-2-pro';
      final response = Completer<Map<String, dynamic>>();
      final media = await _controller(
        ProviderConfig.defaultsFor(
          'fal',
        ).copyWith(enabled: true, models: [_builtin, other]),
        fetch: (_, _, _) => response.future,
      );
      final old = media.model!;
      final pending = media.refreshFalSettings(old, CancelToken());
      media.selectModel(
        media
            .modelsFor(MediaMode.image)
            .firstWhere((item) => item.spec.id == other),
      );
      response.complete(await _describe(_builtin));
      expect(await pending, isNull);
      expect(
        media.settings.getProviderConfig('fal').modelOverrides,
        old.provider.modelOverrides,
      );
    },
  );

  test(
    'a temporary outage or unpublished schema preserves cached settings and allows retry',
    () async {
      final cached = await _describe(_builtin);
      var calls = 0;
      final media = await _controller(
        ProviderConfig.defaultsFor('fal').copyWith(
          enabled: true,
          models: [_builtin],
          modelOverrides: {
            _builtin: {'falEndpoint': cached},
          },
        ),
        fetch: (_, id, _) async => switch (++calls) {
          1 => throw const SocketException('offline'),
          2 => {'id': id, 'unlisted': true},
          _ => cached,
        },
      );
      Future<bool?> refresh() =>
          media.refreshFalSettings(media.model!, CancelToken());
      await expectLater(refresh(), throwsA(isA<SocketException>()));
      expect(await refresh(), false);
      expect(
        media.model!.provider.modelOverrides[_builtin]['falEndpoint'],
        cached,
      );
      expect(await refresh(), true);
    },
  );

  test(
    'Seedream keeps the requested number of files from a single generation',
    () async {
      const id = 'fal-ai/bytedance/seedream/v4/text-to-image';
      final description = await _describe(id);
      final root = await Directory.systemTemp.createTemp('fal-multi-');
      addTearDown(() => root.delete(recursive: true));
      final png = base64Encode(
        image.encodePng(image.Image(width: 5, height: 5)),
      );
      final submitted = <Object?>[];
      final media = await _controller(
        ProviderConfig.defaultsFor('fal').copyWith(
          enabled: true,
          apiKey: 'fixture',
          models: [id],
          modelOverrides: {
            id: {'falEndpoint': description},
          },
        ),
        fetch: (_, _, _) async => fail('cached schema should be used'),
        files: MediaFileStore(
          directory: () async => Directory('${root.path}/generations'),
        ),
        client: () => MockClient((request) async {
          if (request.method == 'POST') {
            submitted.add(jsonDecode(request.body)['max_images']);
            return http.Response(
              '{"request_id":"task","status":"COMPLETED"}',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'images': List.filled(3, {'url': 'data:image/png;base64,$png'}),
            }),
            200,
          );
        }),
      );
      final repo = media.runner.repository;
      for (final limit in [null, 2]) {
        media.setParameter('fal:max_images', limit);
        media.updatePrompt(null, 'A ceramic cup');
        final topic = (await media.submit(null))!;
        final batch = media.lastSubmission(topic)!;
        await repo
            .watchBatches()
            .firstWhere(
              (rows) => rows.any((b) => b.id == batch && !b.status.isActive),
            )
            .timeout(const Duration(seconds: 8));
        expect((await repo.itemsForBatch(batch)).length, limit ?? 1);
      }
      expect(submitted, [null, 2]);
    },
  );

  test(
    'an edit submits typed settings and saves the inline result when sync mode is selected',
    () async {
      final data = await _describe(_edit);
      final provider = ProviderConfig.defaultsFor('fal').copyWith(
        enabled: true,
        apiKey: 'fixture',
        models: [_edit],
        modelOverrides: {
          _edit: {'type': 'image', 'falEndpoint': data},
        },
      );
      final root = await Directory.systemTemp.createTemp('fal-settings-');
      SandboxPathResolver.debugSetDirs(docsDir: root.path);
      addTearDown(() async {
        SandboxPathResolver.debugSetDirs();
        await root.delete(recursive: true);
      });
      final png = image.encodePng(
        image.Image(width: 16, height: 12, numChannels: 4),
      );
      final source = await File('${root.path}/cup.png').writeAsBytes(png);
      final requests = <String>[];
      final bodies = <Map>[];
      final media = await _controller(
        provider,
        fetch: (_, _, _) async => fail('cached schema should be used'),
        files: MediaFileStore(
          directory: () async => Directory('${root.path}/generations'),
        ),
        client: () => MockClient((request) async {
          requests.add(request.method);
          if (request.method == 'POST') {
            bodies.add(jsonDecode(request.body) as Map);
            return http.Response(
              '{"request_id":"task","status":"COMPLETED"}',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'images': [
                {'url': 'data:image/png;base64,${base64Encode(png)}'},
              ],
            }),
            200,
          );
        }),
      );
      media.addReferencePaths(null, [source.path]);
      media.updatePrompt(null, 'Change the cup to green');
      media.setParameter('fal:strength', '1');
      expect(media.canSubmit(null), isFalse);
      media.setParameter('fal:strength', '0');
      media.setParameter('fal:watermark', true);
      media.setParameter('fal:sync_mode', true);
      media.setParameter('fal:automatic_feature', false);
      media.setParameter('fal:background', 'transparent');
      expect(media.parameters['format'], 'png');
      media.setParameter('format', 'jpeg');
      expect(media.canSubmit(null), false);
      media.setParameter(
        'format',
        null,
      ); // Automatic format must stay PNG for transparency.
      media.setParameter('fal:format', 'model value');
      media.setParameter('size', '1.5K');
      media.setParameter('fal:loras', '[{"path":"first"}]');
      expect(media.canSubmit(null), isTrue);
      final topic = (await media.submit(null))!;
      final id = media.lastSubmission(topic)!;
      final repo = media.runner.repository;
      final rows = await repo
          .watchBatches()
          .firstWhere(
            (rows) => rows.any((b) => b.id == id && !b.status.isActive),
          )
          .timeout(const Duration(seconds: 8));
      expect(
        rows.firstWhere((b) => b.id == id).status,
        GenerationStatus.succeeded,
      );
      expect(requests, ['POST', 'GET']);
      expect(bodies.single, {
        'prompt': 'Change the cup to green',
        'version': '1.0',
        'variant': 'balanced',
        'image_urls': ['data:image/png;base64,${base64Encode(png)}'],
        'watermark': true,
        'sync_mode': true,
        'automatic_feature': false,
        'strength': 0,
        'background': 'transparent',
        'output_format': 'png',
        'format': 'model value',
        'image_size': 'auto_1.5K',
        'loras': [
          {'path': 'first'},
        ],
      });
      final saved = (await repo.itemsForBatch(id)).single;
      expect(
        await File(SandboxPathResolver.resolveForIo(saved.path)!).readAsBytes(),
        png,
      );
    },
  );

  test(
    'partial fal download retries the saved queue result and keeps existing files',
    () async {
      const id = 'fal-ai/nano-banana';
      final desc = await _describe(id);
      final provider = ProviderConfig.defaultsFor('fal').copyWith(
        enabled: true,
        apiKey: 'fixture',
        models: [id],
        modelOverrides: {
          id: {'falEndpoint': desc},
        },
      );
      final root = await Directory.systemTemp.createTemp('fal-retry');
      addTearDown(() => root.delete(recursive: true));
      final png = base64Encode(
        image.encodePng(image.Image(width: 4, height: 4)),
      );
      var posts = 0, gets = 0;
      final media = await _controller(
        provider,
        fetch: (_, _, _) async => desc,
        files: MediaFileStore(
          directory: () async => Directory('${root.path}/generations'),
        ),
        client: () => MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            return http.Response(
              '{"request_id":"job","status":"COMPLETED"}',
              200,
            );
          }
          gets++;
          return http.Response(
            jsonEncode({
              'images': [
                {'url': 'data:image/png;base64,$png'},
                {'url': 'data:image/png;base64,${gets == 1 ? 'AAAA' : png}'},
              ],
            }),
            200,
          );
        }),
      );
      final request = MediaRequest(
        modelId: id,
        mode: MediaMode.image,
        prompt: 'A pair',
        parameters: const {
          'extra': {'limit_generations': false},
        },
      );
      final first = await media.runner.enqueue(
        provider: provider,
        request: request,
      );
      expect(await first.completed, GenerationStatus.partial);
      final repo = media.runner.repository;
      final retained = (await repo.itemsForBatch(first.batchId)).single;
      final row = (await repo.batch(first.batchId))!;
      final cursor = FalBatchState.fromParameters(row.paramsJson)!;
      expect(cursor.pending!.files, 2);
      expect(
        MediaRequest.fromBatch(row).parameters,
        isNot(contains(FalBatchState.key)),
      );
      final retry = (await media.runner.retry(first.batchId, provider))!;
      expect(await retry.completed, GenerationStatus.succeeded);
      final results = await repo.itemsForBatch(first.batchId);
      expect(results.map((r) => r.ordinal), [0, 1]);
      expect(results.first.id, retained.id);
      expect((posts, gets), (1, 2));
    },
  );

  test(
    'an interrupted second fal submission resumes by generations, not files',
    () async {
      const id = 'fal-ai/bytedance/seedream/v4/text-to-image';
      final desc = await _describe(id);
      final provider = ProviderConfig.defaultsFor('fal').copyWith(
        enabled: true,
        apiKey: 'fixture',
        models: [id],
        modelOverrides: {
          id: {'falEndpoint': desc},
        },
      );
      final root = await Directory.systemTemp.createTemp('fal-logical-count');
      addTearDown(() => root.delete(recursive: true));
      final png = base64Encode(
        image.encodePng(image.Image(width: 3, height: 3)),
      );
      final counts = <int>[];
      final media = await _controller(
        provider,
        fetch: (_, _, _) async => desc,
        files: MediaFileStore(
          directory: () async => Directory('${root.path}/generations'),
        ),
        client: () => MockClient((r) async {
          if (r.method == 'POST') {
            final body = jsonDecode(r.body);
            counts.add(body['num_images'] as int? ?? 1);
            if (counts.length == 2) {
              return http.Response('{"error":"failed"}', 422);
            }
            return http.Response(
              '{"request_id":"chunk","status":"COMPLETED"}',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'images': List.filled(counts.length == 1 ? 8 : 1, {
                'url': 'data:image/png;base64,$png',
              }),
            }),
            200,
          );
        }),
      );
      final first = await media.runner.enqueue(
        provider: provider,
        request: const MediaRequest(
          modelId: id,
          mode: MediaMode.image,
          prompt: 'A series',
          count: 7,
          parameters: {'fal:max_images': 2},
        ),
      );
      expect(await first.completed, GenerationStatus.partial);
      expect(
        await media.runner.repository.itemsForBatch(first.batchId),
        hasLength(8),
      );
      final retry = (await media.runner.retry(first.batchId, provider))!;
      expect(await retry.completed, GenerationStatus.succeeded);
      expect(counts, [6, 1, 1]);
      expect(
        await media.runner.repository.itemsForBatch(first.batchId),
        hasLength(9),
      );
    },
  );

  test(
    'video drafts retain their provider ID and requested final frame',
    () async {
      const id = 'bytedance/seedance-2.5/text-to-video';
      final provider = ProviderConfig.defaultsFor(
        'fal',
      ).copyWith(enabled: true, apiKey: 'fixture', models: [id, _builtin]);
      final root = await Directory.systemTemp.createTemp('fal-last-frame');
      addTearDown(() => root.delete(recursive: true));
      final clip = base64Encode([0, 0, 0, 12, ...ascii.encode('ftypqt  ')]);
      final png = base64Encode(
        image.encodePng(image.Image(width: 4, height: 4)),
      );
      final media = await _controller(
        provider.copyWith(models: [_builtin, id]),
        fetch: (_, _, _) async => fail('unexpected schema request'),
        files: MediaFileStore(
          directory: () async => Directory('${root.path}/generations'),
        ),
        client: () => MockClient(
          (r) async => r.method == 'POST'
              ? http.Response('{"request_id":"job","status":"COMPLETED"}', 200)
              : http.Response(
                  jsonEncode({
                    'video': {'url': 'data:video/quicktime;base64,$clip'},
                    'last_frame': {'url': 'data:image/png;base64,$png'},
                    'draft_id': 'draft-42',
                  }),
                  200,
                ),
        ),
      );
      final ticket = await media.runner.enqueue(
        provider: provider,
        request: const MediaRequest(
          modelId: id,
          mode: MediaMode.video,
          prompt: 'A scene',
          parameters: {
            'extra': {'draft': true, 'return_last_frame': true},
          },
        ),
      );
      expect(await ticket.completed, GenerationStatus.succeeded);
      final repo = media.runner.repository;
      final rows = await repo.itemsForBatch(ticket.batchId);
      expect(rows.map((r) => (r.mode, r.mime)), [
        (MediaMode.video, 'video/quicktime'),
        (MediaMode.image, 'image/png'),
      ]);
      expect(
        FalBatchState.fromParameters(
          (await repo.batch(ticket.batchId))!.paramsJson,
        )!.draftId,
        'draft-42',
      );
    },
  );

  test(
    'empty completed results can recover, and repeating uses the historical image count',
    () async {
      const id = 'fal-ai/flux/schnell';
      final provider = ProviderConfig.defaultsFor(
        'fal',
      ).copyWith(enabled: true, apiKey: 'key', models: [id]);
      final root = await Directory.systemTemp.createTemp('fal-empty');
      addTearDown(() => root.delete(recursive: true));
      final png = base64Encode(
        image.encodePng(image.Image(width: 4, height: 4)),
      );
      final counts = <int>[];
      var reads = 0;
      final media = await _controller(
        provider,
        fetch: (_, _, _) async => fail('no schema fetch'),
        files: MediaFileStore(
          directory: () => Directory('${root.path}/generations').create(),
        ),
        client: () => MockClient((r) async {
          if (r.method == 'POST') {
            counts.add(jsonDecode(r.body)['num_images'] as int? ?? 1);
            return http.Response(
              '{"request_id":"job","status":"COMPLETED"}',
              200,
            );
          }
          reads++;
          return http.Response(
            jsonEncode({
              'images': [
                if (reads > 2) {'url': 'data:image/png;base64,$png'},
              ],
            }),
            200,
          );
        }),
      );
      final ticket = await media.runner.enqueue(
        provider: provider,
        request: const MediaRequest(
          modelId: id,
          mode: MediaMode.image,
          prompt: 'A cup',
        ),
      );
      expect(await ticket.completed, GenerationStatus.failed);
      final again = (await media.runner.retry(ticket.batchId, provider))!;
      expect(await again.completed, GenerationStatus.failed);
      final recovered = (await media.runner.retry(ticket.batchId, provider))!;
      expect(await recovered.completed, GenerationStatus.succeeded);
      final row = (await media.runner.repository.batch(ticket.batchId))!;
      final changed = provider.copyWith(
        modelOverrides: {
          id: {
            'media': {
              'extra': {'num_images': 3},
            },
          },
        },
      );
      await media.settings.setProviderConfig(changed.id, changed);
      expect(media.count, 3);
      media.selectCount(2);
      expect(media.count, 2);
      expect(media.extraParameters?['num_images'], 2);
      final repeat = await media.runner.enqueue(
        provider: changed,
        request: MediaRequest.fromBatch(row),
        applyModelExtra: false,
      );
      expect(await repeat.completed, GenerationStatus.succeeded);
      expect(counts, [1, 1]);
      expect(reads, 4);
    },
  );
}
