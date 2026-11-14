import 'dart:async';
import 'package:Kelivo/utils/image_compressor.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:drift/native.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/composer_draft_store.dart';
import 'package:Kelivo/core/models/image_edit_document.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/services/file_upload_service.dart';
import 'package:Kelivo/features/chat/pages/image_editor_page.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

class _Picker extends ImagePickerPlatform {
  _Picker(this.gallery, this.camera);
  final List<String> gallery;
  final String camera;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => gallery.map(XFile.new).toList();

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    expect(source, ImageSource.camera);
    return XFile(camera);
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  Completer<void>? gate;
  @override
  Future<String?> getApplicationSupportPath() async {
    await gate?.future;
    return path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() => getApplicationSupportPath();
}

void main() {
  late Directory dir;
  late List<String> paths;
  late PathProviderPlatform previous;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kelivo-composer-images-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(dir.path);
    paths = [];
    for (var i = 0; i < 3; i++) {
      final bitmap = image.Image(width: 120, height: 80);
      image.fill(bitmap, color: image.ColorRgb8(60 + i * 40, 150, 200));
      final path = '${dir.path}/photo$i.png';
      await File(path).writeAsBytes(image.encodePng(bitmap));
      paths.add(path);
    }
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await dir.delete(recursive: true);
  });
  Future<void> drain(WidgetTester tester, {bool Function()? done}) async {
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump(const Duration(milliseconds: 30));
      if (i >= 12 &&
          (done?.call() ?? true) &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  Future<
    (
      ChatInputBarController,
      TextEditingController,
      FocusNode,
      ValueNotifier<int>,
    )
  >
  open(
    WidgetTester tester, {
    ChatInputSubmissionResult submission = ChatInputSubmissionResult.rejected,
    Size size = const Size(1000, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final assistant = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final media = ChatInputBarController();
    final controller = TextEditingController(text: 'keep my draft');
    final focus = FocusNode();
    final sent = ValueNotifier(0);
    addTearDown(settings.dispose);
    addTearDown(assistant.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(sent.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistant),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                controller: controller,
                focusNode: focus,
                mediaController: media,
                onSend: (_) async {
                  sent.value++;
                  return submission;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (media, controller, focus, sent);
  }

  FileUploadService pickerService(
    WidgetTester tester,
    ChatInputBarController media, {
    List<String>? gallery,
  }) {
    final context = tester.element(find.byType(ChatInputBar));
    final settings = context.read<SettingsProvider>();
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _Picker(gallery ?? [paths[0]], paths[1]);
    addTearDown(() => ImagePickerPlatform.instance = previous);
    const haptics = MethodChannel('haptic_feedback');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(haptics, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(haptics, null));
    return FileUploadService(
      getContext: () => context,
      mediaController: media,
      isImageCropperEnabled: () => settings.imageCropperEnabled,
      getImageCompressConfig: settings.resolveImageCompressConfig,
    );
  }

  final mobilePlatforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });
  testWidgets(
    'mobile gallery opens crop for the picked batch; each edit retains its full original',
    (tester) async {
      final (media, text, _, sent) = await open(
        tester,
        size: const Size(393, 852),
      );
      final service = pickerService(
        tester,
        media,
        gallery: [paths[0], paths[0]],
      );
      final settings = service.getContext().read<SettingsProvider>();
      await settings.setImageCropperEnabled(true);
      media.addImages([paths[2]]);
      final picking = service.onPickPhotos();
      await tester.pump();
      await drain(tester);
      expect(
        tester.widget<ImageEditorPage>(find.byType(ImageEditorPage)).images,
        hasLength(2),
      );
      expect(find.byTooltip('Rotate left'), findsOneWidget);
      expect(media.snapshotInput(text.text).imagePaths, [paths[2]]);
      await tester.tap(find.text('1:1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('image-editor-thumbnail-1')));
      await drain(tester);
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await drain(tester, done: () => !media.hasUnreadyImages);
      await picking;
      final imported = media.snapshotDraft(text.text).images;
      expect(imported, hasLength(3));
      expect(imported[0].path, paths[2]);
      expect(imported[1].edits.crop, isNotNull);
      expect(imported[2].edits.quarterTurns, 3);
      final pixels = await tester.runAsync(() async {
        Future<(int, int)> dimensions(String path) async {
          final decoded = image.decodeImage(await File(path).readAsBytes())!;
          return (decoded.width, decoded.height);
        }

        return [
          for (final item in imported.skip(1)) ...[
            await dimensions(item.path),
            await dimensions(item.sourcePath!),
          ],
        ];
      });
      expect(pixels, [(80, 80), (120, 80), (80, 120), (120, 80)]);
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:1')),
      );
      await drain(tester);
      await tester.tap(find.text('Edit'));
      await drain(tester);
      await tester.tap(find.text('Revert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await drain(tester);
      final restored = media.snapshotDraft(text.text).images[1];
      expect(restored.edits.isEmpty, isTrue);
      expect(restored.path, restored.sourcePath);
      expect(text.text, 'keep my draft');
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: mobilePlatforms,
  );

  testWidgets(
    'wide tablet crop keeps batch navigation and requires removing an unreadable photo',
    (tester) async {
      final (media, text, _, sent) = await open(
        tester,
        size: const Size(1366, 1024),
      );
      final corrupt = File('${dir.path}/corrupt.jpg');
      await tester.runAsync(() => corrupt.writeAsBytes([1, 2, 3]));
      final service = pickerService(
        tester,
        media,
        gallery: [paths[0], corrupt.path],
      );
      await service
          .getContext()
          .read<SettingsProvider>()
          .setImageCropperEnabled(true);
      final picking = service.onPickPhotos();
      await tester.pump();
      await drain(tester);
      expect(find.byTooltip('Rotate left'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('image-editor-thumbnail-1')),
        findsOneWidget,
      );
      await tester.tap(find.text('Done'));
      await drain(tester);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(media.hasDraftMedia, isFalse);
      await tester.tap(find.text('Remove'));
      await drain(tester);
      await tester.tap(find.text('Done'));
      await drain(tester, done: () => !media.hasUnreadyImages);
      await picking;
      final imported = media.snapshotInput(text.text).imagePaths.single;
      expect(image.decodeImage(File(imported).readAsBytesSync())!.width, 120);
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'mobile camera honors the crop preference and cancelling leaves the draft intact',
    (tester) async {
      final (media, text, _, sent) = await open(
        tester,
        size: const Size(393, 852),
      );
      final service = pickerService(tester, media);
      final context = service.getContext(),
          settings = context.read<SettingsProvider>();
      await service.onPickCamera(context);
      await drain(tester, done: () => !media.hasUnreadyImages);
      expect(find.byType(ImageEditorPage), findsNothing);
      final original = media.snapshotDraft(text.text).images.single;
      expect(original.edits.isEmpty, isTrue);
      await settings.setImageCropperEnabled(true);
      final picking = service.onPickCamera(context);
      await tester.pump();
      await drain(tester);
      expect(find.byTooltip('Rotate left'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await picking;
      expect(
        media.snapshotDraft(text.text).images.single.sameValue(original),
        isTrue,
      );
      expect(text.text, 'keep my draft');
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: mobilePlatforms,
  );

  testWidgets(
    'duplicate source paths keep separate attachment identities in preview',
    (tester) async {
      final (media, _, _, _) = await open(tester);
      media.addImages([paths[0], paths[0]]);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:1')),
      );
      await drain(tester);
      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      expect(viewer.initialIndex, 1);
      expect(viewer.images.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'processing image cannot open a preview and becomes available only when ready',
    (tester) async {
      final (media, text, _, sent) = await open(tester);
      final platform = PathProviderPlatform.instance as _Paths;
      platform.gate = Completer<void>();
      media.enqueueImages(
        [paths[0]],
        const ImageCompressConfig(
          enabled: false,
          quality: 100,
          maxLongEdge: 1568,
          includeTransparent: false,
        ),
      );
      await tester.pump();
      expect(media.hasUnreadyImages, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await tester.pump();
      expect(find.byType(ImageViewerPage), findsNothing);
      platform.gate!.complete();
      await drain(tester, done: () => !media.hasUnreadyImages);
      expect(media.hasUnreadyImages, isFalse);
      expect(
        media.snapshotDraft(text.text).images.single.sourcePath,
        isNotNull,
      );
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'preview opens selected ready image; close and remove preserve the draft',
    (tester) async {
      final (media, text, focus, sent) = await open(tester);
      media.restoreDraft(
        ComposerDraftInput(
          text: text.text,
          images: [
            DraftImage(path: paths[0]),
            DraftImage(path: '${dir.path}/missing.png', failed: true),
            DraftImage(path: paths[2]),
          ],
        ),
      );
      focus.requestFocus();
      text.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:2')),
      );
      await drain(tester);
      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      expect(viewer.images, [paths[0], paths[2]]);
      expect(viewer.initialIndex, 1);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(text.text, 'keep my draft');
      expect(
        text.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      await tester.tap(find.byKey(const ValueKey('chat-input-image-remove:0')));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(media.snapshotDraft(text.text).images.length, 2);
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'draft pull-down returns after a short drag and keeps moving after a dismissal',
    (tester) async {
      final (media, text, _, sent) = await open(
        tester,
        size: const Size(393, 852),
      );
      media.addImages([paths[0], paths[1]]);
      text.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
      await tester.pumpAndSettle();
      final draft = media.snapshotDraft(text.text);
      Future<void> previewSecondImage() async {
        await tester.tap(
          find.byKey(const ValueKey('chat-input-image-preview:1')),
        );
        await drain(tester);
      }

      await previewSecondImage();
      final photo = find.descendant(
        of: find.byKey(const ValueKey('image-viewer-page-view')),
        matching: find.byKey(ValueKey((paths[1], 0))),
      );
      final center = tester.getCenter(photo);

      final short = await tester.startGesture(center);
      await short.moveBy(const Offset(0, 25));
      await short.moveBy(const Offset(0, 50));
      await tester.pump();
      final shortRelease = tester.getCenter(photo).dy;
      expect(shortRelease, greaterThan(center.dy));
      await short.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getCenter(photo).dy, lessThan(shortRelease));
      await tester.pumpAndSettle();
      expect(tester.getCenter(photo), center);

      final dismiss = await tester.startGesture(center);
      await dismiss.moveBy(const Offset(0, 25));
      await dismiss.moveBy(const Offset(0, 180));
      await tester.pump();
      final release = tester.getCenter(photo).dy;
      expect(release, greaterThan(center.dy + 140));
      final route = ModalRoute.of(tester.element(photo))!;
      await dismiss.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getCenter(photo).dy, greaterThan(release + 1));
      expect(route.animation!.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);

      await previewSecondImage();
      await tester.flingFrom(center, const Offset(0, 95), 1600);
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(media.snapshotDraft(text.text).sameValue(draft), isTrue);
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'edit completion updates pixels and metadata then returns directly to composer',
    (tester) async {
      final (media, text, _, sent) = await open(tester);
      media.addImages([paths[0], paths[1]]);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await drain(tester);
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await drain(tester);
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await drain(tester);
      expect(find.byType(ImageEditorPage), findsNothing);
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(text.text, 'keep my draft');
      expect(sent.value, 0);
      final snapshot = media.snapshotDraft(text.text);
      expect(snapshot.images.first.path, isNot(paths[0]));
      expect(snapshot.images.first.edits.quarterTurns, 3);
      expect(snapshot.images.first.sourcePath, paths[0]);
      expect(snapshot.images[1].path, paths[1]);
      final bytes = await tester.runAsync(
        () => File(snapshot.images.first.path).readAsBytes(),
      );
      final rendered = image.decodeImage(bytes!)!;
      expect(rendered.width, 80);
      expect(rendered.height, 120);
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await drain(tester);
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await drain(tester);
      expect(find.text('Revert'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageEditorPage), findsNothing);
      expect(find.byType(ImageViewerPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'retry sends the re-rendered mosaic and keeps the selected quality',
    (tester) async {
      final (media, text, _, sent) = await open(tester);
      final bitmap = image.Image(width: 640, height: 200);
      image.fill(bitmap, color: image.ColorRgb8(255, 255, 255));
      for (var x = 200; x < 440; x += 6) {
        image.fillRect(
          bitmap,
          x1: x,
          y1: 65,
          x2: x + 2,
          y2: 85,
          color: image.ColorRgb8(0, 0, 0),
        );
      }
      await tester.runAsync(
        () => File(paths[0]).writeAsBytes(image.encodePng(bitmap)),
      );
      const edits = ImageEditDocument(
        mosaic: [ImageMosaicOp(rect: Rect.fromLTWH(300, 90, 400, 60))],
      );
      media.restoreDraft(
        ComposerDraftInput(
          images: [
            DraftImage(
              path: '${dir.path}/lost.png',
              sourcePath: paths[0],
              edits: edits,
              quality: ImageUploadQuality.original,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(media.hasUnreadyImages, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await drain(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(media.hasUnreadyImages, isFalse);
      expect(sent.value, 0);
      final restored = media.snapshotDraft(text.text).images.single;
      expect(restored.edits.sameValue(edits), isTrue);
      expect(restored.quality, ImageUploadQuality.original);
      final queued = media.snapshotInput(text.text).imagePaths.single;
      final bytes = await tester.runAsync(() => File(queued).readAsBytes());
      final rendered = image.decodePng(bytes!)!;
      var redacted = 0;
      for (var y = 65; y <= 85; y++) {
        for (var x = 200; x < 440; x++) {
          if (rendered.getPixel(x, y).r != bitmap.getPixel(x, y).r) redacted++;
        }
      }
      expect(redacted, greaterThan(1000));
      expect(rendered.getPixel(5, 5).r, 255);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<void> writeDetailedImage(WidgetTester tester) async {
    final random = math.Random(17);
    final bitmap = image.Image(width: 320, height: 240);
    for (final pixel in bitmap) {
      pixel.setRgb(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }
    await tester.runAsync(
      () => File(paths[0]).writeAsBytes(image.encodePng(bitmap)),
    );
  }

  testWidgets(
    'quality update blocks send after closing preview and preserves a legacy baseline',
    (tester) async {
      final (media, text, _, sent) = await open(tester);
      await writeDetailedImage(tester);
      media.restoreDraft(
        ComposerDraftInput(images: [DraftImage(path: paths[0])]),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await drain(tester);
      await tester.tap(find.byTooltip('Image size'));
      await tester.pumpAndSettle();
      final platform = PathProviderPlatform.instance as _Paths;
      platform.gate = Completer<void>();
      await tester.tap(find.text('Data Saver'));
      await tester.pump();
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(media.hasUnreadyImages, isTrue);
      await tester.tap(find.byIcon(Lucide.ArrowUp));
      await tester.pump();
      expect(sent.value, 0);
      platform.gate!.complete();
      await drain(tester, done: () => !media.hasUnreadyImages);
      expect(media.hasUnreadyImages, isFalse);
      final draft = ComposerDraftInput.fromJson(
        media.snapshotDraft(text.text).toJson(),
      );
      final saved = draft.images.single;
      expect(saved.path, isNot(paths[0]));
      expect(saved.quality, ImageUploadQuality.saver);
      expect(saved.sourcePath, paths[0]);
      expect(saved.sourceIsOriginal, isFalse);
      media.restoreDraft(draft);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await drain(tester);
      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      expect(viewer.draft!.originalAvailable(0), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final send in [false, true]) {
    testWidgets(
      'private unedited source is retired when the attachment is ${send ? "sent" : "removed"}',
      (tester) async {
        final (media, text, _, sent) = await open(
          tester,
          submission: ChatInputSubmissionResult.sent,
        );
        await writeDetailedImage(tester);
        media.enqueueImages(
          [paths[0]],
          const ImageCompressConfig(
            enabled: true,
            quality: 50,
            maxLongEdge: 128,
            includeTransparent: false,
          ),
        );
        await drain(tester);
        final item = media.snapshotDraft(text.text).images.single;
        expect(item.sourcePath, isNot(paths[0]));
        expect(item.path, isNot(item.sourcePath));
        await tester.tap(
          send
              ? find.byIcon(Lucide.ArrowUp)
              : find.byKey(const ValueKey('chat-input-image-remove:0')),
        );
        await drain(tester);
        expect(sent.value, send ? 1 : 0);
        expect(media.snapshotDraft(text.text).images, isEmpty);
        expect(File(item.sourcePath!).existsSync(), isFalse);
        expect(File(item.path).existsSync(), send);
        expect(File(paths[0]).existsSync(), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'temporary conversation reclaims an in-place clipboard original after send',
    (tester) async {
      final (media, text, _, sent) = await open(
        tester,
        submission: ChatInputSubmissionResult.sent,
      );
      final db = AppDatabase(NativeDatabase.memory());
      final store = ComposerDraftStore(db, directory: () async => dir);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      media.draftStore = store;
      media.draftOwnerId = 'temporary';
      expect(media.capture().persistent, isFalse);
      await writeDetailedImage(tester);
      final source = await tester.runAsync(() async {
        final target = await media.uploadDirectory();
        return File(paths[0]).copy('${target.path}/paste_12.png');
      });
      media.enqueueImages(
        [source!.path],
        const ImageCompressConfig(
          enabled: true,
          quality: 50,
          maxLongEdge: 128,
          includeTransparent: false,
        ),
        deleteSourcesAfterProcessing: true,
      );
      await drain(tester, done: () => !media.hasUnreadyImages);
      final processed = media.snapshotDraft(text.text).images.single;
      expect(processed.sourcePath, source.path);
      expect(processed.path, isNot(source.path));
      await tester.tap(find.byIcon(Lucide.ArrowUp));
      await drain(tester, done: () => !source.existsSync());
      expect(sent.value, 1);
      expect(source.existsSync(), isFalse);
      expect(File(processed.path).existsSync(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'retrying a persisted clipboard source does not turn it into a shared file',
    (tester) async {
      final (media, text, _, _) = await open(tester);
      final db = AppDatabase(NativeDatabase.memory());
      final store = ComposerDraftStore(db, directory: () async => dir);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await tester.runAsync(() => store.load('owner'));
      final privateDir = await tester.runAsync(
        () => store.directoryFor('owner'),
      );
      media.draftStore = store;
      media.draftOwnerId = 'owner';
      media.onDraftChanged = () =>
          store.setInput('owner', media.snapshotDraft(text.text));
      await writeDetailedImage(tester);
      final source = await tester.runAsync(
        () => File(paths[0]).copy('${privateDir!.path}/paste_5.png'),
      );
      media.restoreDraft(
        ComposerDraftInput(
          images: [
            DraftImage(
              path: '${privateDir!.path}/paste_5.jpg',
              sourcePath: source!.path,
              quality: ImageUploadQuality.saver,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await drain(tester, done: () => !media.hasUnreadyImages);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        media.snapshotDraft(text.text).images.single.sourcePath,
        source.path,
      );
      await tester.tap(find.byKey(const ValueKey('chat-input-image-remove:0')));
      await drain(tester, done: () => !source.existsSync());
      expect(source.existsSync(), isFalse);
      media.onDraftChanged = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'removing an import in progress also retires late private writes',
    (tester) async {
      final (media, text, _, _) = await open(tester);
      final db = AppDatabase(NativeDatabase.memory());
      final gate = Completer<void>();
      var paused = false;
      var directoryRequests = 0;
      final store = ComposerDraftStore(
        db,
        directory: () async {
          if (paused) {
            directoryRequests++;
            await gate.future;
          }
          return dir;
        },
      );
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await tester.runAsync(() => store.load('owner'));
      final privateDir = await tester.runAsync(
        () => store.directoryFor('owner'),
      );
      media.draftStore = store;
      media.draftOwnerId = 'owner';
      media.onDraftChanged = () =>
          store.setInput('owner', media.snapshotDraft(text.text));
      await writeDetailedImage(tester);
      paused = true;
      await tester.runAsync(() async {
        media.enqueueImages(
          [paths[0]],
          const ImageCompressConfig(
            enabled: true,
            quality: 45,
            maxLongEdge: 128,
            includeTransparent: false,
          ),
        );
      });
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-input-image-remove:0')));
      await tester.pump();
      gate.complete();
      await drain(
        tester,
        done: () =>
            directoryRequests >= 3 &&
            privateDir!.listSync().whereType<File>().isEmpty,
      );
      expect(directoryRequests, greaterThanOrEqualTo(3));
      expect(media.snapshotDraft(text.text).images, isEmpty);
      expect(privateDir!.listSync().whereType<File>(), isEmpty);
      expect(File(paths[0]).existsSync(), isTrue);
      media.onDraftChanged = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed attachment opens recovery screen without opening preview',
    (tester) async {
      final (media, text, _, sent) = await open(tester);
      media.restoreDraft(
        ComposerDraftInput(
          text: text.text,
          images: [DraftImage(path: '${dir.path}/missing.png', failed: true)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-image-preview:0')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(find.text("Couldn't process image"), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(media.snapshotDraft(text.text).images, isEmpty);
      expect(sent.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
