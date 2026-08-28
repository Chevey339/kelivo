import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/app_directories.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../../../../utils/upload_dedupe.dart';
import '../../stream/stream_chunk.dart';

/// The download streams to disk, so memory is not the constraint: on desktop
/// this is the API's own per-file limit, and on a phone it is what a chat is
/// willing to spend of the device's storage on one file.
final _generatedFileSizeLimit = (Platform.isIOS || Platform.isAndroid)
    ? 200 * 1024 * 1024
    : 500 * 1024 * 1024;

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

    final dir = await AppDirectories.getUploadDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // Written under its final name straight away and hashed on the way, so a
    // file of any size costs a bounded amount of memory. Should an identical
    // copy already be stored, this one is dropped again in its favour.
    final destination = await UploadDedupe.reserveUniqueFile(dir, name);
    ({int size, List<int> bytes})? digest;
    try {
      digest = await _streamToFile(
        client: client,
        uri: Uri.parse('$base/files/$fileId/content'),
        headers: getHeaders,
        destination: destination,
      );
    } finally {
      // A download cut off — the client closed under it, say — must not
      // leave its half in the upload directory.
      if (digest == null) await _discard(destination);
    }
    if (digest == null) return null;
    var path = destination.path;
    final identical = await UploadDedupe.findIdenticalDigest(
      dir,
      digest.size,
      digest.bytes,
      name,
      exclude: path,
    );
    if (identical != null) {
      await _discard(destination);
      path = identical;
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

/// Streams the body at [uri] into [destination], returning its size and
/// SHA-256, or null when the body cannot be used (a failed request, an empty
/// body, or one past [_generatedFileSizeLimit]).
Future<({int size, List<int> bytes})?> _streamToFile({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required File destination,
}) async {
  final request = http.Request('GET', uri)..headers.addAll(headers);
  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) return null;

  final sink = destination.openWrite();
  final hash = _DigestSink();
  final hasher = sha256.startChunkedConversion(hash);
  var size = 0;
  try {
    await for (final chunk in response.stream) {
      size += chunk.length;
      if (size > _generatedFileSizeLimit) return null;
      sink.add(chunk);
      hasher.add(chunk);
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
  if (size == 0) return null;
  hasher.close();
  return (size: size, bytes: hash.digest!.bytes);
}

/// Receives the one digest a chunked SHA-256 conversion emits on close.
class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}

Future<void> _discard(File file) async {
  try {
    await file.delete();
  } catch (_) {}
}

/// The container names the file, so it can name a path or nothing at all.
String _generatedFileName(String raw, String fileId) {
  final base = raw.split(RegExp(r'[\\/]')).last.trim();
  if (base.isEmpty || base == '.' || base == '..') return fileId;
  return base;
}
