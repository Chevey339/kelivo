import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../utils/multimodal_input_utils.dart';
import '../api/tool_call_cancellation.dart';

/// MCP-local paths may only name images saved by the client. A server's file
/// URI (including one persisted before this check) is never a local attachment.
class McpImageSnapshot {
  static const _prefix = 'mcp_img';

  static Future<String?> save(String mime, String data) async {
    final path = await AppDirectories.saveBase64Image(
      mime,
      data,
      prefix: _prefix,
    );
    return path == null ? null : SandboxPathResolver.canonicalize(path);
  }

  /// Materialize URL-only image results once, before persisting the tool result.
  /// Own the connection so timeout and cancellation also release its socket.
  static Future<String?> download(
    String url, {
    String? mime,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final image = await _fetch(url, mime: mime, timeout: timeout);
    return image == null ? null : save(image.mime, image.data);
  }

  static Future<({String mime, String data})?> _fetch(
    String url, {
    String? mime,
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
      final response = await client
          .send(
            http.AbortableRequest(
              'GET',
              uri,
              abortTrigger: cancellation?.cancelled,
            ),
          )
          .then(http.Response.fromStream)
          .timeout(timeout);
      cancellation?.throwIfCancelled();
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        return null;
      }
      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final imageMime = contentType?.startsWith('image/') == true
          ? contentType!
          : mime ?? inferMediaMimeFromSource(url, fallbackMime: 'image/png');
      return (mime: imageMime, data: base64Encode(response.bodyBytes));
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
    final parsed = Uri.tryParse(uri);
    if (parsed?.isScheme('http') == true || parsed?.isScheme('https') == true) {
      final image = await _fetch(uri);
      return image == null ? null : 'data:${image.mime};base64,${image.data}';
    }
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
      final bytes = await File(resolved).readAsBytes();
      final mime = inferMediaMimeFromSource(
        resolved,
        fallbackMime: 'image/png',
      );
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }
}
