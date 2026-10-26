import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import './app_directories.dart';

class AvatarCache {
  AvatarCache._();

  static final Map<String, String?> _memo = <String, String?>{};
  static final Map<String, Future<String?>> _pending = {};
  static final _changes = ValueNotifier<int>(0);
  static Listenable get changes => _changes;
  static int get revision => _changes.value;
  static Future<void>? _diskQueue;

  // Downloads run concurrently; only short file operations and cache deletion
  // are ordered, so a completed old write cannot undo a clear or eviction.
  static Future<T> _onDisk<T>(Future<T> Function() action) {
    final result = (_diskQueue ?? Future<void>.value()).then((_) => action());
    late final Future<void> tail;
    tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() {
          if (identical(_diskQueue, tail)) _diskQueue = null;
        });
    _diskQueue = tail;
    return result;
  }

  static void clearMemory() {
    _memo.clear();
    _pending.clear();
    _changes.value++;
  }

  /// Invalidates in-flight loads before deleting cache files. New loads wait
  /// for [deleteFiles], and old downloads cannot repopulate the cleared cache.
  static Future<void> clearCache(Future<void> Function() deleteFiles) {
    final cleared = _onDisk(deleteFiles);
    clearMemory();
    return cleared;
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
      final seg = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.toLowerCase()
          : '';
      final m = RegExp(
        r"\.(png|jpg|jpeg|webp|gif|bmp|ico|svg)",
      ).firstMatch(seg);
      if (m != null) ext = m.group(1)!;
    }
    return 'av_$hex.$ext';
  }

  /// Synchronous cache peek: returns the locally cached file path for [url]
  /// only if it is already memoized and the file still exists on disk.
  /// Returns null when not yet resolved (caller should fall back to [getPath]).
  static String? peek(String url) {
    if (url.isEmpty) return null;
    final cached = _memo[url];
    if (cached == null) return null;
    try {
      if (File(cached).existsSync()) return cached;
    } catch (_) {}
    return null;
  }

  /// Ensures avatar at [url] is cached locally and returns the file path.
  /// On failure, returns null.
  static Future<String?> getPath(String url) {
    if (url.isEmpty) return Future.value();
    // Legacy callers still resolve in build. A failed URL should not retry on
    // every rebuild; clear/evict explicitly invalidates this result as before.
    if (_memo.containsKey(url) && _memo[url] == null) return Future.value();
    final pending = _pending[url];
    if (pending != null) return pending;
    late final Future<String?> request;
    request = _load(url, () => identical(_pending[url], request)).whenComplete(
      () {
        if (identical(_pending[url], request)) _pending.remove(url);
      },
    );
    _pending[url] = request;
    return request;
  }

  static Future<String?> _load(String url, bool Function() current) async {
    try {
      late File file;
      final cached = await _onDisk(() async {
        if (!current()) return null;
        final memo = _memo[url];
        if (memo != null && await File(memo).exists()) return memo;
        if (!current()) return null;
        final dir = await _cacheDir();
        file = File('${dir.path}/${_safeName(url)}');
        if (await file.exists() && current()) return file.path;
        return null;
      });
      if (!current()) return null;
      if (cached != null) return _memo[url] = cached;
      // Download and save
      final res = await http.get(Uri.parse(url));
      if (current() && res.statusCode >= 200 && res.statusCode < 300) {
        return await _onDisk(() async {
          if (!current()) return null;
          await file.parent.create(recursive: true);
          await file.writeAsBytes(res.bodyBytes, flush: true);
          if (!current()) return null;
          return _memo[url] = file.path;
        });
      }
    } catch (_) {}
    if (current()) _memo[url] = null;
    return null;
  }

  static Future<void> evict(String url) {
    _pending.remove(url);
    _memo.remove(url);
    final removed = _onDisk(() async {
      try {
        final dir = await _cacheDir();
        final file = File('${dir.path}/${_safeName(url)}');
        if (await file.exists()) await file.delete();
      } catch (_) {}
    });
    _changes.value++;
    return removed;
  }
}
