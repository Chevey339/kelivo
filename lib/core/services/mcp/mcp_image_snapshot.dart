import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
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
    Uint8List bytes,
  ) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    try {
      final image = await ToolImage.fromBytes(bytes);
      final uri = await _store(image);
      return (uri: uri, width: image.width, height: image.height);
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    }
  }

  static Future<String> _store(ToolImage image) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final directory = await AppDirectories.getImagesDirectory();
    await directory.create(recursive: true);
    final extension = image.mime == 'image/png' ? 'png' : 'jpg';
    final file = File(
      p.join(directory.path, '${_prefix}_${const Uuid().v4()}.$extension'),
    );
    try {
      await file.writeAsBytes(image.bytes, flush: true);
      cancellation?.throwIfCancelled();
      return SandboxPathResolver.canonicalize(file.path);
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

  /// Read current snapshots or URL-only results. Historical URLs are fetched
  /// in memory; only the tool execution that persists a URI saves a new file.
  static Future<String?> readDataUrl(String uri) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    try {
      final parsed = Uri.tryParse(uri);
      if (parsed?.isScheme('http') == true ||
          parsed?.isScheme('https') == true) {
        final bytes = await _fetch(uri);
        if (bytes == null) return null;
        final image = await ToolImage.fromBytes(bytes);
        cancellation?.throwIfCancelled();
        return 'data:${image.mime};base64,${base64Encode(image.bytes)}';
      }
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
      final image = await ToolImage.read(resolved);
      cancellation?.throwIfCancelled();
      return 'data:${image.mime};base64,${base64Encode(image.bytes)}';
    } catch (_) {
      cancellation?.throwIfCancelled();
      return null;
    }
  }
}
