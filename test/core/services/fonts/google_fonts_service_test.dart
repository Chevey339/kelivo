import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/services/fonts/google_fonts_service.dart';

Map<String, dynamic> entry(String family, {String? url, bool regular = true}) =>
    {
      'family': family,
      'subsets': ['latin'],
      'files': {
        if (regular)
          'regular': url ?? 'https://fonts.gstatic.com/s/font/v1/font.ttf',
      },
    };
String catalog(List<Map<String, dynamic>> fonts) =>
    jsonEncode({'items': fonts});

class _AbortableClient extends http.BaseClient {
  final started = Completer<void>();
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('LICENSE_FONT')) {
      return http.StreamedResponse(Stream.value(utf8.encode('License')), 200);
    }
    final stream = StreamController<List<int>>();
    unawaited(
      (request as http.AbortableRequest).abortTrigger!.then((_) {
        aborted = true;
        stream.addError(http.RequestAbortedException());
        unawaited(stream.close());
      }),
    );
    started.complete();
    return http.StreamedResponse(stream.stream, 200);
  }
}

void main() {
  late Directory dir;
  setUp(
    () async =>
        dir = await Directory.systemTemp.createTemp('google-fonts-test-'),
  );
  tearDown(() async => dir.delete(recursive: true));

  test(
    'catalog sorts regular complete TTF faces and rejects unsafe sources',
    () {
      final fonts = GoogleFontsService.parseCatalog(
        catalog([
          entry('Zed', url: 'http://fonts.gstatic.com/s/font/v1/font.ttf'),
          entry('Abel'),
          entry('Italic Only', regular: false),
          entry('Webfont', url: 'https://fonts.gstatic.com/s/font/font.woff2'),
          entry('Foreign', url: 'https://other.example/font.ttf'),
          entry('Credentials', url: 'https://user@fonts.gstatic.com/font.ttf'),
          entry('Port', url: 'https://fonts.gstatic.com:444/font.ttf'),
          entry('Scheme', url: 'ftp://fonts.gstatic.com/font.ttf'),
        ]),
      );
      expect(fonts.map((f) => f.family), ['Abel', 'Zed']);
      expect(fonts.last.url.scheme, 'https');
    },
  );

  test(
    'fresh catalog is cached across service instances without networking',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(catalog([entry('Abel')]), 200);
      });
      final first = GoogleFontsService(client: client, cacheDirectory: dir);
      await first.loadCatalog();
      final second = GoogleFontsService(client: client, cacheDirectory: dir);
      expect((await second.loadCatalog()).single.family, 'Abel');
      expect(requests, 1);
      expect(await dir.list().map((f) => f.path.split('/').last).toList(), [
        'catalog.json',
      ]);
      client.close();
    },
  );

  test(
    'offline stale catalog works but explicit refresh reports failure',
    () async {
      final file = File('${dir.path}/catalog.json');
      await file.writeAsString(catalog([entry('Abel')]));
      await file.setLastModified(
        DateTime.now().subtract(const Duration(days: 8)),
      );
      final service = GoogleFontsService(
        cacheDirectory: dir,
        client: MockClient((_) async => http.Response('', 503)),
      );
      expect((await service.loadCatalog()).single.family, 'Abel');
      await expectLater(
        service.loadCatalog(refresh: true),
        throwsA(isA<HttpException>()),
      );
      expect(
        GoogleFontsService.parseCatalog(
          await file.readAsString(),
        ).single.family,
        'Abel',
      );
      service.close();
    },
  );

  test('invalid refresh never replaces a valid cached catalog', () async {
    final file = File('${dir.path}/catalog.json');
    await file.writeAsString(catalog([entry('Abel')]));
    final service = GoogleFontsService(
      cacheDirectory: dir,
      client: MockClient((_) async => http.Response('{"items":[]}', 200)),
    );
    await expectLater(
      service.loadCatalog(refresh: true),
      throwsFormatException,
    );
    expect(
      GoogleFontsService.parseCatalog(await file.readAsString()).single.family,
      'Abel',
    );
    service.close();
  });

  test('corrupt cache is replaced by valid remote catalog', () async {
    await File('${dir.path}/catalog.json').writeAsString('broken');
    final service = GoogleFontsService(
      cacheDirectory: dir,
      client: MockClient(
        (_) async => http.Response(catalog([entry('Abel')]), 200),
      ),
    );
    expect((await service.loadCatalog()).single.family, 'Abel');
    service.close();
  });

  test(
    'download keeps full font and license until explicitly disposed',
    () async {
      final bytes = await File(
        'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf',
      ).readAsBytes();
      final paths = <String>[];
      final service = GoogleFontsService(
        cacheDirectory: dir,
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.followRedirects, isFalse);
          return request.url.path.endsWith('LICENSE_FONT')
              ? http.Response('Font license', 200)
              : http.Response.bytes(bytes, 200);
        }),
      );
      final font = GoogleFontsService.parseCatalog(
        catalog([entry('JetBrains Mono')]),
      ).single;
      var received = 0;
      final result = await service.download(
        font,
        onProgress: (n, _) => received = n,
      );
      expect(paths.first, endsWith('/jetbrains-mono/LICENSE_FONT'));
      expect(result.license, 'Font license');
      expect(await result.file.readAsBytes(), bytes);
      expect(received, bytes.length);
      await result.dispose();
      expect(await dir.list().toList(), isEmpty);
      service.close();
    },
  );

  for (final status in [200, 302, 404]) {
    test(
      'invalid or unsuccessful font response $status removes temporary files',
      () async {
        final service = GoogleFontsService(
          cacheDirectory: dir,
          client: MockClient(
            (request) async => request.url.path.endsWith('LICENSE_FONT')
                ? http.Response('License', 200)
                : http.Response('<html>error</html>', status),
          ),
        );
        final font = GoogleFontsService.parseCatalog(
          catalog([entry('Abel')]),
        ).single;
        await expectLater(service.download(font), throwsA(anything));
        expect(await dir.list().toList(), isEmpty);
        service.close();
      },
    );
  }

  test(
    'oversized stream without content length is rejected and cleaned',
    () async {
      final client = MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('LICENSE_FONT')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('License')),
            200,
          );
        }
        return http.StreamedResponse(
          Stream.fromIterable(List.filled(65, Uint8List(1024 * 1024))),
          200,
        );
      });
      final service = GoogleFontsService(cacheDirectory: dir, client: client);
      final font = GoogleFontsService.parseCatalog(
        catalog([entry('Abel')]),
      ).single;
      await expectLater(service.download(font), throwsFormatException);
      expect(await dir.list().toList(), isEmpty);
      service.close();
    },
  );

  test(
    'decompressed catalog does not compare bytes with compressed length',
    () async {
      final content = utf8.encode(catalog([entry('Abel')]));
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.value(content),
          200,
          contentLength: 10,
          headers: {'content-encoding': 'gzip'},
        ),
      );
      final service = GoogleFontsService(cacheDirectory: dir, client: client);
      expect((await service.loadCatalog()).single.family, 'Abel');
      service.close();
    },
  );

  test(
    'closing service aborts transport and cleans in-progress download',
    () async {
      final client = _AbortableClient();
      final service = GoogleFontsService(client: client, cacheDirectory: dir);
      final font = GoogleFontsService.parseCatalog(
        catalog([entry('Abel')]),
      ).single;
      final result = service.download(font);
      final expectation = expectLater(
        result,
        throwsA(isA<http.RequestAbortedException>()),
      );
      await client.started.future;
      service.close();
      await expectation;
      expect(client.aborted, isTrue);
      expect(await dir.list().toList(), isEmpty);
    },
  );

  test('truncated response fails without replacing cache', () async {
    final content = utf8.encode(catalog([entry('Abel')]));
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(
        Stream.value(content),
        200,
        contentLength: content.length + 10,
      ),
    );
    final service = GoogleFontsService(cacheDirectory: dir, client: client);
    await expectLater(service.loadCatalog(), throwsFormatException);
    expect(await dir.list().toList(), isEmpty);
    service.close();
  });
}
