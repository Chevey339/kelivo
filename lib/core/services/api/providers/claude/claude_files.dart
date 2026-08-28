import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/app_directories.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../../../../utils/upload_dedupe.dart';
import '../../stream/stream_chunk.dart';

/// The download streams to disk, so memory is not the constraint: on desktop
/// this is the API's own per-file limit, and on a phone it is what a chat is
/// willing to spend of the device's storage on one file.
final claudeFileSizeLimit = (Platform.isIOS || Platform.isAndroid)
    ? 200 * 1024 * 1024
    : 500 * 1024 * 1024;

/// An upload is buffered whole by the HTTP client on its way out, so this is
/// what a phone can hold in memory for one request — well under the API's own
/// limit.
const int claudeUploadSizeLimit = 100 * 1024 * 1024;

/// How long an uploaded attachment is kept for. It is copied into the
/// container by the request that follows the upload, and nothing refers to
/// the file after that.
const int _uploadExpirySeconds = 24 * 60 * 60;

/// The message headers negotiate a JSON body and an SSE response; neither
/// describes a file transfer.
Map<String, String> _filesApiHeaders(Map<String, String> headers) => {
  for (final entry in headers.entries)
    if (entry.key.toLowerCase() != 'content-type' &&
        entry.key.toLowerCase() != 'accept')
      entry.key: entry.value,
};

/// An attachment that never reached the API, thrown before the turn's first
/// request so nothing is billed. Its text is what the user reads: which file
/// and what went wrong, in the terms of the action they took — attaching a
/// file — not of where it was going.
class ClaudeFileUploadException implements Exception {
  const ClaudeFileUploadException(this.fileName, this.reason);

  final String fileName;
  final String reason;

  @override
  String toString() => 'Attachment "$fileName" could not be uploaded: $reason';
}

/// The name the Files API will accept for [raw]: 1–255 characters with none
/// of `<>:"|?*\/` or control characters, falling back to [fallback].
String claudeUploadFileName(String raw, {String fallback = 'upload'}) {
  final base = raw.split(RegExp(r'[\\/]')).last;
  final cleaned = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1f]'), '_').trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return fallback;
  if (cleaned.length <= 255) return cleaned;
  final dot = cleaned.lastIndexOf('.');
  final ext = dot > 0 ? cleaned.substring(dot) : '';
  return cleaned.substring(0, 255 - ext.length) + ext;
}

/// Uploads the local file at [path] through the Files API and returns its
/// `file_id`, for a `container_upload` block.
///
/// Unlike a generated file's download, this is not cosmetic: the turn is
/// about the file. So a file that cannot be uploaded — unreadable, over
/// [claudeUploadSizeLimit], refused by the API — throws
/// [ClaudeFileUploadException], and the caller has not sent anything yet.
Future<String> uploadClaudeFile({
  required http.Client client,
  required String base,
  required Map<String, String> headers,
  required String path,
  required String name,
  String mime = '',
}) async {
  final displayName = name.trim().isEmpty ? path : name;
  final resolved = SandboxPathResolver.resolveForIo(path);
  final file = resolved == null ? null : File(resolved);
  if (file == null || !await file.exists()) {
    throw ClaudeFileUploadException(displayName, 'the file cannot be read');
  }
  final size = await file.length();
  if (size > claudeUploadSizeLimit) {
    throw ClaudeFileUploadException(
      displayName,
      'it is larger than the ${claudeUploadSizeLimit ~/ (1024 * 1024)} MB limit',
    );
  }

  final request = http.MultipartRequest('POST', Uri.parse('$base/files'))
    ..headers.addAll(_filesApiHeaders(headers))
    ..fields['expires_in_seconds'] = '$_uploadExpirySeconds'
    ..files.add(
      http.MultipartFile(
        'file',
        file.openRead(),
        size,
        filename: claudeUploadFileName(displayName),
        contentType: _mediaTypeOrNull(mime),
      ),
    );
  final http.StreamedResponse response;
  try {
    response = await client.send(request);
  } catch (e) {
    throw ClaudeFileUploadException(displayName, e.toString());
  }
  final body = await response.stream.bytesToString();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ClaudeFileUploadException(
      displayName,
      'HTTP ${response.statusCode}: ${_apiErrorMessage(body)}',
    );
  }
  final id = _fileIdFrom(body);
  if (id == null) {
    throw ClaudeFileUploadException(displayName, 'the API returned no file id');
  }
  return id;
}

MediaType? _mediaTypeOrNull(String mime) {
  if (mime.trim().isEmpty) return null;
  try {
    return MediaType.parse(mime.trim());
  } catch (_) {
    return null;
  }
}

String? _fileIdFrom(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final id = (decoded['id'] ?? '').toString();
      if (id.isNotEmpty) return id;
    }
  } catch (_) {}
  return null;
}

/// The API's own sentence about what went wrong, or as much of the body as
/// fits a snackbar when it is not the usual error envelope.
String _apiErrorMessage(String body) {
  String text = body;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final message = (decoded['error']['message'] ?? '').toString();
      if (message.isNotEmpty) text = message;
    }
  } catch (_) {}
  text = text.trim();
  return text.length <= 300 ? text : '${text.substring(0, 300)}…';
}

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
    final getHeaders = _filesApiHeaders(headers);

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
    if (declaredSize is int && declaredSize > claudeFileSizeLimit) {
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
/// body, or one past [claudeFileSizeLimit]).
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
      if (size > claudeFileSizeLimit) return null;
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
