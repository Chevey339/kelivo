import 'package:Kelivo/core/providers/settings_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/desktop/setting/world_book_pane.dart';
import 'package:Kelivo/features/world_book/pages/world_book_page.dart';
import 'package:Kelivo/features/world_book/widgets/world_book_entry_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harnesses = Expando<BusinessTestHarness>();
  final screenshotDir = Platform.environment['KELIVO_WORLD_BOOK_SCREENSHOTS'];
  setUpAll(() async {
    if (screenshotDir == null) return;
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    final bytes = await font.readAsBytes();
    await (FontLoader(
      'WorldBookPreview',
    )..addFont(Future.value(bytes.buffer.asByteData()))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  Future<WorldBookProvider> mount(
    WidgetTester tester, {
    required bool desktop,
    Brightness brightness = Brightness.light,
    Size? size,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    final harness = await tester.runAsync(() => createBusinessTestHarness());
    final provider = WorldBookProvider(preferences: harness!.preferences);
    harnesses[provider] = harness;
    late SettingsProvider settings;
    await tester.runAsync(() async {
      settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await provider.initialize();
      await provider.addBook(
        const WorldBook(
          id: 'book',
          name: 'Story world',
          description: 'Characters and setting',
          entries: [
            WorldBookEntry(
              id: 'alpha',
              name: 'Alpha',
              content: 'A',
              keywords: ['dragon'],
              sticky: 3,
              cooldown: 2,
              position: WorldBookInjectionPosition.beforeSystemPrompt,
            ),
            WorldBookEntry(
              id: 'beta',
              name: 'Beta',
              content: 'B',
              constantActive: true,
              position: WorldBookInjectionPosition.atDepth,
            ),
            WorldBookEntry(
              id: 'gamma',
              name: 'Gamma',
              content: 'C',
              enabled: false,
              constantActive: true,
              position: WorldBookInjectionPosition.bottomOfChat,
            ),
          ],
        ),
      );
    });
    tester.view.physicalSize =
        size ?? (desktop ? const Size(1100, 850) : const Size(393, 852));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme =
        (brightness == Brightness.light
                ? buildLightTheme(null)
                : buildDarkTheme(null))
            .copyWith(
              platform: desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
            );
    if (screenshotDir != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'WorldBookPreview'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'WorldBookPreview',
        ),
      );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: RepaintBoundary(
          key: const ValueKey('world-book-screenshot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: desktop
                ? const Scaffold(body: DesktopWorldBookPane())
                : const WorldBookPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (screenshotDir == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('world-book-screenshot')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(screenshotDir).create(recursive: true);
      await File(
        '$screenshotDir/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final desktop in [false, true]) {
    final platform = desktop ? 'desktop' : 'mobile';
    for (final locale in [const Locale('en'), const Locale('zh')]) {
      testWidgets(
        '$platform ${locale.languageCode} keeps labels and counts aligned at narrow widths',
        (tester) async {
          final provider = await mount(
            tester,
            desktop: desktop,
            locale: locale,
            size: Size(desktop ? 600 : 320, 850),
            textScale: 1.4,
          );
          await tester.runAsync(
            () => provider.updateBook(
              provider.books.single.copyWith(
                name: 'A world with a long name 很长的世界书名称',
                entries: [
                  provider.books.single.entries.first.copyWith(
                    name: 'A very long entry title 很长的条目名称',
                  ),
                  ...provider.books.single.entries.skip(1),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final title in find.byType(WorldBookEntryTitle).evaluate()) {
            final row = find.byWidget(title.widget);
            final label = find
                .descendant(of: row, matching: find.byType(Text))
                .first;
            final badge = find.descendant(
              of: row,
              matching: find.byType(WorldBookPositionBadge),
            );
            expect(
              tester.getCenter(label).dy,
              closeTo(tester.getCenter(badge).dy, 1),
            );
            expect(
              tester.getRect(label).right,
              lessThan(tester.getRect(badge).left),
            );
          }
          final l10n = AppLocalizations.of(tester.element(find.text('2/3')))!;
          expect(
            tester.getCenter(find.text('2/3')).dy,
            closeTo(
              tester.getCenter(find.byTooltip(l10n.worldBookAddEntry)).dy,
              1,
            ),
          );
          expect(tester.takeException(), isNull);
          await screenshot(tester, '$platform-${locale.languageCode}-narrow');
        },
      );
    }
    testWidgets(
      '$platform moves entries down exactly one place and persists enabled state',
      (tester) async {
        final provider = await mount(tester, desktop: desktop);
        expect(find.text('2/3'), findsOneWidget);
        expect(find.byType(WorldBookPositionBadge), findsNWidgets(3));
        final positions = tester
            .widgetList<WorldBookPositionBadge>(
              find.byType(WorldBookPositionBadge),
            )
            .map((w) => w.position)
            .toSet();
        expect(positions, hasLength(3));
        final handles = find.byType(ReorderableDragStartListener);
        final first = tester.getCenter(handles.at(0));
        final second = tester.getCenter(handles.at(1));
        final gesture = await tester.startGesture(first);
        await tester.pump();
        final distance = second.dy - first.dy + 20;
        for (double dy = 8; dy <= distance; dy += 8) {
          await gesture.moveTo(first + Offset(0, dy));
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(provider.books.single.entries.map((e) => e.id), [
          'beta',
          'alpha',
          'gamma',
        ]);
        await tester.tap(find.byType(IosSwitch).first);
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.runAsync(() => provider.loadAll());
        await tester.pumpAndSettle();
        expect(find.text('1/3'), findsOneWidget);
        expect(provider.books.single.entries.first.enabled, isFalse);
        expect(provider.books.single.entries.map((e) => e.id), [
          'beta',
          'alpha',
          'gamma',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    for (final brightness in Brightness.values) {
      testWidgets(
        '$platform ${brightness.name} editor saves timing values without layout errors',
        (tester) async {
          final provider = await mount(
            tester,
            desktop: desktop,
            brightness: brightness,
          );
          await screenshot(tester, '$platform-${brightness.name}-list');
          await tester.tap(find.text('Alpha'));
          await tester.pumpAndSettle();
          final timed = find.byType(WorldBookTimedEffectsFields);
          await tester.ensureVisible(timed);
          await tester.pumpAndSettle();
          for (final pair in [
            ('Sticky (messages)', '5'),
            ('Cooldown (messages)', '4'),
            ('Delay (messages)', '3'),
          ]) {
            final field = find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is IosFormTextField && w.label == pair.$1,
              ),
              matching: find.byType(TextField),
            );
            await tester.ensureVisible(field);
            await tester.enterText(field, pair.$2);
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await screenshot(tester, '$platform-${brightness.name}-editor');
          await tester.tap(find.text('Save').last);
          await tester.pumpAndSettle();
          await tester.runAsync(() => provider.loadAll());
          await tester.pumpAndSettle();
          final entry = provider.books.single.entries.first;
          expect((entry.sticky, entry.cooldown, entry.delay), (5, 4, 3));
          expect(entry.position, WorldBookInjectionPosition.beforeSystemPrompt);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'desktop supports repeated mouse drags after hovering the handle',
    (tester) async {
      final provider = await mount(tester, desktop: true);
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      for (var attempt = 0; attempt < 4; attempt++) {
        final handles = find.byType(ReorderableDragStartListener);
        final first = tester.getCenter(handles.at(0));
        final last = tester.getCenter(handles.at(2));
        await mouse.moveTo(first);
        await tester.pump(const Duration(seconds: 1));
        await mouse.down(first);
        for (var step = 1; step <= 25; step++) {
          await mouse.moveTo(
            Offset.lerp(first, last + const Offset(0, 20), step / 25)!,
          );
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(find.text('Drag to reorder'), findsNothing);
        if (attempt == 0) await screenshot(tester, 'desktop-drag');
        await mouse.up();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(provider.books.single.entries.map((e) => e.id), [
        'beta',
        'gamma',
        'alpha',
      ]);
      await mouse.removePointer();
      semantics.dispose();
    },
  );
  testWidgets(
    'desktop can start another drag before the previous drop settles',
    (tester) async {
      final provider = await mount(tester, desktop: true);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      for (var attempt = 0; attempt < 4; attempt++) {
        final handles = find.byType(ReorderableDragStartListener);
        final first = tester.getCenter(handles.first);
        final last = tester.getCenter(handles.last);
        await mouse.moveTo(first);
        await mouse.down(first);
        for (var step = 1; step <= 20; step++) {
          await mouse.moveTo(
            Offset.lerp(first, last + const Offset(0, 20), step / 20)!,
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await mouse.removePointer();
      await tester.pumpAndSettle();
      await tester.runAsync(() => provider.loadAll());
      expect(provider.books.single.entries.map((e) => e.id).toSet(), {
        'alpha',
        'beta',
        'gamma',
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop keeps multiple books stable when a drag is interrupted by a rebuild',
    (tester) async {
      final provider = await mount(tester, desktop: true);
      await tester.runAsync(
        () => provider.addBook(
          provider.books.single.copyWith(id: 'other', name: 'Other world'),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      final handle = find.descendant(
        of: find.byKey(const ValueKey('desktop-world-book-entry-book-gamma')),
        matching: find.byType(ReorderableDragStartListener),
      );
      final from = tester.getCenter(handle);
      await mouse.moveTo(from);
      await tester.pump(const Duration(seconds: 1));
      await mouse.down(from);
      await mouse.moveTo(from + const Offset(80, -100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => provider.setEntryEnabled('book', 'alpha', false),
      );
      await tester.pump();
      await tester.runAsync(() => provider.setBookCollapsed('book', true));
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.runAsync(() => provider.setBookCollapsed('book', false));
      await tester.pumpAndSettle();
      expect(provider.books.first.entries.map((e) => e.id).toSet(), {
        'alpha',
        'beta',
        'gamma',
      });
      expect(find.byType(WorldBookEntryTitle), findsNWidgets(6));
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      semantics.dispose();
    },
  );
  for (final collapsed in [false, true]) {
    testWidgets(
      'desktop drags whole books from the card header with collapsed=$collapsed',
      (tester) async {
        final provider = await mount(tester, desktop: true);
        await tester.runAsync(() async {
          await provider.addBook(
            provider.books.single.copyWith(id: 'other', name: 'Other world'),
          );
          await provider.setBookCollapsed('book', collapsed);
          await provider.setBookCollapsed('other', collapsed);
        });
        await tester.pumpAndSettle();
        final first = tester.getCenter(find.text('Story world'));
        final second = tester.getCenter(find.text('Other world'));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: first);
        await mouse.down(first);
        final distance = second.dy - first.dy + 25;
        for (double dy = 8; dy <= distance; dy += 8) {
          await mouse.moveTo(first + Offset(0, dy));
          await tester.pump(const Duration(milliseconds: 20));
        }
        await screenshot(tester, 'desktop-book-drag-$collapsed');
        await tester.runAsync(() async {
          await mouse.up();
          await tester.pumpAndSettle();
          await harnesses[provider]!.preferences.flushPendingWrites();
          await provider.loadAll();
        });
        await tester.pumpAndSettle();
        expect(provider.books.map((book) => book.id), ['other', 'book']);
        expect(provider.isBookCollapsed('book'), collapsed);
        expect(provider.getById('book')!.entries.map((entry) => entry.id), [
          'alpha',
          'beta',
          'gamma',
        ]);
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
      },
    );
  }

  testWidgets(
    'desktop entry drags and clicks do not reorder their containing books',
    (tester) async {
      final provider = await mount(tester, desktop: true);
      await tester.runAsync(
        () => provider.addBook(
          provider.books.single.copyWith(id: 'other', name: 'Other world'),
        ),
      );
      await tester.pumpAndSettle();
      Finder handle(String id) => find.descendant(
        of: find.byKey(ValueKey('desktop-world-book-entry-book-$id')),
        matching: find.byType(ReorderableDragStartListener),
      );
      final first = tester.getCenter(handle('alpha'));
      final second = tester.getCenter(handle('beta'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: first);
      await mouse.down(first);
      for (double dy = 8; dy <= second.dy - first.dy + 20; dy += 8) {
        await mouse.moveTo(first + Offset(0, dy));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.runAsync(() async {
        await mouse.up();
        await tester.pumpAndSettle();
        await harnesses[provider]!.preferences.flushPendingWrites();
        await provider.loadAll();
      });
      await tester.pumpAndSettle();
      expect(provider.books.map((book) => book.id), ['book', 'other']);
      expect(provider.books.first.entries.map((entry) => entry.id), [
        'beta',
        'alpha',
        'gamma',
      ]);
      expect(provider.books.last.entries.map((entry) => entry.id), [
        'alpha',
        'beta',
        'gamma',
      ]);
      final l10n = AppLocalizations.of(
        tester.element(find.text('Story world')),
      )!;
      await tester.tap(find.text('Beta').first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.worldBookEditEntry), findsOneWidget);
      expect(provider.books.map((book) => book.id), ['book', 'other']);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    },
  );
}
