import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/services/mcp/mcp_icon_cache.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() {
    McpIconCache.clearMemory();
    directory = Directory.systemTemp.createTempSync('mcp-icon-test-');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'favicon URL contains only the server origin and no credentials or query',
    () {
      expect(
        McpIconCache.faviconFor(
          'https://user:secret@example.com:8443/private/mcp?key=secret#fragment',
        ).toString(),
        'https://example.com:8443/favicon.ico',
      );
      expect(McpIconCache.faviconFor('stdio:command'), isNull);
      expect(
        McpIconCache.acceptsDeclaredSource(
          'https://elsewhere.example/icon.png',
          'https://mcp.example/sse',
        ),
        isFalse,
      );
      expect(
        McpIconCache.acceptsDeclaredSource(
          'https://mcp.example/icon.png',
          'https://mcp.example/sse',
        ),
        isTrue,
      );
      expect(
        McpIconCache.acceptsDeclaredSource(
          'file:///etc/passwd',
          'https://mcp.example',
        ),
        isFalse,
      );
      expect(
        McpIconCache.acceptsDeclaredSource('https://mcp.example/icon.png', ''),
        isFalse,
      );
    },
  );

  test(
    'concurrent icon requests are deduplicated and cached without authentication',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.headers.containsKey('authorization'), isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M0 0h24v24H0z"/></svg>',
          200,
        );
      });
      final paths = await Future.wait(
        List.generate(
          4,
          (_) => McpIconCache.getPath(
            'https://icons.example/logo.svg',
            client: client,
            directory: directory,
          ),
        ),
      );
      expect(requests, 1);
      expect(paths.toSet().length, 1);
      expect(paths.first, endsWith('.svg'));
      expect(
        await McpIconCache.getPath(
          'https://icons.example/logo.svg',
          client: client,
          directory: directory,
        ),
        paths.first,
      );
      expect(requests, 1);
    },
  );

  test(
    'invalid, oversized and cross-origin responses fail without a cached file',
    () async {
      for (final response in [
        http.Response('<html>not an icon</html>', 200),
        http.Response('<svg broken', 200),
        http.Response(
          'x',
          200,
          headers: {'content-length': '${McpIconCache.maxBytes + 1}'},
        ),
        http.Response(
          '',
          302,
          headers: {'location': 'https://elsewhere.example/secret'},
        ),
      ]) {
        McpIconCache.clearMemory();
        expect(
          await McpIconCache.getPath(
            'https://mcp.example/icon',
            client: MockClient((_) async => response),
            directory: directory,
          ),
          isNull,
        );
      }
      expect(directory.listSync(), isEmpty);
    },
  );

  test(
    'uploaded icons remain usable after the app storage root changes',
    () async {
      final original = PathProviderPlatform.instance;
      addTearDown(() => PathProviderPlatform.instance = original);
      PathProviderPlatform.instance = _Paths('${directory.path}/before');
      final source = File('${directory.path}/upload.png');
      final png = img.encodePng(img.Image(width: 2, height: 2));
      await source.writeAsBytes(png);
      final name = await McpIconCache.importFile(source.path);
      expect(name, isNot(contains('/')));
      final stored = (await McpIconCache.localPath(name))!;
      await source.delete();
      final restored = File('${directory.path}/after/avatars/$name');
      await restored.parent.create(recursive: true);
      await File(stored).copy(restored.path);
      PathProviderPlatform.instance = _Paths('${directory.path}/after');
      expect(await McpIconCache.localPath(name), restored.path);
      expect(await restored.readAsBytes(), png);
      expect(await McpIconCache.localPath('../upload.png'), isNull);
    },
  );

  test('ICO validates the embedded PNG dimensions before full decoding', () {
    final png = img.encodePng(img.Image(width: 9000, height: 1));
    final header = ByteData(22)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, 1, Endian.little)
      ..setUint8(6, 0) // ICO directory claims 256 pixels, PNG claims 9000.
      ..setUint8(7, 1)
      ..setUint16(10, 1, Endian.little)
      ..setUint16(12, 32, Endian.little)
      ..setUint32(14, png.length, Endian.little)
      ..setUint32(18, 22, Endian.little);
    final bytes = Uint8List.fromList([...header.buffer.asUint8List(), ...png]);
    expect(bytes.length, lessThan(McpIconCache.maxBytes));
    expect(McpIconCache.normalize(bytes), isNull);
  });

  test('classic DIB favicons remain supported with bounded dimensions', () {
    final dib = ByteData(40 + 16)
      ..setUint32(0, 40, Endian.little)
      ..setInt32(4, 2, Endian.little)
      ..setInt32(8, 4, Endian.little)
      ..setUint16(12, 1, Endian.little)
      ..setUint16(14, 32, Endian.little)
      ..setUint32(20, 16, Endian.little);
    final header = ByteData(22)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, 1, Endian.little)
      ..setUint8(6, 2)
      ..setUint8(7, 2)
      ..setUint16(10, 1, Endian.little)
      ..setUint16(12, 32, Endian.little)
      ..setUint32(14, dib.lengthInBytes, Endian.little)
      ..setUint32(18, 22, Endian.little);
    Uint8List bytes() => Uint8List.fromList([
      ...header.buffer.asUint8List(),
      ...dib.buffer.asUint8List(),
    ]);
    final result = McpIconCache.normalize(bytes());
    expect(result, isNotNull);
    expect(img.decodePng(result!.bytes)!.width, 2);
    dib.setInt32(4, 9000, Endian.little);
    expect(McpIconCache.normalize(bytes()), isNull);
  });

  test('ICO favicons become PNGs supported by Flutter', () {
    final bytes = img.encodeIco(img.Image(width: 16, height: 16));
    final result = McpIconCache.normalize(bytes);
    expect(result!.extension, 'png');
    expect(img.decodePng(result.bytes)!.width, 16);
  });

  test(
    'inline server icons are supported but local paths and malformed data are not',
    () async {
      final png = img.encodePng(img.Image(width: 2, height: 2));
      final uri = 'data:image/png;base64,${base64Encode(png)}';
      final path = await McpIconCache.getPath(uri, directory: directory);
      expect(path, isNotNull);
      expect(await File(path!).readAsBytes(), png);
      expect(
        await McpIconCache.getPath('file:///etc/passwd', directory: directory),
        isNull,
      );
      expect(McpIconCache.normalize(Uint8List.fromList([1, 2, 3])), isNull);
    },
  );
}
