import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/settings_page.dart';
import 'package:Kelivo/features/settings/widgets/settings_search_entry.dart';
import 'package:Kelivo/features/settings/widgets/settings_search_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  final output = Platform.environment['KELIVO_SEARCH_MOTION_DIR'];
  final font = Platform.environment['KELIVO_SEARCH_QA_FONT'];
  setUpAll(() async {
    if (font != null) {
      final loader = FontLoader('SettingsSearchQA');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(font).readAsBytes())),
      );
      await loader.load();
    }
    if (output != null) {
      final loader = FontLoader('packages/lucide_icons_flutter/Lucide');
      loader.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await loader.load();
    }
  });

  Future<GlobalKey> pumpSettings(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool reduceMotion = false,
    Size size = const Size(390, 844),
    FakeViewPadding padding = const FakeViewPadding(top: 47, bottom: 34),
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = padding;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    final key = GlobalKey();
    final theme = brightness == Brightness.light
        ? buildLightThemeForScheme(ThemePalettes.defaultPalette.light)
        : buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: font == null
              ? theme
              : theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    fontFamily: 'SettingsSearchQA',
                  ),
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle:
                        (theme.appBarTheme.titleTextStyle ??
                                theme.textTheme.titleLarge!)
                            .copyWith(fontFamily: 'SettingsSearchQA'),
                  ),
                ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Finder surface(Finder parent) => find.descendant(
    of: parent,
    matching: find.byKey(const ValueKey('settings-search-field-surface')),
  );
  Finder content(Finder parent) => find.descendant(
    of: parent,
    matching: find.byKey(const ValueKey('settings-search-field-content')),
  );
  ScrollController scroll(WidgetTester tester) => tester
      .widget<CustomScrollView>(find.byType(CustomScrollView).first)
      .controller!;

  testWidgets('collapsing actually shrinks the field and fades its content', (
    tester,
  ) async {
    try {
      await pumpSettings(tester);
      final controller = scroll(tester);
      final extent = controller.offset;
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final entry = find.byType(SettingsSearchEntry);
      final expanded = tester.getRect(surface(entry));
      expect(expanded.height, 40);
      expect(tester.widget<Opacity>(content(entry)).opacity, 1);
      controller.jumpTo(extent * 0.25);
      await tester.pump();
      final partial = tester.getRect(surface(entry));
      expect(partial.height, closeTo(30, 0.1));
      expect((partial.top - expanded.top).abs(), lessThan(3));
      expect(
        tester.widget<Opacity>(content(entry)).opacity,
        inExclusiveRange(0, 1),
      );
      controller.jumpTo(extent * 0.9);
      await tester.pump();
      expect(tester.getSize(surface(entry)).height, closeTo(4, 0.1));
      expect(tester.widget<Opacity>(content(entry)).opacity, 0);
      controller.jumpTo(extent);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSearchEntry).hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'landscape search respects safe areas throughout the flight (${brightness.name})',
      (tester) async {
        try {
          await pumpSettings(
            tester,
            brightness: brightness,
            size: const Size(844, 390),
            padding: const FakeViewPadding(left: 47, right: 47, bottom: 21),
          );
          scroll(tester).jumpTo(0);
          await tester.pumpAndSettle();
          final entry = find.byType(SettingsSearchEntry);
          final origin = tester.getRect(surface(entry));
          expect(origin.left, 63);
          expect(origin.right, 781);
          await tester.tap(entry);
          await tester.pump();
          final view = find.byType(SettingsSearchView);
          expect(tester.getRect(surface(view)), origin);
          await tester.pump(const Duration(milliseconds: 180));
          final moving = tester.getRect(surface(view));
          expect(moving.left, closeTo(63, 0.01));
          expect(moving.right, lessThanOrEqualTo(781.01));
          expect(moving.top, inExclusiveRange(8, origin.top));
          await tester.pumpAndSettle();
          final target = tester.getRect(surface(view));
          expect(target.left, 63);
          expect(target.top, 8);
          final cancel = tester.getRect(find.text('取消'));
          expect(cancel.left, greaterThanOrEqualTo(target.right + 8));
          expect(cancel.right, lessThanOrEqualTo(797));
          for (final row in tester.widgetList<IosNavRow>(
            find.descendant(of: view, matching: find.byType(IosNavRow)),
          )) {
            final rect = tester.getRect(find.byWidget(row));
            expect(rect.left, greaterThanOrEqualTo(63));
            expect(rect.right, lessThanOrEqualTo(781));
          }
          await tester.tap(find.text('取消'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          final returning = tester.getRect(surface(view));
          expect(returning.left, closeTo(63, 0.01));
          expect(returning.right, lessThanOrEqualTo(781.01));
          expect(returning.top, inExclusiveRange(target.top, origin.top));
          await tester.pumpAndSettle();
          expect(find.byType(SettingsSearchView), findsNothing);
          expect(tester.getRect(surface(entry)), origin);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
    testWidgets(
      'field flies up and returns without moving the settings page (${brightness.name})',
      (tester) async {
        final frames = <Map<String, Object>>[];
        try {
          final boundaryKey = await pumpSettings(
            tester,
            brightness: brightness,
          );
          Future<List<int>?> pixelAt(Offset point) => tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final local = boundary.globalToLocal(point);
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset =
                (local.dy.floor() * image.width + local.dx.floor()) * 4;
            final pixel = bytes!.buffer.asUint8List().sublist(
              offset,
              offset + 4,
            );
            image.dispose();
            return pixel;
          });
          Future<void> record(String phase, {int hold = 30}) async {
            if (output == null) return;
            final name =
                '${brightness.name}-${frames.length.toString().padLeft(3, '0')}-$phase.png';
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(output).createSync(recursive: true);
              await File(
                '$output/$name',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            frames.add({'file': name, 'durationMs': hold});
          }

          await record('collapsed', hold: 500);
          final controller = scroll(tester);
          final extent = controller.offset;
          // Sample exact scroll offsets before a ballistic tick, including the
          // same intermediate layout used while the pointer is dragging.
          for (var i = 1; i <= 10; i++) {
            controller.jumpTo(extent * (1 - i / 10));
            await tester.pump();
            await record('reveal');
          }
          await tester.pumpAndSettle();
          await record('expanded', hold: 450);
          final origin = tester.getRect(
            surface(find.byType(SettingsSearchEntry)),
          );
          final sample = Offset(origin.right - 24, origin.center.dy);
          final restingPixel = await pixelAt(sample);
          final settingsBounds = tester.getRect(find.byType(SettingsPage));
          await tester.tap(find.byType(SettingsSearchEntry));
          await tester.pump();
          final view = find.byType(SettingsSearchView);
          final editable = find.descendant(
            of: view,
            matching: find.byType(EditableText),
          );
          final inputState = tester.state(editable);
          final first = tester.getRect(surface(view));
          expect(first.top, closeTo(origin.top, 0.1));
          expect(first.width, closeTo(origin.width, 0.1));
          await record('open-start');
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 30));
            final rect = tester.getRect(surface(view));
            expect(tester.state(editable), same(inputState));
            expect(rect.height, closeTo(40, 0.1));
            expect(
              find.descendant(of: view, matching: find.byType(TextField)),
              findsOneWidget,
            );
            if (i == 2) {
              expect(rect.top, lessThan(origin.top));
              expect(rect.top, greaterThan(55));
              expect(rect.width, lessThan(origin.width));
            }
            expect(tester.getRect(find.byType(SettingsPage)), settingsBounds);
            await record('opening');
          }
          await tester.pumpAndSettle();
          final top = tester.getRect(surface(view));
          expect(top.top, closeTo(55, 0.1));
          await tester.enterText(
            find.descendant(of: view, matching: find.byType(TextField)),
            '字体',
          );
          await tester.pumpAndSettle();
          await record('results', hold: 900);
          await tester.tap(find.text('取消'));
          await tester.pump();
          for (var i = 0; i < 9; i++) {
            await tester.pump(const Duration(milliseconds: 30));
            final rect = tester.getRect(surface(view));
            if (i == 3) {
              expect(rect.top, greaterThan(top.top));
              expect(rect.top, lessThan(origin.top));
            }
            await record('closing');
          }
          await tester.pump(const Duration(milliseconds: 30));
          await record('close-last-frame');
          expect(
            await pixelAt(sample),
            restingPixel,
            reason: 'No blank field on the last dismissal frame',
          );
          await tester.pumpAndSettle();
          expect(find.byType(SettingsSearchView), findsNothing);
          expect(
            tester.getRect(surface(find.byType(SettingsSearchEntry))),
            origin,
          );
          expect(
            find.byType(SettingsSearchEntry).hitTestable(),
            findsOneWidget,
          );
          await record('restored', hold: 650);
          for (var i = 1; i <= 10; i++) {
            controller.jumpTo(extent * i / 10);
            await tester.pump();
            await record('collapse');
          }
          await tester.pumpAndSettle();
          await record('collapsed-again', hold: 500);
          expect(tester.takeException(), isNull);
          if (output != null) {
            await tester.runAsync(
              () => File(
                '$output/${brightness.name}-frames.json',
              ).writeAsString(jsonEncode(frames)),
            );
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets(
    'back during opening reverses cleanly and the entry can open again',
    (tester) async {
      try {
        await pumpSettings(tester);
        scroll(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SettingsSearchEntry));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSearchView), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byType(SettingsSearchEntry).hitTestable(), findsOneWidget);
        await tester.tap(find.byType(SettingsSearchEntry));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSearchView), findsOneWidget);
        final cancelPosition = tester.getCenter(find.text('取消'));
        await tester.tapAt(cancelPosition);
        await tester.tapAt(cancelPosition);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('reduce motion opens and closes without an intermediate flight', (
    tester,
  ) async {
    try {
      await pumpSettings(tester, reduceMotion: true);
      scroll(tester).jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SettingsSearchEntry));
      await tester.pumpAndSettle();
      final view = find.byType(SettingsSearchView);
      expect(tester.widget<SettingsSearchView>(view).transition.value, 1);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSearchView), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets(
    'dismissal uses the resized origin rather than the old rectangle',
    (tester) async {
      try {
        await pumpSettings(tester);
        scroll(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SettingsSearchEntry));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(600, 700);
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSearchView), findsNothing);
        expect(
          tester.getRect(surface(find.byType(SettingsSearchEntry))).width,
          568,
        );
        expect(find.byType(SettingsSearchEntry).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
