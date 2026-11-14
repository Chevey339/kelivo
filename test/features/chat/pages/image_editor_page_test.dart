import 'dart:async';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../../support/business_test_harness.dart';
import 'dart:io';
import 'package:Kelivo/core/models/image_edit_document.dart';
import 'package:Kelivo/features/chat/pages/image_editor_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo-editor-widget-');
    final bitmap = image.Image(width: 800, height: 500);
    image.fill(bitmap, color: image.ColorRgb8(220, 230, 240));
    path = '${directory.path}/source.png';
    await File(path).writeAsBytes(image.encodePng(bitmap));
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    List<EditorImage>? images,
    Future<void> Function(Map<int, ImageEditDocument>)? onSave,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => ImageEditorPage(
                      images:
                          images ??
                          [EditorImage(id: 1, path: path, sourcePath: path)],
                      onSave: onSave ?? (_) async {},
                      onRetry: (_) async => null,
                      onRemove: (_) {},
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump(const Duration(milliseconds: 30));
      if (find
              .byKey(const ValueKey('image-editor-stage'))
              .evaluate()
              .isNotEmpty ||
          find.text("Couldn't process image").evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mobile crop, draw and restore are undoable; Done returns without sending',
    (tester) async {
      Map<int, ImageEditDocument>? saved;
      await open(tester, onSave: (docs) async => saved = docs);
      expect(tester.takeException(), isNull);
      expect(find.text('Revert').hitTestable(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1:1'));
      await tester.pumpAndSettle();
      expect(find.text('Revert').hitTestable(), findsOneWidget);
      final cropCenter = tester.getCenter(
        find.byKey(const ValueKey('image-editor-stage')),
      );
      await tester.dragFrom(
        cropCenter - const Offset(110, 110),
        const Offset(20, 20),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-draw')));
      await tester.pumpAndSettle();
      final center = tester.getCenter(
        find.byKey(const ValueKey('image-editor-stage')),
      );
      await tester.dragFrom(
        center - const Offset(50, 0),
        const Offset(100, 30),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revert'));
      await tester.pumpAndSettle();
      expect(find.text('Revert').hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Revert').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageEditorPage), findsNothing);
      expect(saved![1]!.crop, isNotNull);
      expect(saved![1]!.crop!.left, greaterThan(.1875));
      expect(saved![1]!.strokes, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reopened edited image can revert with an initially empty undo history',
    (tester) async {
      Map<int, ImageEditDocument>? saved;
      await open(
        tester,
        images: [
          EditorImage(
            id: 1,
            path: path,
            sourcePath: path,
            document: const ImageEditDocument(quarterTurns: 1),
          ),
        ],
        onSave: (docs) async => saved = docs,
      );
      expect(find.text('Revert').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Revert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(saved![1]!.isEmpty, isTrue);
    },
  );
  testWidgets(
    'cancel confirms only changed documents and keeps editing when requested',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      final keep = find.ancestor(
        of: find.text('Keep editing'),
        matching: find.byType(IosCardPress),
      );
      final keepRect = tester.getRect(keep);
      expect(keepRect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(keepRect.centerRight - const Offset(12, 0));
      await tester.pumpAndSettle();
      expect(find.byType(ImageEditorPage), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageEditorPage), findsNothing);
    },
  );
  testWidgets('text is entered on the image and saved as an editable layer', (
    tester,
  ) async {
    Map<int, ImageEditDocument>? saved;
    await open(
      tester,
      size: const Size(1200, 800),
      onSave: (docs) async => saved = docs,
    );
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-text')));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('image-editor-stage'))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Look here');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(saved![1]!.texts.single.text, 'Look here');
  });
  testWidgets(
    'keyboard keeps mobile text visible without overflowing controls',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-text')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('image-editor-stage'))),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(EditableText), '文字说明');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.textInputAction, TextInputAction.done);
      final rect = tester.getRect(find.byType(EditableText));
      expect(rect.center.dy, lessThan(552));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
    },
  );
  testWidgets(
    'undo and redo cross image boundaries without losing either document',
    (tester) async {
      Map<int, ImageEditDocument>? saved;
      await open(
        tester,
        images: [
          EditorImage(id: 1, path: path, sourcePath: path),
          EditorImage(id: 2, path: path, sourcePath: path),
        ],
        onSave: (docs) async => saved = docs,
      );
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rotate left'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('image-editor-thumbnail-1')));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-draw')));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('image-editor-stage'))),
        const Offset(60, 20),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Revert').hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(saved!.keys, [1]);
      expect(saved![1]!.quarterTurns, 3);
    },
  );

  testWidgets('tapping the letterbox does not start text or draw a mark', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-text')));
    await tester.pumpAndSettle();
    final stage = tester.getRect(
      find.byKey(const ValueKey('image-editor-stage')),
    );
    await tester.tapAt(stage.topCenter + const Offset(0, 16));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-draw')));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      stage.topCenter + const Offset(0, 16),
      const Offset(0, 48),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revert').hitTestable(), findsNothing);
  });

  testWidgets('a locked crop can grow again from an edge midpoint', (
    tester,
  ) async {
    Map<int, ImageEditDocument>? saved;
    await open(tester, onSave: (docs) async => saved = docs);
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    final stage = tester.getRect(
      find.byKey(const ValueKey('image-editor-stage')),
    );
    final photoWidth = stage.width - 24;
    final right = stage.center + Offset(photoWidth * 0.3125, 0);
    await tester.dragFrom(right, const Offset(-50, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(right - const Offset(50, 0), const Offset(35, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final crop = saved![1]!.crop!;
    expect(crop.width, closeTo(.625 - 15 / photoWidth, .01));
    expect(crop.left, closeTo(.1875, .01));
    expect(crop.height * 500, closeTo(crop.width * 800, 1));
  });

  testWidgets('the full crop border and its outside margin follow the finger', (
    tester,
  ) async {
    Map<int, ImageEditDocument>? saved;
    await open(tester, onSave: (docs) async => saved = docs);
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
    await tester.pumpAndSettle();
    final stage = tester.getRect(
      find.byKey(const ValueKey('image-editor-stage')),
    );
    final width = stage.width - 24, height = width * 500 / 800;
    final frame = Rect.fromCenter(
      center: stage.center,
      width: width,
      height: height,
    );
    await tester.dragFrom(
      frame.topCenter - const Offset(72, 15),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revert').hitTestable(), findsOneWidget);
    await tester.dragFrom(
      frame.bottomRight + const Offset(8, 14),
      const Offset(-45, -33),
    );
    await tester.pumpAndSettle();
    // A drag starting far from the frame must not edit it when it crosses the edge.
    await tester.dragFrom(
      frame.topCenter - const Offset(0, 75),
      const Offset(0, 110),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final crop = saved![1]!.crop!;
    expect(crop.left, 0);
    expect(crop.top, closeTo(40 / height, .003));
    expect(crop.right, closeTo(1 - 45 / width, .003));
    expect(crop.bottom, closeTo(1 - 33 / height, .003));
  });

  testWidgets('Done keeps its button state and bounds when Revert appears', (
    tester,
  ) async {
    final saving = Completer<void>();
    var saves = 0;
    await open(
      tester,
      onSave: (_) {
        saves++;
        return saving.future;
      },
    );
    final done = find.ancestor(
      of: find.text('Done'),
      matching: find.byType(IosCardPress),
    );
    final state = tester.state(done);
    final bounds = tester.getRect(done);
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate left'));
    await tester.pump();
    expect(tester.state(done), same(state));
    expect(tester.getRect(done), bounds);
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    expect(tester.state(done), same(state));
    expect(tester.getRect(done), bounds);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(tester.state(done), same(state));
    expect(tester.getRect(done), bounds);
    expect(
      find.descendant(
        of: done,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tapAt(bounds.center);
    await tester.pump();
    expect(saves, 1);
    saving.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ImageEditorPage), findsNothing);
  });

  testWidgets('rotated crop edges keep a screen-sized hit area while zoomed', (
    tester,
  ) async {
    Map<int, ImageEditDocument>? saved;
    await open(
      tester,
      images: [
        EditorImage(
          id: 1,
          path: path,
          document: const ImageEditDocument(quarterTurns: 1),
        ),
      ],
      onSave: (docs) async => saved = docs,
    );
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
    await tester.pumpAndSettle();
    final stage = tester.getRect(
      find.byKey(const ValueKey('image-editor-stage')),
    );
    final height = (stage.width - 24) * 800 / 500;
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    viewer.transformationController!.value = Matrix4.identity()
      ..translateByDouble(
        -stage.width / 2,
        height * .8 - stage.height / 2,
        0,
        1,
      )
      ..scaleByDouble(2, 2, 1, 1);
    await tester.pump();
    // After the quarter turn, the visible top edge represents source left.
    final top = stage.center - Offset(0, height * .2);
    await tester.dragFrom(top + const Offset(48, -35), const Offset(0, 60));
    await tester.dragFrom(top + const Offset(48, -20), const Offset(0, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final crop = saved![1]!.crop!;
    expect(crop.left, closeTo(40 / (height * 2), .003));
    expect(crop.right, 1);
    expect(crop.top, 0);
    expect(crop.bottom, 1);
  });

  testWidgets(
    'a mosaic drawn after flipping is stored over the chosen photo pixels',
    (tester) async {
      Map<int, ImageEditDocument>? saved;
      await open(
        tester,
        images: [
          EditorImage(
            id: 1,
            path: path,
            sourcePath: path,
            document: const ImageEditDocument(flipX: true),
          ),
        ],
        onSave: (docs) async => saved = docs,
      );
      await tester.tap(find.byKey(const ValueKey('image-editor-tool-mosaic')));
      await tester.pumpAndSettle();
      final stage = tester.getRect(
        find.byKey(const ValueKey('image-editor-stage')),
      );
      await tester.tapAt(stage.center - Offset((stage.width - 24) * .25, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(saved![1]!.mosaic.single.points.single.dx, closeTo(750, 1));
    },
  );

  testWidgets('undo in crop mode reloads an evicted image', (tester) async {
    await open(
      tester,
      images: [
        for (var id = 1; id <= 4; id++)
          EditorImage(id: id, path: path, sourcePath: path),
      ],
    );
    final crop = find.byKey(const ValueKey('image-editor-tool-crop'));
    await tester.tap(crop);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate left'));
    await tester.pumpAndSettle();
    await tester.tap(crop);
    await tester.pumpAndSettle();
    for (var i = 1; i < 4; i++) {
      await tester.tap(find.byKey(ValueKey('image-editor-thumbnail-$i')));
      for (var frame = 0; frame < 40; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (find
            .byKey(const ValueKey('image-editor-stage'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
    }
    await tester.tap(crop);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 40 && find.text('1:1').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('Revert').hitTestable(), findsNothing);
  });
  testWidgets('failed input shows retry and remove with disabled tools', (
    tester,
  ) async {
    await open(tester, images: [EditorImage(id: 1, path: path, failed: true)]);
    expect(find.text("Couldn't process image"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('image-editor-tool-crop')));
    await tester.pumpAndSettle();
    expect(find.text('1:1'), findsNothing);
  });
}
