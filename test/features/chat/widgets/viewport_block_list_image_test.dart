import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/features/chat/widgets/viewport_block_list.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  var conversation = Conversation(id: 'images', title: 'Images');

  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
}

class _ImageResolver extends FileLinkResolver {
  _ImageResolver({required super.workspaces, required this.root});

  final Directory root;
  final rootsByWorkspace = <String, Directory>{};
  Future<void>? pending;
  bool reject = false;

  @override
  Future<FileSystemEntity?> resolveToHostEntry(
    KelivoLink link, {
    required String conversationId,
    required WorkspaceBinding binding,
  }) async {
    if (pending case final wait?) await wait;
    if (reject) return null;
    final selectedRoot = rootsByWorkspace[binding.workspaceId] ?? root;
    final file = File('${selectedRoot.path}/${link.relativePath}');
    return file.existsSync() ? file : null;
  }
}

class _RouteObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  for (final reloadCase in [
    'cached',
    'evicted',
    'rebound',
    'missing',
    'open',
    'rejected',
  ]) {
    testWidgets('workspace image re-entry: $reloadCase', (tester) async {
      final root = Directory.systemTemp.createTempSync('kelivo_image_reentry_');
      addTearDown(() => root.deleteSync(recursive: true));
      File(
        '${root.path}/dash-dark-1.png',
      ).writeAsBytesSync(image.encodePng(image.Image(width: 360, height: 571)));
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      addTearDown(settings.dispose);
      final workspaces = WorkspaceProvider(
        store: ExtensionEntityStore(harness.database),
      );
      await workspaces.loaded;
      addTearDown(workspaces.dispose);
      final resolver = _ImageResolver(workspaces: workspaces, root: root);
      final chat = _Chat();
      addTearDown(chat.dispose);
      final bucket = PageStorageBucket();
      final observer = _RouteObserver();
      var generation = 0;
      Widget host() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          Provider<FileLinkResolver>.value(value: resolver),
        ],
        child: MaterialApp(
          navigatorObservers: [observer],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: MarkdownWithCodeHighlight(
                key: ValueKey(generation),
                text: '![360x571](kelivo://workspace/dash-dark-1.png)',
                conversationId: 'images',
              ),
            ),
          ),
        ),
      );

      Future<void> waitForPixels() async {
        for (var frame = 0; frame < 30; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          final pixels = tester.widgetList<RawImage>(find.byType(RawImage));
          if (pixels.length == 1 && pixels.single.image != null) break;
        }
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      }

      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await tester.pumpWidget(host());
      await waitForPixels();
      final size = tester.getSize(find.byType(Image));

      if (reloadCase == 'evicted') {
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
      } else if (reloadCase == 'rebound') {
        final other = Directory('${root.path}/other')..createSync();
        File('${other.path}/dash-dark-1.png').writeAsBytesSync(
          image.encodePng(image.Image(width: 360, height: 200)),
        );
        resolver.rootsByWorkspace['other'] = other;
        chat.conversation = Conversation(
          id: 'images',
          title: 'Images',
          extras: {WorkspaceBinding.keyId: 'other'},
        );
      } else if (reloadCase == 'missing') {
        File('${root.path}/dash-dark-1.png').deleteSync();
      }
      final reload = Completer<void>();
      resolver.pending = reload.future;
      generation++;
      await tester.pumpWidget(host());
      for (var frame = 0; frame < 3; frame++) {
        // The global decoded image is still cached. Revalidating the workspace
        // path must not replace it with a spinner for a single painted frame.
        if (reloadCase == 'cached' ||
            reloadCase == 'open' ||
            reloadCase == 'rejected') {
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(RawImage), findsOneWidget);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          expect(tester.getSize(find.byType(Image)), size);
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(RawImage), findsNothing);
          expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (reloadCase == 'open' || reloadCase == 'rejected') {
        resolver.reject = reloadCase == 'rejected';
        await tester.tap(find.byType(Image));
        await tester.pump();
        expect(
          observer.pushes,
          1,
          reason: 'Opening must await workspace validation.',
        );
        reload.complete();
        await tester.idle();
        expect(observer.pushes, reloadCase == 'open' ? 2 : 1);
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }
      reload.complete();
      if (reloadCase == 'missing') {
        await tester.pumpAndSettle();
        expect(find.byType(RawImage), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      } else {
        await waitForPixels();
        expect(tester.getSize(find.byType(Image)), size);
        if (reloadCase == 'rebound') {
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image!.height,
            200,
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final switchBucket in [false, true]) {
    testWidgets(
      switchBucket
          ? 'workspace image heights follow the message storage bucket'
          : 'workspace images retain different heights while reloading',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final root = Directory.systemTemp.createTempSync(
          'kelivo_image_extents_',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        for (final entry in {
          'wide.png': (16, 8),
          'tall.png': (4, 12),
        }.entries) {
          File('${root.path}/${entry.key}').writeAsBytesSync(
            image.encodePng(
              image.Image(width: entry.value.$1, height: entry.value.$2),
            ),
          );
        }
        final harness = await createBusinessTestHarness();
        final settings = SettingsProvider(harness.preferences);
        await settings.loaded;
        addTearDown(settings.dispose);
        final workspaces = WorkspaceProvider(
          store: ExtensionEntityStore(harness.database),
        );
        await workspaces.loaded;
        addTearDown(workspaces.dispose);
        final resolver = _ImageResolver(workspaces: workspaces, root: root);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var bucket = PageStorageBucket();
        var width = 360.0;
        var generation = 0;
        final sources = [
          '![wide](kelivo://workspace/wide.png)',
          '![portrait](kelivo://workspace/tall.png)',
          '![720x300](kelivo://workspace/wide.png)',
          '<img src="${root.path}/tall.png" width="96" height="128">',
        ];
        Widget host() => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider<ChatService>(create: (_) => _Chat()),
            Provider<FileLinkResolver>.value(value: resolver),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PageStorage(
                bucket: bucket,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: SingleChildScrollView(
                      controller: controller,
                      child: ViewportBlockList(
                        key: ValueKey(generation),
                        storageId: 'body',
                        itemCount: 40,
                        structureToken: 40,
                        itemKey: (i) => i,
                        estimateExtent: (i, width) => 100,
                        itemBuilder: (context, i) => i < sources.length
                            ? MarkdownWithCodeHighlight(
                                key: ValueKey('image-$i'),
                                text: sources[i],
                                conversationId: 'images',
                                detailsStateKey: ('images', i),
                              )
                            : SizedBox(height: 100, child: Text('row-$i')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        Future<void> settleImages() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            final decoded = tester.widgetList<RawImage>(find.byType(RawImage));
            if (decoded.length == 4 &&
                decoded.every((image) => image.image != null)) {
              break;
            }
          }
          final decoded = tester.widgetList<RawImage>(find.byType(RawImage));
          expect(decoded, hasLength(4));
          expect(decoded.every((image) => image.image != null), isTrue);
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(host());
        await tester.pump();
        await settleImages();
        Size imageSize(int i) => tester.getSize(
          find.descendant(
            of: find.byKey(ValueKey('image-$i')),
            matching: find.byType(Image),
          ),
        );
        expect(imageSize(0), const Size(360, 180));
        expect(imageSize(1), const Size(360, 1080));
        expect(imageSize(2), const Size(360, 150));
        expect(imageSize(3), const Size(96, 128));
        if (switchBucket) {
          bucket = PageStorageBucket();
          await tester.pumpWidget(host());
          await tester.pumpAndSettle();
        }
        controller.jumpTo(1200);
        await tester.pumpAndSettle();
        final measuredExtent = controller.position.maxScrollExtent;

        final loading = Completer<void>();
        resolver.pending = loading.future;
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        generation++;
        await tester.pumpWidget(host());
        await tester.pump();
        expect(
          controller.position.maxScrollExtent,
          closeTo(measuredExtent, .5),
        );
        expect(controller.offset, closeTo(1200, .5));

        width = 240;
        await tester.pumpWidget(host());
        await tester.pump();
        final resizedExtent = controller.position.maxScrollExtent;
        final resizedOffset = controller.offset;
        loading.complete();
        await settleImages();
        expect(controller.position.maxScrollExtent, closeTo(resizedExtent, .5));
        expect(controller.offset, closeTo(resizedOffset, .5));
        expect(imageSize(0), const Size(240, 120));
        expect(imageSize(1), const Size(240, 720));
        expect(imageSize(2), const Size(240, 100));
        expect(imageSize(3), const Size(96, 128));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
