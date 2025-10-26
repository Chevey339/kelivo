import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class AvatarCache {
  AvatarCache._();

  static final Map<String, String?> _memo = <String, String?>{};

  static Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/cache/avatars');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _safeName(String url) {
    // JS 的 int 是 53-bit 安全整数，不能精确表示 64-bit 常量；
    // 这里改用 Dart 自带的 hash 工具，避免 Web 上的溢出问题。
    final int h = Object.hashAll(url.codeUnits);
    final hex = h.toUnsigned(32).toRadixString(16).padLeft(8, '0');
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

  /// Ensures avatar at [url] is cached.
  /// - On native: returns local file path
  /// - On web: returns data URL (data:image/...;base64,xxxx)
  /// On failure, returns null.
  static Future<String?> getPath(String url) async {
    if (url.isEmpty) return null;
    if (_memo.containsKey(url)) return _memo[url];
    try {
      // Download and save
      final res = await http.get(Uri.parse(url));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (kIsWeb) {
          final mime = _inferMimeFromUrl(url) ?? 'image/png';
          final b64 = base64Encode(res.bodyBytes);
          final dataUrl = 'data:$mime;base64,$b64';
          _memo[url] = dataUrl;
          return dataUrl;
        } else {
          final dir = await _cacheDir();
          final name = _safeName(url);
          final file = File('${dir.path}/$name');
          await file.writeAsBytes(res.bodyBytes, flush: true);
          _memo[url] = file.path;
          return file.path;
        }
      }
    } catch (_) {}
    _memo[url] = null;
    return null;
  }

  static Future<void> evict(String url) async {
    try {
      if (!kIsWeb) {
        final dir = await _cacheDir();
        final name = _safeName(url);
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    _memo.remove(url);
  }

  static String? _inferMimeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.ico')) return 'image/x-icon';
    return 'image/png';
  }
}
