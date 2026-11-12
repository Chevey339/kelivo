import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../api/tool_call_cancellation.dart';
import '../tool_image.dart';

/// MCP-local paths may only name images saved by the client. A server's file
/// URI (including one persisted before this check) is never a local attachment.
class McpImageSnapshot {
  static const _prefix = 'mcp_img';
  static final _deduplicatedName = RegExp(r'^mcp_img_[a-f0-9]{64}\.(png|jpg)$');

  static bool isDeduplicatedFile(String path) =>
      _deduplicatedName.hasMatch(p.basename(path));

  /// Reusing an unreferenced preview starts a new GC grace period before its
  /// next tool result has been checkpointed into the message asset registry.
  static Future<File?> reuseLocalFile(String uri) async {
    final file = await localFile(uri);
    if (file == null) return null;
    try {
      await file.setLastModified(DateTime.now());
      return file;
    } on FileSystemException {
      return null;
    }
  }

  static Future<String?> save(String data) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    try {
      final cleaned = data.replaceAll(RegExp(r'\s'), '');
      if (cleaned.length > ((ToolImage.maxFileBytes + 2) ~/ 3) * 4) {
        return null;
      }
      return (await saveBytes(base64Decode(cleaned)))?.uri;
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    }
  }

  /// Return the stored dimensions so screenshot coordinates describe the
  /// bounded image sent to the model, rather than the original native bitmap.
  static Future<({String uri, int width, int height})?> saveBytes(
    Uint8List bytes, {
    bool deduplicate = false,
  }) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    try {
      final image = await ToolImage.fromBytes(bytes);
      final uri = await _store(image, deduplicate: deduplicate);
      return (uri: uri, width: image.width, height: image.height);
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    }
  }

  static Future<String> _store(
    ToolImage image, {
    bool deduplicate = false,
  }) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final directory = await AppDirectories.getImagesDirectory();
    await directory.create(recursive: true);
    final extension = image.mime == 'image/png' ? 'png' : 'jpg';
    final id = deduplicate
        ? sha256.convert(image.bytes).toString()
        : const Uuid().v4();
    final target = File(p.join(directory.path, '${_prefix}_$id.$extension'));
    if (deduplicate && await target.exists()) {
      try {
        await target.setLastModified(DateTime.now());
        cancellation?.throwIfCancelled();
        return SandboxPathResolver.canonicalize(target.path);
      } on FileSystemException {
        // GC may have isolated the old file between exists and reuse.
        if (await target.exists()) rethrow;
      }
    }
    // Publish content-addressed previews atomically. A cancelled concurrent
    // save must never delete an existing image owned by another message.
    final file = deduplicate
        ? File(p.join(directory.path, '${_prefix}_${const Uuid().v4()}.tmp'))
        : target;
    try {
      await file.writeAsBytes(image.bytes, flush: true);
      cancellation?.throwIfCancelled();
      if (deduplicate) {
        if (await target.exists()) {
          await file.delete();
        } else {
          try {
            await file.rename(target.path);
          } on FileSystemException {
            if (!await target.exists()) rethrow;
            await file.delete();
          }
        }
        await target.setLastModified(DateTime.now());
      }
      return SandboxPathResolver.canonicalize(target.path);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  /// Materialize URL-only image results once, before persisting the tool result.
  /// Own the connection so timeout and cancellation also release its socket.
  static Future<String?> download(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cancellation = ToolCallCancellation.current;
    try {
      final bytes = await _fetch(url, timeout: timeout);
      if (bytes == null) return null;
      return await _store(await ToolImage.fromBytes(bytes));
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    }
  }

  static Future<Uint8List?> _fetch(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final client = http.Client();
    try {
      final bytes = await client
          .send(
            http.AbortableRequest(
              'GET',
              uri,
              abortTrigger: cancellation?.cancelled,
            ),
          )
          .then((response) async {
            if (response.statusCode < 200 ||
                response.statusCode >= 300 ||
                (response.contentLength ?? 0) > ToolImage.maxFileBytes) {
              return null;
            }
            final buffer = BytesBuilder(copy: false);
            await for (final chunk in response.stream) {
              if (buffer.length + chunk.length > ToolImage.maxFileBytes) {
                return null;
              }
              buffer.add(chunk);
            }
            return buffer.isEmpty ? null : buffer.takeBytes();
          })
          .timeout(timeout);
      cancellation?.throwIfCancelled();
      return bytes;
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    } finally {
      client.close();
    }
  }

  /// Share URL materialization without sharing a generation's cancellation.
  /// A surviving reader retries an aborted owner's read through the same slot.
  static final _urlReads =
      <String, ({Future<String?> future, ToolCallCancellation? owner})>{};

  static Future<String?> readDataUrl(String uri, {String? cacheKey}) async {
    if (cacheKey == null ||
        !(uri.startsWith('http://') || uri.startsWith('https://'))) {
      return _readDataUrl(uri, cacheKey: cacheKey);
    }
    final cancellation = ToolCallCancellation.current;
    final key = '$cacheKey|$uri';
    while (true) {
      cancellation?.throwIfCancelled();
      final existing = _urlReads[key];
      if (existing != null) {
        try {
          final result = await (cancellation == null
              ? existing.future
              : Future.any<String?>([
                  existing.future,
                  cancellation.cancelled.then<String?>((_) {
                    cancellation.throwIfCancelled();
                    return null;
                  }),
                ]));
          cancellation?.throwIfCancelled();
          return result;
        } catch (_) {
          cancellation?.throwIfCancelled();
          var ownerCancelled = false;
          try {
            existing.owner?.throwIfCancelled();
          } on StateError {
            ownerCancelled = true;
          }
          if (!ownerCancelled) rethrow;
          // Another survivor may already have installed the retry. Never
          // remove that new slot or start an independent competing download.
          if (identical(_urlReads[key]?.future, existing.future)) {
            _urlReads.remove(key);
          }
          continue;
        }
      }
      final read = _readDataUrl(uri, cacheKey: cacheKey);
      _urlReads[key] = (future: read, owner: cancellation);
      try {
        final result = await read;
        cancellation?.throwIfCancelled();
        return result;
      } finally {
        if (identical(_urlReads[key]?.future, read)) _urlReads.remove(key);
      }
    }
  }

  static Future<String?> _readDataUrl(String uri, {String? cacheKey}) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    try {
      final parsed = Uri.tryParse(uri);
      if (parsed?.isScheme('http') == true ||
          parsed?.isScheme('https') == true) {
        final cache = cacheKey == null
            ? null
            : File(
                p.join(
                  (await AppDirectories.getCacheDirectory()).path,
                  'image_context',
                  sha256.convert(utf8.encode('$cacheKey|$uri')).toString(),
                ),
              );
        if (cache != null && await cache.exists()) {
          return await cache.readAsString();
        }
        final bytes = await _fetch(uri);
        if (bytes == null) return null;
        final image = await ToolImage.fromBytes(bytes);
        cancellation?.throwIfCancelled();
        final data = 'data:${image.mime};base64,${base64Encode(image.bytes)}';
        if (cache != null) {
          await cache.parent.create(recursive: true);
          final temporary = File('${cache.path}.${const Uuid().v4()}.tmp');
          try {
            await temporary.writeAsString(data, flush: true);
            if (!await cache.exists()) {
              await temporary.rename(cache.path);
            }
          } finally {
            if (await temporary.exists()) await temporary.delete();
          }
          return await cache.readAsString();
        }
        return data;
      }
      final file = await localFile(uri);
      if (file == null) return null;
      final image = await ToolImage.read(file.path);
      cancellation?.throwIfCancelled();
      return 'data:${image.mime};base64,${base64Encode(image.bytes)}';
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    }
  }

  /// Resolve a client-owned snapshot for local UI display without loading its
  /// full pixels into Dart or fetching a URL supplied by a page/tool result.
  static Future<File?> localFile(String uri) async {
    try {
      final path = SandboxPathResolver.resolveForIo(uri);
      if (path == null || !p.basename(path).startsWith('${_prefix}_')) {
        return null;
      }
      final root = await (await AppDirectories.getImagesDirectory())
          .resolveSymbolicLinks();
      final resolved = await File(path).resolveSymbolicLinks();
      if (!p.equals(p.dirname(resolved), root) ||
          !p.basename(resolved).startsWith('${_prefix}_')) {
        return null;
      }
      return File(resolved);
    } catch (_) {
      return null;
    }
  }
}
