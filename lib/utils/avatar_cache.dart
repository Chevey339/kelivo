import 'dart:io';
import 'package:http/http.dart' as http;
import './app_directories.dart';

class AvatarCache {
  AvatarCache._();

  static final Map<String, String?> _memo = <String, String?>{};

  static void clearMemory() {
    _memo.clear();
  }

  static Future<Directory> _cacheDir() async {
    return await AppDirectories.getAvatarCacheDirectory();
  }

  static String _safeName(String url) {
    // Use 64-bit FNV-1a hash to avoid collisions from common URL prefixes
    int h = 0xcbf29ce484222325; // FNV offset basis
    const int prime = 0x100000001b3; // FNV prime
    for (final c in url.codeUnits) {
      h ^= c;
      h = (h * prime) & 0xFFFFFFFFFFFFFFFF; // keep 64-bit
    }
    final hex = h.toRadixString(16).padLeft(16, '0');
    // Attempt to keep a reasonable extension (may help some platforms)
    final uri = Uri.tryParse(url);
    String ext = 'img';
    if (uri != null) {
      final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.toLowerCase() : '';
      final m = RegExp(r"\.(png|jpg|jpeg|webp|gif|bmp|ico)").firstMatch(seg);
      if (m != null) ext = m.group(1)!;
    }
    return 'av_$hex.$ext';
  }

  /// Ensures avatar at [url] is cached locally and returns the file path.
  /// On failure, returns null.
  static Future<String?> getPath(String url) async {
    if (url.isEmpty) return null;
    if (_memo.containsKey(url)) {
      final cached = _memo[url];
      if (cached == null) return null;
      try {
        final f = File(cached);
        if (await f.exists()) return cached;
      } catch (_) {}
      // Stale entry: file was deleted; re-resolve.
      _memo.remove(url);
    }
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final name = _safeName(url);
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        _memo[url] = file.path;
        return file.path;
      }
      // Download and save
      final res = await http.get(Uri.parse(url));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await file.writeAsBytes(res.bodyBytes, flush: true);
        _memo[url] = file.path;
        return file.path;
      }
    } catch (_) {}
    _memo[url] = null;
    return null;
  }

  static Future<void> evict(String url) async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return;
      final name = _safeName(url);
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _memo.remove(url);
  }
}
