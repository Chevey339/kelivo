import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/utils/svg_image_provider.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as images;
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart'
    as compiler;

const _source =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 32">'
    '<rect width="64" height="32" fill="currentColor"/></svg>';
String _data(String source) =>
    'data:image/svg+xml;base64,${base64Encode(utf8.encode(source))}';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<int> compile(String body) => compiler.encodeSvg(
    xml: sanitizeSvgImage(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">$body</svg>',
    ),
    debugName: 'budget-test',
    enableClippingOptimizer: false,
    enableMaskingOptimizer: false,
    enableOverdrawOptimizer: false,
  );

  test('SVG dash expansion has a cumulative budget after styles and transforms', () {
    expect(
      compile('<path d="M0 5 L100 5" stroke="black" stroke-dasharray="1"/>'),
      isNotEmpty,
    );
    for (final body in [
      '<path d="M0 5 L100 5" stroke="black" stroke-dasharray="0.000001"/>',
      '<path d="M0 5 C30 5 60 5 100 5" stroke="black" stroke-dasharray="0.000001"/>',
      '<g transform="scale(1000000)" stroke="black" stroke-dasharray="1"><path d="M0 5 L100 5"/></g>',
      '<g stroke="black" stroke-dasharray="0.005"><path d="M0 5 L200 5"/><path d="M0 10 L200 10"/></g>',
      '<defs><path id="line" d="M0 5 L200 5" stroke="black" stroke-dasharray="0.005"/></defs><use href="#line"/><use href="#line"/>',
    ]) {
      expect(
        () => compile(body),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('geometry'),
          ),
        ),
        reason: body,
      );
    }
  });

  test('SVG curved path subdivision cannot bypass the shared work budget', () {
    const path =
        '<path d="M0 0 C0 100 100 100 100 0" stroke="black" stroke-dasharray="1e100"/>';
    expect(compile(path), isNotEmpty);
    expect(compile(path.replaceFirst('1e100', '2')), isNotEmpty);
    for (final scale in ['1e12', '1e14', '1e16', '1e100']) {
      expect(
        () => compile('<g transform="scale($scale)">$path</g>'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('limit exceeded'),
          ),
        ),
        reason:
            'A curved path must stop during length calculation at scale $scale',
      );
    }
  });

  test('ordinary paths and clip references share the geometry budget', () {
    final path = 'M0 0${'L1 1L0 0' * 2500}';
    final definition = '<path id="shape" d="$path"/>';
    expect(compile('<defs>$definition</defs><use href="#shape"/>'), isNotEmpty);
    const oneClip = '<rect width="10" height="10" clip-path="url(#clip)"/>';
    final clip = '<clipPath id="clip"><use href="#shape"/></clipPath>';
    expect(compile('<defs>$definition$clip</defs>$oneClip'), isNotEmpty);
    for (final body in [
      '<defs>$definition</defs>${'<use href="#shape"/>' * 16}',
      '<defs>$definition$clip</defs>${oneClip * 16}',
      '<defs><text id="label">${'a' * 3000}</text></defs>${'<use href="#label"/>' * 24}',
    ]) {
      expect(
        () => compile(body),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('geometry work limit'),
          ),
        ),
      );
    }
  });

  test('SVG pattern tiles are bounded before native bitmap decoding', () {
    String pattern(String id, int width, int height) =>
        '<pattern id="$id" patternUnits="userSpaceOnUse" width="$width" height="$height"><rect width="1" height="1" fill="red"/></pattern>';
    String fill(String id) => '<rect width="10" height="10" fill="url(#$id)"/>';
    expect(
      compile('<defs>${pattern('p', 10, 10)}</defs>${fill('p')}'),
      isNotEmpty,
    );
    for (final body in [
      '<defs>${pattern('p', 8192, 8192)}</defs>${fill('p')}',
      '<defs>${pattern('p', 2048, 2048)}${pattern('q', 2048, 2048)}</defs>${fill('p')}${fill('q')}',
    ]) {
      expect(
        () => compile(body),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('pattern'),
          ),
        ),
      );
    }
  });

  test(
    'SVG detection handles query strings, fragments, case and data URIs',
    () {
      for (final source in [
        'https://example.com/graph.SVG?token=1#part',
        '/tmp/a b.svg',
        'file:///tmp/graph.svg',
        _data(_source),
        'data:image/svg+xml,%3Csvg%2F%3E',
      ]) {
        expect(isSvgImageSource(source), isTrue, reason: source);
      }
      expect(
        isSvgImageSource('https://example.com/image.png?name=a.svg'),
        isFalse,
      );
      expect(isSvgImageSource('data:image/png;base64,abc'), isFalse);
    },
  );

  test(
    'sanitizer retains local paint references but removes active and external content',
    () {
      const source =
          '''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 10 10" onload="bad()">
<script>bad()</script><foreignObject><div>hidden</div></foreignObject>
<defs><linearGradient id="paint"><stop offset="0" stop-color="red"/></linearGradient></defs>
<rect id="shape" width="10" height="10" fill="url(#paint)" style="stroke:blue;behavior:bad()"/>
<use xlink:href="#shape"/><use href="https://example.com/x.svg#shape"/>
<image href="https://example.com/tracker.png"/><animate attributeName="x"/>
</svg>''';
      final safe = sanitizeSvgImage(source);
      expect(safe, contains('url(#paint)'));
      expect(safe, contains('xlink:href="#shape"'));
      expect(safe, contains('stroke:blue'));
      for (final forbidden in [
        'script',
        'foreignObject',
        'onload',
        'https://example.com',
        'animate',
        'behavior',
      ]) {
        expect(safe, isNot(contains(forbidden)));
      }
      expect(
        sanitizeSvgImage(
          '<svg><path fill="url(https://example.com/x)"/></svg>',
        ),
        isNot(contains('url(')),
      );
    },
  );

  test(
    'SVG limits reject malformed, deep, oversized and entity-bearing documents',
    () {
      for (final source in [
        '<svg>',
        '<html/>',
        '<!DOCTYPE svg [<!ENTITY x "x">]><svg/>',
        '<svg>${'<g>' * 50}${'</g>' * 50}</svg>',
        '<svg>${'<rect/>' * 4096}</svg>',
        '<svg>${' ' * (2 * 1024 * 1024)}</svg>',
      ]) {
        expect(() => sanitizeSvgImage(source), throwsA(anything));
      }
    },
  );

  test(
    'native SVG decoding preserves aspect ratio and keys theme colors independently',
    () async {
      final red = SvgImageProvider(
        _data(_source),
        currentColor: const Color(0xffff0000),
      );
      final blue = SvgImageProvider(
        _data(_source),
        currentColor: const Color(0xff0000ff),
      );
      expect(
        red,
        SvgImageProvider(_data(_source), currentColor: const Color(0xffff0000)),
      );
      expect(red, isNot(blue));
      final redPng = images.decodePng(await red.pngBytes())!;
      final bluePng = images.decodePng(await blue.pngBytes())!;
      expect(redPng.width, 128);
      expect(redPng.height, 64);
      expect(redPng.getPixel(20, 20).r, 255);
      expect(redPng.getPixel(20, 20).b, 0);
      expect(bluePng.getPixel(20, 20).b, 255);
      final encoded = Uri.dataFromString(
        _source,
        mimeType: 'image/svg+xml',
      ).toString();
      expect(
        images.decodePng(await SvgImageProvider(encoded).pngBytes()),
        isNotNull,
      );
    },
  );

  test(
    'local and HTTP SVGs decode without fetching embedded external images',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final directory = await Directory.systemTemp.createTemp(
          'kelivo-svg-test-',
        );
        final file = await File(
          '${directory.path}/test.svg',
        ).writeAsString(_source);
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var requests = 0;
        final subscription = server.listen((request) async {
          requests++;
          request.response.headers.contentType = ContentType(
            'image',
            'svg+xml',
          );
          request.response.write(
            _source.replaceFirst(
              '</svg>',
              '<image href="http://127.0.0.1:${server.port}/external.png"/></svg>',
            ),
          );
          await request.response.close();
        });
        try {
          expect(
            images.decodePng(await SvgImageProvider(file.path).pngBytes()),
            isNotNull,
          );
          expect(
            images.decodePng(
              await SvgImageProvider(
                'http://127.0.0.1:${server.port}/test.SVG?v=1',
              ).pngBytes(),
            ),
            isNotNull,
          );
          expect(requests, 1);
        } finally {
          await subscription.cancel();
          await server.close(force: true);
          await directory.delete(recursive: true);
        }
      }, _RealHttpOverrides());
    },
  );

  test('SVG image providers honor viewer decode limits', () async {
    final provider = SafeResizeImage(
      SvgImageProvider(_data(_source)),
      width: 32,
      height: 16,
      maxEdge: 32,
      maxPixels: 512,
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final complete = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) => complete.complete(info),
      onError: complete.completeError,
    );
    stream.addListener(listener);
    try {
      final info = await complete.future;
      expect(info.image.width, 32);
      expect(info.image.height, 16);
      info.dispose();
    } finally {
      stream.removeListener(listener);
    }
  });
}
