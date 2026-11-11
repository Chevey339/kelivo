import 'dart:async';
import 'dart:ui' as ui;

import 'package:Kelivo/features/intelligent_ui/host/gallery/web_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_preview.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_web_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../support/genui_web_platform.dart';

UiWebDocument document({
  UiGenerationStatus status = UiGenerationStatus.complete,
}) => UiWebDocument.parse(
  genUiWebGallerySource,
  closed: true,
  generation: status,
);

Widget app(Widget child, {EdgeInsets padding = EdgeInsets.zero}) => MaterialApp(
  theme: buildLightTheme(null),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(padding: padding),
    child: child!,
  ),
  home: Scaffold(body: GenUiThemeScope(child: child)),
);

void main() {
  late FakeGenUiWebPlatform platform;
  setUp(() {
    platform = FakeGenUiWebPlatform();
    WebViewPlatform.instance = platform;
  });
  testWidgets('one spoken title and focusable disabled Open with its reason', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var opens = 0;
      await tester.pumpWidget(
        app(
          GenUiWebCard(
            document: document(status: UiGenerationStatus.generating),
            supported: true,
            onOpen: (_) async {
              opens++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getSemantics(find.byType(GenUiWebCard));
      expect(
        'Local counter'.allMatches(card.getSemanticsData().label),
        hasLength(1),
      );
      final button = tester
          .getSemantics(find.bySemanticsLabel('Open'))
          .getSemanticsData();
      expect(button.hasAction(ui.SemanticsAction.tap), isFalse);
      expect(button.hint, 'Can be opened after generation finishes');
      final focus = tester
          .widget<GenUiWebOpenButton>(find.byType(GenUiWebOpenButton))
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(opens, 0);
      expect(platform.controllers, isEmpty);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
    'unsupported and export cards have no Open or native controller',
    (tester) async {
      await tester.pumpWidget(
        app(
          GenUiWebCard(
            document: document(),
            supported: false,
            onExportHtml: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
      expect(find.text('Copy source'), findsOneWidget);
      expect(find.text('Export HTML'), findsOneWidget);
      await tester.pumpWidget(
        app(
          GenUiWebCard(document: document(), supported: true, exporting: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenUiWebOpenButton), findsNothing);
      expect(find.text('View source'), findsNothing);
      expect(platform.controllers, isEmpty);
    },
  );
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'Open is lazy; Esc discards the session and returns focus at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => GenUiWebCard(
                document: document(),
                supported: true,
                onOpen: (value) => showUiWebPreview(context, value),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 34),
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<GenUiWebOpenButton>(
          find.byType(GenUiWebOpenButton),
        );
        expect(platform.controllers, isEmpty);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(platform.controllers, hasLength(1));
        expect(find.text('Native preview test double'), findsOneWidget);
        if (width == 390) {
          expect(tester.getRect(find.byType(WebViewWidget)).bottom, 900 - 34);
        }
        final l10n = AppLocalizations.of(
          tester.element(find.text('Native preview test double')),
        )!;
        expect(find.text(l10n.genuiWebSandboxNote), findsNothing);
        expect(find.text(l10n.genuiWebCspNote), findsNothing);
        await tester.tap(find.byTooltip(l10n.genuiWebInfo));
        await tester.pumpAndSettle();
        expect(find.text(l10n.genuiWebSandboxNote), findsOneWidget);
        expect(find.text(l10n.genuiWebCspNote), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(l10n.genuiWebCspNote), findsNothing);
        expect(find.text('Native preview test double'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Native preview test double'), findsNothing);
        expect(button.focusNode!.hasFocus, isTrue);
        expect(
          platform.controllers.single.documents.last,
          UiWebSandbox.emptyDocument,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(platform.controllers, hasLength(2));
        expect(
          platform.controllers.last.documents.first,
          UiWebSandbox.wrap(document().html, title: document().title),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
  testWidgets('loading is covered and the page stays alive throughout exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    platform.finishInitial = false;
    var nativeTaps = 0;
    platform.onTap = () => nativeTaps++;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => GenUiWebCard(
              document: document(),
              supported: true,
              onOpen: (value) => showUiWebPreview(context, value),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(WebViewWidget), findsOneWidget);
      final cover = find.byKey(const ValueKey('genui-web-loading-cover'));
      expect(cover, findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(WebViewWidget)));
      expect(nativeTaps, 0);
      expect(
        find.bySemanticsLabel(RegExp('Native preview action')),
        findsNothing,
      );
      final native = platform.controllers.single;
      native.navigation!.finished!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(cover, findsOneWidget);
      await tester.pumpAndSettle();
      expect(cover, findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Native preview action')),
        findsOneWidget,
      );
      await tester.tapAt(tester.getCenter(find.byType(WebViewWidget)));
      expect(nativeTaps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(native.scripts, isEmpty);
      expect(native.documents, hasLength(1));
      await tester.pumpAndSettle();
      expect(find.byType(WebViewWidget), findsNothing);
      expect(native.documents.last, UiWebSandbox.emptyDocument);
    } finally {
      semantics.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('disposing the entire Navigator closes its native session', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    var finished = false;
    unawaited(
      showUiWebPreview(context, document()).then((_) {
        finished = true;
      }),
    );
    await tester.pumpAndSettle();
    expect(platform.controllers, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(
      platform.controllers.single.documents.last,
      UiWebSandbox.emptyDocument,
    );
    expect(finished, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  testWidgets(
    'a replacement waits for the previous native teardown and route',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final first = showUiWebPreview(context, document());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview information'));
      await tester.pumpAndSettle();
      expect(find.text('Preview information'), findsOneWidget);
      final wait = Completer<void>();
      platform.cleanupWait = wait;
      final second = showUiWebPreview(context, document());
      await tester.pump();
      expect(platform.controllers, hasLength(1));
      wait.complete();
      await tester.pumpAndSettle();
      await first;
      expect(find.text('Preview information'), findsNothing);
      expect(platform.controllers, hasLength(2));
      expect(
        platform.controllers.first.documents.last,
        UiWebSandbox.emptyDocument,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await second;
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
