import 'dart:async';
import 'dart:io';

import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/avatar_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  int reads = 0;
  @override
  Future<String?> getApplicationDocumentsPath() async {
    reads++;
    return root;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    reads++;
    return root;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform paths;
  setUp(() async {
    paths = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('avatar_cache_test_');
    PathProviderPlatform.instance = _Paths(root.path);
    AvatarCache.clearMemory();
  });
  tearDown(() async {
    AvatarCache.clearMemory();
    PathProviderPlatform.instance = paths;
    await root.delete(recursive: true);
  });

  test(
    'parallel callers share one download and reuse the disk cache',
    () async {
      var requests = 0;
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          final loads = List.generate(
            20,
            (_) => AvatarCache.getPath('https://avatar.test/a.png'),
          );
          expect(loads.every((load) => identical(load, loads.first)), isTrue);
          response.complete(http.Response('image', 200));
          final results = await Future.wait(loads);
          expect(requests, 1);
          expect(results.toSet(), hasLength(1));
          expect(await File(results.first!).readAsString(), 'image');
          AvatarCache.clearMemory();
          expect(
            await AvatarCache.getPath('https://avatar.test/a.png'),
            results.first,
          );
          expect(requests, 1);
        },
        () => MockClient((_) {
          requests++;
          return response.future;
        }),
      );
    },
  );

  test(
    'failed requests are cached until an explicit eviction permits retry',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          expect(
            await AvatarCache.getPath('https://avatar.test/retry'),
            isNull,
          );
          for (var i = 0; i < 5; i++) {
            expect(
              await AvatarCache.getPath('https://avatar.test/retry'),
              isNull,
            );
          }
          expect(requests, 1);
          await AvatarCache.evict('https://avatar.test/retry');
          expect(
            await AvatarCache.getPath('https://avatar.test/retry'),
            isNotNull,
          );
          expect(requests, 2);
        },
        () => MockClient(
          (_) async => http.Response('image', ++requests == 1 ? 503 : 200),
        ),
      );
    },
  );

  test('memoized paths do not repeat platform directory lookups', () async {
    final paths = PathProviderPlatform.instance as _Paths;
    await http.runWithClient(() async {
      final first = await AvatarCache.getPath('https://avatar.test/memo');
      final reads = paths.reads;
      for (var i = 0; i < 5; i++) {
        expect(await AvatarCache.getPath('https://avatar.test/memo'), first);
      }
      expect(paths.reads, reads);
    }, () => MockClient((_) async => http.Response('image', 200)));
  });

  for (final evict in [false, true]) {
    test(
      '${evict ? 'eviction' : 'cache clear'} rejects a late old download',
      () async {
        const url = 'https://avatar.test/race';
        final entered = Completer<void>();
        final oldResponse = Completer<http.Response>();
        var requests = 0;
        await http.runWithClient(
          () async {
            final old = AvatarCache.getPath(url);
            await entered.future;
            if (evict) {
              await AvatarCache.evict(url);
            } else {
              await AvatarCache.clearCache(() async {
                final directory =
                    await AppDirectories.getAvatarCacheDirectory();
                if (await directory.exists()) {
                  await directory.delete(recursive: true);
                }
              });
            }
            final fresh = await AvatarCache.getPath(url);
            oldResponse.complete(http.Response('obsolete image', 200));
            expect(await old, isNull);
            expect(await File(fresh!).readAsString(), 'fresh image');
            expect(await AvatarCache.getPath(url), fresh);
            expect(requests, 2);
          },
          () => MockClient((_) async {
            requests++;
            if (requests == 1) {
              entered.complete();
              return oldResponse.future;
            }
            return http.Response('fresh image', 200);
          }),
        );
      },
    );
  }

  test('a load started while deleting waits for the deletion', () async {
    const url = 'https://avatar.test/deleting';
    var requests = 0;
    await http.runWithClient(
      () async {
        final path = await AvatarCache.getPath(url);
        final entered = Completer<void>();
        final finish = Completer<void>();
        final clearing = AvatarCache.clearCache(() async {
          entered.complete();
          await finish.future;
          await File(path!).delete();
        });
        await entered.future;
        final reloaded = AvatarCache.getPath(url);
        finish.complete();
        await clearing;
        expect(await reloaded, path);
        expect(await File(path!).readAsString(), 'image 2');
        expect(requests, 2);
      },
      () => MockClient((_) async => http.Response('image ${++requests}', 200)),
    );
  });
}
