import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/app_directories.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../../../../utils/upload_dedupe.dart';
import '../../stream/stream_chunk.dart';

/// The API allows 500 MB per file and this has to hold the whole thing in
/// memory to write it, which is well past what a chat attachment can be.
const _generatedFileSizeLimit = 32 * 1024 * 1024;

/// The `file_id`s a code execution result reported, in arrival order.
///
/// A container run reports each file it left in `$OUTPUT_DIR` as an id inside
/// its own result `content` list. No other server tool result carries one, so
/// the shape is the whole test — the tool name never has to be consulted.
List<String> claudeGeneratedFileIds(Object? output) {
  if (output is! Map) return const <String>[];
  final content = output['content'];
  if (content is! List) return const <String>[];
  return <String>[
    for (final entry in content)
      if (entry is Map) (entry['file_id'] ?? '').toString(),
  ]..removeWhere((id) => id.isEmpty);
}

/// Fetches [fileId] through the Files API and stores it as an upload, or null
/// when it cannot be had.
///
/// Anthropic hands a generated file back as an id rather than as bytes, so a
/// chart the model just drew is invisible until it is downloaded. Every
/// failure here is cosmetic next to losing the turn, so none of them throw.
Future<GeneratedFile?> downloadClaudeGeneratedFile({
  required http.Client client,
  required String base,
  required Map<String, String> headers,
  required String fileId,
}) async {
  try {
    // The message headers negotiate a JSON body and an SSE response; neither
    // describes a file download.
    final getHeaders = <String, String>{
      for (final entry in headers.entries)
        if (entry.key.toLowerCase() != 'content-type' &&
            entry.key.toLowerCase() != 'accept')
          entry.key: entry.value,
    };

    final metaResponse = await client.get(
      Uri.parse('$base/files/$fileId'),
      headers: getHeaders,
    );
    if (metaResponse.statusCode < 200 || metaResponse.statusCode >= 300) {
      return null;
    }
    final meta = jsonDecode(metaResponse.body);
    if (meta is! Map) return null;
    // Only what a skill or the container created may be downloaded; asking for
    // anything else is a 400 that costs a round trip.
    if (meta['downloadable'] == false) return null;
    final declaredSize = meta['size_bytes'];
    if (declaredSize is int && declaredSize > _generatedFileSizeLimit) {
      return null;
    }
    final name = _generatedFileName(
      (meta['filename'] ?? '').toString(),
      fileId,
    );
    final reported = (meta['mime_type'] ?? '').toString().trim().toLowerCase();
    // The container named the file, so its extension is the reliable half: a
    // chart handed back as application/octet-stream still belongs in the
    // message as a picture rather than as something to download.
    final mime = reported.startsWith('image/')
        ? reported
        : inferMediaMimeFromSource(name, fallbackMime: reported);

    final contentResponse = await client.get(
      Uri.parse('$base/files/$fileId/content'),
      headers: getHeaders,
    );
    if (contentResponse.statusCode < 200 || contentResponse.statusCode >= 300) {
      return null;
    }
    final bytes = contentResponse.bodyBytes;
    if (bytes.isEmpty || bytes.length > _generatedFileSizeLimit) return null;

    final dir = await AppDirectories.getUploadDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var path = await UploadDedupe.findIdentical(dir, bytes, name);
    if (path == null) {
      final destination = await UploadDedupe.reserveUniqueFile(dir, name);
      try {
        await destination.writeAsBytes(bytes, flush: true);
      } catch (_) {
        try {
          await destination.delete();
        } catch (_) {}
        rethrow;
      }
      path = destination.path;
    }
    return GeneratedFile(
      uri: SandboxPathResolver.canonicalize(path),
      name: name,
      mime: mime.isEmpty ? null : mime,
    );
  } catch (_) {
    return null;
  }
}

/// The container names the file, so it can name a path or nothing at all.
String _generatedFileName(String raw, String fileId) {
  final base = raw.split(RegExp(r'[\\/]')).last.trim();
  if (base.isEmpty || base == '.' || base == '..') return fileId;
  return base;
}
