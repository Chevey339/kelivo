import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Content-addressed helpers for the shared upload directory.
///
/// Attachments are identified by their bytes, not by size or mtime: the
/// Android/iOS document pickers hand us a fresh copy in the app cache whose
/// modification time is the moment of the pick, so timestamps of the very same
/// physical file never match across two picks.
class UploadDedupe {
  /// Hashing this many bytes blocks long enough to drop frames, so it moves to
  /// a background isolate.
  static const int _backgroundHashThreshold = 2 * 1024 * 1024;

  /// Stored uploads that some import has resolved to, keyed by absolute path.
  ///
  /// A path lands here the moment it is opened for comparison — before the
  /// bytes are read — because on Unix the reader keeps reading happily through
  /// an unlink and would otherwise return a path that no longer exists. The
  /// mark is one-way: it only ever makes a caller keep a file it might
  /// otherwise clean up, never the reverse. [reserveUniqueFile] clears it for
  /// a freshly created path, so a name that gets deleted and later reused does
  /// not inherit a stale mark.
  static final Set<String> _shared = <String>{};

  /// Whether anything besides its creator may be pointing at [path]. A caller
  /// that wants to clean up its own copy has to leave shared files alone.
  static bool isShared(String path) => _shared.contains(_key(path));

  /// Returns the path of a stored file that carries exactly [bytes] and was
  /// saved under [fileName] (or a versioned variant such as "notes(1).txt"),
  /// or null when the file is new to [dir].
  ///
  /// The name has to match as well: callers derive the display name and the
  /// MIME type from the returned path, so "config.json" must never resolve to
  /// an identical "notes.txt".
  static Future<String?> findIdentical(
    Directory dir,
    Uint8List bytes,
    String fileName,
  ) async {
    final candidates = await _sameNameAndSize(dir, bytes.length, fileName);
    if (candidates.isEmpty) return null;
    return _firstWithDigest(candidates, await _digestOfBytes(bytes));
  }

  /// [findIdentical] for a file that was hashed as it streamed to disk, so its
  /// bytes are no longer in memory. [exclude] is the caller's own copy.
  static Future<String?> findIdenticalDigest(
    Directory dir,
    int size,
    List<int> digest,
    String fileName, {
    String? exclude,
  }) async {
    final candidates = await _sameNameAndSize(dir, size, fileName);
    if (exclude != null) {
      final key = _key(exclude);
      candidates.removeWhere((file) => _key(file.path) == key);
    }
    if (candidates.isEmpty) return null;
    return _firstWithDigest(candidates, digest);
  }

  /// Only same-named, same-sized files can match. Collecting them first keeps
  /// the common "nothing alike is stored" case free of any hashing.
  static Future<List<File>> _sameNameAndSize(
    Directory dir,
    int size,
    String fileName,
  ) async {
    if (!await dir.exists()) return <File>[];

    final files = <File>[];
    final storedNames = <String>{};
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        files.add(entity);
        storedNames.add(p.basename(entity.path));
      }
    } catch (_) {}

    final candidates = <File>[];
    for (final file in files) {
      final name = p.basename(file.path);
      // A numbered name only belongs to [fileName]'s family when we also wrote
      // the unnumbered original; otherwise "notes(1).txt" is just a file the
      // user happens to have named that way.
      final matchesName =
          name == fileName ||
          (storedNames.contains(fileName) && _isVersionOf(name, fileName));
      if (!matchesName) continue;
      try {
        final stat = await file.stat();
        if (stat.size != size) continue;
      } catch (_) {
        continue;
      }
      candidates.add(file);
    }
    return candidates;
  }

  static Future<String?> _firstWithDigest(
    List<File> candidates,
    List<int> digest,
  ) async {
    for (final candidate in candidates) {
      // Marked before the read, not after: a concurrent import must not delete
      // this file out from under the stream we are about to open.
      _shared.add(_key(candidate.path));
      try {
        final existing = await sha256.bind(candidate.openRead()).first;
        if (listEquals(existing.bytes, digest)) return candidate.path;
      } catch (_) {}
    }
    return null;
  }

  /// Creates an unused file in [dir], appending "(1)", "(2)"… to [fileName]
  /// until the exclusive create succeeds.
  static Future<File> reserveUniqueFile(Directory dir, String fileName) async {
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    var counter = 0;

    while (true) {
      final suffix = counter == 0 ? '' : '($counter)';
      final candidate = File(p.join(dir.path, '$base$suffix$ext'));
      try {
        final created = await candidate.create(exclusive: true);
        // The path was free a moment ago, so nothing can be pointing at it and
        // any mark left over from a deleted namesake is stale.
        _shared.remove(_key(created.path));
        return created;
      } on FileSystemException {
        if (!await candidate.exists()) rethrow;
        counter++;
      }
    }
  }

  /// True when [candidateName] is a versioned variant of [fileName], e.g.
  /// "notes(2).txt" for "notes.txt".
  static bool _isVersionOf(String candidateName, String fileName) {
    if (p.extension(candidateName) != p.extension(fileName)) return false;
    final base = p.basenameWithoutExtension(fileName);
    final candidateBase = p.basenameWithoutExtension(candidateName);
    if (!candidateBase.startsWith(base)) return false;
    final suffix = candidateBase.substring(base.length);
    return RegExp(r'^\(\d+\)$').hasMatch(suffix);
  }

  static Future<List<int>> _digestOfBytes(Uint8List bytes) async {
    if (bytes.length >= _backgroundHashThreshold) {
      return compute(_sha256Bytes, bytes);
    }
    return _sha256Bytes(bytes);
  }

  static String _key(String path) => p.normalize(p.absolute(path));
}

List<int> _sha256Bytes(Uint8List bytes) => sha256.convert(bytes).bytes;

/// Outcome of storing a picked file in the upload directory.
class UploadWrite {
  const UploadWrite(this.path, {required this.reused});

  final String path;

  /// True when [path] is a file that already existed in the upload directory.
  /// Such a file may be referenced by earlier messages, so a caller that
  /// discards its own draft must not delete it.
  final bool reused;
}
