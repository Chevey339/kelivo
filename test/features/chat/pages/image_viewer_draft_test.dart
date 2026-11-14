import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:Kelivo/core/models/image_upload_quality.dart';
import 'package:Kelivo/features/chat/models/image_viewer_draft_mode.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';

void main() {
  late Directory dir;
  late List<String> paths;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kelivo-quality-');
    paths = [];
    for (var i = 0; i < 3; i++) {
      final bitmap = image.Image(width: 120 + i * 60, height: 80 + i * 40);
      image.fill(bitmap, color: image.ColorRgb8(60 + i * 40, 140, 160));
      final path = '${dir.path}/$i.png';
      await File(path).writeAsBytes(image.encodePng(bitmap));
      paths.add(path);
    }
  });
  tearDown(() async => dir.delete(recursive: true));
  Future<void> pump(WidgetTester tester, ImageViewerDraftMode? draft) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageViewerPage(images: [paths[0]], draft: draft),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  String currentPath(WidgetTester tester) {
    final provider = tester.widget<Image>(find.byType(Image).first).image;
    return ((provider as SafeResizeImage).imageProvider as FileImage).file.path;
  }

  testWidgets('compact macOS gallery keeps Copy Image', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pump(tester, null);
      expect(find.byTooltip('Copy Image'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('sent image has no edit or size controls', (tester) async {
    await pump(tester, null);
    expect(find.text('Edit'), findsNothing);
    expect(find.byTooltip('Image size'), findsNothing);
  });
  testWidgets(
    'quality keeps only the latest result and preserves stage geometry',
    (tester) async {
      final requests = <ImageUploadQuality, Completer<String>>{};
      var selected = ImageUploadQuality.balanced;
      await pump(
        tester,
        ImageViewerDraftMode(
          onEdit: (_) async => false,
          qualityOf: (_) => selected,
          customQualityOf: (_) => 85,
          originalAvailable: (_) => true,
          onQualityChanged: (i, q, c) {
            selected = q;
            return (requests[q] = Completer<String>()).future;
          },
        ),
      );
      final before = tester.getRect(find.byType(Image).first);
      await tester.tap(find.byTooltip('Image size'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High Quality'));
      await tester.pump();
      await tester.ensureVisible(find.text('Data Saver'));
      await tester.tap(find.text('Data Saver'));
      await tester.pump();
      requests[ImageUploadQuality.saver]!.complete(paths[2]);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      requests[ImageUploadQuality.high]!.complete(paths[1]);
      await tester.pumpAndSettle();
      expect(currentPath(tester), paths[2]);
      expect(tester.getRect(find.byType(Image).first), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed compression retains the usable file and missing original is disabled',
    (tester) async {
      var calls = 0;
      await pump(
        tester,
        ImageViewerDraftMode(
          onEdit: (_) async => false,
          qualityOf: (_) => ImageUploadQuality.balanced,
          customQualityOf: (_) => 85,
          originalAvailable: (_) => false,
          onQualityChanged: (_, q, c) async {
            calls++;
            throw const FileSystemException('write failed');
          },
        ),
      );
      await tester.tap(find.byTooltip('Image size'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('High Quality'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(currentPath(tester), paths[0]);
      expect(
        AppSnackBarManager().activeToasts.any(
          (entry) => entry.notification.message == "Couldn't process image",
        ),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 4));
      AppSnackBarManager().dismissAll();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('failed preview retries a file that has become readable', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => File(paths[0]).readAsBytes());
    await tester.runAsync(() => File(paths[0]).delete());
    await pump(tester, null);
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('Retry'), findsOneWidget);
    await tester.runAsync(() => File(paths[0]).writeAsBytes(bytes!));
    await tester.tap(find.text('Retry'));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
