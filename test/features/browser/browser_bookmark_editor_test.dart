import 'package:Kelivo/features/browser/widgets/browser_text_field.dart';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_bookmark_editor.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  final original = BrowserBookmark(
    url: 'https://example.com',
    title: 'Original title',
    createdAt: DateTime(2026),
  );

  Future<void> mount(
    WidgetTester tester, {
    required ValueChanged<BrowserBookmarkEdit?> onResult,
    double scale = 1,
    Size size = const Size(390, 844),
    Widget? favicon,
    Locale locale = const Locale('en'),
    double letterSpacing = .25,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: ThemeData(
          platform: debugDefaultTargetPlatformOverride ?? TargetPlatform.iOS,
          textTheme: ThemeData().textTheme
              .apply(bodyColor: Colors.black)
              .copyWith(
                bodyMedium: TextStyle(
                  fontSize: 14,
                  letterSpacing: letterSpacing,
                ),
              ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('editorPixels'),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: BrowserTextButton(
                onPressed: () async => onResult(
                  await showBrowserBookmarkEditor(
                    context,
                    bookmark: original,
                    favicon: favicon,
                  ),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mobile cancel returns no edit and injected favicon stays inside the grouped form',
    (tester) async {
      BrowserBookmarkEdit? result = (title: 'not returned', url: 'pending');
      await mount(
        tester,
        onResult: (next) => result = next,
        favicon: const ColoredBox(
          key: ValueKey('providedFavicon'),
          color: Colors.orange,
        ),
      );
      final editor = find.byType(BrowserBookmarkEditor);
      final page = find.byType(BrowserManagementPage);
      expect(tester.getSize(page), const Size(390, 844));
      expect(
        ModalRoute.of(tester.element(editor)),
        isA<CupertinoPageRoute<BrowserBookmarkEdit>>(),
      );
      expect(find.byType(BrowserDialogHeader), findsNothing);
      final group = find.descendant(
        of: editor,
        matching: find.byType(BrowserSurfaceGroup),
      );
      final favicon = find.byKey(const ValueKey('providedFavicon'));
      expect(tester.getSize(favicon), const Size(40, 40));
      expect(tester.getRect(group).contains(tester.getCenter(favicon)), isTrue);
      final title = find.byKey(const ValueKey('browserBookmarkTitleField'));
      final url = find.byKey(const ValueKey('browserBookmarkUrlField'));
      expect(tester.getRect(title).top, lessThan(tester.getRect(url).top));
      await tester.enterText(title, 'Unsaved changes');
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(result, isNull);
      expect(find.text('Edit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cupertino bookmark editor inherits its page text style', (
    tester,
  ) async {
    await mount(tester, onResult: (_) {}, letterSpacing: 1.4);
    final editor = find.byType(BrowserBookmarkEditor);
    expect(
      ModalRoute.of(tester.element(editor)),
      isA<CupertinoPageRoute<BrowserBookmarkEdit>>(),
    );
    final title = find.text('Edit bookmark');
    final paragraph = tester.renderObject<RenderParagraph>(title);
    final style = paragraph.text.style!;
    final pageTheme = Theme.of(tester.element(title));
    expect(style.color, pageTheme.colorScheme.onSurface);
    expect(style.decoration, TextDecoration.none);
    expect(style.fontSize, 17);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.letterSpacing, 1.4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile editor keeps top save accessible with large text and a keyboard',
    (tester) async {
      BrowserBookmarkEdit? result;
      await mount(
        tester,
        onResult: (next) => result = next,
        scale: 3,
        size: const Size(320, 640),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final url = find.byKey(const ValueKey('browserBookmarkUrlField'));
      await tester.ensureVisible(url);
      await tester.enterText(url, 'https://user:secret@example.com');
      final save = find.widgetWithText(BrowserTextButton, 'Save');
      final bounds = tester.getRect(save);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      expect(bounds.bottom, lessThan(380));
      expect(
        tester.widget<BrowserTextButton>(save).foregroundColor,
        Colors.white,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text('Enter a valid HTTP or HTTPS website address.'),
        findsOneWidget,
      );
      await tester.enterText(url, 'https://new.example/path');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(result, (
        title: 'Original title',
        url: 'https://new.example/path',
      ));
      expect(find.byType(BrowserBookmarkEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets(
      'mobile ${locale.languageCode} save paints its full label and header stays centered',
      (tester) async {
        await mount(
          tester,
          locale: locale,
          letterSpacing: 1.4,
          onResult: (_) {},
        );
        final localized = AppLocalizations.of(
          tester.element(find.byType(BrowserBookmarkEditor)),
        )!;
        final label = find.text(localized.browserSave);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        final title = find.text(localized.browserEditBookmark);
        expect(tester.getCenter(title).dx, closeTo(195, .01));
        final save = find.widgetWithText(
          BrowserTextButton,
          localized.browserSave,
        );
        expect(
          tester.getRect(save).left,
          greaterThan(tester.getRect(title).right),
        );
        expect(
          tester.getCenter(save).dy,
          closeTo(
            tester.getCenter(find.byTooltip(localized.browserCancel)).dy,
            .01,
          ),
        );

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('editorPixels')),
        );
        final image = (await tester.runAsync(boundary.toImage))!;
        final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final labelBounds = tester.getRect(label);
        var visibleTextPixels = 0;
        for (
          var y = labelBounds.top.ceil();
          y < labelBounds.bottom.floor();
          y++
        ) {
          for (
            var x = labelBounds.left.ceil();
            x < labelBounds.right.floor();
            x++
          ) {
            final offset = (y * image.width + x) * 4;
            if (bytes.getUint8(offset) > 220 &&
                bytes.getUint8(offset + 1) > 220 &&
                bytes.getUint8(offset + 2) > 220) {
              visibleTextPixels++;
            }
          }
        }
        image.dispose();
        expect(visibleTextPixels, greaterThan(40));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'desktop editor keeps dialog geometry and returns a validated edit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        BrowserBookmarkEdit? result;
        await mount(
          tester,
          onResult: (next) => result = next,
          size: const Size(1100, 800),
        );
        final editor = find.byType(BrowserBookmarkEditor);
        expect(tester.widget<BrowserBookmarkEditor>(editor).fullPage, isFalse);
        expect(find.byType(BrowserManagementPage), findsNothing);
        expect(find.byType(BrowserDialogHeader), findsOneWidget);
        expect(tester.getSize(editor).width, lessThanOrEqualTo(460));
        expect(
          ModalRoute.of(tester.element(editor)),
          isA<PopupRoute<BrowserBookmarkEdit>>(),
        );
        final fields = find.byType(BrowserTextField);
        await tester.enterText(fields.first, '');
        await tester.enterText(fields.last, 'https://desktop.example');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(result, (
          title: 'desktop.example',
          url: 'https://desktop.example',
        ));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
