import 'dart:io';

import 'package:Kelivo/core/models/avatar_config.dart';
import 'package:Kelivo/shared/widgets/configurable_avatar.dart';
import 'package:Kelivo/utils/avatar_cache.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  });
  tearDown(() async {
    AvatarCache.clearMemory();
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
