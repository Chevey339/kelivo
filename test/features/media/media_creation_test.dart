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
import 'package:Kelivo/features/chat/widgets/chat_creation_images.dart';
import 'package:Kelivo/features/media/pages/media_creation_page.dart';
import 'package:Kelivo/features/media/providers/media_creation_controller.dart';
import 'package:Kelivo/features/media/widgets/creation_composer.dart';
import 'package:Kelivo/features/media/widgets/creation_gallery.dart';
import 'package:Kelivo/features/media/widgets/creation_lightbox.dart';
import 'package:Kelivo/features/media/widgets/creation_timeline.dart';
import 'package:Kelivo/features/media/widgets/creation_waiting_card.dart';
import 'package:flutter/services.dart';
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
            final file = await File(
              '${folder.path}/result.png',
            ).writeAsBytes(image.encodePng(image.Image(width: 30, height: 30)));
            final created = DateTime(2025, 1, 2);
            await repository.enqueue(
              GenerationBatchRowsCompanion.insert(
                id: 'batch',
                topicId: const Value('topic'),
                providerId: _provider.id,
                modelId: _model,
                mode: MediaMode.image,
                prompt: 'A wide mountain lake',
                paramsJson: '{}',
                referencesJson: '[]',
                status: GenerationStatus.succeeded,
                source: GenerationSource.workbench,
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
            for (var index = 0; index < 2; index++) {
              await harness.database
                  .into(harness.database.generationItemRows)
                  .insert(
                    GenerationItemRowsCompanion.insert(
                      id: 'image-$index',
                      batchId: 'batch',
                      ordinal: index,
                      mode: MediaMode.image,
                      path: file.path,
                      mime: 'image/png',
                      byteSize: await file.length(),
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
            home: const DesktopMediaCreationPage(),
          ),
        ),
      );
      await tester.tap(find.text('All creations'));
      await tester.pumpAndSettle();
      expect(find.byType(CreationArtworkTile), findsNWidgets(2));
      await tester.tap(find.byType(CreationArtworkTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Show in topic'));
      await tester.pumpAndSettle();
      expect(find.text('A wide mountain lake'), findsOneWidget);
      expect(find.text('Mountain trip'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
              paramsJson: jsonEncode({'count': chat ? 1 : 3}),
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
        expect(
          find.text(desktop ? '1 image' : 'Auto · 1 image'),
          findsOneWidget,
        );
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
