import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../workspace/file_link_resolver.dart';

/// App wiring resolves the tab owner's binding, never the foreground chat.
class BrowserWorkspaceResources {
  static final instance = BrowserWorkspaceResources();
  Future<Directory?> Function(String sessionId)? rootForSession;

  static bool isWorkspaceUrl(String value) {
    if (KelivoLink.tryParse(value)?.kind != KelivoLinkKind.workspaceFile) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'kelivo' &&
        uri.host == 'workspace' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        _segments(uri) != null;
  }

  static List<String>? _segments(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.any(
      (s) =>
          s == '..' ||
          s == '.' ||
          s.contains('/') ||
          s.contains(r'\') ||
          s.contains(':') ||
          s.contains('\u0000'),
    )) {
      return null;
    }
    return segments.where((s) => s.isNotEmpty).toList();
  }

  Future<BrowserWorkspaceScope> scope(String? sessionId) async {
    if (sessionId == null || rootForSession == null) {
      throw StateError('browser_workspace_not_bound');
    }
    final directory = await rootForSession!(sessionId);
    if (directory == null) throw StateError('browser_workspace_not_bound');
    final root = await directory.resolveSymbolicLinks();
    final host =
        'ws-${sha256.convert(utf8.encode('$sessionId\n$root')).toString().substring(0, 32)}.kelivo.invalid';
    return BrowserWorkspaceScope._(this, sessionId, root, host);
  }
}

class BrowserWorkspaceScope {
  BrowserWorkspaceScope._(this.resources, this.sessionId, this.root, this.host);
  final BrowserWorkspaceResources resources;
  final String sessionId, root, host;
  bool _closed = false;
  Future<void> _reads = Future<void>.value();
  static const maxResourceBytes = 16 * 1024 * 1024;

  Uri internalUrl(String publicUrl, {required bool android}) {
    if (!BrowserWorkspaceResources.isWorkspaceUrl(publicUrl)) {
      throw const FormatException('Invalid workspace URL');
    }
    return Uri.parse(
      publicUrl,
    ).replace(scheme: android ? 'https' : 'kelivo', host: host);
  }

  bool owns(Uri uri) =>
      uri.host == host &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      (uri.scheme == 'kelivo' || uri.scheme == 'https');

  String publicUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && owns(uri)
        ? uri.replace(scheme: 'kelivo', host: 'workspace').toString()
        : value;
  }

  Future<File> file(Uri uri) async {
    if (_closed ||
        !(owns(uri) ||
            BrowserWorkspaceResources.isWorkspaceUrl(uri.toString()))) {
      throw StateError('browser_workspace_access_denied');
    }
    final current = await resources.rootForSession?.call(sessionId);
    if (current == null || await current.resolveSymbolicLinks() != root) {
      throw StateError('browser_workspace_binding_changed');
    }
    final segments = BrowserWorkspaceResources._segments(uri);
    if (segments == null) throw StateError('browser_workspace_access_denied');
    final path = p.joinAll([
      root,
      ...segments,
      if (segments.isEmpty || uri.path.endsWith('/')) 'index.html',
    ]);
    final resolved = await File(path).resolveSymbolicLinks();
    if (!p.isWithin(root, resolved) || _closed) {
      throw StateError('browser_workspace_access_denied');
    }
    return File(resolved);
  }

  /// Serialize local reads to bound transient image buffers. There is no
  /// polling, renderer creation, directory copy or long-lived byte cache.
  Future<({Uint8List bytes, String mime})?> read(Uri uri) {
    final result = _reads.then((_) async {
      RandomAccessFile? handle;
      try {
        final target = await file(uri);
        final mime = _mime(p.extension(target.path).toLowerCase());
        if (mime == null) return null;
        handle = await target.open();
        final length = await handle.length();
        if (length > maxResourceBytes || _closed) return null;
        final bytes = await handle.read(length);
        return _closed ? null : (bytes: bytes, mime: mime);
      } on FileSystemException {
        return null;
      } on StateError {
        return null;
      } finally {
        await handle?.close();
      }
    });
    _reads = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void close() => _closed = true;

  static String? _mime(String extension) => switch (extension) {
    '.html' || '.htm' => 'text/html',
    '.css' => 'text/css',
    '.js' || '.mjs' => 'application/javascript',
    '.json' || '.map' => 'application/json',
    '.txt' || '.csv' => 'text/plain',
    '.xml' => 'application/xml',
    '.svg' => 'image/svg+xml',
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.ico' => 'image/x-icon',
    '.woff' => 'font/woff',
    '.woff2' => 'font/woff2',
    '.ttf' => 'font/ttf',
    '.otf' => 'font/otf',
    '.wasm' => 'application/wasm',
    '.pdf' => 'application/pdf',
    _ => null,
  };
}
