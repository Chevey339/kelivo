import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_menu.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/core/services/haptics.dart';

const _items = [
  BrowserMenuEntry(
    value: 'new',
    icon: LucideIcons.plus,
    label: 'New tab',
    group: BrowserMenuGroup.navigation,
  ),
  BrowserMenuEntry(
    value: 'bookmark',
    icon: LucideIcons.bookmark,
    label: 'Add bookmark',
  ),
  BrowserMenuEntry(
    value: 'find',
    icon: LucideIcons.search,
    label: 'Find on page',
    secondary: true,
  ),
  BrowserMenuEntry(
    value: 'copy',
    icon: LucideIcons.link,
    label: 'Copy link',
    secondary: true,
  ),
  BrowserMenuEntry(
    value: 'external',
    icon: LucideIcons.externalLink,
    label: 'Open in default browser',
    secondary: true,
  ),
  BrowserMenuEntry(
    value: 'bookmarks',
    icon: LucideIcons.bookOpen,
    label: 'Bookmarks',
    group: BrowserMenuGroup.library,
    footer: true,
  ),
  BrowserMenuEntry(
    value: 'history',
    icon: LucideIcons.history,
    label: 'History',
    group: BrowserMenuGroup.library,
  ),
  BrowserMenuEntry(
    value: 'settings',
    icon: LucideIcons.settings2,
    label: 'Browser settings',
    group: BrowserMenuGroup.application,
    footer: true,
  ),
  BrowserMenuEntry(
    value: 'close',
    icon: LucideIcons.x,
    label: 'Close browser',
    group: BrowserMenuGroup.application,
  ),
];

void main() {
  late _MenuFixture fixture;
  final surface = find.byKey(const ValueKey('browserMenuSurface'));

  Future<void> primeReadyMotion(WidgetTester tester) async {
    for (var frame = 0; frame < 5 && fixture.transitionStarts == 0; frame++) {
      await tester.pump();
    }
    expect(fixture.transitionStarts, 1);
    // Readiness arrives outside build. Prime the first live animation frame
    // without advancing time so timed assertions start at the source geometry.
    await tester.pump();
  }

  Future<void> mount(
    WidgetTester tester, {
    required bool desktop,
    required Rect anchor,
    Size? size,
    double textScale = 1,
    bool settle = true,
    bool open = true,
    bool selectable = false,
    BrowserSurfaceStyle style = BrowserSurfaceStyle.liquid,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize =
        size ?? (desktop ? const Size(800, 600) : const Size(390, 844));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fixture = _MenuFixture(desktop: desktop, anchor: anchor);
    addTearDown(fixture.underlyingClicks.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: BrowserGlassScope(
            style: style,
            child: selectable
                ? Overlay(
                    initialEntries: [
                      OverlayEntry(
                        builder: (_) => SelectionArea(child: child!),
                      ),
                    ],
                  )
                : child!,
          ),
        ),
        home: fixture,
      ),
    );
    await tester.pumpAndSettle();
    if (!open) return;
    await tester.tap(find.byKey(const ValueKey('menuTrigger')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await primeReadyMotion(tester);
    }
  }

  for (final desktop in [false, true]) {
    testWidgets('menu and submenu inherit the app font on desktop=$desktop', (
      tester,
    ) async {
      const family = 'BrowserCustomFont';
      const fallback = ['BrowserFallback'];
      await mount(
        tester,
        desktop: desktop,
        anchor: desktop
            ? const Rect.fromLTWH(700, 540, 38, 38)
            : const Rect.fromLTWH(326, 750, 48, 48),
        theme: ThemeData(fontFamily: family, fontFamilyFallback: fallback),
      );
      void expectFont(String label) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label).last,
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.text.style!.fontFamily, family);
        expect(paragraph.text.style!.fontFamilyFallback, fallback);
        expect(paragraph.text.style!.decoration, TextDecoration.none);
      }

      expectFont('New tab');
      expectFont('Bookmarks');
      await tester.tap(find.text('Page options'));
      await tester.pumpAndSettle();
      expectFont('Page options');
      expectFont('Copy link');
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(fixture.results, ['copy']);
    });
  }

  testWidgets('desktop menu fades out in place above and below its anchor', (
    tester,
  ) async {
    for (final y in [30.0, 540.0]) {
      await mount(tester, desktop: true, anchor: Rect.fromLTWH(700, y, 38, 38));
      final before = tester.getRect(surface);
      Navigator.of(tester.element(surface)).pop();
      await tester.pump();
      var previousOpacity = 1.0;
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(surface), before);
        final opacity = tester.widget<BrowserGlass>(surface).opacity;
        expect(opacity, lessThan(previousOpacity));
        previousOpacity = opacity;
      }
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
    }
  });

  testWidgets('touch menu prepares its source shape before starting once', (
    tester,
  ) async {
    const anchor = Rect.fromLTWH(326, 750, 48, 48);
    await mount(tester, desktop: false, anchor: anchor, open: false);
    await tester.tap(find.byKey(const ValueKey('menuTrigger')));
    await tester.pump();
    final prepared = tester.widget<BrowserGlass>(surface);
    expect(tester.getRect(surface), anchor);
    expect(prepared.opacity, 0);
    expect(
      find.descendant(of: surface, matching: find.byIcon(LucideIcons.ellipsis)),
      findsNothing,
    );
    expect(fixture.transitionStarts, 0);
    await primeReadyMotion(tester);
    // Readiness may be delivered again while parameter updates finish.
    prepared.onReady!();
    await tester.pump();
    expect(tester.widget<BrowserGlass>(surface).opacity, 1);
    expect(fixture.transitionStarts, 1);
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getSize(surface).width, inExclusiveRange(48, 250));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 200));
    await tester.pumpAndSettle();
    prepared.onReady!();
    await tester.pump();
    expect(fixture.transitionStarts, 1);
    expect(fixture.results, [null]);
    expect(surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissal in the preparation frame never starts a late ready', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
      open: false,
    );
    VoidCallback? lateReady;
    tester.binding.addPostFrameCallback((_) {
      final glass = tester.widget<BrowserGlass>(surface);
      expect(glass.opacity, 0);
      lateReady = glass.onReady;
      // Same close path as the outside barrier, while its host has mounted but
      // before the material's end-of-frame readiness callback can arrive.
      Navigator.of(tester.element(surface)).pop();
    });
    await tester.tap(find.byKey(const ValueKey('menuTrigger')));
    await tester.pump();
    expect(fixture.results, [null]);
    expect(fixture.transitionStarts, 0);
    lateReady!();
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(fixture.transitionStarts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile menu sits next to its real trigger with compact grouped rows',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor);
      final bounds = tester.getRect(surface);
      expect(bounds.width, 250);
      expect(bounds.right, anchor.right);
      expect(bounds.bottom, anchor.bottom);
      expect(bounds.height, lessThan(400));
      final firstRow = find
          .ancestor(
            of: find.text('New tab'),
            matching: find.byType(FocusableActionDetector),
          )
          .first;
      expect(tester.getSize(firstRow).height, 44);
      expect(find.text('Find on page'), findsNothing);
      expect(find.text('Page options'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(InkResponse), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile glass grows from and retracts to the triggering control',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor, settle: false);
      expect(tester.getRect(surface), anchor);
      await tester.pump(const Duration(milliseconds: 70));
      final intermediate = tester.getSize(surface);
      expect(intermediate.width, greaterThan(anchor.width));
      expect(intermediate.width, lessThan(250));
      await tester.pumpAndSettle();
      final expanded = tester.getSize(surface);
      expect(expanded.width, 250);
      expect(expanded.height, greaterThan(anchor.height));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final retracting = tester.getSize(surface);
      expect(retracting.width, lessThan(expanded.width));
      expect(retracting.width, greaterThanOrEqualTo(anchor.width));
      expect(retracting.height, lessThan(expanded.height));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile lens rounds outward while content scales and clears inside it',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(
        tester,
        desktop: false,
        anchor: anchor,
        settle: false,
        theme: ThemeData(platform: TargetPlatform.iOS),
      );
      final initialRadius = tester.widget<BrowserGlass>(surface).radius;
      expect(initialRadius, 1000);
      expect(
        initialRadius.clamp(0, tester.getSize(surface).shortestSide / 2),
        closeTo(24, .01),
      );
      await tester.pump(const Duration(milliseconds: 90));
      final intermediateSurface = tester.getRect(surface);
      final intermediateText = tester.getRect(find.text('New tab'));
      final intermediateGlass = tester.widget<BrowserGlass>(surface);
      expect(intermediateGlass.radius, initialRadius);
      expect(
        intermediateGlass.radius.clamp(0, intermediateSurface.shortestSide / 2),
        intermediateSurface.shortestSide / 2,
      );
      final blur = find.byKey(const ValueKey('browserMenuContentBlur'));
      expect(tester.widget<ImageFiltered>(blur).enabled, isTrue);
      expect(
        find.ancestor(of: surface, matching: find.byType(ImageFiltered)),
        findsNothing,
      );
      await tester.pumpAndSettle();
      final expandedSurface = tester.getRect(surface);
      final expandedText = tester.getRect(find.text('New tab'));
      expect(
        intermediateText.width / expandedText.width,
        closeTo(intermediateSurface.width / expandedSurface.width, .01),
      );
      expect(
        intermediateText.height / expandedText.height,
        closeTo(intermediateSurface.height / expandedSurface.height, .01),
      );
      expect(tester.widget<ImageFiltered>(blur).enabled, isFalse);
      expect(tester.widget<BrowserGlass>(surface).radius, 25);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android menu morph keeps foreground sharp without an offscreen blur',
    (tester) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 90));
      final blur = tester.widget<ImageFiltered>(
        find.byKey(const ValueKey('browserMenuContentBlur')),
      );
      expect(blur.enabled, isFalse);
      expect(tester.getSize(surface).width, inExclusiveRange(48, 250));
      await tester.pumpAndSettle();
      expect(find.text('New tab'), findsOneWidget);
    },
  );

  testWidgets('touch menu selection uses a capsule highlight', (tester) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('New tab')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final highlight = find.byKey(const ValueKey('browserMenuSelection'));
    final box =
        tester.widget<DecoratedBox>(highlight).decoration as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(20));
    expect(box.color!.a, greaterThan(0));
    final row = find
        .ancestor(
          of: find.text('New tab'),
          matching: find.byType(FocusableActionDetector),
        )
        .first;
    expect(
      tester.getRect(highlight).left,
      closeTo(tester.getRect(row).left + 4, .01),
    );
    expect(
      tester.getRect(highlight).right,
      closeTo(tester.getRect(row).right - 4, .01),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(fixture.results, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile closing lifts the lens and settles back onto its trigger',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor);
      final expanded = tester.getRect(surface);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final early = tester.getRect(surface);
      expect(early.bottom, lessThan(anchor.bottom));
      expect(anchor.bottom - early.bottom, lessThanOrEqualTo(48));
      final widthRemaining =
          (early.width - anchor.width) / (expanded.width - anchor.width);
      expect(widthRemaining, lessThan(.45));
      final positionRemaining =
          (early.top - anchor.top) / (expanded.top - anchor.top);
      expect(positionRemaining, greaterThan(widthRemaining));
      await tester.pump(const Duration(milliseconds: 100));
      final late = tester.getRect(surface);
      expect(late.width - anchor.width, lessThan(10));
      expect(
        expanded.width - early.width,
        greaterThan(early.width - late.width),
      );
      expect(late.right, closeTo(anchor.right, .01));
      expect(late.bottom, greaterThan(early.bottom));
      expect(late.bottom, closeTo(anchor.bottom, 5));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop closing stays still while its material dissolves', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: true,
      anchor: const Rect.fromLTWH(720, 64, 32, 32),
    );
    final expanded = tester.getRect(surface);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 44));
    final early = tester.getRect(surface);
    expect(early, expanded);
    final earlyOpacity = tester.widget<BrowserGlass>(surface).opacity;
    expect(earlyOpacity, lessThan(.9));
    expect(early.size, expanded.size);
    await tester.pump(const Duration(milliseconds: 44));
    final late = tester.getRect(surface);
    expect(late, expanded);
    expect(
      tester.widget<BrowserGlass>(surface).opacity,
      lessThan(earlyOpacity),
    );
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop menu uses its toolbar anchor and has no elastic container',
    (tester) async {
      const anchor = Rect.fromLTWH(720, 64, 32, 32);
      await mount(tester, desktop: true, anchor: anchor);
      final bounds = tester.getRect(surface);
      expect(bounds.width, 256);
      expect(bounds.right, anchor.right);
      expect(bounds.top, anchor.bottom + 7);
      final firstRow = find
          .ancestor(
            of: find.text('New tab'),
            matching: find.byType(FocusableActionDetector),
          )
          .first;
      expect(tester.getSize(firstRow).height, 32);
      expect(
        find.descendant(of: surface, matching: find.byType(BrowserPress)),
        findsNothing,
      );
      expect(
        find.ancestor(of: surface, matching: find.byType(BrowserPress)),
        findsNothing,
      );
      final before = tester.getRect(surface);
      await tester.drag(find.text('New tab'), const Offset(20, 14));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop menu keeps the arrow cursor across rows and padding', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: true,
      anchor: const Rect.fromLTWH(720, 64, 32, 32),
    );
    final initialBounds = tester.getRect(surface);
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    for (final point in [
      tester.getCenter(find.text('New tab')),
      initialBounds.topLeft + const Offset(3, 3),
      tester.getCenter(find.text('History')),
    ]) {
      await mouse.moveTo(point);
      await tester.pumpAndSettle();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic,
      );
      expect(tester.getRect(surface), initialBounds);
    }
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop outside click and Escape dismiss without passing clicks to the page',
    (tester) async {
      await mount(
        tester,
        desktop: true,
        anchor: const Rect.fromLTWH(720, 64, 32, 32),
      );
      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .last;
      expect(barrier.color?.a, greaterThan(0));
      await tester.tapAt(const Offset(20, 500));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(fixture.underlyingClicks.value, 0);
      expect(fixture.results, [null]);

      await tester.tap(find.byKey(const ValueKey('menuTrigger')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(fixture.results, [null, null]);
      expect(fixture.underlyingClicks.value, 0);
    },
  );

  testWidgets(
    'menu padding consumes clicks and selecting a command returns only that command',
    (tester) async {
      await mount(
        tester,
        desktop: true,
        anchor: const Rect.fromLTWH(720, 64, 32, 32),
      );
      final bounds = tester.getRect(surface);
      await tester.tapAt(bounds.topLeft + const Offset(3, 3));
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      expect(fixture.underlyingClicks.value, 0);
      await tester.tap(find.text('Add bookmark'));
      await tester.pumpAndSettle();
      expect(fixture.results, ['bookmark']);
      expect(fixture.underlyingClicks.value, 0);
      expect(surface, findsNothing);
    },
  );

  testWidgets('page actions layer over the retained parent and return to it', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    final parent = tester.element(surface);
    final originalBounds = tester.getRect(surface);
    await tester.tap(find.text('Page options'));
    await tester.pumpAndSettle();
    expect(find.text('Find on page'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('New tab'), findsOneWidget);
    expect(tester.element(surface), same(parent));
    expect(tester.widget<BrowserGlass>(surface).opacity, 1);
    final submenu = find.byKey(const ValueKey('browserSubmenuSurface'));
    expect(submenu, findsOneWidget);
    expect(tester.getRect(submenu).overlaps(tester.getRect(surface)), isTrue);
    expect(tester.getRect(surface).width, lessThan(originalBounds.width));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('New tab'), findsOneWidget);
    expect(tester.element(surface), same(parent));
    expect(tester.getRect(surface), originalBounds);
    expect(tester.widget<BrowserGlass>(submenu).opacity, 0);
    expect(find.text('Copy link').hitTestable(), findsNothing);
    await tester.tap(
      find.descendant(of: surface, matching: find.text('Page options')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(fixture.results, ['copy']);
    expect(fixture.underlyingClicks.value, 0);
  });

  testWidgets(
    'mobile highlight balances twelve-point icon spacing and footer edges',
    (tester) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
      );
      final row = find.ancestor(
        of: find.text('History'),
        matching: find.byType(FocusableActionDetector),
      );
      final icon = find.descendant(
        of: row,
        matching: find.byIcon(LucideIcons.history),
      );
      final finger = await tester.startGesture(tester.getCenter(row));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final highlight = tester.getRect(
        find.byKey(const ValueKey('browserMenuSelection')),
      );
      expect(tester.getRect(icon).left - highlight.left, closeTo(12, .01));
      expect(
        tester.getRect(icon).left - tester.getRect(surface).left,
        closeTo(24, .01),
      );
      await finger.cancel();
      await tester.pumpAndSettle();
      final firstFooter = await tester.startGesture(
        tester.getCenter(find.text('Bookmarks')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.getRect(find.byKey(const ValueKey('browserMenuSelection'))).left,
        closeTo(highlight.left, .01),
      );
      await firstFooter.cancel();
      await tester.pumpAndSettle();
      final lastFooter = await tester.startGesture(
        tester.getCenter(find.text('Browser settings')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('browserMenuSelection')))
            .right,
        closeTo(highlight.right, .01),
      );
      await lastFooter.cancel();
      await tester.pumpAndSettle();
      expect(fixture.results, isEmpty);
    },
  );

  testWidgets('mobile child aligns its header with the source row', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    final source = find.ancestor(
      of: find.descendant(of: surface, matching: find.text('Page options')),
      matching: find.byType(FocusableActionDetector),
    );
    await tester.tap(source);
    await tester.pumpAndSettle();
    final child = find.byKey(const ValueKey('browserSubmenuSurface'));
    expect(
      tester.getRect(child).top,
      closeTo(tester.getRect(source).top - 8, 1),
    );
    expect(tester.getRect(child).bottom, lessThanOrEqualTo(834));
    expect(tester.getRect(child).overlaps(tester.getRect(surface)), isTrue);
  });

  testWidgets('mobile source-anchored child stays inside a short viewport', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      size: const Size(320, 400),
      textScale: 2,
      anchor: const Rect.fromLTWH(250, 340, 48, 48),
    );
    await tester.tap(find.text('Page options'));
    await tester.pumpAndSettle();
    final child = find.byKey(const ValueKey('browserSubmenuSurface'));
    final source = find.ancestor(
      of: find.descendant(of: surface, matching: find.text('Page options')),
      matching: find.byType(FocusableActionDetector),
    );
    final bounds = tester.getRect(child);
    expect(bounds.top, greaterThanOrEqualTo(10));
    expect(bounds.bottom, lessThanOrEqualTo(390));
    expect(bounds.left, greaterThanOrEqualTo(10));
    expect(bounds.right, lessThanOrEqualTo(310));
    expect(bounds.top, lessThan(tester.getRect(source).top - 8));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(tester.widget<BrowserGlass>(child).opacity, 0);
    expect(tester.takeException(), isNull);
  });

  for (final style in BrowserSurfaceStyle.values) {
    testWidgets('both mobile menu layers retain the ${style.name} material', (
      tester,
    ) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
        style: style,
      );
      final primary = tester.element(surface);
      await tester.tap(find.text('Page options'));
      await tester.pumpAndSettle();
      final secondary = find.byKey(const ValueKey('browserSubmenuSurface'));
      expect(BrowserGlassScope.of(tester.element(secondary)), style);
      expect(BrowserGlassScope.of(tester.element(surface)), style);
      expect(tester.element(surface), same(primary));
      expect(find.byType(BrowserGlass), findsNWidgets(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      expect(tester.widget<BrowserGlass>(secondary).opacity, 0);
      expect(tester.element(surface), same(primary));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(secondary, findsNothing);
      expect(fixture.results, [null]);
    });
  }

  testWidgets(
    'canceling a held submenu preserves its source until whole-menu dismissal',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor, open: false);
      final finger = await tester.startGesture(anchor.center, pointer: 91);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final primary = tester.element(surface);
      await finger.moveTo(tester.getCenter(find.text('Page options')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.element(surface), same(primary));
      expect(
        find.byKey(const ValueKey('browserSubmenuSurface')),
        findsOneWidget,
      );
      await finger.moveTo(tester.getCenter(find.text('Copy link')));
      await tester.pump();
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(fixture.results, [null]);
      expect(surface, findsNothing);
      expect(find.byKey(const ValueKey('browserSubmenuSurface')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (anchor, opensRight) in [
    (const Rect.fromLTWH(24, 64, 32, 32), true),
    (const Rect.fromLTWH(720, 64, 32, 32), false),
  ]) {
    testWidgets(
      'desktop submenu opens ${opensRight ? 'right' : 'left'} and preserves a hover corridor',
      (tester) async {
        await mount(tester, desktop: true, anchor: anchor);
        final source = find.text('Page options');
        final primary = tester.getRect(surface);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(400, 580));
        await mouse.moveTo(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pumpAndSettle();
        final submenu = find.byKey(const ValueKey('browserSubmenuSurface'));
        final bounds = tester.getRect(submenu);
        if (opensRight) {
          expect(bounds.left, greaterThanOrEqualTo(primary.right));
        } else {
          expect(bounds.right, lessThanOrEqualTo(primary.left));
        }
        expect(bounds.left, greaterThanOrEqualTo(10));
        expect(bounds.right, lessThanOrEqualTo(790));
        expect(tester.getRect(surface), primary);
        final gap = Offset(
          opensRight
              ? (primary.right + bounds.left) / 2
              : (bounds.right + primary.left) / 2,
          tester.getCenter(source).dy,
        );
        await mouse.moveTo(gap);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<BrowserGlass>(submenu).opacity, 1);
        await mouse.moveTo(tester.getCenter(find.text('Copy link')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<BrowserGlass>(submenu).opacity, 1);
        final regions = tester.widgetList<MouseRegion>(
          find.descendant(of: submenu, matching: find.byType(MouseRegion)),
        );
        expect(
          regions
              .where((region) => region.cursor != MouseCursor.defer)
              .every((region) => region.cursor == SystemMouseCursors.basic),
          isTrue,
        );
        await mouse.moveTo(const Offset(400, 580));
        await tester.pump(const Duration(milliseconds: 330));
        await tester.pumpAndSettle();
        expect(tester.widget<BrowserGlass>(submenu).opacity, 0);
        expect(surface, findsOneWidget);
        await mouse.removePointer();
      },
    );
  }

  testWidgets(
    'desktop cursor remains arrow over glyphs icons gaps and both layers',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(
        tester,
        desktop: true,
        selectable: true,
        anchor: const Rect.fromLTWH(720, 64, 32, 32),
      );
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(20, 580));
      for (final name in ['New tab', 'Page options', 'Copy link']) {
        if (name == 'Copy link') {
          await mouse.moveTo(tester.getCenter(find.text('Page options')));
          await tester.pump(const Duration(milliseconds: 180));
          await tester.pumpAndSettle();
        }
        final text = find.text(name);
        final row = find.ancestor(
          of: text,
          matching: find.byType(FocusableActionDetector),
        );
        final bounds = tester.getRect(row);
        for (final point in [
          tester.getCenter(text),
          tester.getTopLeft(text) + const Offset(1, 2),
          bounds.centerLeft + const Offset(2, 0),
          bounds.centerRight - const Offset(2, 0),
        ]) {
          await mouse.moveTo(point);
          await tester.pump();
          expect(
            RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
            SystemMouseCursors.basic,
          );
        }
        final label = tester.getSemantics(row);
        expect(
          label.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
      }
      for (final (key, panel) in [
        ('browserMenuCursorFootprint', surface),
        (
          'browserSubmenuCursorFootprint',
          find.byKey(const ValueKey('browserSubmenuSurface')),
        ),
      ]) {
        final footprint = find.byKey(ValueKey(key));
        final decoration =
            tester.widget<DecoratedBox>(footprint).decoration as BoxDecoration;
        expect(decoration.color!.a, closeTo(1 / 255, .00001));
        expect(tester.getRect(footprint), tester.getRect(panel));
      }
      expect(
        tester
            .widgetList<RichText>(
              find.descendant(of: surface, matching: find.byType(RichText)),
            )
            .every((paragraph) => paragraph.selectionRegistrar == null),
        isTrue,
      );
      await mouse.removePointer();
      semantics.dispose();
    },
  );

  testWidgets('desktop hover moves one capsule highlight within each panel', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: true,
      anchor: const Rect.fromLTWH(720, 64, 32, 32),
    );
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(20, 580));
    await mouse.moveTo(tester.getCenter(find.text('Page options')));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pumpAndSettle();
    final child = find.byKey(const ValueKey('browserSubmenuSurface'));
    int highlights(Finder panel) => tester
        .widgetList<DecoratedBox>(
          find.descendant(of: panel, matching: find.byType(DecoratedBox)),
        )
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.color != null &&
              (decoration.color!.a - .075).abs() < .001;
        })
        .length;
    for (final label in ['Find on page', 'Copy link']) {
      await mouse.moveTo(tester.getCenter(find.text(label)));
      await tester.pump();
      expect(highlights(child), 1);
    }
    await mouse.moveTo(tester.getCenter(find.text('New tab')));
    await tester.pump();
    expect(highlights(surface), 1);
    final row = find.ancestor(
      of: find.text('New tab'),
      matching: find.byType(FocusableActionDetector),
    );
    final background = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: row, matching: find.byType(DecoratedBox)),
        )
        .first;
    expect(
      (background.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(16),
    );
    await mouse.removePointer();
    await tester.pumpAndSettle();
  });

  for (final leaveMenu in [false, true]) {
    testWidgets(
      'desktop hover dismissal clears the submenu source highlight (outside: $leaveMenu)',
      (tester) async {
        final highlightStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = highlightStrategy,
        );
        await mount(
          tester,
          desktop: true,
          anchor: const Rect.fromLTWH(720, 64, 32, 32),
          style: BrowserSurfaceStyle.solid,
        );
        Color background(String label) {
          final row = find.ancestor(
            of: find.text(label),
            matching: find.byType(FocusableActionDetector),
          );
          final box = tester.widget<DecoratedBox>(
            find.descendant(of: row, matching: find.byType(DecoratedBox)).first,
          );
          return (box.decoration as BoxDecoration).color!;
        }

        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(20, 580));
        await mouse.moveTo(tester.getCenter(find.text('Page options')));
        await mouse.down(tester.getCenter(find.text('Page options')));
        await mouse.up();
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.text('Copy link')));
        await tester.pump();
        await mouse.moveTo(
          leaveMenu
              ? const Offset(20, 580)
              : tester.getCenter(find.text('History')),
        );
        await tester.pump(const Duration(milliseconds: 330));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BrowserGlass>(
                find.byKey(const ValueKey('browserSubmenuSurface')),
              )
              .opacity,
          0,
        );
        expect(background('Page options'), Colors.transparent);
        expect(background('History').a, leaveMenu ? 0 : closeTo(.075, .001));
        expect(fixture.results, isEmpty);
        await mouse.removePointer();
        await tester.sendKeyEvent(
          leaveMenu ? LogicalKeyboardKey.escape : LogicalKeyboardKey.enter,
        );
        await tester.pumpAndSettle();
        expect(fixture.results, [leaveMenu ? null : 'history']);
        expect(surface, findsNothing);
      },
    );
  }

  testWidgets('keyboard submenu dismissal restores focus to its source', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: true,
      anchor: const Rect.fromLTWH(720, 64, 32, 32),
      style: BrowserSurfaceStyle.solid,
    );
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.escape,
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      final source = tester.widget<FocusableActionDetector>(
        find.ancestor(
          of: find.text('Page options'),
          matching: find.byType(FocusableActionDetector),
        ),
      );
      expect(source.focusNode!.hasPrimaryFocus, isTrue);
      expect(
        tester
            .widget<BrowserGlass>(
              find.byKey(const ValueKey('browserSubmenuSurface')),
            )
            .opacity,
        0,
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(fixture.results, [null]);
  });

  testWidgets('recessed parent stays legible outside the child footprint', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    await tester.tap(find.text('Page options'));
    await tester.pumpAndSettle();
    final primaryElement = tester.element(surface);
    final secondary = find.byKey(const ValueKey('browserSubmenuSurface'));
    final childElement = tester.element(secondary);
    final parentContent = find.byKey(
      const ValueKey('browserMenuParentContent'),
    );
    double alpha(String key) =>
        tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;
    // The material does the occlusion. No second mask may erase exposed
    // parent rows as the child moves independently in its overlay portal.
    expect(
      find.descendant(of: parentContent, matching: find.byType(ClipPath)),
      findsNothing,
    );

    expect(alpha('browserMenuParentContent'), closeTo(.72, .001));
    expect(tester.widget<BrowserGlass>(surface).opacity, 1);
    expect(alpha('browserSubmenuContent'), 1);
    expect(find.text('New tab'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(alpha('browserMenuParentContent'), greaterThanOrEqualTo(.72));
      expect(tester.widget<BrowserGlass>(surface).opacity, 1);
      expect(tester.element(surface), same(primaryElement));
      expect(tester.element(secondary), same(childElement));
    }
    await tester.pumpAndSettle();
    expect(alpha('browserMenuParentContent'), 1);
    expect(alpha('browserSubmenuContent'), 0);
    expect(tester.widget<BrowserGlass>(secondary).opacity, 0);
  });

  testWidgets('desktop cascade supports click, escape, and outside dismissal', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: true,
      anchor: const Rect.fromLTWH(720, 64, 32, 32),
    );
    await tester.tap(find.text('Page options'));
    await tester.pumpAndSettle();
    final submenu = find.byKey(const ValueKey('browserSubmenuSurface'));
    await tester.tapAt(tester.getTopLeft(submenu) + const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(fixture.underlyingClicks.value, 0);
    expect(tester.widget<BrowserGlass>(submenu).opacity, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<BrowserGlass>(submenu).opacity, 0);
    expect(surface, findsOneWidget);
    await tester.tap(find.text('Page options'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 500));
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(submenu, findsNothing);
    expect(fixture.results, [null]);
    expect(fixture.underlyingClicks.value, 0);
  });

  testWidgets(
    'one held pointer can enter a child, return, and select its original parent',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor, open: false);
      final finger = await tester.startGesture(anchor.center, pointer: 92);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final primary = tester.element(surface);
      await finger.moveTo(tester.getCenter(find.text('Page options')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final submenu = find.byKey(const ValueKey('browserSubmenuSurface'));
      final back = find.descendant(
        of: submenu,
        matching: find.text('Page options'),
      );
      await finger.moveTo(tester.getCenter(back));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.element(surface), same(primary));
      expect(tester.widget<BrowserGlass>(submenu).opacity, 0);
      expect(fixture.results, isEmpty);
      await finger.moveTo(tester.getCenter(find.text('New tab')));
      await tester.pump();
      await finger.up();
      await tester.pumpAndSettle();
      expect(fixture.results, ['new']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a layered command returns the parent to the exact source bounds',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor);
      await tester.tap(find.text('Page options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy link'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 249));
      final ending = tester.getRect(surface);
      expect(ending.width, closeTo(anchor.width, .8));
      expect(ending.height, closeTo(anchor.height, .8));
      expect(ending.right, closeTo(anchor.right, .8));
      expect(ending.bottom, closeTo(anchor.bottom, .8));
      await tester.pumpAndSettle();
      expect(fixture.results, ['copy']);
      expect(surface, findsNothing);
    },
  );

  testWidgets(
    'returning during submenu preparation permits reopening the same material host',
    (tester) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
      );
      final primary = tester.element(surface);
      final submenu = find.byKey(const ValueKey('browserSubmenuSurface'));
      tester.binding.addPostFrameCallback((_) {
        expect(tester.widget<BrowserGlass>(submenu).opacity, 0);
        Navigator.of(tester.element(submenu)).pop();
      });
      // Keyboard activation opens synchronously. A touch tap deliberately
      // queues its pointer-up until the selection listener's first frame.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final secondary = tester.element(submenu);
      expect(tester.widget<BrowserGlass>(submenu).opacity, 0);
      expect(tester.element(surface), same(primary));
      await tester.tap(
        find.descendant(of: surface, matching: find.text('Page options')),
      );
      await tester.pumpAndSettle();
      expect(tester.element(submenu), same(secondary));
      expect(tester.widget<BrowserGlass>(submenu).opacity, 1);
      expect(tester.element(surface), same(primary));
      expect(fixture.results, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accessibility actions open submenus and invoke commands without pointer taps',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(
          tester,
          desktop: false,
          anchor: const Rect.fromLTWH(326, 750, 48, 48),
        );
        Future<void> activate(String label) async {
          final finder = find.bySemanticsLabel(label);
          expect(finder, findsOneWidget);
          final node = tester.getSemantics(finder);
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
          node.owner!.performAction(node.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
        }

        await activate('Page options');
        expect(find.text('Copy link'), findsOneWidget);
        await activate('Back: Page options');
        expect(find.text('New tab'), findsOneWidget);
        await activate('Page options');
        await activate('Copy link');
        expect(fixture.results, ['copy']);
        expect(fixture.underlyingClicks.value, 0);
        expect(surface, findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('footer shortcuts expose one accessibility tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
      );
      final finder = find.bySemanticsLabel('Bookmarks');
      expect(finder, findsOneWidget);
      final node = tester.getSemantics(finder);
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, ui.SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(fixture.results, ['bookmarks']);
      expect(fixture.underlyingClicks.value, 0);
      expect(surface, findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'menu repositions and scrolls within a small window at large text sizes',
    (tester) async {
      await mount(
        tester,
        desktop: true,
        anchor: const Rect.fromLTWH(8, 300, 32, 32),
        size: const Size(320, 400),
        textScale: 2,
      );
      final bounds = tester.getRect(surface);
      expect(bounds.left, greaterThanOrEqualTo(10));
      expect(bounds.right, lessThanOrEqualTo(310));
      expect(bounds.top, greaterThanOrEqualTo(10));
      expect(bounds.bottom, lessThanOrEqualTo(390));
      await tester.ensureVisible(find.text('Close browser'));
      await tester.tap(find.text('Close browser'));
      await tester.pumpAndSettle();
      expect(fixture.results, ['close']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'held trigger selects rows without moving or stretching the menu',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor, open: false);
      final finger = await tester.startGesture(anchor.center);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      expect(fixture.results, isEmpty);
      Rect paintedBounds() {
        final box = tester.renderObject<RenderBox>(surface);
        return MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
      }

      final restingBounds = paintedBounds();
      await finger.moveTo(tester.getCenter(find.text('New tab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final highlight = find.byKey(const ValueKey('browserMenuSelection'));
      expect(highlight, findsOneWidget);
      final firstRect = tester.getRect(highlight);
      expect(
        firstRect.contains(tester.getCenter(find.text('New tab'))),
        isTrue,
      );
      expect(paintedBounds(), restingBounds);
      await finger.moveTo(tester.getCenter(find.text('Bookmarks')));
      await tester.pumpAndSettle();
      expect(paintedBounds(), restingBounds);
      expect(tester.getRect(highlight).top, greaterThan(firstRect.top));
      expect(
        tester
            .getRect(highlight)
            .contains(tester.getCenter(find.text('Bookmarks'))),
        isTrue,
      );
      expect(fixture.results, isEmpty);
      await finger.up();
      await tester.pumpAndSettle();
      expect(fixture.results, ['bookmarks']);
      expect(fixture.underlyingClicks.value, 0);
      expect(surface, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('holding then releasing the trigger leaves the menu open', (
    tester,
  ) async {
    const anchor = Rect.fromLTWH(326, 750, 48, 48);
    await mount(tester, desktop: false, anchor: anchor, open: false);
    final finger = await tester.startGesture(anchor.center);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await finger.up();
    await tester.pumpAndSettle();
    expect(fixture.results, isEmpty);
    expect(surface, findsOneWidget);
    await tester.tap(find.text('New tab'));
    await tester.pumpAndSettle();
    expect(fixture.results, ['new']);
  });

  testWidgets('held selection ignores another finger and can enter a submenu', (
    tester,
  ) async {
    const anchor = Rect.fromLTWH(326, 750, 48, 48);
    await mount(tester, desktop: false, anchor: anchor, open: false);
    final finger = await tester.startGesture(anchor.center, pointer: 41);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final other = await tester.startGesture(
      tester.getCenter(find.text('New tab')),
      pointer: 42,
    );
    await other.up();
    await tester.pump();
    expect(fixture.results, isEmpty);
    await finger.moveTo(tester.getCenter(find.text('Page options')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Copy link'), findsOneWidget);
    expect(fixture.results, isEmpty);
    await finger.moveTo(tester.getCenter(find.text('Copy link')));
    await tester.pump(const Duration(milliseconds: 100));
    await finger.up();
    await tester.pumpAndSettle();
    expect(fixture.results, ['copy']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'held pointer cancellation and outside release invoke no action',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      for (final cancel in [true, false]) {
        await mount(tester, desktop: false, anchor: anchor, open: false);
        final finger = await tester.startGesture(anchor.center);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        await finger.moveTo(tester.getCenter(find.text('New tab')));
        await tester.pump();
        if (cancel) {
          await finger.cancel();
        } else {
          await finger.moveTo(const Offset(24, 200));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('browserMenuSelection')),
            findsNothing,
          );
          await finger.up();
        }
        await tester.pumpAndSettle();
        expect(fixture.results, [null]);
        expect(fixture.underlyingClicks.value, 0);
        expect(surface, findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('system back dismisses a touch menu without popping its page', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(find.byKey(const ValueKey('menuTrigger')), findsOneWidget);
    expect(fixture.results, [null]);
  });

  testWidgets('release or cancel before the first overlay frame is retained', (
    tester,
  ) async {
    const anchor = Rect.fromLTWH(326, 750, 48, 48);
    for (final cancel in [false, true]) {
      await mount(tester, desktop: false, anchor: anchor, open: false);
      // Transfer an already-held pointer, then end it before a build can mount
      // the menu. This exercises the scheduling gap after long-press detection.
      const point = Offset(24, 200);
      final finger = await tester.startGesture(point, pointer: 61);
      final result = fixture.open(
        tester.element(find.byKey(const ValueKey('menuTrigger'))),
        pointer: 61,
        position: point,
      );
      if (cancel) {
        await finger.cancel();
      } else {
        await finger.up();
      }
      await tester.pumpAndSettle();
      if (cancel) {
        expect(surface, findsNothing);
        expect(fixture.results, [null]);
        expect(fixture.transitionStarts, 0);
      } else {
        expect(surface, findsOneWidget);
        await tester.tap(find.text('New tab'));
        await tester.pumpAndSettle();
        expect(fixture.results, ['new']);
      }
      await result;
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'opened menu scrubs across rows and footer and selects only on release',
    (tester) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.text('New tab')),
        pointer: 61,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final highlight = find.byKey(const ValueKey('browserMenuSelection'));
      expect(highlight, findsOneWidget);
      final other = await tester.startGesture(
        tester.getCenter(find.text('Close browser')),
        pointer: 62,
      );
      await other.up();
      await tester.pump();
      expect(fixture.results, isEmpty);
      await finger.moveTo(tester.getCenter(find.text('Bookmarks')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 170));
      expect(highlight, findsOneWidget);
      expect(
        tester
            .getRect(highlight)
            .contains(tester.getCenter(find.text('Bookmarks'))),
        isTrue,
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(fixture.results, ['bookmarks']);
      expect(fixture.underlyingClicks.value, 0);
    },
  );

  testWidgets(
    'opened selection cancellation and outside release leave actions untouched',
    (tester) async {
      for (final cancel in [true, false]) {
        await mount(
          tester,
          desktop: false,
          anchor: const Rect.fromLTWH(326, 750, 48, 48),
        );
        final finger = await tester.startGesture(
          tester.getCenter(find.text('New tab')),
        );
        await tester.pump();
        await finger.moveTo(tester.getCenter(find.text('Add bookmark')));
        await tester.pump(const Duration(milliseconds: 220));
        if (cancel) {
          await finger.cancel();
        } else {
          await finger.moveTo(const Offset(20, 200));
          await finger.up();
        }
        await tester.pumpAndSettle();
        expect(fixture.results, isEmpty);
        expect(surface, findsOneWidget);
        expect(
          find.byKey(const ValueKey('browserMenuSelection')),
          findsNothing,
        );
        expect(fixture.underlyingClicks.value, 0);
        await tester.tapAt(const Offset(20, 200));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('menu selection respects the global haptic switch', (
    tester,
  ) async {
    final enabled = Haptics.enabled;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    });
    addTearDown(() {
      Haptics.setEnabled(enabled);
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    calls.clear();
    Haptics.setEnabled(false);
    final finger = await tester.startGesture(
      tester.getCenter(find.text('New tab')),
    );
    await tester.pump();
    expect(calls, isEmpty);
    Haptics.setEnabled(true);
    await finger.moveTo(tester.getCenter(find.text('Add bookmark')));
    await tester.pump();
    expect(calls, hasLength(1));
    await finger.cancel();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opened menu can dwell into a submenu then slide to a command', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(326, 750, 48, 48),
    );
    final finger = await tester.startGesture(
      tester.getCenter(find.text('Page options')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Copy link'), findsOneWidget);
    await finger.moveTo(tester.getCenter(find.text('Copy link')));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(fixture.results, ['copy']);
  });

  testWidgets('scrollable touch menus scroll instead of scrub-selecting rows', (
    tester,
  ) async {
    await mount(
      tester,
      desktop: false,
      anchor: const Rect.fromLTWH(300, 290, 48, 48),
      size: const Size(390, 360),
      textScale: 2,
    );
    final scroll = find.descendant(
      of: surface,
      matching: find.byType(SingleChildScrollView),
    );
    final controller = tester.widget<SingleChildScrollView>(scroll).controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
    final finger = await tester.startGesture(
      tester.getCenter(find.text('New tab')),
    );
    await tester.pump();
    await finger.moveBy(const Offset(0, -70));
    await tester.pump();
    await finger.moveBy(const Offset(0, -60));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(fixture.results, isEmpty);
    expect(find.byKey(const ValueKey('browserMenuSelection')), findsNothing);
  });

  testWidgets(
    'host subtree removal completes a pending menu without retaining its route',
    (tester) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
        open: false,
      );
      final context = tester.element(find.byKey(const ValueKey('menuTrigger')));
      final result = fixture.open(context);
      // Remove the portal owner before the first overlay build.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await result;
      await tester.pumpAndSettle();
      expect(fixture.results, [null]);
      expect(fixture.transitionStarts, 0);
      expect(surface, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'interrupted opening closes continuously and hands the source back only at the end',
    (tester) async {
      await mount(
        tester,
        desktop: false,
        anchor: const Rect.fromLTWH(326, 750, 48, 48),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 70));
      final before = tester.getRect(surface);
      await tester.tapAt(const Offset(20, 200));
      await tester.pump();
      final after = tester.getRect(surface);
      expect(after.left, closeTo(before.left, .01));
      expect(after.top, closeTo(before.top, .01));
      expect(after.size, before.size);
      expect(fixture.results, isEmpty);
      await tester.pumpAndSettle();
      expect(fixture.results, [null]);
      expect(surface, findsNothing);
    },
  );

  testWidgets(
    'closing retargets a lifted source to its current resting bounds',
    (tester) async {
      const resting = Rect.fromLTWH(326, 750, 48, 48);
      const lifted = Rect.fromLTWH(316, 740, 68, 68);
      for (final interrupt in [false, true]) {
        await mount(tester, desktop: false, anchor: resting, open: false);
        final context = tester.element(
          find.byKey(const ValueKey('menuTrigger')),
        );
        final result = fixture.open(
          context,
          openingAnchor: lifted,
          resolveAnchor: () => resting,
        );
        await primeReadyMotion(tester);
        if (interrupt) {
          await tester.pump(const Duration(milliseconds: 100));
        } else {
          await tester.pumpAndSettle();
        }
        final before = tester.getRect(surface);
        await tester.tapAt(const Offset(20, 200));
        await tester.pump();
        expect(tester.getRect(surface), before);
        // Reverse duration follows the current controller value (100 or 250ms).
        await tester.pump(Duration(milliseconds: interrupt ? 99 : 249));
        final ending = tester.getRect(surface);
        expect(ending.width, closeTo(resting.width, .8));
        expect(ending.height, closeTo(resting.height, .8));
        expect(ending.right, closeTo(resting.right, .8));
        expect(ending.bottom, closeTo(resting.bottom, .8));
        expect(fixture.results, isEmpty);
        await tester.pumpAndSettle();
        await result;
        expect(fixture.results, [null]);
      }
    },
  );

  testWidgets(
    'closing tolerates a removed source without reading a detached box',
    (tester) async {
      const anchor = Rect.fromLTWH(326, 750, 48, 48);
      await mount(tester, desktop: false, anchor: anchor, open: false);
      final context = tester.element(find.byKey(const ValueKey('menuTrigger')));
      final result = fixture.open(context, resolveAnchor: () => null);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 200));
      await tester.pumpAndSettle();
      await result;
      expect(fixture.results, [null]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('removing the host route also removes its menu and barrier', (
    tester,
  ) async {
    const anchor = Rect.fromLTWH(326, 750, 48, 48);
    await mount(tester, desktop: false, anchor: anchor, open: false);
    final host = _MenuFixture(desktop: false, anchor: anchor);
    addTearDown(host.underlyingClicks.dispose);
    final navigator = Navigator.of(
      tester.element(find.byKey(const ValueKey('menuTrigger'))),
    );
    final route = MaterialPageRoute<void>(builder: (_) => host);
    unawaited(navigator.push(route));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menuTrigger')));
    await tester.pumpAndSettle();
    expect(surface, findsOneWidget);
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(host.results, [null]);
    expect(tester.takeException(), isNull);
  });
}

class _MenuFixture extends StatelessWidget {
  _MenuFixture({required this.desktop, required this.anchor});
  final bool desktop;
  final Rect anchor;
  final trigger = GlobalKey();
  final results = <String?>[];
  final _transitionStartFrames = <Duration>[];
  int get transitionStarts => _transitionStartFrames.length;
  final underlyingClicks = ValueNotifier<int>(0);

  Future<void> open(
    BuildContext context, {
    int? pointer,
    Offset? position,
    Rect? openingAnchor,
    Rect? Function()? resolveAnchor,
  }) async {
    final box = trigger.currentContext!.findRenderObject()! as RenderBox;
    results.add(
      await showBrowserMenu<String>(
        context,
        title: 'More',
        items: _items,
        anchorRect: openingAnchor ?? box.localToGlobal(Offset.zero) & box.size,
        resolveAnchor: resolveAnchor,
        desktop: desktop,
        heldPointer: pointer,
        pressPosition: position,
        onTransitionStart: () => _transitionStartFrames.add(
          WidgetsBinding.instance.currentSystemFrameTimeStamp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BrowserMenuHost(
    child: Builder(
      builder: (context) => Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => underlyingClicks.value++,
              ),
            ),
            Positioned.fromRect(
              rect: anchor,
              child: SizedBox(
                key: trigger,
                child: BrowserPress(
                  key: const ValueKey('menuTrigger'),
                  draggable: !desktop,
                  onTap: () => open(context),
                  onLongPress: () => open(context),
                  onLongPressStart: (pointer, details) => open(
                    context,
                    pointer: pointer,
                    position: details.globalPosition,
                  ),
                  child: const Icon(LucideIcons.ellipsis),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
