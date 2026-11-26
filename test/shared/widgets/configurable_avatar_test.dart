import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/models/avatar_config.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/shared/widgets/avatar_image.dart';
import 'package:Kelivo/shared/widgets/configurable_avatar.dart';
import 'package:Kelivo/utils/avatar_cache.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:Kelivo/utils/icon_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<void> _finishLoad(WidgetTester tester) async {
  var finished = false;
  final loader = tester.widget<FutureBuilder<String?>>(
    find.byType(FutureBuilder<String?>),
  );
  loader.future!.then((_) => finished = true);
  // Allow real file I/O to complete between fake widget frames.
  for (var i = 0; i < 100 && !finished; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(finished, isTrue);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform paths;
  const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path fill="currentColor" d="M0 0h24v24H0z"/></svg>';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('avatar-widget-');
    paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    AvatarCache.clearMemory();
    IconCache.clearMemory();
  });
  tearDown(() async {
    AvatarCache.clearMemory();
    IconCache.clearMemory();
    PathProviderPlatform.instance = paths;
    await directory.delete(recursive: true);
  });

  Widget host(AvatarConfig avatar, {bool dark = false}) => MaterialApp(
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
      body: ConfigurableAvatar(avatar: avatar, name: 'Unknown'),
    ),
  );

  testWidgets(
    'raster photos decode at the avatar size and preserve their aspect ratio',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final file = File('${directory.path}/avatar.png');
      await tester.runAsync(
        () => file.writeAsBytes(
          img.encodePng(img.Image(width: 600, height: 400)),
        ),
      );
      await tester.pumpWidget(
        host(AvatarConfig(type: AvatarType.file, value: file.path)),
      );
      final raw = find.byType(RawImage);
      for (
        var i = 0;
        i < 100 && tester.widget<RawImage>(raw).image == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      final image = tester.widget<RawImage>(raw).image!;
      expect((image.width, image.height), (84, 56));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(AvatarConfig(type: AvatarType.file, value: file.path)),
      );
      expect(tester.widget<RawImage>(raw).image?.width, 84);
    },
  );

  testWidgets(
    'different avatar sizes share the native frame of an extensionless GIF',
    (tester) async {
      final file = File('${directory.path}/animated-photo');
      final frames = img.Image(width: 320, height: 200)..frameDuration = 100;
      frames.addFrame(img.Image(width: 320, height: 200)..frameDuration = 100);
      file.writeAsBytesSync(img.encodeGif(frames));
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              AvatarImage(
                source: file.path,
                size: 36,
                fallback: const SizedBox(),
              ),
              ConfigurableAvatar(
                name: 'Unknown',
                avatar: AvatarConfig(type: AvatarType.file, value: file.path),
                size: 84,
              ),
            ],
          ),
        ),
      );
      List<ui.Image> paintedFrames() => [
        for (final raw in tester.widgetList<RawImage>(find.byType(RawImage)))
          if (raw.image case final image?) image,
      ];
      for (var i = 0; i < 100 && paintedFrames().length < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      final painted = paintedFrames();
      expect(painted, hasLength(2));
      expect((painted.first.width, painted.first.height), (320, 200));
      expect(painted.first.isCloneOf(painted.last), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final normalize in [false, true]) {
    testWidgets(
      'mounted remote photo refreshes after cache removal (normalize=$normalize)',
      (tester) async {
        const url = 'https://avatar.test/refresh.png';
        final replacement = Completer<http.Response>();
        var requests = 0;
        http.Response photo(int width) => http.Response.bytes(
          img.encodePng(img.Image(width: width, height: width)),
          200,
        );
        final animated = img.Image(width: 320, height: 200)
          ..frameDuration = 100;
        animated.addFrame(
          img.Image(width: 320, height: 200)..frameDuration = 100,
        );
        final first = normalize
            ? photo(3)
            : http.Response.bytes(img.encodeGif(animated), 200);
        Future<void> expectFrame(int width) async {
          for (var i = 0; i < 100; i++) {
            await tester.pump();
            if (tester
                .widgetList<RawImage>(find.byType(RawImage))
                .any((raw) => raw.image?.width == width)) {
              return;
            }
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
          }
          fail('The refreshed avatar did not display its $width-pixel frame');
        }

        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: ConfigurableAvatar(
                  avatar: const AvatarConfig(type: AvatarType.url, value: url),
                  name: 'Unknown',
                  normalizeRemoteIcons: normalize,
                ),
              ),
            );
            await expectFrame(normalize ? 3 : 320);
            final provider = tester.widget<Image>(find.byType(Image)).image;
            final oldKey = await provider.obtainKey(ImageConfiguration.empty);
            await tester.runAsync(
              () => normalize
                  ? StorageUsageService.clearCache(avatarsOnly: true)
                  : AvatarCache.evict(url),
            );
            await tester.pump();
            expect(find.text('U'), findsOneWidget);
            expect(tester.takeException(), isNull);
            replacement.complete(photo(7));
            await expectFrame(7);
            expect(requests, 2);
            expect(
              PaintingBinding.instance.imageCache.statusForKey(oldKey).tracked,
              isFalse,
            );
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient(
            (_) async => ++requests == 1 ? first : replacement.future,
          ),
        );
      },
    );
  }

  testWidgets('normalizes extensionless remote SVGs for search icons', (
    tester,
  ) async {
    const url = 'https://avatar.test/extensionless-icon';
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ConfigurableAvatar(
              avatar: AvatarConfig(type: AvatarType.url, value: url),
              name: 'Unknown',
              normalizeRemoteIcons: true,
            ),
          ),
        );
        await _finishLoad(tester);
        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          (picture.bytesLoader as SvgFileLoader).file.path,
          endsWith('.svg'),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        expect(request.url.toString(), url);
        return http.Response(svg, 200);
      }),
    );
  });

  testWidgets(
    'cached color and monochrome SVGs switch without showing the old variant',
    (tester) async {
      late String colorPath;
      late String monoPath;
      await tester.runAsync(
        () => http.runWithClient(() async {
          colorPath = (await AvatarCache.getPath(
            BrandAssets.lobehubIconUrl('nvidia-color'),
          ))!;
          monoPath = (await AvatarCache.getPath(
            BrandAssets.lobehubIconUrl('nvidia'),
          ))!;
        }, () => MockClient((_) async => http.Response(svg, 200))),
      );

      await tester.pumpWidget(
        host(const AvatarConfig(type: AvatarType.lobehub, value: 'nvidia')),
      );
      SvgPicture picture() =>
          tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect((picture().bytesLoader as SvgFileLoader).file.path, colorPath);
      expect(picture().colorFilter, isNull);
      await tester.pumpWidget(
        host(
          const AvatarConfig(
            type: AvatarType.lobehub,
            value: 'nvidia-color',
            monochrome: true,
          ),
          dark: true,
        ),
      );
      expect((picture().bytesLoader as SvgFileLoader).file.path, monoPath);
      await tester.pumpAndSettle();
      final foreground = Theme.of(
        tester.element(find.byType(ConfigurableAvatar)),
      ).colorScheme.onSurface;
      expect(
        picture().colorFilter,
        ColorFilter.mode(foreground, BlendMode.srcIn),
      );
      expect(
        (picture().bytesLoader as SvgFileLoader).theme?.currentColor,
        foreground,
      );
      await tester.pumpWidget(
        host(const AvatarConfig(type: AvatarType.lobehub, value: 'nvidia')),
      );
      expect((picture().bytesLoader as SvgFileLoader).file.path, colorPath);
      expect(picture().colorFilter, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a brand with no color SVG can use its monochrome asset in color mode',
    (tester) async {
      final colorUrl = BrandAssets.lobehubIconUrl('brand-color');
      final monoUrl = BrandAssets.lobehubIconUrl('brand');
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            host(const AvatarConfig(type: AvatarType.lobehub, value: 'brand')),
          );
          await _finishLoad(tester);
          expect(AvatarCache.peek(colorUrl), isNull);
          final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(
            (picture.bytesLoader as SvgFileLoader).file.path,
            AvatarCache.peek(monoUrl),
          );
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (request) async => request.url.toString() == colorUrl
              ? http.Response('', 404)
              : http.Response(svg, 200),
        ),
      );
    },
  );

  testWidgets(
    'switching from cached monochrome fetches the uncached color variant',
    (tester) async {
      final colorUrl = BrandAssets.lobehubIconUrl('nvidia-color');
      final monoUrl = BrandAssets.lobehubIconUrl('nvidia');
      final requests = <String>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            host(
              const AvatarConfig(
                type: AvatarType.lobehub,
                value: 'nvidia',
                monochrome: true,
              ),
            ),
          );
          await _finishLoad(tester);
          expect(requests, [monoUrl]);
          expect(AvatarCache.peek(colorUrl), isNull);
          await tester.pumpWidget(
            host(const AvatarConfig(type: AvatarType.lobehub, value: 'nvidia')),
          );
          await _finishLoad(tester);
          expect(requests, [monoUrl, colorUrl]);
          final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(
            (picture.bytesLoader as SvgFileLoader).file.path,
            AvatarCache.peek(colorUrl),
          );
          expect(picture.colorFilter, isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          requests.add(request.url.toString());
          return http.Response(svg, 200);
        }),
      );
    },
  );

  testWidgets('failed URL icons retry on reopening but not ordinary rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AvatarConfig(
          type: AvatarType.file,
          value: '${directory.path}/missing.png',
        ),
      ),
    );
    expect(find.text('U'), findsOneWidget);
    var requests = 0;
    var online = false;
    const avatar = AvatarConfig(
      type: AvatarType.url,
      value: 'https://avatar.test/recover.svg',
    );

    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(avatar));
        await _finishLoad(tester);
        expect(find.text('U'), findsOneWidget);
        expect(requests, 1);
        await tester.pumpWidget(host(avatar, dark: true));
        await tester.pumpAndSettle();
        expect(requests, 1);
        await tester.pumpWidget(const SizedBox());
        online = true;
        await tester.pumpWidget(host(avatar));
        await _finishLoad(tester);
        expect(requests, 2);
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('U'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((_) async {
        requests++;
        return http.Response(online ? svg : '', online ? 200 : 503);
      }),
    );
  });
}
