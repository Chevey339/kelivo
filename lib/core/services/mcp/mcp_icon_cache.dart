import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../utils/app_directories.dart';

/// Small, bounded icon downloads. No MCP authentication headers are forwarded.
class McpIconCache {
  static const maxBytes = 2 * 1024 * 1024;
  static const timeout = Duration(seconds: 8);
  static final _pending = <String, Future<String?>>{};
  static final _cache = <String, ({String? path, DateTime time})>{};

  static bool isWebUri(Uri? uri) =>
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;

  static Uri? faviconFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/favicon.ico',
    );
  }

  /// A server may declare inline images or images on its own origin. External
  /// locations are available through the explicit custom URL choice instead.
  static bool acceptsDeclaredSource(String source, String serverUrl) {
    final uri = Uri.tryParse(source);
    if (uri?.scheme == 'data') return source.length <= maxBytes * 2;
    final server = Uri.tryParse(serverUrl);
    return isWebUri(uri) && isWebUri(server) && uri!.origin == server!.origin;
  }

  static String? peek(String source) {
    final cached = _cache[source]?.path;
    return cached != null && File(cached).existsSync() ? cached : null;
  }

  static void clearMemory() {
    _cache.clear();
  }

  static Future<String?> getPath(
    String source, {
    http.Client? client,
    Directory? directory,
  }) {
    final entry = _cache[source];
    if (entry != null &&
        (entry.path != null && File(entry.path!).existsSync() ||
            entry.path == null &&
                DateTime.now().difference(entry.time) <
                    const Duration(minutes: 5))) {
      return Future.value(entry.path);
    }
    return _pending.putIfAbsent(source, () async {
      try {
        final path = await _load(source, client: client, directory: directory);
        _cache[source] = (path: path, time: DateTime.now());
        return path;
      } catch (_) {
        _cache[source] = (path: null, time: DateTime.now());
        return null;
      } finally {
        _pending.remove(source);
      }
    });
  }

  static Future<String?> _load(
    String source, {
    http.Client? client,
    Directory? directory,
  }) async {
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    final dir = directory ?? await AppDirectories.getAvatarCacheDirectory();
    final name = 'mcp_${sha256.convert(utf8.encode(source))}';
    for (final extension in ['svg', 'png', 'img']) {
      final cached = File(p.join(dir.path, '$name.$extension'));
      if (await cached.exists()) return cached.path;
    }
    Uint8List bytes;
    if (uri.scheme == 'data') {
      if (source.length > maxBytes * 2) return null;
      final data = uri.data;
      if (data == null || !data.mimeType.startsWith('image/')) return null;
      bytes = data.contentAsBytes();
    } else {
      if (!isWebUri(uri)) return null;
      final connection = client ?? http.Client();
      try {
        bytes = await (() async {
          // Follow only same-origin redirects, without cookies or credentials.
          var current = uri;
          for (var redirect = 0; redirect < 4; redirect++) {
            final request = http.Request('GET', current)
              ..followRedirects = false;
            final response = await connection.send(request);
            if (response.isRedirect) {
              final location = response.headers['location'];
              if (location == null) {
                throw const FormatException('Missing redirect');
              }
              final next = current.resolve(location);
              if (!isWebUri(next) || next.origin != uri.origin) {
                throw const FormatException('Cross-origin icon redirect');
              }
              await response.stream.listen((_) {}).cancel();
              current = next;
              continue;
            }
            if (response.statusCode != 200 ||
                (response.contentLength ?? 0) > maxBytes) {
              throw const FormatException('Invalid icon response');
            }
            final result = BytesBuilder(copy: false);
            await for (final chunk in response.stream) {
              if (result.length + chunk.length > maxBytes) {
                throw const FormatException('Icon too large');
              }
              result.add(chunk);
            }
            return result.takeBytes();
          }
          throw const FormatException('Too many icon redirects');
        })().timeout(timeout);
      } finally {
        if (client == null) connection.close();
      }
    }
    if (bytes.isEmpty || bytes.length > maxBytes) return null;
    final normalized = await compute(normalize, bytes);
    if (normalized == null) return null;
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$name.${normalized.extension}'));
    await file.writeAsBytes(normalized.bytes, flush: true);
    return file.path;
  }

  static ({Uint8List bytes, String extension})? normalize(Uint8List bytes) {
    if (bytes.length < 4) return null;
    final prefix = utf8
        .decode(bytes.take(512).toList(), allowMalformed: true)
        .trimLeft();
    if (prefix.contains('<svg') ||
        prefix.startsWith('<?xml') &&
            utf8.decode(bytes, allowMalformed: true).contains('<svg')) {
      try {
        if (XmlDocument.parse(utf8.decode(bytes)).rootElement.name.local !=
            'svg') {
          return null;
        }
      } catch (_) {
        return null;
      }
      return (bytes: bytes, extension: 'svg');
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0 &&
        bytes[1] == 0 &&
        bytes[2] == 1 &&
        bytes[3] == 0) {
      try {
        final decoded = _decodeIcoFrame(bytes);
        return decoded == null
            ? null
            : (bytes: img.encodePng(decoded), extension: 'png');
      } catch (_) {
        return null;
      }
    }
    // Validate the header without fully decoding potentially large raster data.
    try {
      final decoder = img.findDecoderForData(bytes);
      if (!{
        img.ImageFormat.png,
        img.ImageFormat.jpg,
        img.ImageFormat.webp,
        img.ImageFormat.gif,
        img.ImageFormat.bmp,
      }.contains(decoder?.format)) {
        return null;
      }
      final info = decoder?.startDecode(bytes);
      if (info == null ||
          info.width <= 0 ||
          info.height <= 0 ||
          info.width > 8192 ||
          info.height > 8192) {
        return null;
      }
      return (bytes: bytes, extension: 'img');
    } catch (_) {
      return null;
    }
  }

  static bool _boundedIcoSize(int width, int height) =>
      width > 0 &&
      height > 0 &&
      width <= 8192 &&
      height <= 8192 &&
      width * height <= 1024 * 1024;

  static img.Image? _decodeIcoFrame(Uint8List bytes) {
    if (bytes.length < 22) return null;
    final count = ByteData.sublistView(bytes).getUint16(4, Endian.little);
    if (count == 0 || count > 256) return null;
    final decoder = img.IcoDecoder();
    final info = decoder.startDecode(bytes) as img.IcoInfo?;
    if (info == null || info.images.isEmpty) return null;
    final frame = info.images.first;
    if (frame.bytesOffset < 6 + count * 16 ||
        frame.bytesSize < 8 ||
        frame.bytesOffset + frame.bytesSize > bytes.length) {
      return null;
    }
    final payload = Uint8List.sublistView(
      bytes,
      frame.bytesOffset,
      frame.bytesOffset + frame.bytesSize,
    );
    final png = img.PngDecoder();
    if (png.isValidFile(payload)) {
      // ICO directory dimensions are not authoritative for embedded PNGs.
      final pngInfo = png.startDecode(payload);
      if (pngInfo == null || !_boundedIcoSize(pngInfo.width, pngInfo.height)) {
        return null;
      }
      return png.decodeFrame(
        0,
      ); // Never expand an embedded APNG into all frames.
    }
    // Validate the DIB's actual dimensions and palette before the decoder can
    // allocate its pixel buffer. ICO DIB height includes the transparency mask.
    if (payload.length < 40) return null;
    final dib = ByteData.sublistView(payload);
    final headerSize = dib.getUint32(0, Endian.little);
    final width = dib.getInt32(4, Endian.little);
    final doubledHeight = dib.getInt32(8, Endian.little).abs();
    if (headerSize < 40 ||
        headerSize > payload.length ||
        doubledHeight.isOdd ||
        !_boundedIcoSize(width, doubledHeight ~/ 2) ||
        dib.getUint16(12, Endian.little) != 1 ||
        !{1, 4, 8, 16, 24, 32}.contains(dib.getUint16(14, Endian.little)) ||
        dib.getUint32(32, Endian.little) > 256) {
      return null;
    }
    return decoder.decodeFrame(0);
  }

  static Future<String> importFile(String path) async {
    final source = File(path);
    if (await source.length() > 10 * 1024 * 1024) {
      throw const FormatException('Icon too large');
    }
    final normalized = await compute(normalize, await source.readAsBytes());
    if (normalized == null) throw const FormatException('Unsupported icon');
    final dir = await AppDirectories.getAvatarsDirectory();
    await dir.create(recursive: true);
    final name =
        'mcp_${sha256.convert(normalized.bytes)}.${normalized.extension}';
    await File(
      p.join(dir.path, name),
    ).writeAsBytes(normalized.bytes, flush: true);
    return name;
  }

  static Future<String?> localPath(String name) async {
    if (p.basename(name) != name ||
        !RegExp(r'^mcp_[a-f0-9]{64}\.(svg|png|img)$').hasMatch(name)) {
      return null;
    }
    final dir = await AppDirectories.getAvatarsDirectory();
    final file = File(p.join(dir.path, name));
    return await file.exists() ? file.path : null;
  }
}
