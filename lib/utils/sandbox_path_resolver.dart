import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import './app_directories.dart';
import './kelivo_file_uri.dart';

/// Resolves persisted absolute file paths that include the iOS sandbox UUID
/// to the current app container path after an app update.
///
/// Example:
///   Before update: /var/mobile/Containers/Data/Application/ABC/Documents/upload/x.png
///   After update:  /var/mobile/Containers/Data/Application/XYZ/Documents/upload/x.png
///
/// We store absolute paths in message content. On iOS, the container prefix
/// changes after update. This helper rewrites any path that points into our
/// previous container's Documents subfolders (upload/avatars) to the current
/// Documents directory. If the rewritten file exists, it returns the new path;
/// otherwise returns the original path.
///
/// Canonical `kelivo-file:///` URIs are resolved lexically against the cached
/// Documents root with no filesystem existence checks.
class SandboxPathResolver {
  SandboxPathResolver._();

  static String? _docsDir;
  static String? _supportDir;
  static bool debug = false;

  /// Call once during app startup to cache the current Documents directory.
  static Future<void> init() async {
    try {
      // Use the platform-specific app data directory
      final dir = await AppDirectories.getAppDataDirectory();
      _docsDir = dir.path;
      try {
        final sup = await getApplicationSupportDirectory();
        _supportDir = sup.path;
      } catch (_) {
        _supportDir = null;
      }
      if (debug) {
        debugPrint(
          '[SandboxPathResolver.init] docsDir=$_docsDir supportDir=$_supportDir',
        );
      }
    } catch (_) {
      // Leave null; fix() will no-op in this case.
      _docsDir = null;
      _supportDir = null;
    }
  }

  /// Test-only seam to inject Documents / Support roots without `path_provider`.
  @visibleForTesting
  static void debugSetDirs({String? docsDir, String? supportDir}) {
    _docsDir = docsDir;
    _supportDir = supportDir;
  }

  /// Synchronously map an old absolute path to the current container's path
  /// when it points under our managed subfolders (upload/images/avatars).
  /// If mapping succeeds and the target exists, returns the mapped path;
  /// otherwise returns [path] unchanged.
  ///
  /// Canonical `kelivo-file:` URIs are resolved without existence probes.
  static String fix(String path) {
    if (path.isEmpty) return path;

    if (KelivoFileUri.isKelivoFileUri(path)) {
      final docs = _docsDir;
      if (docs == null || docs.isEmpty) return path;
      return KelivoFileUri.resolveToAbsolute(path, root: docs) ?? path;
    }

    // Decode file:// percent-escapes before remapping (avoid %20 → %2520).
    // Non-local / UNC file: URIs must not be remapped or probed (SMB risk).
    final String raw0 = _decodeFileUri(path);
    if (raw0 == path && path.toLowerCase().startsWith('file:')) return path;
    if (_isUncPath(raw0)) return path;
    // Only Windows drive paths normalize `\`; POSIX backslash filenames stay.
    final String raw = _normalizeSeparatorsForMatch(raw0);
    if (_isUncPath(raw)) return path;

    final docs = _docsDir;
    final support = _supportDir;
    if (docs == null || docs.isEmpty) return raw;

    // Determine root and tail to map. Prefer the same structured sandbox
    // markers as KelivoFileUri.tryEncodeLegacyAbsolutePath, then generic.
    const subdirs = ['avatars', 'fonts', 'images', 'upload', 'drafts'];
    String? tail; // starts with '/'
    String rootType = 'unknown';

    final encoded = KelivoFileUri.tryEncodeLegacyAbsolutePath(
      raw,
      allowGenericFallback: false,
    );
    if (encoded != null) {
      final segs = KelivoFileUri.decodeToSegments(encoded);
      if (segs != null && segs.isNotEmpty) {
        tail = '/${segs.join('/')}';
        rootType = 'structured_legacy';
      }
    }

    // Final generic fallback: detect '/avatars/' '/images/' '/upload/' anywhere
    // (runtime recovery only — canonicalize never uses this path).
    if (tail == null) {
      for (final s in subdirs) {
        final i = raw.indexOf('/$s/');
        if (i != -1) {
          tail = raw.substring(i); // includes leading '/'
          rootType = 'generic_subdir';
          break;
        }
      }
    }

    if (tail == null) {
      if (debug) {
        debugPrint(
          '[SandboxPathResolver.fix] input=$path -> skipped (no known subdir pattern found)',
        );
      }
      return raw;
    }

    // Primary: map to current ApplicationDocumentsDirectory
    final String mapped = '$docs$tail';
    try {
      if (File(mapped).existsSync()) {
        if (debug) {
          debugPrint(
            '[SandboxPathResolver.fix] root=$rootType input=$path -> mappedDocs=$mapped (exists)',
          );
        }
        return mapped;
      } else {
        if (debug) {
          debugPrint(
            '[SandboxPathResolver.fix] root=$rootType tried mappedDocs=$mapped (missing)',
          );
        }
      }
    } catch (e) {
      if (debug) {
        debugPrint(
          '[SandboxPathResolver.fix] root=$rootType mappedDocs error: $e',
        );
      }
    }

    // Secondary: try ApplicationSupportDirectory
    if (support != null && support.isNotEmpty) {
      final alt = '$support$tail';
      try {
        if (File(alt).existsSync()) {
          if (debug) {
            debugPrint(
              '[SandboxPathResolver.fix] root=$rootType input=$path -> mappedSupport=$alt (exists)',
            );
          }
          return alt;
        } else {
          if (debug) {
            debugPrint(
              '[SandboxPathResolver.fix] root=$rootType tried mappedSupport=$alt (missing)',
            );
          }
        }
      } catch (e) {
        if (debug) {
          debugPrint(
            '[SandboxPathResolver.fix] root=$rootType mappedSupport error: $e',
          );
        }
      }
    }

    // Fallback: search by basename under common folders in both roots
    final String base = _basename(tail);
    for (final root in <String?>[docs, support]) {
      if (root == null || root.isEmpty) continue;
      for (final sub in const [
        'avatars',
        'fonts',
        'images',
        'upload',
        'drafts',
      ]) {
        final probe = '$root/$sub/$base';
        try {
          if (File(probe).existsSync()) {
            if (debug) {
              debugPrint(
                '[SandboxPathResolver.fix] root=$rootType input=$path -> basenameProbe=$probe (exists)',
              );
            }
            return probe;
          } else {
            if (debug) {
              debugPrint(
                '[SandboxPathResolver.fix] root=$rootType tried basenameProbe=$probe (missing)',
              );
            }
          }
        } catch (e) {
          if (debug) {
            debugPrint(
              '[SandboxPathResolver.fix] root=$rootType basenameProbe error: $e',
            );
          }
        }
      }
    }
    if (debug) {
      debugPrint(
        '[SandboxPathResolver.fix] root=$rootType input=$path -> unchanged=$raw (no match)',
      );
    }
    return raw;
  }

  static String _basename(String p) {
    if (p.isEmpty) return p;
    final norm = _looksLikeWindowsDrivePath(p) ? p.replaceAll('\\', '/') : p;
    final i = norm.lastIndexOf('/');
    return i == -1 ? norm : norm.substring(i + 1);
  }

  /// Convert a local absolute path (or `file://` URL) into a stable
  /// `kelivo-file:///` URI when it points under managed app storage.
  ///
  /// Remote (`http`/`https`), `data:`, and already-canonical kelivo-file URIs
  /// pass through unchanged. External absolute paths that cannot be encoded
  /// are returned as-is (after decoding an optional local `file://` prefix).
  ///
  /// Encoding never uses the generic `/images/`·`/upload/` guess. Structured
  /// sandbox markers (`Documents` / `kelivo` / `app_flutter`·`files`) are
  /// still recognized after [encodeFromAbsolute] fails, so old container
  /// UUID paths canonicalize even when [_docsDir] is already set.
  static String canonicalize(String uri) {
    if (uri.isEmpty) return uri;
    if (KelivoFileUri.isKelivoFileUri(uri)) return uri;
    // Case-insensitive: HTTPS://… must not fall into local-path heuristics.
    final lower = uri.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:')) {
      return uri;
    }

    // Portable slash path for legacy matching (Windows must still recognize
    // iOS file:///var/mobile/... markers; Uri.toFilePath is host-specific).
    final portable = KelivoFileUri.toPortableSlashPath(uri);
    if (portable == null) {
      // Non-local file: / UNC / empty — leave unchanged.
      return uri;
    }

    final docs = _docsDir;
    if (docs != null && docs.isNotEmpty) {
      // Prefer encode under the live root (case-insensitive on Windows).
      final underRoot = KelivoFileUri.encodeFromAbsolute(portable, root: docs);
      if (underRoot != null) return underRoot;
      // Also try host-native absolute form when docsDir uses backslashes.
      final native = _decodeFileUri(uri);
      if (native != portable) {
        final underNative = KelivoFileUri.encodeFromAbsolute(
          native,
          root: docs,
        );
        if (underNative != null) return underNative;
      }
      return KelivoFileUri.tryEncodeLegacyAbsolutePath(
            portable,
            allowGenericFallback: false,
          ) ??
          portable;
    }
    return KelivoFileUri.tryEncodeLegacyAbsolutePath(
          portable,
          allowGenericFallback: false,
        ) ??
        portable;
  }

  /// Restore-boundary remap: if [uri] is a known previous managed sandbox
  /// absolute path and the corresponding file exists under the current docs
  /// root (because backup files were copied), return the kelivo-file URI.
  ///
  /// Does **not** reopen generic `/images/` fallback for arbitrary external
  /// paths that merely share a basename with a restored file.
  static String? tryRemapRestoredManagedAbsolute(String uri) {
    final docs = _docsDir;
    if (docs == null || docs.isEmpty) return null;
    if (KelivoFileUri.isKelivoFileUri(uri)) return uri;
    final lower = uri.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:')) {
      return null;
    }
    final portable = KelivoFileUri.toPortableSlashPath(uri);
    if (portable == null) return null;

    final encoded = KelivoFileUri.tryEncodeLegacyAbsolutePath(
      portable,
      allowGenericFallback: false,
    );
    if (encoded == null) return null;
    final abs = KelivoFileUri.resolveToAbsolute(encoded, root: docs);
    if (abs == null) return null;
    try {
      if (File(abs).existsSync()) return encoded;
    } catch (_) {}
    return null;
  }

  /// Decode a local `file:` URI to a filesystem path.
  ///
  /// Returns `null` for UNC/SMB / non-local hosts (`file://server/share/...`)
  /// so callers never turn assistant markdown into network file I/O.
  static String? tryDecodeLocalFileUri(String value) {
    final lower = value.toLowerCase();
    if (!lower.startsWith('file:')) return null;
    try {
      final parsed = Uri.parse(value);
      if (parsed.scheme.toLowerCase() != 'file') return null;
      final host = parsed.host.toLowerCase();
      // Non-local hosts (SMB/UNC via file://server/...) are rejected.
      if (host.isNotEmpty && host != 'localhost') return null;
      // Dart's toFilePath rejects file://localhost/... on non-Windows; drop
      // the authority first. Empty-host UNC forms (file:////server/share)
      // still decode to //server/... and are rejected below.
      final local = host.isEmpty
          ? parsed
          : Uri(scheme: 'file', path: parsed.path);
      final path = local.toFilePath();
      if (_isUncPath(path)) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Resolve [path] for local file I/O without [fix]'s generic `/images/` or
  /// basename probe (those can alias a missing external path onto a
  /// same-named managed file).
  ///
  /// Returns `null` when [path] is a non-local `file:` URI.
  static String? resolveForIo(String path) {
    if (path.isEmpty) return path;
    if (KelivoFileUri.isKelivoFileUri(path)) return fix(path);

    var candidate = path;
    if (path.toLowerCase().startsWith('file:')) {
      final decoded = tryDecodeLocalFileUri(path);
      if (decoded == null) return null;
      candidate = decoded;
    }
    if (_isUncPath(candidate)) return null;

    try {
      if (File(candidate).existsSync()) return candidate;
    } catch (_) {}

    final remapped = _remapStructuredIfExists(candidate);
    return remapped ?? candidate;
  }

  /// Whether [path] refers to an existing local file, using [resolveForIo].
  static bool localFileExists(String path) {
    final resolved = resolveForIo(path);
    if (resolved == null) return false;
    try {
      return File(resolved).existsSync();
    } catch (_) {
      return false;
    }
  }

  static String? _remapStructuredIfExists(String abs) {
    final docs = _docsDir;
    if (docs == null || docs.isEmpty) return null;
    final uri = KelivoFileUri.tryEncodeLegacyAbsolutePath(
      abs,
      allowGenericFallback: false,
    );
    if (uri == null) return null;
    final mapped = KelivoFileUri.resolveToAbsolute(uri, root: docs);
    if (mapped == null) return null;
    try {
      if (File(mapped).existsSync()) return mapped;
    } catch (_) {}
    return null;
  }

  /// Decode a `file:` URI for path remapping. Non-file inputs unchanged.
  /// Non-local/UNC `file:` URIs are returned unchanged (not decoded).
  static String _decodeFileUri(String value) {
    final lower = value.toLowerCase();
    if (!lower.startsWith('file:')) return value;
    return tryDecodeLocalFileUri(value) ?? value;
  }

  static bool _isUncPath(String path) =>
      path.startsWith(r'\\') || path.startsWith('//');

  static bool _looksLikeWindowsDrivePath(String path) =>
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  /// Convert `\` → `/` only for Windows drive paths. POSIX keeps `\`.
  static String _normalizeSeparatorsForMatch(String path) {
    if (_looksLikeWindowsDrivePath(path)) {
      return path.replaceAll('\\', '/');
    }
    return path;
  }

  // Expose current dirs for diagnostic purposes
  static String? get docsDir => _docsDir;
  static String? get supportDir => _supportDir;
}
