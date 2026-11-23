import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/media_repository.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/media_file_store.dart';
import 'package:Kelivo/core/services/media/media_generation_runner.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/desktop/desktop_media_creation_page.dart';
import 'package:Kelivo/features/media/pages/media_creation_page.dart';
import 'package:Kelivo/features/media/providers/media_creation_controller.dart';
import 'package:Kelivo/features/media/widgets/creation_composer.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';

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
    'sending creates a named topic and keeps each topic draft separate',
    () async {
      final harness = await createBusinessTestHarness(
        initial: {BusinessKeyRegistry.creationAutoTitleKey: false},
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await settings.setProviderConfig(_provider.id, _provider);
      final directory = await Directory.systemTemp.createTemp('creation-topic');
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
                  ? const Scaffold(body: DesktopMediaCreationPage())
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
