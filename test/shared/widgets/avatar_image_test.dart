import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/shared/widgets/avatar_image.dart';
import 'package:Kelivo/utils/avatar_cache.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  int calls = 0;
  @override
  Future<String?> getApplicationDocumentsPath() async {
    calls++;
    return path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    calls++;
    return path;
  }
}

void main() {
  testWidgets(
    'rebuilds reuse a lookup; source changes and eviction reload the image',
    (tester) async {
      final originalPaths = PathProviderPlatform.instance;
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('avatar_widget_'),
      );
      final paths = _Paths(root!.path);
      PathProviderPlatform.instance = paths;
      AvatarCache.clearMemory();
      addTearDown(() async {
        PathProviderPlatform.instance = originalPaths;
        AvatarCache.clearMemory();
        await root.delete(recursive: true);
      });
      var size = 2;
      var requests = 0;
      Uint8List bytes() => Uint8List.fromList(
        image.encodePng(image.Image(width: size, height: size)),
      );
      Widget host(String url) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Center(
            child: AvatarImage(
              source: url,
              isNetwork: true,
              size: 32,
              fallback: const Text('placeholder'),
            ),
          ),
        ),
      );
      Future<void> ready(int expectedWidth) async {
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          final images = tester.widgetList<RawImage>(find.byType(RawImage));
          if (images.any((image) => image.image?.width == expectedWidth)) {
            return;
          }
        }
        fail('Avatar did not finish loading width $expectedWidth');
      }

      await http.runWithClient(
        () async {
          const first = 'https://avatar.test/first.png';
          await tester.pumpWidget(host(first));
          await ready(2);
          expect(requests, 1);
          final provider =
              tester.widget<Image>(find.byType(Image)).image as SafeResizeImage;
          expect(
            (provider.width, provider.height, provider.fit),
            (96, 96, SafeResizeFit.cover),
          );
          final calls = paths.calls;
          for (var i = 0; i < 5; i++) {
            await tester.pumpWidget(host(first));
          }
          expect(paths.calls, calls);
          expect(requests, 1);

          const second = 'https://avatar.test/second.png';
          await tester.pumpWidget(host(second));
          await ready(size);
          expect(requests, 2);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image!.width,
            2,
          );

          size = 4;
          final eviction = AvatarCache.evict(second);
          await ready(size);
          await eviction;
          expect(requests, 3);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image!.width,
            4,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((_) async {
          requests++;
          return http.Response.bytes(bytes(), 200);
        }),
      );
    },
  );
  for (final unmounted in [false, true]) {
    testWidgets(
      'cache eviction refreshes ${unmounted ? "unmounted" : "other-size"} decoded images',
      (tester) async {
        final originalPaths = PathProviderPlatform.instance;
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('avatar_revision_'),
        ))!;
        PathProviderPlatform.instance = _Paths(root.path);
        AvatarCache.clearMemory();
        addTearDown(() async {
          PathProviderPlatform.instance = originalPaths;
          AvatarCache.clearMemory();
          await root.delete(recursive: true);
        });
        var pixels = 2;
        var requests = 0;
        var displaySize = 82.0;
        const url = 'https://avatar.test/versioned.png';
        Widget host() => MaterialApp(
          home: Center(
            child: AvatarImage(
              source: url,
              isNetwork: true,
              size: displaySize,
              fallback: const Text('loading'),
            ),
          ),
        );
        Future<void> ready(int expectedWidth) async {
          for (var i = 0; i < 100; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
            if (tester
                .widgetList<RawImage>(find.byType(RawImage))
                .any((image) => image.image?.width == expectedWidth)) {
              return;
            }
          }
          fail('Expected refreshed avatar width $expectedWidth');
        }

        await http.runWithClient(
          () async {
            await tester.pumpWidget(host());
            await ready(2);
            if (unmounted) {
              await tester.pumpWidget(const SizedBox.shrink());
            } else {
              displaySize = 32;
              await tester.pumpWidget(host());
              await ready(2);
            }
            pixels = 4;
            await tester.runAsync(() => AvatarCache.evict(url));
            if (!unmounted) await ready(4);
            displaySize = 82;
            await tester.pumpWidget(host());
            await ready(4);
            expect(requests, 2);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient((_) async {
            requests++;
            return http.Response.bytes(
              image.encodePng(image.Image(width: pixels, height: pixels)),
              200,
            );
          }),
        );
      },
    );
  }
}
