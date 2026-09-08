import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../utils/app_directories.dart';

class GoogleFontEntry {
  const GoogleFontEntry({
    required this.family,
    required this.url,
    required this.subsets,
  });

  final String family;
  final Uri url;
  final List<String> subsets;

  String get packageName => family
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp('[^a-z0-9-]'), '');
}

class DownloadedGoogleFont {
  const DownloadedGoogleFont({required this.file, required this.license});

  final File file;
  final String license;

  Future<void> dispose() async {
    if (await file.parent.exists()) await file.parent.delete(recursive: true);
  }
}

/// The remote snapshot is the Google Fonts Developer API response maintained
/// by Expo. No catalog, font assets, API key, or google_fonts code is bundled.
class GoogleFontsService {
  GoogleFontsService({http.Client? client, this._cacheDirectory})
    : _client = client ?? http.Client();

  static final catalogUri = Uri.parse(
    'https://raw.githubusercontent.com/expo/google-fonts/main/'
    'packages/generator/data/directory-data.json',
  );
  static const _catalogMaxBytes = 8 * 1024 * 1024;
  static const _fontMaxBytes = 64 * 1024 * 1024;
  final http.Client _client;
  final _closed = Completer<void>();
  final Directory? _cacheDirectory;

  Future<Directory> _directory() async {
    final dir =
        _cacheDirectory ??
        Directory(
          '${(await AppDirectories.getCacheDirectory()).path}/google_fonts',
        );
    await dir.create(recursive: true);
    return dir;
  }

  static List<GoogleFontEntry> parseCatalog(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    final entries = <GoogleFontEntry>[];
    for (final item in json['items'] as List) {
      final row = item as Map<String, dynamic>;
      final family = row['family'] as String;
      final files = row['files'] as Map<String, dynamic>;
      // This picker imports one regular face, matching the local font pipeline.
      final regular = files['regular'];
      if (regular is! String || family.trim().isEmpty) continue;
      final original = Uri.parse(regular);
      if (original.scheme != 'http' && original.scheme != 'https') continue;
      final url = original.replace(scheme: 'https');
      if (!_isFontUrl(url)) continue;
      entries.add(
        GoogleFontEntry(
          family: family,
          url: url,
          subsets: (row['subsets'] as List).cast<String>(),
        ),
      );
    }
    if (entries.isEmpty) throw const FormatException('Empty font catalog');
    entries.sort(
      (a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()),
    );
    return entries;
  }

  static bool _isFontUrl(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'fonts.gstatic.com' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      uri.path.endsWith('.ttf');

  Future<List<GoogleFontEntry>> loadCatalog({bool refresh = false}) async {
    final dir = await _directory();
    final cache = File('${dir.path}/catalog.json');
    List<GoogleFontEntry>? cached;
    try {
      if (await cache.length() <= _catalogMaxBytes) {
        cached = parseCatalog(await cache.readAsString());
        final age = DateTime.now().difference(await cache.lastModified());
        if (!refresh && age < const Duration(days: 7)) return cached;
      }
    } catch (_) {
      // Missing or corrupt cache: fetch a fresh catalog.
    }
    try {
      final bytes = await _getBytes(catalogUri, _catalogMaxBytes);
      final entries = parseCatalog(utf8.decode(bytes));
      // A failed cache write must not prevent using a valid downloaded catalog.
      final staging = await dir.createTemp('catalog-');
      try {
        await File(
          '${staging.path}/catalog.json',
        ).writeAsBytes(bytes, flush: true);
        await File('${staging.path}/catalog.json').rename(cache.path);
      } on FileSystemException {
        // The catalog can still be used for this session.
      } finally {
        await staging.delete(recursive: true);
      }
      return entries;
    } catch (_) {
      if (!refresh && cached != null) return cached;
      rethrow;
    }
  }

  Future<DownloadedGoogleFont> download(
    GoogleFontEntry font, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (!_isFontUrl(font.url) || font.packageName.isEmpty) {
      throw const FormatException('Invalid font URL');
    }
    final dir = await (await _directory()).createTemp('download-');
    try {
      final licenseUri = Uri.https(
        'raw.githubusercontent.com',
        '/expo/google-fonts/main/font-packages/${font.packageName}/LICENSE_FONT',
      );
      final license = utf8.decode(await _getBytes(licenseUri, 256 * 1024));
      if (license.trim().isEmpty || license.trimLeft().startsWith('<')) {
        throw const FormatException('Invalid font license');
      }
      final bytes = await _getBytes(
        font.url,
        _fontMaxBytes,
        onProgress: onProgress,
      );
      if (bytes.length < 4 ||
          !(bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0 ||
              ascii.decode(bytes.sublist(0, 4), allowInvalid: true) ==
                  'OTTO')) {
        throw const FormatException('Invalid font file');
      }
      final file = File('${dir.path}/${font.packageName}.ttf');
      await file.writeAsBytes(bytes, flush: true);
      return DownloadedGoogleFont(file: file, license: license);
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<Uint8List> _getBytes(
    Uri uri,
    int maxBytes, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (_closed.isCompleted) throw http.RequestAbortedException(uri);
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: Future.any([_closed.future, abort.future]),
    )..followRedirects = false;
    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      // Native HTTP clients decompress gzip while retaining the encoded length.
      final encoding = response.headers['content-encoding'];
      final total = encoding == null || encoding == 'identity'
          ? response.contentLength
          : null;
      if (total != null && total > maxBytes) {
        await response.stream.listen(null).cancel();
        throw const FormatException('Font response too large');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Font response too large');
        }
        bytes.add(chunk);
        onProgress?.call(bytes.length, total);
      }
      if (total != null && total != bytes.length) {
        throw const FormatException('Incomplete font response');
      }
      return bytes.takeBytes();
    } finally {
      // Cancel the actual transport after timeout, rejection, or stream failure.
      abort.complete();
    }
  }

  void close() {
    if (!_closed.isCompleted) _closed.complete();
    _client.close();
  }
}
