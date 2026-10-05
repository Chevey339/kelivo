import 'package:path/path.dart' as p;

/// Logical URI for managed app-local files.
///
/// Wire form: `kelivo-file:///<root>/<relative...>`
/// where `<root>` ∈ { upload, images, avatars, fonts }.
///
/// Pure/lexical — no filesystem I/O (`dart:io` is forbidden). Roots are
/// injected by the caller.
final class KelivoFileUri {
  KelivoFileUri._();

  static const String _scheme = 'kelivo-file';
  static const String _prefix = '$_scheme:';
  static const String _head = '$_scheme:///';

  static const List<String> _managedRoots = [
    'upload',
    'images',
    'avatars',
    'fonts',
    'drafts',
  ];

  /// Cheap prefix check. Does **not** validate structure.
  static bool isKelivoFileUri(String value) => value.startsWith(_prefix);

  /// Strict decode. Returns `['upload','foo.png']` or `null` if invalid.
  static List<String>? decodeToSegments(String uri) {
    // Require empty authority: `kelivo-file:///...`.
    // Rejects `kelivo-file://host/...` and `kelivo-file:/...`.
    if (!uri.startsWith(_head)) return null;
    final rest = uri.substring(_head.length);
    if (rest.isEmpty) return null;
    // Reject query/fragment without Uri.parse normalization side effects.
    if (rest.contains('?') || rest.contains('#')) return null;
    // Reject host form already covered by _head, and empty segments / dots
    // before percent-decoding so `images/./a` cannot be normalized away.
    final rawParts = rest.split('/');
    if (rawParts.any((s) => s.isEmpty)) return null;

    final segments = <String>[];
    for (final raw in rawParts) {
      if (raw == '.' || raw == '..') return null;
      late final String decoded;
      try {
        decoded = Uri.decodeComponent(raw);
      } on ArgumentError {
        return null;
      } on FormatException {
        return null;
      }
      if (decoded.isEmpty || decoded == '.' || decoded == '..') return null;
      if (decoded.contains('/') || decoded.contains('\\')) return null;
      segments.add(decoded);
    }
    if (segments.length < 2) return null;
    if (!_isManaged(segments.first)) return null;
    return List<String>.unmodifiable(segments);
  }

  /// Resolve against an absolute app-data [root]. No existence checks.
  /// Returns `null` when [uri] is not a valid kelivo-file URI.
  static String? resolveToAbsolute(String uri, {required String root}) {
    final segments = decodeToSegments(uri);
    if (segments == null) return null;
    final ctx = _contextFor(root);
    return ctx.joinAll([root, ...segments]);
  }

  /// Encode an absolute path under `[root]/<managed>/...`.
  /// Returns `null` for external / unmanaged paths.
  ///
  /// Segments containing `\` are rejected so the encoder never emits a URI
  /// that [decodeToSegments] cannot round-trip.
  /// Managed roots are lowercased on the wire (`Images` → `images`).
  static String? encodeFromAbsolute(String abs, {required String root}) {
    // Reject POSIX backslash filenames before path normalization can reinterpret
    // them on Windows-style contexts.
    final looksWindows =
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(abs) ||
        root.contains('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(root);
    if (!looksWindows && abs.contains('\\')) return null;

    final ctx = _contextFor(root);
    final normalizedAbs = ctx.normalize(abs);
    final normalizedRoot = ctx.normalize(root);
    // Windows roots compare case-insensitively via Style.windows.
    if (!ctx.isWithin(normalizedRoot, normalizedAbs)) return null;

    final rel = ctx.relative(normalizedAbs, from: normalizedRoot);
    final parts = ctx.split(rel).where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return null;
    final managed = parts.first.toLowerCase();
    if (!_isManaged(managed)) return null;
    parts[0] = managed;
    for (final part in parts) {
      if (part == '.' || part == '..') return null;
      if (part.contains('\\')) return null;
    }
    return _encodeSegments(parts);
  }

  /// Known production bundle / package identifiers that own managed roots.
  /// Substring matches (e.g. `com.other.kelivo.notes`) are intentionally
  /// rejected — only exact whitelist entries count.
  static const Set<String> _knownBundleIds = {
    'com.psyche.kelivo',
    'psyche.kelivo',
  };

  /// Windows AppData folder name (Flutter BINARY_NAME). Compared
  /// case-insensitively as a whole segment — not a substring.
  static const String _windowsAppFolder = 'kelivo';

  static final RegExp _iosUuid = RegExp(
    r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
  );

  /// Best-effort conversion of a legacy absolute sandbox path into a
  /// kelivo-file URI. Marker order (strict platform sandboxes only):
  /// 1. iOS device `/var/mobile/...` (path-start anchored)
  /// 2. iOS Simulator `/Users/.../CoreSimulator/...` (path-start anchored)
  /// 3. macOS Kelivo container Documents (exact bundle whitelist)
  /// 4. macOS/Linux Application Support / `.local/share` (exact whitelist)
  /// 5. Windows `AppData\Local|Roaming\[com.psyche\]kelivo`
  /// 6. Android package-private app_flutter / files (exact package whitelist)
  /// 7. Generic fallback: first `/<managed>/` occurrence
  ///    (disabled when [allowGenericFallback] is false)
  ///
  /// Purely lexical — no `existsSync`. UNC/SMB rejected. Every platform
  /// matcher is anchored at the start of the portable path so nested archive
  /// copies (`/tmp/archive/...`) cannot be claimed as live sandboxes.
  static String? tryEncodeLegacyAbsolutePath(
    String abs, {
    bool allowGenericFallback = true,
  }) {
    if (abs.isEmpty) return null;
    final portable = toPortableSlashPath(abs);
    if (portable == null) return null;
    final raw = portable;

    const subdirs = ['avatars', 'fonts', 'images', 'upload'];
    String? tail; // starts with '/managed/...'

    // iOS device — must begin at /var/mobile/...
    final iosDevice = RegExp(
      r'^/var/mobile/Containers/Data/Application/([^/]+)/Documents/',
      caseSensitive: false,
    ).firstMatch(raw);
    if (iosDevice != null && _iosUuid.hasMatch(iosDevice.group(1)!)) {
      tail = _normalizeManagedTail('/${raw.substring(iosDevice.end)}', subdirs);
    }

    // iOS Simulator — full home-rooted CoreSimulator path from the start.
    if (tail == null) {
      final iosSim = RegExp(
        r'^/Users/[^/]+/Library/Developer/CoreSimulator/Devices/'
        r'([^/]+)/data/Containers/Data/Application/([^/]+)/Documents/',
        caseSensitive: false,
      ).firstMatch(raw);
      if (iosSim != null &&
          _iosUuid.hasMatch(iosSim.group(1)!) &&
          _iosUuid.hasMatch(iosSim.group(2)!)) {
        tail = _normalizeManagedTail('/${raw.substring(iosSim.end)}', subdirs);
      }
    }

    // macOS Kelivo app container Documents (exact bundle id).
    if (tail == null) {
      final macContainer = RegExp(
        r'^/Users/[^/]+/Library/Containers/([^/]+)/Data/Documents/',
        caseSensitive: false,
      ).firstMatch(raw);
      if (macContainer != null && _isKnownBundleId(macContainer.group(1)!)) {
        tail = _normalizeManagedTail(
          '/${raw.substring(macContainer.end)}',
          subdirs,
        );
      }
    }

    // macOS/Linux Application Support / .local/share Kelivo root.
    if (tail == null) {
      final support = RegExp(
        r'^/(?:Users/[^/]+/Library/Application Support|'
        r'home/[^/]+/\.local/share)/([^/]+)/',
        caseSensitive: false,
      ).firstMatch(raw);
      if (support != null && _isKnownBundleId(support.group(1)!)) {
        tail = _normalizeManagedTail('/${raw.substring(support.end)}', subdirs);
      }
    }

    // Windows: C:/Users/<user>/AppData/Local|Roaming/[com.psyche/]<Kelivo>/...
    // Folder name must equal "kelivo" case-insensitively (not KelivoNotes).
    if (tail == null) {
      final win = RegExp(
        r'^[A-Za-z]:/Users/[^/]+/AppData/(?:Local|Roaming)/'
        r'(?:com\.psyche/)?([^/]+)/',
        caseSensitive: false,
      ).firstMatch(raw);
      if (win != null && win.group(1)!.toLowerCase() == _windowsAppFolder) {
        tail = _normalizeManagedTail('/${raw.substring(win.end)}', subdirs);
      }
    }

    // Android package-private app_flutter
    if (tail == null) {
      final flutter = RegExp(
        r'^/(?:data/user/\d+|data/data)/([^/]+)/app_flutter/',
        caseSensitive: false,
      ).firstMatch(raw);
      if (flutter != null && _isKnownBundleId(flutter.group(1)!)) {
        tail = _normalizeManagedTail('/${raw.substring(flutter.end)}', subdirs);
      }
    }

    // Android package-private files
    if (tail == null) {
      final files = RegExp(
        r'^/(?:(?:data/user/\d+|data/data)/([^/]+)/files/|'
        r'storage/emulated/\d+/Android/data/([^/]+)/files/)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (files != null) {
        final pkg = files.group(1) ?? files.group(2)!;
        if (_isKnownBundleId(pkg)) {
          tail = _normalizeManagedTail('/${raw.substring(files.end)}', subdirs);
        }
      }
    }

    if (tail == null && allowGenericFallback) {
      final lower = raw.toLowerCase();
      for (final s in subdirs) {
        final i = lower.indexOf('/$s/');
        if (i != -1) {
          tail = _normalizeManagedTail(raw.substring(i), subdirs);
          break;
        }
      }
    }

    if (tail == null) return null;

    final trimmed = tail.startsWith('/') ? tail.substring(1) : tail;
    final parts = trimmed.split('/');
    if (parts.length < 2) return null;
    if (parts.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
    if (!_isManaged(parts.first)) return null;
    return _encodeSegments(parts);
  }

  static bool _isKnownBundleId(String value) =>
      _knownBundleIds.contains(value.toLowerCase());

  /// Convert an absolute / file URI into a portable slash path for matching.
  ///
  /// Returns `null` for UNC/SMB / empty inputs. Windows drive paths keep the
  /// `C:/...` form; POSIX backslash filenames are rejected.
  ///
  /// Uses the URI path (always `/`) for `file:` inputs so a Windows host can
  /// still recognize iOS `file:///var/mobile/...` sandbox markers.
  static String? toPortableSlashPath(String abs) {
    if (abs.isEmpty) return null;
    var value = abs;
    if (value.toLowerCase().startsWith('file:')) {
      try {
        final parsed = Uri.parse(value);
        if (parsed.scheme.toLowerCase() != 'file') return null;
        final host = parsed.host.toLowerCase();
        if (host.isNotEmpty && host != 'localhost') return null;
        value = Uri.decodeComponent(parsed.path);
        if (value.startsWith('/') &&
            value.length >= 3 &&
            RegExp(r'^/[A-Za-z]:').hasMatch(value)) {
          // file:///C:/Users/... → C:/Users/...
          value = value.substring(1);
        }
      } catch (_) {
        return null;
      }
    }

    if (value.startsWith(r'\\') || value.startsWith('//')) return null;

    final looksWindows = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
    if (looksWindows) {
      return value.replaceAll('\\', '/');
    }
    if (value.contains('\\')) return null;
    return value;
  }

  static String? _normalizeManagedTail(
    String candidateTail,
    List<String> subdirs,
  ) {
    var tail = candidateTail;
    if (!tail.startsWith('/')) tail = '/$tail';
    final lower = tail.toLowerCase();
    for (final s in subdirs) {
      if (lower.startsWith('/$s/')) {
        // Preserve filename/relative case after the managed root.
        return '/$s${tail.substring(1 + s.length)}';
      }
    }
    return null;
  }

  static String _encodeSegments(List<String> parts) {
    final encoded = parts.map(Uri.encodeComponent).join('/');
    return '$_scheme:///$encoded';
  }

  static bool _isManaged(String value) => _managedRoots.contains(value);

  static p.Context _contextFor(String root) {
    if (root.contains('\\') || RegExp(r'^[A-Za-z]:').hasMatch(root)) {
      return p.Context(style: p.Style.windows);
    }
    return p.Context(style: p.Style.posix);
  }
}
