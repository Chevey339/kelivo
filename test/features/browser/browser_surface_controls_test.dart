import 'dart:ui' show ImageByteFormat, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/pages/browser_bookmark_editor.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_library.dart';
import 'package:Kelivo/features/browser/widgets/browser_favicon.dart';
import 'package:Kelivo/features/browser/widgets/browser_settings.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_switch_lens.dart';
import 'package:Kelivo/features/browser/widgets/browser_progressive_edge.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassAccessibilityScope;
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/browser/widgets/browser_text_field.dart';

void main() {
  late BrowserService service;
  late _MemoryStore store;

  setUp(() async {
    store = _MemoryStore();
    service = BrowserService(store: store);
    await service.initialize();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  void browserTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    });
  }

  browserTest('enabled browser switch uses the application accent', (
    tester,
  ) async {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xff98532b));
    await mount(
      tester,
      Theme(
        data: ThemeData(colorScheme: colors),
        child: Center(child: BrowserSwitch(value: true, onChanged: (_) {})),
      ),
    );
    final track = tester.widget<Container>(
      find.byKey(const ValueKey('browserSwitchTrack')),
    );
    expect((track.decoration as BoxDecoration).color, colors.primary);
  });

  browserTest('UA editor saves custom text and restores both presets', (
    tester,
  ) async {
    final errors = <Object>[];
    await mount(
      tester,
      BrowserSettingsPanel(
        service: service,
        onError: errors.add,
        onDataCleared: () {},
      ),
    );
    await tester.tap(find.text('User agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('up to 2048'), findsOneWidget);
    await tester.enterText(
      find.byType(BrowserTextField),
      'ExampleBrowser/12 Mobile',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.settings.customUserAgent, 'ExampleBrowser/12 Mobile');
    for (final (label, desktop) in [('Desktop', true), ('Mobile', false)]) {
      await tester.tap(find.text('User agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.settings.customUserAgent, isEmpty);
      expect(service.settings.desktopMode, desktop);
    }
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  browserTest(
    'UA and search-engine selections share trailing values at large text sizes',
    (tester) async {
      await service.updateSettings(
        service.settings.copyWith(desktopMode: false),
      );
      for (final scale in [1.0, 2.0]) {
        await mount(
          tester,
          BrowserSettingsPanel(
            service: service,
            onError: (error) => fail('$error'),
            onDataCleared: () {},
          ),
          size: const Size(320, 844),
          scale: scale,
        );
        for (final (label, value) in [
          ('Search engine', 'Bing'),
          ('User agent', 'Mobile'),
        ]) {
          final row = find.byWidgetPredicate(
            (widget) => widget is BrowserSurfaceRow && widget.label == label,
          );
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          expect(tester.widget<BrowserSurfaceRow>(row).subtitle, isNull);
          final text = find.descendant(of: row, matching: find.text(value));
          expect(text, findsOneWidget);
          expect(
            tester.getCenter(text).dx,
            greaterThan(tester.getCenter(find.text(label)).dx),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  browserTest('surface choices persist and update the open panel material', (
    tester,
  ) async {
    final errors = <Object>[];
    await mount(
      tester,
      ListenableBuilder(
        listenable: service,
        builder: (context, _) => BrowserGlassScope(
          style: service.settings.surfaceStyle,
          child: Column(
            children: [
              Builder(
                builder: (context) =>
                    Text('material:${BrowserGlassScope.of(context).name}'),
              ),
              Expanded(
                child: BrowserSettingsPanel(
                  service: service,
                  onError: errors.add,
                  onDataCleared: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (final (label, style) in [
      ('Frosted', BrowserSurfaceStyle.frosted),
      ('Solid', BrowserSurfaceStyle.solid),
      ('Liquid glass', BrowserSurfaceStyle.liquid),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(service.settings.surfaceStyle, style);
      expect((store.state['settings'] as Map)['surfaceStyle'], style.name);
      expect(find.text('material:${style.name}'), findsOneWidget);
    }
    expect(errors, isEmpty);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
    expect(tester.takeException(), isNull);
  });

  browserTest(
    'settings content ignores page notifications and reacts to settings values',
    (tester) async {
      service.dispose();
      final settingsService = _SettingsService(store: store);
      service = settingsService;
      await service.initialize();
      await mount(
        tester,
        BrowserSettingsPanel(
          service: service,
          onError: (_) {},
          onDataCleared: () {},
        ),
      );
      ListView content() => tester.widget<ListView>(find.byType(ListView));
      final before = content();
      for (var index = 0; index < 20; index++) {
        settingsService.backgroundPageChanged();
        await tester.pump();
      }
      await service.createTab(url: 'https://example.com');
      await service.addBookmark(url: 'https://example.com', title: 'Example');
      await tester.pumpAndSettle();
      expect(identical(content(), before), isTrue);
      // A different settings instance with equal values is still the same UI.
      await service.updateSettings(service.settings.copyWith());
      await tester.pumpAndSettle();
      expect(identical(content(), before), isTrue);
      await service.updateSettings(
        service.settings.copyWith(searchEngine: BrowserSearchEngine.google),
      );
      await tester.pumpAndSettle();
      expect(identical(content(), before), isFalse);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Bing'), findsNothing);
      final updated = content();
      settingsService.setClearSupported(false);
      await tester.pumpAndSettle();
      expect(identical(content(), updated), isFalse);
      final clearRow = find.widgetWithText(
        BrowserSurfaceRow,
        'Clear website data',
      );
      await tester.scrollUntilVisible(
        clearRow,
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(tester.widget<BrowserSurfaceRow>(clearRow).onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest('settings content starts below the header and scrolls under it', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
    addTearDown(tester.view.resetPadding);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await mount(
      tester,
      BrowserManagementPage(
        title: 'Browser settings',
        child: BrowserSettingsPanel(
          service: service,
          scrollController: controller,
          onError: (_) {},
          onDataCleared: () {},
        ),
      ),
    );
    final list = find.byType(ListView);
    expect(tester.getRect(list), const Rect.fromLTWH(0, 0, 390, 844));
    final back = tester.getRect(
      find.byKey(const ValueKey('browserManagementBack')),
    );
    final surfaceLabel = find.text('Surface style');
    expect(tester.getRect(surfaceLabel).top, greaterThan(back.bottom));
    controller.jumpTo(80);
    await tester.pump();
    expect(tester.getRect(surfaceLabel).top, lessThan(back.top));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final last = find.widgetWithText(BrowserSurfaceRow, 'Clear website data');
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(844 - 34));
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.5, 3.0]) {
    browserTest('search engine row fits 320 pixels at $scale text scale', (
      tester,
    ) async {
      await service.updateSettings(
        service.settings.copyWith(searchEngine: BrowserSearchEngine.duckDuckGo),
      );
      final errors = <Object>[];
      await mount(
        tester,
        BrowserSettingsPanel(
          service: service,
          onError: errors.add,
          onDataCleared: () {},
        ),
        size: const Size(320, 844),
        scale: scale,
      );
      await tester.ensureVisible(find.text('DuckDuckGo'));
      await tester.pumpAndSettle();
      final valueBounds = tester.getRect(find.text('DuckDuckGo'));
      expect(valueBounds.left, greaterThanOrEqualTo(0));
      expect(valueBounds.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('DuckDuckGo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Google'));
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(service.settings.searchEngine, BrowserSearchEngine.google);
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  browserTest('switch supports pointer and keyboard without an ink overlay', (
    tester,
  ) async {
    var value = false;
    await mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Center(
          child: BrowserSwitch(
            value: value,
            semanticLabel: 'Remember tabs',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(BrowserSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(find.byType(InkResponse), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  browserTest(
    'mobile bookmark editor is a full page with a grouped form and top save action',
    (tester) async {
      await service.addBookmark(url: 'https://example.com', title: 'Original');
      final errors = <Object>[];
      await mount(
        tester,
        BrowserLibrary(
          service: service,
          section: BrowserLibrarySection.bookmarks,
          onOpen: (_) {},
          onError: errors.add,
        ),
      );
      await tester.tap(find.byTooltip('Edit bookmark'));
      await tester.pumpAndSettle();
      final editor = find.byType(BrowserBookmarkEditor);
      final favicon = tester.widget<BrowserFavicon>(
        find.byType(BrowserFavicon),
      );
      expect(identical(favicon.service, service), isTrue);
      expect(favicon.url, 'https://example.com');
      expect(
        ModalRoute.of(tester.element(editor)),
        isA<MaterialPageRoute<BrowserBookmarkEdit>>(),
      );
      expect(
        tester.getSize(find.byType(BrowserManagementPage)),
        const Size(390, 844),
      );
      expect(find.byType(BrowserDialogHeader), findsNothing);
      expect(
        find.descendant(of: editor, matching: find.byType(BrowserSurfaceGroup)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('browserBookmarkFavicon')),
        findsOneWidget,
      );
      expect(tester.getRect(find.text('Save')).top, lessThan(100));
      expect(find.text('Cancel'), findsNothing);
      final title = find.byKey(const ValueKey('browserBookmarkTitleField'));
      final url = find.byKey(const ValueKey('browserBookmarkUrlField'));
      await tester.enterText(title, 'Updated bookmark');
      await tester.enterText(url, 'javascript:alert(1)');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.bookmarks.single.title, 'Original');
      expect(editor, findsOneWidget);
      expect(
        find.text('Enter a valid HTTP or HTTPS website address.'),
        findsOneWidget,
      );
      await tester.enterText(url, 'https://example.org/docs');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.bookmarks.single.title, 'Updated bookmark');
      expect(service.bookmarks.single.url, 'https://example.org/docs');
      expect(editor, findsNothing);
      expect(errors, isEmpty);
      expect(find.byType(InkResponse), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'child switch and glass button own feedback while their row remains tappable',
    (tester) async {
      var value = false;
      var enabled = true;
      var rowTaps = 0;
      var buttonTaps = 0;
      late StateSetter rebuild;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Center(
              child: BrowserSurfaceGroup(
                children: [
                  BrowserSurfaceRow(
                    label: 'Whole row',
                    onTap: () => rowTaps++,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrowserSwitch(
                          value: value,
                          onChanged: enabled
                              ? (next) => setState(() => value = next)
                              : null,
                        ),
                        BrowserSurfaceIconButton(
                          label: 'Child action',
                          icon: LucideIcons.check,
                          surface: true,
                          onPressed: () => buttonTaps++,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is BrowserSurfaceButton &&
            widget.semanticLabel == 'Whole row',
      );
      double tint() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: row,
                              matching: find.byWidgetPredicate(
                                (widget) =>
                                    widget is DecoratedBox &&
                                    widget.position ==
                                        DecorationPosition.foreground,
                              ),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!
              .a;
      expect(tint(), 0);
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(BrowserSwitch)),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(tint(), 0); // Parent TapDown's deadline has elapsed.
      await finger.moveBy(const Offset(22, 0));
      await tester.pump();
      expect(tint(), 0);
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(rowTaps, 0);
      expect(value, isFalse);
      final child = find.byTooltip('Child action');
      final held = await tester.startGesture(tester.getCenter(child));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(tint(), 0);
      expect(
        find.descendant(
          of: child,
          matching: find.byKey(const ValueKey('browserGlassTouchLight')),
        ),
        findsOneWidget,
      );
      await held.up();
      await tester.pumpAndSettle();
      expect(buttonTaps, 1);
      expect(rowTaps, 0);
      rebuild(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BrowserSwitch));
      await tester.pumpAndSettle();
      expect(rowTaps, 0); // A disabled child also shields the row action.
      final rowFinger = await tester.startGesture(
        tester.getCenter(find.text('Whole row')),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(tint(), closeTo(.09, .001));
      await rowFinger.up();
      await tester.pumpAndSettle();
      expect(rowTaps, 1);
      expect(tint(), 0);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'search-engine picker uses the complete grouped outline for press feedback',
    (tester) async {
      await mount(
        tester,
        BrowserSettingsPanel(
          service: service,
          onError: (_) {},
          onDataCleared: () {},
        ),
      );
      await tester.tap(find.text('Search engine'));
      await tester.pumpAndSettle();
      final options = find.byKey(const ValueKey('browserSearchEngineOptions'));
      expect(tester.widget<BrowserSurfaceGroup>(options).filled, isFalse);
      // There is one dialog material; the grouped options don't paint a second
      // opaque card above it, including on the solid/high-contrast paths.
      expect(
        find.ancestor(of: options, matching: find.byType(BrowserGlass)),
        findsOneWidget,
      );
      final optionBackground = find
          .descendant(of: options, matching: find.byType(DecoratedBox))
          .first;
      expect(
        (tester.widget<DecoratedBox>(optionBackground).decoration
                as BoxDecoration)
            .color,
        Colors.transparent,
      );
      for (final (label, corners) in [
        ('Bing', const BorderRadius.vertical(top: Radius.circular(26))),
        ('Google', BorderRadius.zero),
        ('Baidu', const BorderRadius.vertical(bottom: Radius.circular(26))),
      ]) {
        final pickerRow = find.widgetWithText(BrowserSurfaceRow, label).last;
        final button = find.descendant(
          of: pickerRow,
          matching: find.byType(BrowserSurfaceButton),
        );
        expect(
          tester.widget<BrowserSurfaceButton>(button).borderRadius,
          corners,
        );
        expect(
          find.ancestor(
            of: pickerRow,
            matching: find.byType(BrowserSurfaceGroup),
          ),
          findsOneWidget,
        );
      }
      final google = find.widgetWithText(BrowserSurfaceRow, 'Google');
      final finger = await tester.startGesture(tester.getCenter(google));
      await tester.pump(const Duration(milliseconds: 220));
      final paint = find.descendant(
        of: google,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.foreground,
        ),
      );
      expect(
        (tester.widget<DecoratedBox>(paint).decoration as BoxDecoration)
            .borderRadius,
        BorderRadius.zero,
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(service.settings.searchEngine, BrowserSearchEngine.google);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'mobile switch follows dragging and cancels without changing its value',
    (tester) async {
      var value = false;
      var changes = 0;
      var rowTaps = 0;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: BrowserSurfaceRow(
              label: 'Remember tabs',
              onTap: () => rowTaps++,
              trailing: BrowserSwitch(
                value: value,
                semanticLabel: 'Remember tabs',
                onChanged: (next) => setState(() {
                  value = next;
                  changes++;
                }),
              ),
            ),
          ),
        ),
      );
      final thumb = find.byKey(const ValueKey('browserSwitchThumb'));
      final start = tester.getRect(thumb);
      final track = tester.getRect(
        find.byKey(const ValueKey('browserSwitchTrack')),
      );
      expect(track.width / track.height, greaterThan(2));
      expect(track.size, const Size(54, 24));
      expect(start.size, const Size(32, 20));
      expect(start.width, greaterThan(start.height));
      final drag = await tester.startGesture(start.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getSize(thumb).width, greaterThan(start.width));
      expect(tester.getSize(thumb), const Size(50, 31));
      expect(
        tester
            .widget<BrowserSwitchLens>(find.byType(BrowserSwitchLens))
            .progress,
        1,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('browserSwitchTrack'))),
        track,
      );
      await drag.moveBy(const Offset(22, 0));
      await tester.pump();
      expect(tester.getCenter(thumb).dx, greaterThan(start.center.dx));
      expect(value, isFalse);
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(thumb), start);
      expect(changes, 0);
      expect(rowTaps, 0);
      await tester.drag(find.byType(BrowserSwitch), const Offset(42, 0));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 1);
      expect(rowTaps, 0);
      expect(tester.getCenter(thumb).dx, greaterThan(start.center.dx));
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'mobile switch respects right-to-left dragging and disabled input',
    (tester) async {
      var value = false;
      var enabled = true;
      late StateSetter rebuild;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: BrowserSwitch(
                  value: value,
                  onChanged: enabled
                      ? (next) => setState(() => value = next)
                      : null,
                ),
              ),
            );
          },
        ),
      );
      await tester.drag(find.byType(BrowserSwitch), const Offset(-42, 0));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      rebuild(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BrowserSwitch));
      await tester.drag(find.byType(BrowserSwitch), const Offset(42, 0));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest('desktop settings rows stay stationary with a basic cursor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      var selected = 0;
      await mount(
        tester,
        Center(
          child: SizedBox(
            width: 340,
            child: BrowserSurfaceRow(
              label: 'Search engine',
              onTap: () => selected++,
            ),
          ),
        ),
      );
      final row = find.byType(BrowserSurfaceRow);
      final bounds = tester.getRect(row);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(bounds.center);
      await tester.pump();
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic,
      );
      await mouse.down(bounds.center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(row), bounds);
      expect(find.byType(BrowserPress), findsNothing);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(selected, 1);
      await mouse.removePointer();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  browserTest(
    'mobile management Back moves and lights its entire glass surface',
    (tester) async {
      var completed = 0;
      var selected = 0;
      await mount(
        tester,
        BrowserManagementPage(
          title: 'Downloads',
          onDone: () => completed++,
          child: BrowserSurfaceRow(
            label: 'Saved download',
            onTap: () => selected++,
          ),
        ),
      );
      final done = find.byTooltip('Back');
      final press = find.descendant(
        of: done,
        matching: find.byType(BrowserPress),
      );
      final glass = find.descendant(
        of: done,
        matching: find.byType(BrowserGlass),
      );
      expect(press, findsOneWidget);
      expect(
        find.ancestor(of: glass, matching: find.byType(BrowserPress)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: done, matching: find.byType(BrowserSurfaceButton)),
        findsNothing,
      );
      final initial = tester.getRect(glass);
      final finger = await tester.startGesture(initial.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getRect(glass).width, greaterThan(initial.width));
      expect(
        find.descendant(
          of: glass,
          matching: find.byKey(const ValueKey('browserGlassTouchLight')),
        ),
        findsOneWidget,
      );
      await finger.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(glass).center.dx, greaterThan(initial.center.dx));
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(glass).width, closeTo(initial.width, .1));
      expect(completed, 0);
      final row = find.byType(BrowserSurfaceRow);
      expect(
        find.descendant(of: row, matching: find.byType(BrowserPress)),
        findsNothing,
      );
      final rowBounds = tester.getRect(row);
      final rowFinger = await tester.startGesture(rowBounds.center);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getRect(row), rowBounds);
      await rowFinger.up();
      await tester.pumpAndSettle();
      expect(selected, 1);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'mobile text buttons have one press owner and desktop buttons stay stationary',
    (tester) async {
      var selected = 0;
      for (final filled in [false, true]) {
        await mount(
          tester,
          Center(
            child: BrowserTextButton(
              filled: filled,
              onPressed: () => selected++,
              child: const Text('Continue'),
            ),
          ),
        );
        final button = find.byType(BrowserTextButton);
        expect(
          find.descendant(of: button, matching: find.byType(BrowserPress)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: button,
            matching: find.byType(BrowserSurfaceButton),
          ),
          findsNothing,
        );
        final finger = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          find.byKey(
            ValueKey(
              filled ? 'browserGlassTouchLight' : 'browserControlFeedbackPaint',
            ),
          ),
          findsOneWidget,
        );
        await finger.up();
        await tester.pumpAndSettle();
      }
      expect(selected, 2);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await mount(
          tester,
          BrowserManagementPage(
            title: 'History',
            onDone: () => selected++,
            child: const SizedBox.expand(),
          ),
        );
        final done = find.byTooltip('Back');
        final glass = find.descendant(
          of: done,
          matching: find.byType(BrowserGlass),
        );
        expect(find.byType(BrowserPress), findsNothing);
        final bounds = tester.getRect(glass);
        final finger = await tester.startGesture(tester.getCenter(done));
        await tester.pump(const Duration(milliseconds: 200));
        await finger.moveBy(const Offset(12, 0));
        await tester.pump();
        expect(tester.getRect(glass), bounds);
        await finger.cancel();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final (colored, icon) in [(false, false), (true, false), (true, true)]) {
    browserTest(
      'mobile filled control follows drag without activating (colored: $colored, icon: $icon)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          var taps = 0;
          await mount(
            tester,
            Center(
              child: icon
                  ? BrowserSurfaceIconButton(
                      label: 'Done',
                      icon: LucideIcons.check,
                      size: 48,
                      backgroundColor: const Color(0xff007aff),
                      foregroundColor: Colors.white,
                      onPressed: () => taps++,
                    )
                  : BrowserTextButton(
                      filled: !colored,
                      backgroundColor: colored ? const Color(0xff007aff) : null,
                      foregroundColor: colored ? Colors.white : null,
                      onPressed: () => taps++,
                      child: const Text('Save'),
                    ),
            ),
          );
          final button = icon
              ? find.byType(BrowserSurfaceIconButton)
              : find.byType(BrowserTextButton);
          final label = icon
              ? find.byIcon(LucideIcons.check)
              : find.text('Save');
          final start = tester.getCenter(label);
          final finger = await tester.startGesture(tester.getCenter(button));
          await tester.pump(const Duration(milliseconds: 120));
          await finger.moveBy(const Offset(28, 0));
          await tester.pump();
          expect(tester.getCenter(label).dx, greaterThan(start.dx));
          await finger.up();
          await tester.pumpAndSettle();
          expect(
            tester.getCenter(label),
            offsetMoreOrLessEquals(start, epsilon: .1),
          );
          expect(taps, 0);
          final cancelled = await tester.startGesture(tester.getCenter(button));
          await tester.pump(const Duration(milliseconds: 120));
          await cancelled.moveBy(const Offset(-24, 0));
          await tester.pump();
          await cancelled.cancel();
          await tester.pumpAndSettle();
          expect(taps, 0);
          expect(
            tester.getCenter(label),
            offsetMoreOrLessEquals(start, epsilon: .1),
          );
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(taps, 1);
          final actionContext = tester.element(
            find
                .descendant(of: button, matching: find.byType(GestureDetector))
                .first,
          );
          Focus.of(actionContext).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(taps, 2);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  browserTest(
    'group feedback follows only exterior 26 point corners and bookmark row shares its clip',
    (tester) async {
      await mount(
        tester,
        Center(
          child: SizedBox(
            width: 320,
            child: BrowserSurfaceGroup(
              children: [
                for (final label in ['First', 'Middle', 'Last'])
                  BrowserSurfaceRow(label: label, onTap: () {}),
              ],
            ),
          ),
        ),
      );
      final group = find.byType(BrowserSurfaceGroup);
      final clip = find
          .descendant(of: group, matching: find.byType(ClipRRect))
          .first;
      expect(
        tester.widget<ClipRRect>(clip).borderRadius,
        BorderRadius.circular(26),
      );
      for (final (label, expected) in [
        ('First', const BorderRadius.vertical(top: Radius.circular(26))),
        ('Middle', BorderRadius.zero),
        ('Last', const BorderRadius.vertical(bottom: Radius.circular(26))),
      ]) {
        final row = find.widgetWithText(BrowserSurfaceRow, label);
        final bounds = tester.getRect(row);
        final button = find.descendant(
          of: row,
          matching: find.byType(BrowserSurfaceButton),
        );
        expect(
          tester.widget<BrowserSurfaceButton>(button).borderRadius,
          expected,
        );
        final finger = await tester.startGesture(tester.getCenter(row));
        await tester.pump(const Duration(milliseconds: 120));
        final paint = find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground,
          ),
        );
        expect(
          (tester.widget<DecoratedBox>(paint).decoration as BoxDecoration)
              .borderRadius,
          expected,
        );
        expect(tester.getRect(row), bounds);
        expect(
          find.descendant(of: row, matching: find.byType(BrowserPress)),
          findsNothing,
        );
        await finger.cancel();
        await tester.pumpAndSettle();
      }
      await service.addBookmark(url: 'https://example.com', title: 'Example');
      await mount(
        tester,
        BrowserLibrary(
          service: service,
          section: BrowserLibrarySection.bookmarks,
          onOpen: (_) {},
          onError: (_) {},
        ),
      );
      final saved = find.byWidgetPredicate(
        (widget) =>
            widget is BrowserSurfaceButton && widget.semanticLabel == 'Example',
      );
      expect(tester.widget<BrowserSurfaceButton>(saved).radius, 20);
      final savedClip = find
          .ancestor(of: saved, matching: find.byType(ClipRRect))
          .first;
      expect(
        tester.widget<ClipRRect>(savedClip).borderRadius,
        BorderRadius.circular(20),
      );
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'reduced transparency removes optical passes from switch and edge',
    (tester) async {
      await mount(
        tester,
        GlassAccessibilityScope(
          reduceTransparency: true,
          child: Column(
            children: [
              const SizedBox(
                height: 100,
                child: BrowserProgressiveEdge(top: true),
              ),
              BrowserSwitch(value: true, onChanged: (_) {}),
            ],
          ),
        ),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(BrowserSwitch)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester.widget<BrowserSwitchLens>(find.byType(BrowserSwitchLens)).opaque,
        isTrue,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'pressed switch interior samples its track instead of an opaque gradient',
    (tester) async {
      Future<(int, int, int)> sample({
        required bool value,
        required bool pressed,
      }) async {
        const boundaryKey = ValueKey('switchPixels');
        await mount(
          tester,
          Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 90,
                  height: 60,
                  child: Center(
                    child: BrowserGlassScope(
                      style: BrowserSurfaceStyle.liquid,
                      child: Theme(
                        data: ThemeData(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xff34c759),
                          ),
                        ),
                        child: BrowserSwitch(
                          key: ValueKey(value),
                          value: value,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final finger = pressed
            ? await tester.startGesture(
                tester.getCenter(find.byType(BrowserSwitch)),
              )
            : null;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final center = boundary.globalToLocal(
          tester.getCenter(find.byKey(const ValueKey('browserSwitchThumb'))),
        );
        final result = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ImageByteFormat.rawRgba,
            ))!;
            final index =
                (center.dy.floor() * image.width + center.dx.floor()) * 4;
            return (
              bytes.getUint8(index),
              bytes.getUint8(index + 1),
              bytes.getUint8(index + 2),
            );
          } finally {
            image.dispose();
          }
        });
        await finger?.cancel();
        await tester.pumpAndSettle();
        return result!;
      }

      final idleOff = await sample(value: false, pressed: false);
      final idleOn = await sample(value: true, pressed: false);
      expect(idleOff, idleOn); // Idle keeps the existing opaque white thumb.
      final pressedOff = await sample(value: false, pressed: true);
      final pressedOn = await sample(value: true, pressed: true);
      // The same point inside the same rim must reveal the green track only
      // when enabled. A filled opaque gradient produces identical interiors.
      final offGreenBias = pressedOff.$2 - pressedOff.$1;
      final onGreenBias = pressedOn.$2 - pressedOn.$1;
      expect(onGreenBias - offGreenBias, greaterThan(30));
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'removing a switch during a drag cancels without using a dead context',
    (tester) async {
      await mount(
        tester,
        Center(child: BrowserSwitch(value: false, onChanged: (_) {})),
      );
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(BrowserSwitch)),
      );
      await drag.moveBy(const Offset(24, 0));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'bookmark confirmation remains usable with large text on a narrow screen',
    (tester) async {
      var confirmed = false;
      await mount(
        tester,
        Builder(
          builder: (context) => Center(
            child: BrowserTextButton(
              onPressed: () async {
                confirmed = await confirmBrowserAction(
                  context,
                  'Clear your browsing history?',
                  'Clear history',
                );
              },
              child: const Text('Open confirmation'),
            ),
          ),
        ),
        size: const Size(320, 640),
        scale: 1.8,
      );
      await tester.tap(find.text('Open confirmation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryStore extends BrowserStore {
  Map<String, dynamic> state = {};

  @override
  Future<Map<String, dynamic>> read() async => state;

  @override
  Future<void> write(Map<String, Object?> value) async {
    state = Map<String, dynamic>.from(value);
  }
}

class _SettingsService extends BrowserService {
  _SettingsService({super.store});
  bool _clearSupported = true;
  @override
  bool get supportsWebsiteDataClear => _clearSupported;
  void backgroundPageChanged() => notifyListeners();
  void setClearSupported(bool value) {
    _clearSupported = value;
    notifyListeners();
  }
}
