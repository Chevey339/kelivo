import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
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

    final displayed = tester.widget<Image>(find.byType(Image)).image;
    expect(displayed, isA<SafeResizeImage>());
    expect(
      identical((displayed as SafeResizeImage).imageProvider, provider),
      isTrue,
    );
    expect(displayed.width, isNotNull);
    expect(displayed.height, isNotNull);
    expect(
      displayed.width * displayed.height,
      lessThanOrEqualTo(kMaxViewerDecodePixels),
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

  testWidgets('ImageViewerPage wraps network images with bounded ResizeImage', (
    tester,
  ) async {
    const url = 'https://example.com/huge.png';
    await tester.pumpWidget(_viewerApp(images: const [url]));
    await tester.pump();

    final displayed = tester.widget<Image>(find.byType(Image)).image;
    expect(displayed, isA<SafeResizeImage>());
    final resized = displayed as SafeResizeImage;
    expect(resized.imageProvider, isA<NetworkImage>());
    expect((resized.imageProvider as NetworkImage).url, url);
    expect(resized.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(resized.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(
      resized.width * resized.height,
      lessThanOrEqualTo(kMaxViewerDecodePixels),
    );
  });

  testWidgets('ImageViewerPage viewport change recalculates decode size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(_mobileSize.width * 2, _mobileSize.height * 2);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _viewerApp(images: const [_transparentPngDataUrl], size: _mobileSize),
    );
    await tester.pump();

    final first = tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;

    tester.view.physicalSize = Size(
      _desktopSize.width * 2,
      _desktopSize.height * 2,
    );
    await tester.pumpWidget(
      _viewerApp(images: const [_transparentPngDataUrl], size: _desktopSize),
    );
    await tester.pump();

    final second = tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
    expect(second.width != first.width || second.height != first.height, isTrue);
    expect(second.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(second.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(
      second.width * second.height,
      lessThanOrEqualTo(kMaxViewerDecodePixels),
    );
  });

  testWidgets(
    'ImageViewerPage save and share still target the original source',
    (tester) async {
      const url = 'https://example.com/original.png';
      await tester.pumpWidget(_viewerApp(images: const [url]));
      await tester.pump();

      final page = tester.widget<ImageViewerPage>(find.byType(ImageViewerPage));
      expect(page.images.single, url);

      final displayed = tester.widget<Image>(find.byType(Image)).image;
      expect(displayed, isA<SafeResizeImage>());
      expect(
        ((displayed as SafeResizeImage).imageProvider as NetworkImage).url,
        url,
      );
    },
  );

  test('viewer decode clamps a 17k original under 48 MiB', () {
    const originalWidth = 17277;
    const originalHeight = 11457;
    expect(originalWidth * originalHeight * 4, greaterThan(700 << 20));

    final decode = computeViewerDecodePixels(
      logicalWidth: originalWidth.toDouble(),
      logicalHeight: originalHeight.toDouble(),
      devicePixelRatio: 1,
    );
    expect(decode.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(decode.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(decode.width * decode.height, lessThanOrEqualTo(kMaxViewerDecodePixels));
    expect(decode.width * decode.height * 4, lessThanOrEqualTo(48 << 20));
  });

  test('copy of extension-less 17k PNG keeps original bytes', () async {
    debugClipboardImageCodecCalls = 0;
    addTearDown(() => debugClipboardImageCodecCalls = 0);

    final bytes = _pngWithIhdrSize(17277, 11457);
    expect(detectClipboardImageFormat(bytes: bytes), 'png');

    final prepared = await prepareClipboardImageBytes(bytes: bytes);
    expect(prepared, isNotNull);
    expect(prepared!.format, 'png');
    expect(prepared.converted, isFalse);
    expect(prepared.bytes, bytes);
    expect(debugClipboardImageCodecCalls, 0);
  });

  test('clipboard PNG requires the full 8-byte signature', () {
    expect(
      detectClipboardImageFormat(bytes: const [0x89, 0x50, 0x4E, 0x47]),
      isEmpty,
    );
    expect(
      detectClipboardImageFormat(bytes: _transparentPngBytes),
      'png',
    );
  });

  test('clipboard GIF and WebP require full signatures', () {
    expect(
      detectClipboardImageFormat(
        bytes: const [0x47, 0x49, 0x46, 0x38, 0x39],
      ),
      isEmpty,
    );
    expect(
      detectClipboardImageFormat(bytes: 'GIF89a'.codeUnits),
      'gif',
    );
    expect(
      detectClipboardImageFormat(
        bytes: [
          0x52, 0x49, 0x46, 0x46,
          0, 0, 0, 0,
          0x57, 0x45, 0x42, 0x50,
        ],
      ),
      'webp',
    );
    expect(
      detectClipboardImageFormat(
        bytes: [
          0x52, 0x49, 0x46, 0x46,
          0, 0, 0, 0,
          0x57, 0x45, 0x42, 0x00,
        ],
      ),
      isEmpty,
    );
  });

  test('clipboard format uses magic only, not Content-Type or extension', () {
    final png = Uint8List.fromList(_transparentPngBytes);
    expect(detectClipboardImageFormat(bytes: png), 'png');
    expect(inferClipboardImageFormatHint('image/png'), 'png');
    expect(inferClipboardImageFormatHint('image/apng'), isEmpty);
    expect(inferClipboardImageFormatHint('not-a-png'), isEmpty);
    expect(inferClipboardImageFormatHint('photo.jpg.png'), 'png');
    expect(
      detectClipboardImageFormat(bytes: const [0x00, 0x01, 0x02]),
      isEmpty,
    );
    expect(
      detectClipboardImageFormat(bytes: _bmpRgb(2, 2)),
      isEmpty,
    );
  });

  test('BMP named like PNG is transcoded with both decode axes capped', () async {
    debugClipboardImageCodecCalls = 0;
    debugLastClipboardDecodeTarget = null;
    addTearDown(() {
      debugClipboardImageCodecCalls = 0;
      debugLastClipboardDecodeTarget = null;
    });

    final tall = _bmpRgb(40, 800);
    final prepared = await prepareClipboardImageBytes(bytes: tall);
    expect(prepared, isNotNull);
    expect(prepared!.converted, isTrue);
    expect(prepared.format, 'png');
    expect(detectClipboardImageFormat(bytes: tall), isEmpty);
    expect(detectClipboardImageFormat(bytes: prepared.bytes), 'png');
    expect(debugClipboardImageCodecCalls, 1);
    final target = debugLastClipboardDecodeTarget!;
    expect(target.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(target.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(target.width * target.height, lessThanOrEqualTo(kMaxViewerDecodePixels));
    expect(
      resolveClipboardFallbackSourcePath(
        sourcePath: '/tmp/photo.png',
        converted: prepared.converted,
      ),
      isNull,
    );
  });

  test('unknown-format copy budgets a very tall image and a large square', () {
    final tall = computeViewerDecodePixels(
      logicalWidth: 1000,
      logicalHeight: 20000,
      devicePixelRatio: 1,
    );
    expect(tall.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(tall.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(tall.width * tall.height, lessThanOrEqualTo(kMaxViewerDecodePixels));
    expect(tall.height, lessThan(20000));
    expect(tall.width, lessThanOrEqualTo(tall.height));

    final square = computeViewerDecodePixels(
      logicalWidth: 8000,
      logicalHeight: 8000,
      devicePixelRatio: 1,
    );
    expect(square.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(square.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(
      square.width * square.height,
      lessThanOrEqualTo(kMaxViewerDecodePixels),
    );
    expect(square.width * square.height, lessThan(4096 * 4096));
  });

  test('converted clipboard payload drops the original sourcePath', () {
    expect(
      resolveClipboardFallbackSourcePath(
        sourcePath: '/tmp/original.bmp',
        converted: true,
      ),
      isNull,
    );
    expect(
      resolveClipboardFallbackSourcePath(
        sourcePath: '/tmp/original.png',
        converted: false,
      ),
      '/tmp/original.png',
    );
  });

  test('quantizeViewerDecodePixels keeps 2050 square off the 4096 jump', () {
    final q = quantizeViewerDecodePixels(width: 2050, height: 2050);
    expect(q.width, lessThan(3500));
    expect(q.height, lessThan(3500));
    expect(q.width * q.height * 4, lessThan(30 << 20));
    expect(q.width * q.height, lessThanOrEqualTo(kMaxViewerDecodePixels));
  });

  test('canReuseViewerDisplayPixels upgrades landscape to portrait', () {
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 2048,
        cachedHeight: 1024,
        targetWidth: 1024,
        targetHeight: 2048,
      ),
      isFalse,
    );
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 1024,
        cachedHeight: 2048,
        targetWidth: 2048,
        targetHeight: 1024,
      ),
      isFalse,
    );
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 2048,
        cachedHeight: 1024,
        targetWidth: 1800,
        targetHeight: 900,
      ),
      isTrue,
    );
  });

  testWidgets(
    'browsing many images does not keep size listeners or decoded images live',
    (tester) async {
      final counts = _LiveImageCounts();
      final images = List<String>.generate(
        9,
        (index) => 'memory://live-$index',
      );
      final providers = <String, ImageProvider>{
        for (var i = 0; i < images.length; i++)
          images[i]: _CountingImageProvider(i, counts),
      };

      await tester.pumpWidget(
        _viewerApp(images: images, imageProviders: providers, size: _desktopSize),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      for (var i = 0; i < images.length - 1; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.pumpAndSettle();
      }

      final state = tester.state<State<ImageViewerPage>>(
        find.byType(ImageViewerPage),
      );
      expect(imageViewerDebugSizeListenerCount(state), 0);
      expect(counts.liveImageCount, lessThanOrEqualTo(3));
    },
  );

  testWidgets(
    'continuous desktop resize does not reload the image dozens of times',
    (tester) async {
      final counts = _LiveImageCounts();
      const url = 'https://cdn.example.com/no-ext';
      final provider = _CountingImageProvider(1, counts);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageViewerPage(
            images: const [url],
            imageProviders: {url: provider},
          ),
        ),
      );
      await tester.pump();
      final sizes = <String>{};

      for (var width = 801; width <= 860; width++) {
        tester.view.physicalSize = Size(width.toDouble(), 600);
        await tester.pump();
        final displayed = tester.widget<Image>(find.byType(Image)).image;
        if (displayed is SafeResizeImage) {
          sizes.add('${displayed.width}x${displayed.height}');
        }
      }

      expect(sizes.length, lessThan(3), reason: 'sizes=$sizes');
      expect(counts.loads, greaterThan(0));
    },
  );

  test('quantizeViewerDecodePixels stays on one bucket across a 60px drag', () {
    final sizes = <String>{};
    for (var width = 800; width <= 860; width++) {
      final exact = computeViewerDecodePixels(
        logicalWidth: width - 184,
        logicalHeight: 600 - 188,
        devicePixelRatio: 1,
      );
      final q = quantizeViewerDecodePixels(
        width: exact.width,
        height: exact.height,
      );
      sizes.add('${q.width}x${q.height}');
    }
    expect(sizes.length, 1);
  });

  test('unknown-format square BMP also sets both codec targets', () async {
    debugLastClipboardDecodeTarget = null;
    addTearDown(() => debugLastClipboardDecodeTarget = null);

    final prepared = await prepareClipboardImageBytes(bytes: _bmpRgb(256, 256));
    expect(prepared, isNotNull);
    expect(prepared!.converted, isTrue);
    final target = debugLastClipboardDecodeTarget!;
    expect(target.width, isNonZero);
    expect(target.height, isNonZero);
    expect(target.width, lessThanOrEqualTo(kMaxViewerDecodeEdge));
    expect(target.height, lessThanOrEqualTo(kMaxViewerDecodeEdge));
  });

  test('canReuseViewerDisplayPixels waits for +20% on exact pixels', () {
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 512,
        cachedHeight: 512,
        targetWidth: 513,
        targetHeight: 513,
      ),
      isTrue,
    );
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 1024,
        cachedHeight: 1024,
        targetWidth: 1025,
        targetHeight: 1025,
      ),
      isTrue,
    );
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 1000,
        cachedHeight: 800,
        targetWidth: 1200,
        targetHeight: 960,
      ),
      isTrue,
    );
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 1000,
        cachedHeight: 800,
        targetWidth: 1201,
        targetHeight: 961,
      ),
      isFalse,
    );
  });

  test('quantize happens only after an exact-size upgrade decision', () {
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 512,
        cachedHeight: 512,
        targetWidth: 513,
        targetHeight: 513,
      ),
      isTrue,
    );
    final upgraded = quantizeViewerDecodePixels(width: 1025, height: 1025);
    expect(upgraded.width, greaterThanOrEqualTo(1024));
    expect(
      canReuseViewerDisplayPixels(
        cachedWidth: 1024,
        cachedHeight: 1024,
        targetWidth: 1025,
        targetHeight: 1025,
      ),
      isTrue,
    );
  });

  testWidgets(
    'rotate swaps decode axes and restores them after a full turn',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          _viewerApp(
            images: const [_widePngDataUrl],
            size: const Size(1024, 720),
          ),
        );
        await tester.pumpAndSettle();

        final initial =
            tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
        expect(initial.width, greaterThan(initial.height));

        await tester.tap(find.byTooltip('Rotate Right'));
        await tester.pumpAndSettle();
        final right =
            tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
        expect(right.height, greaterThan(right.width));

        await tester.tap(find.byTooltip('Rotate Left'));
        await tester.pumpAndSettle();
        final leftBack =
            tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
        expect(leftBack.width, initial.width);
        expect(leftBack.height, initial.height);

        await tester.tap(find.byTooltip('Rotate Left'));
        await tester.pumpAndSettle();
        final left =
            tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
        expect(left.height, greaterThan(left.width));

        await tester.tap(find.byTooltip('Rotate Right'));
        await tester.pumpAndSettle();
        final restored =
            tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
        expect(restored.width, initial.width);
        expect(restored.height, initial.height);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'ImageViewerPage does not reuse a landscape decode after a portrait rotate',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _viewerApp(images: const [_widePngDataUrl], size: const Size(800, 400)),
      );
      await tester.pumpAndSettle();

      final landscape =
          tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
      expect(landscape.width, greaterThan(landscape.height));

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        _viewerApp(images: const [_widePngDataUrl], size: const Size(400, 800)),
      );
      await tester.pumpAndSettle();

      final portrait =
          tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
      expect(
        canReuseViewerDisplayPixels(
          cachedWidth: landscape.width,
          cachedHeight: landscape.height,
          targetWidth: portrait.width,
          targetHeight: portrait.height,
        ),
        isFalse,
      );
      expect(identical(portrait, landscape), isFalse);
      expect(portrait.height, greaterThan(portrait.width));
    },
  );
}

Uint8List _bmpRgb(int width, int height) {
  final rowStride = ((width * 3 + 3) ~/ 4) * 4;
  final pixelBytes = rowStride * height;
  final fileSize = 54 + pixelBytes;
  final out = ByteData(fileSize);
  out.setUint8(0, 0x42);
  out.setUint8(1, 0x4D);
  out.setUint32(2, fileSize, Endian.little);
  out.setUint32(10, 54, Endian.little);
  out.setUint32(14, 40, Endian.little);
  out.setInt32(18, width, Endian.little);
  out.setInt32(22, height, Endian.little);
  out.setUint16(26, 1, Endian.little);
  out.setUint16(28, 24, Endian.little);
  out.setUint32(34, pixelBytes, Endian.little);
  final bytes = out.buffer.asUint8List();
  for (var y = 0; y < height; y++) {
    final row = 54 + y * rowStride;
    for (var x = 0; x < width; x++) {
      bytes[row + x * 3] = 0xC8;
      bytes[row + x * 3 + 1] = 0x40;
      bytes[row + x * 3 + 2] = 0x20;
    }
  }
  return bytes;
}

Uint8List _pngWithIhdrSize(int width, int height) {
  final bytes = Uint8List.fromList(_transparentPngBytes);
  ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes;
}

class _LiveImageCounts {
  int loads = 0;
  int liveImageCount = 0;
}

class _CountingImageProvider extends ImageProvider<_CountingImageProvider> {
  _CountingImageProvider(this.id, this.counts);

  final int id;
  final _LiveImageCounts counts;

  @override
  Future<_CountingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CountingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CountingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    counts.loads += 1;
    counts.liveImageCount += 1;
    final completer = MemoryImage(
      Uint8List.fromList(_transparentPngBytes),
      scale: 1.0 + id,
    ).loadImage(
      MemoryImage(Uint8List.fromList(_transparentPngBytes), scale: 1.0 + id),
      decode,
    );
    completer.addOnLastListenerRemovedCallback(() {
      counts.liveImageCount -= 1;
    });
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is _CountingImageProvider && other.id == id;

  @override
  int get hashCode => id;
}
