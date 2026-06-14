import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _transparentPngDataUrl =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
    'hgGAWjR9awAAAABJRU5ErkJggg==';

const _widePngDataUrl =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAABQAAAAKCAYAAAC0VX7mAAAAF0lEQVR4nGP4z8Dw'
    'n5qYYdTAUQOHo4EAf0SOgJVcF6MAAAAASUVORK5CYII=';

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0xDA,
  0x63,
  0x64,
  0xF8,
  0xCF,
  0x50,
  0x0F,
  0x00,
  0x03,
  0x86,
  0x01,
  0x80,
  0x5A,
  0x34,
  0x7D,
  0x6B,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

const _openViewerKey = ValueKey('open-image-viewer');
const _mobileSize = Size(390, 844);
const _desktopSize = Size(1024, 720);

void _setTestViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _viewerApp({
  required List<String> images,
  int initialIndex = 0,
  Map<String, ImageProvider> imageProviders = const <String, ImageProvider>{},
  Size size = const Size(390, 844),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ImageViewerPage(
        images: images,
        initialIndex: initialIndex,
        imageProviders: imageProviders,
      ),
    ),
  );
}

Widget _viewerRouteApp({
  required List<String> images,
  int initialIndex = 0,
  Map<String, ImageProvider> imageProviders = const <String, ImageProvider>{},
  Size size = _mobileSize,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: GestureDetector(
              key: _openViewerKey,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImageViewerPage(
                      images: images,
                      initialIndex: initialIndex,
                      imageProviders: imageProviders,
                    ),
                  ),
                );
              },
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _pumpViewerRoute(
  WidgetTester tester, {
  required List<String> images,
  int initialIndex = 0,
  Map<String, ImageProvider> imageProviders = const <String, ImageProvider>{},
  Size size = _mobileSize,
}) async {
  await tester.pumpWidget(
    _viewerRouteApp(
      images: images,
      initialIndex: initialIndex,
      imageProviders: imageProviders,
      size: size,
    ),
  );
  await tester.tap(find.byKey(_openViewerKey));
  await tester.pumpAndSettle();
}

Finder _displayTransformFinder(int index) {
  return find.byKey(ValueKey('image-viewer-display-transform-$index'));
}

void main() {
  testWidgets('ImageViewerPage uses a preloaded provider for the first frame', (
    tester,
  ) async {
    final provider = MemoryImage(Uint8List.fromList(_transparentPngBytes));

    await tester.pumpWidget(
      _viewerApp(
        images: const [_transparentPngDataUrl],
        imageProviders: {_transparentPngDataUrl: provider},
      ),
    );
    await tester.pump();

    expect(
      identical(tester.widget<Image>(find.byType(Image)).image, provider),
      isTrue,
    );
  });

  testWidgets(
    'ImageViewerPage keeps data image provider stable after rebuild',
    (tester) async {
      await tester.pumpWidget(
        _viewerApp(images: const [_transparentPngDataUrl]),
      );
      await tester.pump();

      final firstProvider = tester.widget<Image>(find.byType(Image)).image;

      await tester.drag(find.byType(Image), const Offset(0, 24));
      await tester.pump();

      final secondProvider = tester.widget<Image>(find.byType(Image)).image;
      final stableProvider = identical(secondProvider, firstProvider);

      await tester.pump(const Duration(milliseconds: 50));

      expect(stableProvider, isTrue);
    },
  );

  testWidgets('ImageViewerPage compact tap closes preview', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _setTestViewSize(tester, _mobileSize);
    try {
      await _pumpViewerRoute(tester, images: const [_transparentPngDataUrl]);

      expect(find.byTooltip('Close preview'), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('image-viewer-page-view'))),
      );
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerPage), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ImageViewerPage compact image uses the full viewport width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _setTestViewSize(tester, _mobileSize);
    try {
      await tester.pumpWidget(
        _viewerApp(images: const [_transparentPngDataUrl], size: _mobileSize),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(Image)).width,
        moreOrLessEquals(_mobileSize.width, epsilon: 0.1),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ImageViewerPage hero frame matches the displayed image bounds', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _setTestViewSize(tester, _mobileSize);
    try {
      await tester.pumpWidget(
        _viewerApp(images: const [_widePngDataUrl], size: _mobileSize),
      );
      await tester.pumpAndSettle();

      final heroSize = tester.getSize(find.byType(Hero));

      expect(heroSize.width, moreOrLessEquals(_mobileSize.width, epsilon: 0.1));
      expect(
        heroSize.height,
        moreOrLessEquals(_mobileSize.width / 2, epsilon: 0.1),
      );
      expect(heroSize.height, lessThan(_mobileSize.height / 3));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ImageViewerPage compact zoom keeps pan inside the viewer', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _setTestViewSize(tester, _mobileSize);
    try {
      const secondImage =
          'data:image/png;base64,'
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mP8z8Dwn4GB'
          'gYGBgAEABP8CBAEwQ2EAAAAASUVORK5CYII=';

      await tester.pumpWidget(
        _viewerApp(
          images: const [_transparentPngDataUrl, secondImage],
          size: _mobileSize,
        ),
      );
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);

      final pageCenter = tester.getCenter(
        find.byKey(const ValueKey('image-viewer-page-view')),
      );
      final firstFinger = await tester.createGesture(
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      final secondFinger = await tester.createGesture(
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      await firstFinger.down(pageCenter + const Offset(-24, 0));
      await secondFinger.down(pageCenter + const Offset(24, 0));
      await tester.pump();
      await firstFinger.moveTo(pageCenter + const Offset(-96, 0));
      await secondFinger.moveTo(pageCenter + const Offset(96, 0));
      await tester.pump();
      await firstFinger.up();
      await secondFinger.up();
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('image-viewer-page-view')),
      );
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer).first,
      );

      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
      expect(viewer.boundaryMargin, EdgeInsets.zero);
      expect(viewer.clipBehavior, Clip.hardEdge);

      await tester.drag(
        find.byKey(const ValueKey('image-viewer-page-view')),
        const Offset(-280, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'ImageViewerPage compact double tap zooms without closing preview',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _setTestViewSize(tester, _mobileSize);
      try {
        const secondImage =
            'data:image/png;base64,'
            'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mP8z8Dwn4GB'
            'gYGBgAEABP8CBAEwQ2EAAAAASUVORK5CYII=';

        await tester.pumpWidget(
          _viewerApp(
            images: const [_transparentPngDataUrl, secondImage],
            size: _mobileSize,
          ),
        );
        await tester.pump();

        final pageCenter = tester.getCenter(
          find.byKey(const ValueKey('image-viewer-page-view')),
        );
        await tester.tapAt(pageCenter);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(pageCenter);
        await tester.pumpAndSettle();

        expect(find.byType(ImageViewerPage), findsOneWidget);
        final pageView = tester.widget<PageView>(
          find.byKey(const ValueKey('image-viewer-page-view')),
        );
        expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
        expect(find.text('1/2'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('ImageViewerPage compact transform actions update the image', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _setTestViewSize(tester, _mobileSize);
    try {
      await tester.pumpWidget(
        _viewerApp(images: const [_transparentPngDataUrl], size: _mobileSize),
      );
      await tester.pump();

      expect(find.byTooltip('Flip Horizontal'), findsOneWidget);
      expect(find.byTooltip('Flip Vertical'), findsOneWidget);
      expect(find.byTooltip('Rotate Left'), findsOneWidget);
      expect(find.byTooltip('Rotate Right'), findsOneWidget);

      final initial = tester.widget<Transform>(_displayTransformFinder(0));
      expect(initial.transform.storage[0], moreOrLessEquals(1));

      await tester.tap(find.byTooltip('Flip Horizontal'));
      await tester.pumpAndSettle();

      final flipped = tester.widget<Transform>(_displayTransformFinder(0));
      expect(flipped.transform.storage[0], moreOrLessEquals(-1));

      await tester.tap(find.byTooltip('Rotate Right'));
      await tester.pumpAndSettle();

      final rotated = tester.widget<Transform>(_displayTransformFinder(0));
      expect(rotated.transform.storage[0].abs(), lessThan(0.001));
      expect(rotated.transform.storage[1].abs(), moreOrLessEquals(1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ImageViewerPage desktop background tap closes preview', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _setTestViewSize(tester, _desktopSize);
    try {
      await _pumpViewerRoute(
        tester,
        images: const [_transparentPngDataUrl],
        size: _desktopSize,
      );

      await tester.tapAt(const Offset(110, 120));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerPage), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ImageViewerPage desktop image tap keeps preview open', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _setTestViewSize(tester, _desktopSize);
    try {
      await _pumpViewerRoute(
        tester,
        images: const [_transparentPngDataUrl],
        size: _desktopSize,
      );

      await tester.tapAt(_desktopSize.center(Offset.zero));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerPage), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ImageViewerPage rotate actions animate by the shortest turn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _viewerApp(images: const [_transparentPngDataUrl], size: _desktopSize),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Rotate Left'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate Left'));
    await tester.pumpAndSettle();

    final afterTwoLeft = tester.widget<Transform>(_displayTransformFinder(0));
    expect(afterTwoLeft.transform.storage[0], moreOrLessEquals(-1));
    expect(afterTwoLeft.transform.storage[5], moreOrLessEquals(-1));

    await tester.tap(find.byTooltip('Rotate Right'));
    await tester.pumpAndSettle();

    final afterOneRight = tester.widget<Transform>(_displayTransformFinder(0));
    expect(afterOneRight.transform.storage[0].abs(), lessThan(0.001));
    expect(afterOneRight.transform.storage[1], moreOrLessEquals(-1));

    await tester.tap(find.byTooltip('Rotate Right'));
    await tester.pump();
    final beforeMidTurn = tester.widget<Transform>(_displayTransformFinder(0));
    expect(beforeMidTurn.transform.storage[0].abs(), lessThan(0.001));
    await tester.pump(const Duration(milliseconds: 40));

    final midTurn = tester.widget<Transform>(_displayTransformFinder(0));
    final cosine = midTurn.transform.storage[0];
    expect(cosine, inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate Right'));
    await tester.pumpAndSettle();

    final afterThreeRight = tester.widget<Transform>(
      _displayTransformFinder(0),
    );
    expect(afterThreeRight.transform.storage[0].abs(), lessThan(0.001));
    expect(afterThreeRight.transform.storage[1], moreOrLessEquals(1));
  });

  testWidgets(
    'ImageViewerPage wide layout exposes navigation and zoom actions',
    (tester) async {
      const secondImage =
          'data:image/png;base64,'
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mP8z8Dwn4GB'
          'gYGBgAEABP8CBAEwQ2EAAAAASUVORK5CYII=';

      await tester.pumpWidget(
        _viewerApp(
          images: const [_transparentPngDataUrl, secondImage],
          size: _desktopSize,
        ),
      );
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);
      expect(find.byTooltip('Previous Image'), findsOneWidget);
      expect(find.byTooltip('Next Image'), findsOneWidget);
      expect(find.byTooltip('Zoom In'), findsOneWidget);
      expect(find.byTooltip('Zoom Out'), findsOneWidget);
      expect(find.byTooltip('Reset Zoom'), findsOneWidget);
      expect(find.byTooltip('Flip Horizontal'), findsOneWidget);
      expect(find.byTooltip('Flip Vertical'), findsOneWidget);
      expect(find.byTooltip('Rotate Left'), findsOneWidget);
      expect(find.byTooltip('Rotate Right'), findsOneWidget);
    },
  );

  testWidgets('ImageViewerPage arrow keys move between images', (tester) async {
    const secondImage =
        'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mP8z8Dwn4GB'
        'gYGBgAEABP8CBAEwQ2EAAAAASUVORK5CYII=';

    await tester.pumpWidget(
      _viewerApp(
        images: const [_transparentPngDataUrl, secondImage],
        size: _desktopSize,
      ),
    );
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
  });
}
