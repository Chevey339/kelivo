import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/media_repository.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/media_file_store.dart';
import 'package:Kelivo/core/services/media/media_generation_runner.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/desktop/desktop_media_creation_page.dart';
import 'package:Kelivo/desktop/hotkeys/chat_action_bus.dart';
import 'package:Kelivo/features/chat/widgets/chat_creation_images.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/core/services/tools/generate_image_tool.dart';
import 'package:Kelivo/features/settings/widgets/storage_contents_list.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/features/media/pages/media_creation_page.dart';
import 'package:Kelivo/features/media/providers/media_creation_controller.dart';
import 'package:Kelivo/features/media/widgets/creation_composer.dart';
import 'package:Kelivo/shared/widgets/configurable_avatar.dart';
import 'package:Kelivo/features/media/widgets/creation_enhancement_panel.dart';
import 'package:Kelivo/features/media/widgets/creation_gallery.dart';
import 'package:Kelivo/features/media/widgets/creation_lightbox.dart';
import 'package:Kelivo/features/media/widgets/creation_timeline.dart';
import 'package:Kelivo/features/media/widgets/creation_topic_card.dart';
import 'package:Kelivo/features/media/widgets/creation_waiting_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as drag;
import 'package:Kelivo/features/media/widgets/creation_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../support/business_test_harness.dart';

const _model = 'gpt-image-2';
final _provider = ProviderConfig(
  id: 'media-fixture',
  name: 'Test Images',
  baseUrl: 'https://images.example.test/v1',
  enabled: true,
  apiKey: 'fixture',
  models: [_model],
);
final _videoProvider = ProviderConfig(
  id: 'video-fixture',
  name: 'Video fixture',
  baseUrl: 'https://api.x.ai/v1',
  enabled: true,
  apiKey: 'fixture',
  models: const ['grok-imagine-video-1.5'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fal video form and runner enforce required end frames and accept a reference-image list',
    () async {
      const frames = 'studio/paired';
      const references = 'studio/references';
      Map<String, dynamic> override(String id, Map<String, dynamic> fields) => {
        'falEndpoint': {
          'id': id,
          'name': id,
          'category': 'image-to-video',
          'output': 'video',
          'fields': fields,
        },
      };
      final provider = ProviderConfig.defaultsFor('fal').copyWith(
        enabled: true,
        models: [frames, references],
        modelOverrides: {
          frames: override(frames, {
            'prompt': {},
            'first_frame_url': {'required': true},
            'last_frame_url': {'required': true},
          }),
          references: override(references, {
            'prompt': {},
            'image_urls': {
              'required': true,
              'array': true,
              'minItems': 2,
              'maxItems': 3,
            },
          }),
        },
      );
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await settings.setProviderConfig('fal', provider);
      final runner = MediaGenerationRunner(
        repository: MediaRepository(harness.database),
        files: const MediaFileStore(),
      );
      final controller = MediaCreationController(
        runner: runner,
        settings: settings,
        preferences: harness.preferences,
      );
      addTearDown(() async {
        controller.dispose();
        await runner.shutdown();
        runner.dispose();
        settings.dispose();
      });
      controller.setMode(MediaMode.video);
      controller.selectModel(
        controller
            .modelsFor(MediaMode.video)
            .firstWhere((choice) => choice.spec.id == frames),
      );
      controller.setFrame(null, MediaReferenceRole.firstFrame, 'first.png');
      expect(controller.canSubmit(null), isFalse);
      await expectLater(
        runner.enqueue(
          provider: provider,
          request: const MediaRequest(
            modelId: frames,
            mode: MediaMode.video,
            prompt: 'Movement',
            references: [
              MediaReference('first.png', role: MediaReferenceRole.firstFrame),
            ],
          ),
        ),
        throwsA(
          isA<MediaFailure>().having(
            (err) => err.kind,
            'invalid frames',
            MediaFailureKind.parameters,
          ),
        ),
      );
      controller.setFrame(null, MediaReferenceRole.lastFrame, 'last.png');
      expect(controller.canSubmit(null), isTrue);
      controller.selectModel(
        controller
            .modelsFor(MediaMode.video)
            .firstWhere((choice) => choice.spec.id == references),
      );
      expect(controller.showsFrames(null), isFalse);
      expect(controller.canSubmit(null), isFalse);
      expect(
        controller.addReferencePaths(null, ['one.png', 'two.png']),
        CreationReferenceResult.added,
      );
      expect(controller.canSubmit(null), isTrue);
      expect(controller.enhancementReferencePaths(null), [
        'one.png',
        'two.png',
      ]);
    },
  );

  test(
    'enhancement includes only the selected video model’s reference frames',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      final provider = _videoProvider.copyWith(
        models: const ['grok-imagine-video-1.5', 'grok-imagine-video'],
      );
      await settings.setProviderConfig(provider.id, provider);
      final runner = MediaGenerationRunner(
        repository: MediaRepository(harness.database),
        files: const MediaFileStore(),
      );
      await runner.initialized;
      final controller = MediaCreationController(
        runner: runner,
        settings: settings,
        preferences: harness.preferences,
      );
      addTearDown(() async {
        controller.dispose();
        settings.dispose();
        await runner.shutdown();
        runner.dispose();
      });
      controller.setMode(MediaMode.video);
      controller.selectModel(
        controller.models.singleWhere(
          (model) => model.spec.id == 'grok-imagine-video-1.5',
        ),
      );
      controller.setFrame(null, MediaReferenceRole.firstFrame, '/first.png');
      controller.setFrame(null, MediaReferenceRole.lastFrame, '/last.png');
      expect(controller.enhancementReferencePaths(null), [
        '/first.png',
        '/last.png',
      ]);
      controller.selectModel(
        controller.models.singleWhere(
          (model) => model.spec.id == 'grok-imagine-video',
        ),
      );
      expect(controller.enhancementReferencePaths(null), ['/first.png']);
    },
  );

  test(
    'one TokenDance Qwen topic can generate twice and edit the original',
    () async {
      final harness = await createBusinessTestHarness(
        initial: {BusinessKeyRegistry.creationAutoTitleKey: false},
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      const model = 'qwen-image-2.1-turbo';
      final provider = _provider.copyWith(
        baseUrl: 'https://tokendance.space/gateway/v1',
        models: const [model],
      );
      await settings.setProviderConfig(provider.id, provider);
      final root = await Directory.systemTemp.createTemp('qwen-topic');
      SandboxPathResolver.debugSetDirs(docsDir: root.path);
      final png = image.encodePng(image.Image(width: 24, height: 16));
      final inputs = <List<dynamic>>[];
      final sizes = <Object?>[];
      final repository = MediaRepository(harness.database);
      final runner = MediaGenerationRunner(
        repository: repository,
        files: MediaFileStore(
          directory: () async => Directory('${root.path}/generations'),
        ),
        clientFactory: (_, _) => MockClient((request) async {
          if (request.method == 'GET') return http.Response.bytes(png, 200);
          expect(
            request.url.toString(),
            'https://tokendance.space/gateway/alibaba/api/v1/services/aigc/multimodal-generation/generation',
          );
          final body = jsonDecode(request.body);
          expect(body['model'], model);
          sizes.add(body['parameters']['size']);
          inputs.add(body['input']['messages'].single['content'] as List);
          return http.Response(
            jsonEncode({
              'output': {
                'choices': [
                  {
                    'message': {
                      'content': [
                        {'image': 'https://images.example.test/cup.png'},
                      ],
                    },
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      final controller = MediaCreationController(
        runner: runner,
        settings: settings,
        preferences: harness.preferences,
      );
      addTearDown(() async {
        controller.dispose();
        await runner.shutdown();
        runner.dispose();
        settings.dispose();
        SandboxPathResolver.debugSetDirs();
        await root.delete(recursive: true);
      });
      Future<GenerationItemRow> output(String topic) async {
        final id = controller.lastSubmission(topic)!;
        await repository
            .watchBatches()
            .firstWhere(
              (rows) => rows.any((b) => b.id == id && !b.status.isActive),
            )
            .timeout(const Duration(seconds: 5));
        expect(
          (await repository.batch(id))!.status,
          GenerationStatus.succeeded,
        );
        return (await repository.itemsForBatch(id)).single;
      }

      controller.updatePrompt(null, 'A ceramic cup');
      final topic = (await controller.submit(null))!;
      final original = await output(topic);
      controller.updatePrompt(topic, 'A different image of a kite');
      expect(await controller.submit(topic), topic);
      await output(topic);
      final edit = await controller.editItem(
        original,
        controller.editingModel(original)!,
        prompt: 'Paint the cup blue',
        ratio: 'auto',
      );
      expect(await edit!.completed, GenerationStatus.succeeded);
      expect(inputs, [
        [
          {'text': 'A ceramic cup'},
        ],
        [
          {'text': 'A different image of a kite'},
        ],
        [
          {'image': 'data:image/png;base64,${base64Encode(png)}'},
          {'text': 'Paint the cup blue'},
        ],
      ]);
      final batches = await repository.watchBatches().first;
      expect(batches, hasLength(3));
      expect(batches.map((batch) => batch.topicId), everyElement(topic));
      final failed = GenerationBatchRowsCompanion.insert(
        id: 'previous-qwen-batch',
        topicId: Value(topic),
        providerId: provider.id,
        modelId: model,
        mode: MediaMode.image,
        source: GenerationSource.workbench,
        status: GenerationStatus.failed,
        prompt: 'A ceramic cup in landscape',
        paramsJson: '{"aspectRatio":"3:2","count":1,"size":"1536x1024"}',
        referencesJson: '[]',
        createdAt: DateTime.now(),
      );
      await repository.enqueue(failed);
      final retry = await runner.retry(failed.id.value, provider);
      expect(await retry!.completed, GenerationStatus.succeeded);
      expect(sizes.last, '1536*1024');
    },
  );

  test(
    'sending creates a named topic and keeps each topic draft separate',
    () async {
      final harness = await createBusinessTestHarness(
        initial: {BusinessKeyRegistry.creationAutoTitleKey: false},
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await settings.setProviderConfig(_provider.id, _provider);
      final directory = await Directory.systemTemp.createTemp('creation-topic');
      SandboxPathResolver.debugSetDirs(docsDir: directory.path);
      addTearDown(SandboxPathResolver.debugSetDirs);
      final png = base64Encode(
        image.encodePng(image.Image(width: 12, height: 8)),
      );
      final runner = MediaGenerationRunner(
        repository: MediaRepository(harness.database),
        files: MediaFileStore(
          directory: () async => Directory('${directory.path}/generations'),
        ),
        clientFactory: (_, _) => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {'b64_json': png},
              ],
            }),
            200,
          ),
        ),
      );
      final controller = MediaCreationController(
        runner: runner,
        settings: settings,
        preferences: harness.preferences,
      );
      addTearDown(() async {
        controller.dispose();
        settings.dispose();
        await runner.shutdown();
        runner.dispose();
        await directory.delete(recursive: true);
      });

      const prompt = 'A bird perched in a garden tree';
      controller.updatePrompt(null, prompt);
      final id = (await controller.submit(null))!;
      final topic = (await runner.repository.watchTopics().first).single;
      expect(topic.id, id);
      expect(topic.title, prompt.substring(0, 20));
      expect(topic.titleSource, GenerationTitleSource.prompt);
      expect(controller.draftFor(null).prompt, isEmpty);

      controller.updatePrompt(id, 'Make the light softer');
      controller.updatePrompt(null, 'A separate idea');
      expect(controller.draftFor(id).prompt, 'Make the light softer');
      expect(controller.draftFor(null).prompt, 'A separate idea');

      final batches = await runner.repository
          .watchBatches()
          .firstWhere(
            (rows) => rows.single.status == GenerationStatus.succeeded,
          )
          .timeout(const Duration(seconds: 5));
      expect(batches.single.topicId, id);
      expect(
        await runner.repository.itemsForBatch(batches.single.id),
        hasLength(1),
      );
      final savedBatch = batches.single;
      final imageRow = (await runner.repository.itemsForBatch(
        savedBatch.id,
      )).single;
      final favorites = runner.repository.watchItems().firstWhere(
        (rows) => rows.any((row) => row.id == imageRow.id && row.favorite),
      );
      await controller.setFavorite(imageRow.id, true);
      await favorites;
      expect(
        controller
            .galleryItems(CreationGalleryFilter.favorites, 'GARDEN')
            .single
            .id,
        imageRow.id,
      );
      expect(
        controller.galleryItems(CreationGalleryFilter.videos, ''),
        isEmpty,
      );
      expect(
        controller.galleryItems(CreationGalleryFilter.all, 'unmatched'),
        isEmpty,
      );
      expect(controller.coverCells(id).single?.id, imageRow.id);
      await controller.setTopicView(CreationTopicView.covers);
      expect(controller.topicView, CreationTopicView.covers);
      expect(
        harness.preferences.getString(BusinessKeyRegistry.creationTopicViewKey),
        'covers',
      );
      expect(controller.waitGame, CreationWaitGame.random);
      await controller.setWaitGame(CreationWaitGame.off);
      expect(controller.waitGame, CreationWaitGame.off);
      expect(
        harness.preferences.getString(BusinessKeyRegistry.creationWaitGameKey),
        'off',
      );

      final repeat = (await controller.repeat(savedBatch))!;
      expect(await repeat.completed, GenerationStatus.succeeded);
      expect(repeat.batchId, isNot(savedBatch.id));
      final repeated = (await runner.repository.batch(repeat.batchId))!;
      expect(repeated.topicId, id);
      expect(repeated.prompt, savedBatch.prompt);
      expect(repeated.paramsJson, savedBatch.paramsJson);
      await controller.deleteBatch(repeated);
      expect(await runner.repository.batch(repeat.batchId), isNull);
      expect(await runner.repository.batch(savedBatch.id), isNotNull);

      final editingModel = controller.editingModel(imageRow)!;
      final edited = (await controller.editItem(
        imageRow,
        editingModel,
        prompt: 'Make the sky brighter',
        ratio: 'auto',
      ))!;
      expect(await edited.completed, GenerationStatus.succeeded);
      final editRow = (await runner.repository.batch(edited.batchId))!;
      expect(editRow.topicId, id);
      expect(editRow.parentItemId, imageRow.id);
      expect(editRow.source, GenerationSource.edit);
      expect(
        await runner.repository.itemsForBatch(savedBatch.id),
        hasLength(1),
      );

      final db = harness.database;
      final now = DateTime.now();
      await db
          .into(db.conversationRows)
          .insert(
            ConversationRowsCompanion.insert(
              id: 'history',
              title: 'My chat',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.messageRows)
          .insert(
            MessageRowsCompanion.insert(
              id: 'message',
              conversationId: 'history',
              role: 'user',
              timestamp: now,
              messageOrder: 0,
            ),
          );
      const imageUris = [
        'kelivo-file:///upload/chat.png',
        'https://cdn.example.test/output?sig=fixture',
      ];
      for (final (index, uri) in imageUris.indexed) {
        await db
            .into(db.messagePartRows)
            .insert(
              MessagePartRowsCompanion.insert(
                conversationId: 'history',
                revisionId: 'message',
                ordinal: index,
                kind: 'image',
                payload: ImagePart(uri: uri).encodePayload(),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      final referenceImages = await runner.repository.recentImages(
        RecentImageSource.all,
        offset: 0,
        limit: 10,
      );
      expect(referenceImages, hasLength(4));
      expect(referenceImages.first.source, RecentImageSource.chat);
      expect(referenceImages.first.title, 'My chat');
      expect(
        referenceImages
            .where((item) => item.source == RecentImageSource.chat)
            .map((item) => item.path),
        unorderedEquals(imageUris),
      );
      expect(
        referenceImages.where(
          (item) => item.source == RecentImageSource.creation,
        ),
        hasLength(2),
      );
      expect(
        await runner.repository.recentImages(
          RecentImageSource.chat,
          offset: 2,
          limit: 1,
        ),
        isEmpty,
      );
      await controller.deleteTopic(id);
      expect(await runner.repository.batch(batches.single.id), isNull);
      expect(await runner.repository.itemsForBatch(batches.single.id), isEmpty);
      expect(
        await Directory(
          '${directory.path}/generations/${batches.single.id}',
        ).exists(),
        isFalse,
      );
    },
  );

  testWidgets(
    'desktop gallery opens a filtered lightbox and jumps to its topic',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpCreationGallery(tester, desktop: true);
      await tester.tap(find.text('All creations'));
      await tester.pumpAndSettle();
      expect(find.byType(CreationArtworkTile), findsNWidgets(2));
      await tester.tap(find.byType(CreationArtworkTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      final stage = find.byType(InteractiveViewer);
      await tester.tapAt(tester.getCenter(find.byTooltip('Previous creation')));
      await tester.pumpAndSettle();
      expect(stage, findsOneWidget);
      for (final point in [
        tester.getCenter(stage),
        tester.getTopLeft(stage) + const Offset(2, 2),
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(stage, findsNothing);
        await tester.tap(find.byType(CreationArtworkTile).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Close').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag.toString().startsWith('creation:'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CreationArtworkTile).first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Show in topic'));
      await tester.pumpAndSettle();
      expect(find.text('A wide mountain lake'), findsOneWidget);
      expect(find.text('Mountain trip'), findsWidgets);
      final topicMenu = find.byTooltip('More').hitTestable().first;
      final buttonBounds = tester.getRect(topicMenu);
      expect(buttonBounds.right, 1280 - 16);
      await tester.tap(topicMenu);
      await tester.pumpAndSettle();
      final menu = find.text('Rename topic');
      expect(menu, findsOneWidget);
      expect(tester.getRect(menu).top, greaterThan(buttonBounds.bottom));
      await tester.tapAt(const Offset(400, 50));
      await tester.pumpAndSettle();

      final prompt = find.text('A wide mountain lake');
      final tile = find.byType(CreationArtworkTile).first;
      final promptBounds = tester.getRect(prompt);
      final tileBounds = tester.getRect(tile);
      final copy = find.byTooltip('Copy prompt');
      final groupActions = find.ancestor(
        of: copy,
        matching: find.byType(CreationHoverActions),
      );
      final fade = find
          .descendant(of: groupActions, matching: find.byType(FadeTransition))
          .first;
      double opacity() => tester.widget<FadeTransition>(fade).opacity.value;
      expect(opacity(), 0);
      expect(copy.hitTestable(), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 5));
      await mouse.moveTo(tileBounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(opacity(), allOf(greaterThan(0), lessThan(1)));
      expect(tester.getRect(prompt), promptBounds);
      expect(tester.getRect(tile), tileBounds);
      await tester.pump(const Duration(milliseconds: 180));
      expect(opacity(), 1);
      expect(copy.hitTestable(), findsOneWidget);
      await mouse.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(opacity(), 0);
      expect(tester.getRect(tile), tileBounds);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'long topics open at the latest batch and gallery links reveal the original batch',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final media = await _pumpCreationGallery(
        tester,
        desktop: true,
        count: 1,
        laterBatches: 30,
      );
      await tester.tap(find.text('Mountain trip'));
      await tester.pumpAndSettle();
      expect(find.text('Study 30').hitTestable(), findsOneWidget);
      expect(find.text('A wide mountain lake').hitTestable(), findsNothing);
      media.addReferencePaths('topic', [media.worksFor('topic').single.path]);
      final composer = find.byType(CreationComposer);
      await tester.enterText(
        find.descendant(of: composer, matching: find.byType(EditableText)),
        List.filled(6, 'a longer draft').join('\n'),
      );
      await tester.pumpAndSettle();
      final latest = find.byKey(const ValueKey('later-30')).first;
      expect(
        tester.getRect(latest).bottom,
        lessThanOrEqualTo(tester.getRect(composer).top),
      );
      await tester.tap(find.text('All creations'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CreationArtworkTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show in topic'));
      await tester.pumpAndSettle();
      expect(find.text('A wide mountain lake').hitTestable(), findsOneWidget);
      expect(find.text('Study 30').hitTestable(), findsNothing);
      final timeline = tester.state(find.byType(CreationTimeline));
      tester.view.physicalSize = const Size(690, 820);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CreationTimeline)), same(timeline));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'new and saved desktop topic rows align at large text sizes and cover actions fit the thumbnail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 680);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final media = await _pumpCreationGallery(
        tester,
        desktop: true,
        count: 1,
        locale: const Locale('tr'),
      );
      await tester.runAsync(() => media.setTopicView(CreationTopicView.list));
      await tester.pumpAndSettle();
      final rows = find.byType(CreationTopicListRow);
      expect(rows, findsNWidgets(2));
      final newTitle = AppLocalizations.of(
        tester.element(rows.first),
      )!.creationNewTopic;
      final draftTitle = find.descendant(
        of: rows.first,
        matching: find.text(newTitle),
      );
      final savedTitle = find.descendant(
        of: rows.last,
        matching: find.text('Mountain trip'),
      );
      expect(
        tester.getTopLeft(draftTitle).dx,
        tester.getTopLeft(savedTitle).dx,
      );
      expect(
        tester.getRect(rows.first).bottom,
        lessThan(tester.getRect(rows.last).top),
      );
      await tester.runAsync(() => media.setTopicView(CreationTopicView.covers));
      await tester.pumpAndSettle();
      final card = find.byType(CreationTopicCard);
      final photo = find
          .descendant(of: card, matching: find.byType(CreationFileImage))
          .first;
      final photoSize = tester.getSize(photo);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(card));
      await tester.pumpAndSettle();
      final more = AppLocalizations.of(
        tester.element(card),
      )!.chatMessageWidgetMoreTooltip;
      final moreButton = find
          .descendant(of: card, matching: find.byTooltip(more))
          .hitTestable();
      expect(tester.getSize(moreButton).width, lessThanOrEqualTo(24));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(tester.getSize(photo), photoSize);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'the creation menu manages preferences before the first mobile topic',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final media = await _pumpCreationGallery(
        tester,
        desktop: false,
        seedTopic: false,
      );
      await tester.pumpAndSettle();
      final menu = find.byTooltip('Display and waiting games');
      expect(menu.hitTestable(), findsOneWidget);
      Future<void> choose(String label) async {
        await tester.runAsync(() => tester.tap(menu));
        await tester.pumpAndSettle();
        expect(find.text('Change in Settings…'), findsNothing);
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
          await media.preferences.flushPendingWrites();
        });
        await tester.pumpAndSettle();
      }

      await choose('Covers only');
      expect(media.topicView, CreationTopicView.covers);
      await choose('Name topics automatically');
      expect(media.autoTitle, isFalse);
      await choose('Off');
      expect(media.waitGame, CreationWaitGame.off);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final desktop in [false, true]) {
    testWidgets(
      'single artwork lightbox returns a reference to its ${desktop ? 'desktop' : 'mobile'} topic draft',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = desktop
            ? const Size(1280, 820)
            : const Size(390, 844);
        if (!desktop) {
          tester.view.padding = const FakeViewPadding(bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(bottom: 34);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
        }
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final media = await _pumpCreationGallery(
          tester,
          desktop: desktop,
          count: 1,
        );
        await tester.tap(find.text('Mountain trip').first);
        await tester.pumpAndSettle();
        final timeline = tester.getRect(find.byType(CreationTimeline));
        final prompt = tester.getRect(find.text('A wide mountain lake'));
        expect(
          prompt.top - timeline.top,
          lessThan(76),
          reason: 'Short topics start below the header',
        );
        final tile = find.byType(CreationArtworkTile).first;
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.text('1 / 1'), findsOneWidget);
        final thumbnail = find.bySemanticsLabel('Tab 1 of 1');
        expect(thumbnail, findsOneWidget);
        if (desktop) {
          expect(find.byTooltip('Previous creation'), findsOneWidget);
          expect(find.byTooltip('Next creation'), findsOneWidget);
        } else {
          expect(tester.getTopLeft(thumbnail).dx, 16);
          await tester.tapAt(tester.getCenter(thumbnail) + const Offset(95, 0));
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsNothing);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          await tester.tap(thumbnail);
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsOneWidget);
        }
        await tester.tap(find.byTooltip('More').hitTestable().last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use as reference'));
        await tester.pumpAndSettle();
        expect(find.text('1 / 1'), findsNothing);
        expect(
          tester.getRect(find.text('A wide mountain lake')).top,
          prompt.top,
          reason: 'Adding a reference must not move a short conversation down',
        );
        expect(media.imageReferences('topic'), hasLength(1));
        final path = media.imageReferences('topic').single.path;
        expect(
          media.addReferencePaths('topic', [path]),
          CreationReferenceResult.alreadyAdded,
        );
        expect(media.imageReferences(null), isEmpty);
        final remove = find.byTooltip('Delete');
        if (desktop) {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          final ref = find.byKey(ValueKey(path));
          await mouse.addPointer(location: const Offset(0, 0));
          await mouse.moveTo(tester.getCenter(ref));
          await tester.pumpAndSettle();
          final position = tester.getCenter(remove.hitTestable().last);
          await mouse.moveTo(position);
          await mouse.down(position);
          await mouse.up();
          await mouse.removePointer();
        } else {
          await tester.tap(remove.hitTestable().last);
        }
        await tester.pumpAndSettle();
        expect(media.imageReferences('topic'), isEmpty);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'chat image details and the Creation link can be hidden independently',
    (tester) async {
      final media = await _pumpCreationGallery(
        tester,
        desktop: true,
        count: 1,
        chatMessageId: 'chat-result',
      );
      await tester.pumpAndSettle();
      final link = find.text('Show in Creation');
      final info = find.textContaining(_model);
      expect(link, findsOneWidget);
      expect(info, findsOneWidget);
      await tester.runAsync(() => media.settings.setShowChatImageInfo(false));
      await tester.pump();
      expect(info, findsNothing);
      expect(link, findsOneWidget);
      await tester.runAsync(() => media.settings.setShowChatImageLink(false));
      await tester.pump();
      expect(link, findsNothing);
      expect(find.byType(CreationFileImage), findsOneWidget);
      await tester.runAsync(() => media.settings.setShowChatImageInfo(true));
      await tester.pump();
      expect(info, findsOneWidget);
      expect(link, findsNothing);
    },
  );

  testWidgets(
    'creation storage drills from the prompt into a saved artwork preview',
    (tester) async {
      final media = await _pumpCreationGallery(tester, desktop: true, count: 1);
      await tester.pumpAndSettle();
      final file = File(media.itemsFor('batch').single.path);
      final stats = StorageUsageStats(fileCount: 1, bytes: file.lengthSync());
      final host = tester.element(find.byType(DesktopMediaCreationPage));
      Navigator.of(host).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: StorageContentsList(
              category: StorageUsageCategory(
                key: StorageUsageCategoryKey.creations,
                stats: stats,
                subcategories: [
                  StorageUsageSubcategory(
                    id: 'batch',
                    path: file.parent.path,
                    isDirectory: true,
                    stats: stats,
                  ),
                ],
              ),
              fmtBytes: (value) => '$value B',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('storage-content-batch'));
      expect(
        find.descendant(of: row, matching: find.text('A wide mountain lake')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(CreationMediaCover)),
        findsOneWidget,
      );
      await tester.tap(row);
      final item = find.byKey(FileBrowser.itemKey('result.png'));
      for (var i = 0; i < 30 && item.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final more = find.byWidgetPredicate(
        (w) =>
            w is IosIconButton &&
            w.tooltip ==
                AppLocalizations.of(host)!.chatMessageWidgetMoreTooltip,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(more));
      await tester.pumpAndSettle();
      final painted = tester.widget<AnimatedContainer>(
        find.descendant(of: more, matching: find.byType(AnimatedContainer)),
      );
      expect((painted.decoration! as BoxDecoration).shape, BoxShape.circle);
      expect(
        (painted.decoration! as BoxDecoration).color,
        isNot(Colors.transparent),
      );
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('zoomed desktop panning keeps the artwork in the viewer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpCreationGallery(tester, desktop: true);
    await tester.tap(find.text('All creations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CreationArtworkTile).first);
    await tester.pumpAndSettle();
    final stage = find.byType(InteractiveViewer);
    final center = tester.getCenter(stage);
    final controller = tester
        .widget<InteractiveViewer>(stage)
        .transformationController!;
    final dragSource = tester.widget<drag.DraggableWidget>(
      find.descendant(of: stage, matching: find.byType(drag.DraggableWidget)),
    );
    expect(dragSource.isLocationDraggable(center), isTrue);
    controller.value = Matrix4.identity()
      ..translateByDouble(-160, -100, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);
    expect(dragSource.isLocationDraggable(center), isFalse);
    final pan = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 650));
    await pan.moveBy(const Offset(10, 5));
    await tester.pump();
    final before = controller.value.getTranslation();
    await pan.moveBy(const Offset(22, 15));
    await tester.pump();
    final after = controller.value.getTranslation();
    expect(after.x - before.x, closeTo(22, .1));
    expect(after.y - before.y, closeTo(15, .1));
    await pan.up();
    await tester.pumpAndSettle();
    expect(stage, findsOneWidget);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(stage, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'mobile lightbox follows a horizontal swipe and a downward dismissal',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpCreationGallery(tester, desktop: false);
      await tester.tap(find.text('Mountain trip').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CreationArtworkTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      final viewport = find.byType(InteractiveViewer);
      final center = tester.getCenter(viewport);
      final first = await tester.startGesture(center - const Offset(48, 0));
      final second = await tester.startGesture(center + const Offset(48, 0));
      await first.moveBy(const Offset(-36, 0));
      await second.moveBy(const Offset(36, 0));
      await tester.pump();
      expect(
        tester
            .widget<InteractiveViewer>(viewport)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1.2),
      );
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(viewport, findsOneWidget);
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(viewport, findsNothing);
      await tester.tap(find.byType(CreationArtworkTile).first);
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(tester.getCenter(viewport));
      await drag.moveBy(const Offset(-30, 0));
      await tester.pump();
      await drag.moveBy(const Offset(-95, 0));
      await tester.pumpAndSettle();
      final chrome = find.ancestor(
        of: find.text('1 / 2'),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(chrome.first).opacity, 0);
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.drag(viewport, const Offset(0, 170));
      await tester.pumpAndSettle();
      expect(viewport, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'rapid desktop artwork hover and leaving the conversation retire all controls',
    (tester) async {
      await _pumpCreationGallery(
        tester,
        desktop: true,
        count: 1,
        chatMessageId: 'message',
      );
      await tester.pumpAndSettle();
      final image = find.byType(CreationFileImage).first;
      final inside = tester.getCenter(image);
      final outside = tester.getBottomRight(image) + const Offset(22, 18);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: outside);
      await tester.pump();
      final glass = find.descendant(
        of: find.byType(ChatCreationImages),
        matching: find.byType(BackdropFilter),
      );
      expect(
        tester.widgetList<BackdropFilter>(glass).where((w) => w.enabled),
        isEmpty,
      );
      await mouse.moveTo(inside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final buttons = tester
          .widgetList<BackdropFilter>(glass)
          .where((w) => w.enabled)
          .toList();
      expect(buttons, hasLength(1));
      await mouse.moveTo(outside);
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<BackdropFilter>(glass).where((w) => w.enabled),
        isEmpty,
      );
      for (var i = 0; i < 6; i++) {
        await mouse.moveTo(inside);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 36));
        await mouse.moveTo(outside);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
      }
      final underGradient = tester.getBottomLeft(image) + const Offset(20, -15);
      await mouse.moveTo(underGradient);
      await tester.pumpAndSettle();
      await mouse.down(underGradient);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'iOS topic supports canceling and completing an edge swipe with its draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final media = await _pumpCreationGallery(tester, desktop: false);
      final title = find.text('Mountain trip');
      await tester.tap(title.first);
      await tester.pumpAndSettle();
      final timeline = find.byType(CreationTimeline);
      final route = ModalRoute.of(tester.element(timeline))!;
      expect(route.popGestureEnabled, isTrue);
      media.updatePrompt('topic', 'Keep this draft');
      Future<void> swipe(double distance) async {
        final drag = await tester.startGesture(const Offset(2, 320));
        await drag.moveBy(const Offset(22, 0));
        await tester.pump();
        await drag.moveBy(Offset(distance, 0));
        await tester.pump(const Duration(milliseconds: 160));
        expect(route.popGestureInProgress, isTrue);
        await drag.up();
        await tester.pumpAndSettle();
      }

      await swipe(36);
      expect(timeline, findsOneWidget);
      await swipe(295);
      expect(timeline, findsNothing);
      await tester.tap(title.first);
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('the rewrite panel can be dismissed at its trailing edge', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              child: MediaQuery(
                data: const MediaQueryData(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(1.6),
                ),
                child: CreationEnhancementPanel(
                  desktop: false,
                  original: 'Cup',
                  modelName: 'An unusually long model name',
                  spans: null,
                  onClose: () => cancelled = true,
                  onAgain: () {},
                  onApply: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(CreationEnhancementPanel));
    final close = tester.getRect(find.byTooltip('Close'));
    expect(close.width, greaterThanOrEqualTo(44));
    await tester.tapAt(Offset(bounds.right - 15, close.center.dy));
    expect(cancelled, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final chat in [false, true]) {
    testWidgets(
      '${chat ? 'chat' : 'creation timeline'} preserves a playing card through result publication',
      (tester) async {
        final visibility = VisibilityDetectorController.instance;
        final previousInterval = visibility.updateInterval;
        visibility.updateInterval = Duration.zero;
        addTearDown(() => visibility.updateInterval = previousInterval);
        final (
          harness,
          settings,
          runner,
          controller,
          folder,
        ) = (await tester.runAsync(() async {
          final harness = await BusinessTestHarness.create();
          final settings = SettingsProvider(harness.preferences);
          await settings.loaded;
          await settings.setProviderConfig(_provider.id, _provider);
          final repository = MediaRepository(harness.database);
          final runner = MediaGenerationRunner(
            repository: repository,
            files: const MediaFileStore(),
          );
          await runner.initialized;
          final folder = await Directory.systemTemp.createTemp(
            'creation-reveal',
          );
          await File(
            '${folder.path}/result.png',
          ).writeAsBytes(image.encodePng(image.Image(width: 12, height: 12)));
          final created = DateTime(2026, 4);
          await repository.enqueue(
            GenerationBatchRowsCompanion.insert(
              id: 'playing-batch',
              topicId: chat ? const Value.absent() : const Value('topic'),
              messageId: chat ? const Value('message') : const Value.absent(),
              providerId: _provider.id,
              modelId: _model,
              mode: MediaMode.image,
              prompt: 'Bird in a garden',
              paramsJson: jsonEncode({
                'count': chat ? 1 : 3,
                if (chat)
                  GenerateImageTool.callIdParameter: 'active-generation',
              }),
              referencesJson: '[]',
              status: GenerationStatus.running,
              source: chat ? GenerationSource.chat : GenerationSource.workbench,
              createdAt: created,
            ),
            topic: chat
                ? null
                : GenerationTopicRowsCompanion.insert(
                    id: 'topic',
                    title: 'Garden',
                    titleSource: GenerationTitleSource.manual,
                    createdAt: created,
                    updatedAt: created,
                  ),
          );
          if (!chat) {
            await repository.addItem(
              GenerationItemRow(
                id: 'previous-result',
                batchId: 'playing-batch',
                ordinal: 1,
                mode: MediaMode.image,
                path: '${folder.path}/result.png',
                mime: 'image/png',
                byteSize: 1,
                favorite: false,
                status: GenerationItemStatus.ready,
                createdAt: created,
              ),
            );
          }
          final controller = MediaCreationController(
            runner: runner,
            settings: settings,
            preferences: harness.preferences,
          );
          await repository.watchBatches().first;
          await repository.watchItems().first;
          return (harness, settings, runner, controller, folder);
        }))!;
        addTearDown(() async {
          controller.dispose();
          settings.dispose();
          await runner.shutdown();
          runner.dispose();
          await harness.close();
          await folder.delete(recursive: true);
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<MediaCreationController>.value(
                value: controller,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: Scaffold(
                body: chat
                    ? const ChatCreationImages(
                        messageId: 'message',
                        attachments: [],
                        streaming: true,
                      )
                    : const CreationTimeline(topicId: 'topic', desktop: true),
              ),
            ),
          ),
        );
        await tester.pump();
        final waiting = find.byWidgetPredicate(
          (widget) => widget is CreationWaitingCard && widget.result == null,
        );
        expect(waiting, findsNWidgets(chat ? 1 : 2));
        if (chat) {
          final projection = projectAssistantTimeline(
            parts: const [
              ToolCallPart(
                '{"id":"active-generation","name":"generate_image","arguments":{}}',
              ),
            ],
            liveTools: const [],
            reasoningSegments: const [],
            visualContent: '',
            partsArrivalOrdered: true,
          );
          final placement = ChatImagePlacement.resolve(
            tester.element(waiting.first),
            'message',
            const [],
            projection,
            listen: false,
          )!;
          expect(
            placement.atCall.values.single.single.batch!.id,
            'playing-batch',
          );
          expect(placement.footer, isEmpty);
        }
        await tester.tap(waiting.first);
        await tester.pump();
        expect(find.bySemanticsLabel('Score 0'), findsOneWidget);
        await tester.runAsync(() async {
          for (var ordinal = 0; ordinal < (chat ? 1 : 2); ordinal++) {
            await runner.repository.addItem(
              GenerationItemRow(
                id: 'result-$ordinal',
                batchId: 'playing-batch',
                ordinal: chat ? ordinal : ordinal + 2,
                mode: MediaMode.image,
                path: '${folder.path}/result.png',
                mime: 'image/png',
                byteSize: 1,
                favorite: false,
                status: GenerationItemStatus.ready,
                createdAt: DateTime(2026, 4),
              ),
            );
          }
          await runner.repository.updateBatch(
            'playing-batch',
            const GenerationBatchRowsCompanion(
              status: Value(GenerationStatus.succeeded),
            ),
          );
          await runner.repository.watchBatches().first;
          await runner.repository.watchItems().first;
        });
        await tester.pump();
        expect(find.text('Creation ready · 0'), findsOneWidget);
        if (chat) {
          expect(find.text('Image created'), findsOneWidget);
        }
        final images = find.byType(
          chat ? CreationFileImage : CreationArtworkTile,
        );
        expect(images, chat ? findsNothing : findsNWidgets(2));
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('Creation ready · 0'), findsNothing);
        if (chat) {
          expect(find.text('Image created'), findsNothing);
        }
        expect(images, findsNWidgets(chat ? 1 : 3));
        if (chat) {
          final events = <CreationChatAction>[];
          final subscription = ChatActionBus.instance.creationStream.listen(
            events.add,
          );
          addTearDown(subscription.cancel);
          final path = tester.widget<CreationFileImage>(images.first).path;
          await tester.tap(images.first);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('More').hitTestable().last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Use as reference'));
          await tester.pumpAndSettle();
          expect(
            events.whereType<PrefillChatImage>().single.path,
            SandboxPathResolver.resolveForIo(path),
          );
          expect(controller.imageReferences(null), isEmpty);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final desktop in [false, true]) {
    testWidgets(
      'creation composer exposes supported image controls on ${desktop ? 'desktop' : 'mobile'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = desktop
            ? const Size(1280, 820)
            : const Size(390, 844);
        if (!desktop) {
          tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
        }
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final (harness, settings, runner, controller) = (await tester.runAsync(
          () async {
            final harness = await BusinessTestHarness.create();
            final settings = SettingsProvider(harness.preferences);
            await settings.loaded;
            await settings.setProviderConfig(_provider.id, _provider);
            await settings.setProviderConfig(_videoProvider.id, _videoProvider);
            final runner = MediaGenerationRunner(
              repository: MediaRepository(harness.database),
              files: const MediaFileStore(),
            );
            await runner.initialized;
            final controller = MediaCreationController(
              runner: runner,
              settings: settings,
              preferences: harness.preferences,
            );
            return (harness, settings, runner, controller);
          },
        ))!;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<MediaCreationController>.value(
                value: controller,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: desktop
                  ? const DesktopMediaCreationPage()
                  : MediaCreationPage(onOpenDrawer: () {}),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CreationComposer), findsOneWidget);
        expect(find.byTooltip('Generate'), findsOneWidget);
        expect(find.byTooltip('Add reference image'), findsOneWidget);
        final composer = find.byType(CreationComposer);
        final input = find.descendant(
          of: composer,
          matching: find.byType(EditableText),
        );
        final send = find.byTooltip('Generate');
        expect(
          tester.getCenter(input).dy,
          closeTo(tester.getCenter(send).dy, 1),
        );
        controller.addReferencePaths(null, ['/sample/reference.png']);
        await tester.pump();
        final thumb = find.descendant(
          of: composer,
          matching: find.byType(CreationFileImage),
        );
        expect(
          tester.getTopLeft(thumb).dx - tester.getTopLeft(composer).dx,
          closeTo(14, 1),
        );
        controller.setReferences(null, []);
        await tester.pump();
        expect(
          find.text(desktop ? '1 image' : 'Auto · 1 image'),
          findsOneWidget,
        );
        final modelAvatars = find.byWidgetPredicate(
          (w) =>
              w is ConfigurableAvatar &&
              w.fallbackAsset == 'assets/icons/openai.svg' &&
              w.name == _model,
        );
        expect(
          find.descendant(of: composer, matching: modelAvatars),
          findsOneWidget,
        );
        await tester.tap(find.text(_model).hitTestable().last);
        await tester.pumpAndSettle();
        expect(modelAvatars, findsNWidgets(2));
        for (final avatar in tester.widgetList<ConfigurableAvatar>(
          modelAvatars,
        )) {
          expect(avatar.withBackground, isFalse);
        }
        final menuIcon = modelAvatars.hitTestable().last;
        final menuText = find.text(_model).hitTestable().last;
        final labelColumn = find
            .ancestor(of: menuText, matching: find.byType(Column))
            .first;
        expect(
          tester.getCenter(menuIcon).dy,
          closeTo(tester.getCenter(labelColumn).dy, 1),
        );
        final search = find.byType(CreationSearchBox).hitTestable().last;
        expect(
          tester.getTopLeft(find.text('Test Images')).dy -
              tester.getBottomLeft(search).dy,
          inInclusiveRange(6.0, 20.0),
        );
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();

        await tester.tap(find.text(desktop ? '1 image' : 'Auto · 1 image'));
        await tester.pumpAndSettle();
        final custom = find.text('Custom').hitTestable();
        expect(
          tester.renderObject<RenderParagraph>(custom).didExceedMaxLines,
          isFalse,
        );
        await tester.tap(custom);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Increase Image count'));
          await harness.preferences.flushPendingWrites();
        });
        await tester.pumpAndSettle();
        expect(controller.count, 2);
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Decrease Image count'));
          await harness.preferences.flushPendingWrites();
        });
        await tester.pumpAndSettle();
        expect(controller.count, 1);
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(desktop ? 'More options' : 'Auto · 1 image'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Extra parameters (JSON)'), findsOneWidget);
        expect(find.text('Quality'), findsOneWidget);
        expect(find.text('Background'), findsOneWidget);
        expect(find.text('Negative prompt'), findsNothing);
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          controller.setMode(MediaMode.video);
          controller.selectDuration(8);
          controller.selectResolution('720p');
          controller.showFrames(null, true);
          await harness.preferences.flushPendingWrites();
        });
        await tester.pump();
        expect(
          find.text(desktop ? '8 seconds' : 'Auto · 8 seconds'),
          findsOneWidget,
        );
        expect(find.text('First frame'), findsOneWidget);
        expect(find.text('Last frame'), findsOneWidget);
        expect(controller.canSubmit(null), isFalse);
        await tester.runAsync(() async {
          controller.selectResolution('1080p');
          controller.setFrame(null, MediaReferenceRole.lastFrame, '/last.png');
          await harness.preferences.flushPendingWrites();
        });
        expect(controller.resolutionFor(null), '720p');
        expect(controller.canSubmit(null), isFalse);
        controller.setFrame(null, MediaReferenceRole.firstFrame, '/first.png');
        await tester.pump();
        expect(controller.canSubmit(null), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          controller.dispose();
          settings.dispose();
          await runner.shutdown();
          runner.dispose();
          await harness.close();
        });
      },
    );
  }
}

Future<MediaCreationController> _pumpCreationGallery(
  WidgetTester tester, {
  required bool desktop,
  int count = 2,
  Locale locale = const Locale('en'),
  bool seedTopic = true,
  String? chatMessageId,
  int laterBatches = 0,
}) async {
  final (harness, settings, runner, controller, folder) = (await tester
      .runAsync(() async {
        final harness = await BusinessTestHarness.create();
        final settings = SettingsProvider(harness.preferences);
        await settings.loaded;
        await settings.setProviderConfig(_provider.id, _provider);
        final repository = MediaRepository(harness.database);
        final runner = MediaGenerationRunner(
          repository: repository,
          files: const MediaFileStore(),
        );
        await runner.initialized;
        final folder = await Directory.systemTemp.createTemp(
          'creation-gallery-test',
        );
        if (seedTopic) {
          final file = await File(
            '${folder.path}/result.png',
          ).writeAsBytes(image.encodePng(image.Image(width: 30, height: 17)));
          final created = DateTime(2025, 1, 2);
          await repository.enqueue(
            GenerationBatchRowsCompanion.insert(
              id: 'batch',
              topicId: chatMessageId == null
                  ? const Value('topic')
                  : const Value.absent(),
              messageId: Value(chatMessageId),
              providerId: _provider.id,
              modelId: _model,
              mode: MediaMode.image,
              prompt: 'A wide mountain lake',
              paramsJson: '{}',
              referencesJson: '[]',
              status: GenerationStatus.succeeded,
              source: chatMessageId == null
                  ? GenerationSource.workbench
                  : GenerationSource.chat,
              createdAt: created,
            ),
            topic: GenerationTopicRowsCompanion.insert(
              id: 'topic',
              title: 'Mountain trip',
              titleSource: GenerationTitleSource.manual,
              createdAt: created,
              updatedAt: created,
            ),
          );
          for (var index = 0; index < count; index++) {
            await harness.database
                .into(harness.database.generationItemRows)
                .insert(
                  GenerationItemRowsCompanion.insert(
                    id: 'image-$index',
                    batchId: 'batch',
                    ordinal: index,
                    mode: MediaMode.image,
                    width: const Value(30),
                    height: const Value(17),
                    path: file.path,
                    mime: 'image/png',
                    byteSize: await file.length(),
                    status: GenerationItemStatus.ready,
                    createdAt: created,
                  ),
                );
          }
          for (var i = 1; i <= laterBatches; i++) {
            await repository.enqueue(
              GenerationBatchRowsCompanion.insert(
                id: 'later-$i',
                topicId: const Value('topic'),
                providerId: _provider.id,
                modelId: _model,
                mode: MediaMode.image,
                prompt: 'Study $i',
                paramsJson: '{}',
                referencesJson: '[]',
                status: GenerationStatus.cancelled,
                source: GenerationSource.workbench,
                createdAt: created.add(Duration(minutes: i)),
              ),
            );
          }
        }
        final controller = MediaCreationController(
          runner: runner,
          settings: settings,
          preferences: harness.preferences,
        );
        await repository.watchItems().first;
        return (harness, settings, runner, controller, folder);
      }))!;
  addTearDown(() async {
    controller.dispose();
    settings.dispose();
    await runner.shutdown();
    runner.dispose();
    await harness.close();
    await folder.delete(recursive: true);
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<MediaCreationController>.value(
          value: controller,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: chatMessageId != null
            ? Scaffold(
                body: ChatCreationImages(
                  messageId: chatMessageId,
                  attachments: const [],
                  streaming: false,
                ),
              )
            : desktop
            ? const DesktopMediaCreationPage()
            : MediaCreationPage(onOpenDrawer: () {}),
      ),
    ),
  );
  return controller;
}
