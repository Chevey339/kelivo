import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import 'app_directories.dart';
import 'avatar_cache.dart';

typedef _IconRequest = ({String source, bool allowCrossOriginRedirects});

/// Checked image imports and bounded, unauthenticated icon downloads.
class IconCache {
  static const maxBytes = 2 * 1024 * 1024;
  static const timeout = Duration(seconds: 8);
  static final _pending = <_IconRequest, Future<String?>>{};
  static final _cache = <_IconRequest, ({String? path, DateTime time})>{};
  static int _directoryRevision = AvatarCache.directoryRevision;

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

  /// An automatically discovered icon must be inline or on its owner's origin.
  static bool acceptsDeclaredSource(String source, String ownerUrl) {
    final uri = Uri.tryParse(source);
    if (uri?.scheme == 'data') return source.length <= maxBytes * 2;
    final owner = Uri.tryParse(ownerUrl);
    return isWebUri(uri) && isWebUri(owner) && uri!.origin == owner!.origin;
  }

  static String? peek(String source, {bool allowCrossOriginRedirects = false}) {
    _syncDirectoryRevision();
    final cached =
        _cache[(
              source: source,
              allowCrossOriginRedirects: allowCrossOriginRedirects,
            )]
            ?.path;
    return cached != null && File(cached).existsSync() ? cached : null;
  }

  static void clearMemory() {
    _cache.clear();
    _pending.clear();
    _directoryRevision = AvatarCache.directoryRevision;
  }

  static void _syncDirectoryRevision() {
    if (_directoryRevision != AvatarCache.directoryRevision) clearMemory();
  }

  static Future<String?> getPath(
    String source, {
    bool allowCrossOriginRedirects = false,
    http.Client? client,
    Directory? directory,
  }) {
    _syncDirectoryRevision();
    final key = (
      source: source,
      allowCrossOriginRedirects: allowCrossOriginRedirects,
    );
    final entry = _cache[key];
    if (entry != null &&
        (entry.path != null && File(entry.path!).existsSync() ||
            entry.path == null &&
                DateTime.now().difference(entry.time) <
                    const Duration(minutes: 5))) {
      return Future.value(entry.path);
    }
    final existing = _pending[key];
    if (existing != null) return existing;
    final revision = _directoryRevision;
    late final Future<String?> request;
    bool current() =>
        revision == AvatarCache.directoryRevision &&
        identical(_pending[key], request);
    request = () async {
      try {
        final path = await _load(
          key,
          current,
          client: client,
          directory: directory,
        );
        if (!current()) return null;
        _cache[key] = (path: path, time: DateTime.now());
        return path;
      } catch (_) {
        if (current()) _cache[key] = (path: null, time: DateTime.now());
        return null;
      } finally {
        if (identical(_pending[key], request)) _pending.remove(key);
      }
    }();
    _pending[key] = request;
    return request;
  }

  static Future<String?> _load(
    _IconRequest key,
    bool Function() current, {
    http.Client? client,
    Directory? directory,
  }) async {
    final source = key.source;
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    final dir = directory ?? await AppDirectories.getAvatarCacheDirectory();
    // An explicitly chosen URL may redirect to a CDN. Keep its cache separate
    // so a server-discovered icon still has to satisfy its origin policy.
    final prefix = key.allowCrossOriginRedirects ? 'remote_icon' : 'mcp';
    final name = '${prefix}_${sha256.convert(utf8.encode(source))}';
    final path = await AvatarCache.withCacheFiles(() async {
      for (final extension in ['svg', 'png', 'img']) {
        final cached = File(p.join(dir.path, '$name.$extension'));
        if (await cached.exists()) return cached.path;
      }
      return null;
    });
    if (!current() || path != null) return path;
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
          // Never forward cookies or credentials across hops.
          var current = uri;
          for (var redirect = 0; redirect < 4; redirect++) {
            final request = http.Request('GET', current)
              ..followRedirects = false;
            final response = await connection.send(request);
            if (response.isRedirect) {
              await response.stream.listen((_) {}).cancel();
              final location = response.headers['location'];
              if (location == null) {
                throw const FormatException('Missing redirect');
              }
              final next = current.resolve(location);
              if (!isWebUri(next) ||
                  (!key.allowCrossOriginRedirects &&
                      next.origin != uri.origin)) {
                throw const FormatException('Disallowed icon redirect');
              }
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
    if (!current() || bytes.isEmpty || bytes.length > maxBytes) return null;
    final normalized = await compute(normalize, bytes);
    if (normalized == null) return null;
    return AvatarCache.withCacheFiles(() async {
      if (!current()) return null;
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, '$name.${normalized.extension}'));
      await file.writeAsBytes(normalized.bytes, flush: true);
      return file.path;
    });
  }

  static ({Uint8List bytes, String extension})? normalize(
    Uint8List bytes, {
    bool preserveRasterExtension = false,
  }) {
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
      final extension = switch (decoder?.format) {
        img.ImageFormat.png => 'png',
        img.ImageFormat.jpg => 'jpg',
        img.ImageFormat.webp => 'webp',
        img.ImageFormat.gif => 'gif',
        img.ImageFormat.bmp => 'bmp',
        _ => null,
      };
      if (extension == null) return null;
      final info = decoder?.startDecode(bytes);
      if (info == null ||
          info.width <= 0 ||
          info.height <= 0 ||
          info.width > 8192 ||
          info.height > 8192) {
        return null;
      }
      return (
        bytes: bytes,
        extension: preserveRasterExtension ? extension : 'img',
      );
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

  static Future<String> importFile(String path) =>
      _importFile(path, separateAvatar: false);

  /// Creates a fresh managed path so deletion of a previous avatar cannot
  /// remove the icon being saved.
  static Future<String> importAvatarFile(String path) =>
      _importFile(path, separateAvatar: true);

  static Future<String> _importFile(
    String path, {
    required bool separateAvatar,
  }) async {
    final source = File(path);
    if (await source.length() > 10 * 1024 * 1024) {
      throw const FormatException('Icon too large');
    }
    final normalized = await compute(
      (bytes) => normalize(bytes, preserveRasterExtension: separateAvatar),
      await source.readAsBytes(),
    );
    if (normalized == null) throw const FormatException('Unsupported icon');
    final dir = await AppDirectories.getAvatarsDirectory();
    await dir.create(recursive: true);
    final hash = sha256.convert(normalized.bytes);
    final baseName = separateAvatar
        ? 'avatar_${const Uuid().v4()}'
        : 'mcp_$hash';
    final name = '$baseName.${normalized.extension}';
    final destination = File(p.join(dir.path, name));
    if (await _matchesHash(destination, hash)) return name;

    // Publish a complete file without truncating an image used by another
    // configuration. Stage outside the avatars directory scanned by backups.
    final stagingDir = await dir.parent.createTemp('.icon-');
    try {
      final staged = await File(
        p.join(stagingDir.path, name),
      ).writeAsBytes(normalized.bytes, flush: true);
      if (!await _matchesHash(destination, hash)) {
        await staged.rename(destination.path);
      }
    } on FileSystemException {
      if (!await _matchesHash(destination, hash)) rethrow;
    } finally {
      await stagingDir.delete(recursive: true);
    }
    return name;
  }

  static Future<bool> _matchesHash(File file, Digest hash) async {
    try {
      if (!await file.exists()) return false;
      return await sha256.bind(file.openRead()).first == hash;
    } on FileSystemException {
      return false;
    }
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
