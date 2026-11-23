import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../database/app_database.dart';
import '../../models/media_creation.dart';
import '../../models/request_budget.dart';
import '../storage/attachment_file_lock.dart';
import 'media_polling.dart';
import 'media_request.dart';

class MediaFileStore {
  const MediaFileStore({
    this.directory = AppDirectories.getGenerationsDirectory,
  });

  final Future<Directory> Function() directory;

  static final _safeId = RegExp(r'^[a-zA-Z0-9_-]+$');
  static const _maxFileBytes = 128 * 1024 * 1024;
  static const _referenceBudget = RequestBudget();

  Future<Directory> _batchDirectory(String id) async {
    if (!_safeId.hasMatch(id)) {
      throw const FormatException('Invalid batch identifier');
    }
    return Directory(p.join((await directory()).path, id));
  }

  String _portable(Directory batch, String path) =>
      KelivoFileUri.encodeFromAbsolute(path, root: batch.parent.parent.path)!;

  Future<List<MediaReference>> snapshotReferences(
    String id,
    List<MediaReference> references,
  ) async {
    if (references.isEmpty) return const [];
    final originals = await _referenceFiles(references);
    final batch = await _batchDirectory(id);
    final refs = await Directory(
      p.join(batch.path, 'refs'),
    ).create(recursive: true);
    final stored = <MediaReference>[];
    for (var index = 0; index < originals.length; index++) {
      final file = originals[index];
      final ext = p.extension(file.path).toLowerCase();
      final safeExt = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(ext) ? ext : '.png';
      final target = p.join(refs.path, '$index$safeExt');
      await file.copy(target);
      stored.add(
        MediaReference(
          _portable(batch, target),
          role: references[index].role,
          parameterKey: references[index].parameterKey,
        ),
      );
    }
    return stored;
  }

  Future<void> validateReferences(List<MediaReference> references) async {
    await _referenceFiles(references);
  }

  Future<List<File>> _referenceFiles(List<MediaReference> references) async {
    var bytes = 0;
    final originals = <File>[];
    for (final ref in references) {
      final source = SandboxPathResolver.resolveForIo(ref.path);
      if (source == null || !await File(source).exists()) {
        throw const MediaFailure(
          MediaFailureKind.parameters,
          'Reference file unavailable',
        );
      }
      final file = File(source);
      bytes += await file.length();
      if (bytes > _referenceBudget.totalImageBytes) {
        throw const MediaFailure(
          MediaFailureKind.referenceTooLarge,
          'Reference images exceed the shared request budget',
        );
      }
      originals.add(file);
    }
    return originals;
  }

  Future<GenerationItemRow> store({
    required String batchId,
    required int ordinal,
    required MediaMode mode,
    required MediaResult result,
    required http.Client downloadClient,
    required Future<void> Function(GenerationItemRow) publish,
  }) async {
    final batch = await (await _batchDirectory(
      batchId,
    )).create(recursive: true);
    final id = const Uuid().v4();
    final pending = File(p.join(batch.path, '$id.part'));
    File? output;
    File? thumbnail;
    try {
      if (result.url case final url?
          when result.base64 == null && result.bytes == null) {
        await _download(downloadClient, url, result.downloadHeaders, pending);
      } else {
        final bytes =
            result.bytes ??
            await compute<String, Uint8List>(base64Decode, result.base64!);
        if (bytes.isEmpty || bytes.length > _maxFileBytes) {
          throw const MediaFailure(
            MediaFailureKind.download,
            'Invalid media length',
          );
        }
        await pending.writeAsBytes(bytes, flush: true);
      }
      final info = mode == MediaMode.image
          ? await compute(_imageInfo, pending.path)
          : null;
      if (mode == MediaMode.image && info == null) {
        throw const MediaFailure(
          MediaFailureKind.download,
          'Unsupported image data',
        );
      }
      final videoMime = mode == MediaMode.video
          ? await _videoMime(pending)
          : null;
      if (mode == MediaMode.video && videoMime == null) {
        throw const MediaFailure(
          MediaFailureKind.download,
          'Unsupported video data',
        );
      }
      final cover = mode == MediaMode.video && result.previewUrl != null
          ? await _readCover(batch, id, result, downloadClient)
          : null;
      return await AttachmentFileLock.synchronized(() async {
        try {
          final mime = info?.mime ?? videoMime ?? result.mime;
          final ext = switch (mime) {
            'video/mp4' => 'mp4',
            'video/webm' => 'webm',
            _ => AppDirectories.extFromMime(mime),
          };
          final stored = await pending.rename(p.join(batch.path, '$id.$ext'));
          output = stored;
          final thumbnailBytes =
              info?.thumbnail ??
              cover?.thumbnail ??
              (mode == MediaMode.video ? await _extractFrame(stored) : null);
          if (thumbnailBytes != null) {
            final thumbs = await Directory(
              p.join(batch.path, 'thumbs'),
            ).create(recursive: true);
            thumbnail = await File(
              p.join(thumbs.path, '$id.jpg'),
            ).writeAsBytes(thumbnailBytes, flush: true);
          }
          final item = GenerationItemRow(
            id: id,
            batchId: batchId,
            ordinal: ordinal,
            mode: mode,
            path: _portable(batch, stored.path),
            thumbnailPath: switch (thumbnail) {
              final file? => _portable(batch, file.path),
              null => null,
            },
            mime: mime,
            width: info?.width ?? result.width ?? cover?.width,
            height: info?.height ?? result.height ?? cover?.height,
            durationMs: result.durationMs,
            byteSize: await stored.length(),
            revisedPrompt: result.revisedPrompt,
            favorite: false,
            status: GenerationItemStatus.ready,
            createdAt: DateTime.now(),
          );
          await publish(item);
          return item;
        } catch (_) {
          for (final file in [?output, ?thumbnail]) {
            await _delete(file);
          }
          rethrow;
        }
      });
    } catch (_) {
      await _delete(pending);
      rethrow;
    }
  }

  static Future<Uint8List?> _extractFrame(File video) async {
    try {
      if (Platform.isLinux) return await _extractLinuxFrame(video);
      return await FcNativeVideoThumbnail()
          .saveThumbnailToBytes(
            srcFile: video.path,
            width: 440,
            height: 440,
            quality: 84,
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // The downloaded video remains available when its codec has no thumbnail.
      return null;
    }
  }

  static Future<Uint8List?> _extractLinuxFrame(File video) async {
    final process = await Process.start('ffmpeg', [
      '-nostdin',
      '-loglevel',
      'error',
      '-i',
      video.path,
      '-frames:v',
      '1',
      '-vf',
      'scale=440:440:force_original_aspect_ratio=decrease',
      '-f',
      'image2pipe',
      '-vcodec',
      'mjpeg',
      'pipe:1',
    ]);
    final timeout = Timer(const Duration(seconds: 8), process.kill);
    try {
      final (_, bytes, code) = await (
        process.stderr.drain<void>(),
        process.stdout.fold(
          BytesBuilder(copy: false),
          (output, chunk) => output..add(chunk),
        ),
        process.exitCode,
      ).wait;
      return code == 0 && bytes.isNotEmpty ? bytes.takeBytes() : null;
    } finally {
      timeout.cancel();
    }
  }

  static Future<_ImageInfo?> _readCover(
    Directory batch,
    String id,
    MediaResult result,
    http.Client client,
  ) async {
    final pending = File(p.join(batch.path, '$id.cover.part'));
    try {
      await _download(
        client,
        result.previewUrl!,
        result.previewHeaders,
        pending,
      );
      return await compute(_imageInfo, pending.path);
    } catch (_) {
      return null;
    } finally {
      await _delete(pending);
    }
  }

  static Future<String?> _videoMime(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(12);
      if (bytes.length < 12) return null;
      if (ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp') {
        return 'video/mp4';
      }
      if (bytes[0] == 0x1a &&
          bytes[1] == 0x45 &&
          bytes[2] == 0xdf &&
          bytes[3] == 0xa3) {
        return 'video/webm';
      }
      return null;
    } finally {
      await handle.close();
    }
  }

  static Future<void> _download(
    http.Client client,
    Uri url,
    Map<String, String> headers,
    File file,
  ) async {
    var current = url;
    var auth = headers;
    late http.StreamedResponse response;
    for (var hops = 0; ; hops++) {
      if (mediaResultUri(current.toString()) == null) {
        throw const MediaFailure(
          MediaFailureKind.download,
          'Invalid media URL',
        );
      }
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(auth);
      response = await client.send(request);
      final location = response.headers['location'];
      if (location == null ||
          !const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        break;
      }
      await response.stream.listen(null).cancel();
      final next = current.resolve(location);
      if (hops == 4 || current.scheme == 'https' && next.scheme != 'https') {
        throw const MediaFailure(
          MediaFailureKind.download,
          'Invalid media redirect',
        );
      }
      if (mediaResultUri(next.toString()) == null) {
        throw const MediaFailure(
          MediaFailureKind.download,
          'Invalid media URL',
        );
      }
      if (current.origin != next.origin) auth = const {};
      current = next;
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (response.contentLength ?? 0) > _maxFileBytes) {
      await response.stream.listen(null).cancel();
      throw MediaFailure(
        MediaFailureKind.download,
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    var length = 0;
    final sink = file.openWrite();
    try {
      await sink.addStream(
        response.stream.map((bytes) {
          length += bytes.length;
          if (length > _maxFileBytes) {
            throw const MediaFailure(
              MediaFailureKind.download,
              'Media file too large',
            );
          }
          return bytes;
        }),
      );
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (length == 0) {
      throw const MediaFailure(
        MediaFailureKind.download,
        'Empty media response',
      );
    }
  }

  Future<void> deleteBatch(String id) async {
    final batch = await _batchDirectory(id);
    if (await batch.exists()) await batch.delete(recursive: true);
  }

  static const _pendingDeletions = '.pending-deletions';

  Future<Directory?> _deletionDirectory(
    Directory root, {
    bool create = false,
  }) async {
    final pending = Directory(p.join(root.path, _pendingDeletions));
    switch (await FileSystemEntity.type(pending.path, followLinks: false)) {
      case FileSystemEntityType.directory:
        return pending;
      case FileSystemEntityType.notFound:
        return create ? pending.create() : null;
      default:
        throw FileSystemException(
          'Invalid creation cleanup directory',
          pending.path,
        );
    }
  }

  /// Keep the files recoverable until the database transaction commits.
  /// The caller holds the attachment lock across both resources.
  Future<void> deleteBatchAndRecord(
    String id,
    Future<void> Function() deleteRecord,
  ) async {
    final batch = await _batchDirectory(id);
    if (!await batch.exists()) {
      await deleteRecord();
      return;
    }
    final pending = (await _deletionDirectory(batch.parent, create: true))!;
    final staged = await batch.rename(p.join(pending.path, id));
    try {
      await deleteRecord();
    } catch (_) {
      await staged.rename(batch.path);
      rethrow;
    }
    await staged.delete(recursive: true);
  }

  Future<void> recoverBatchDeletions(
    Future<bool> Function(String id) hasRecord,
  ) async {
    final root = await directory();
    final pending = await _deletionDirectory(root);
    if (pending == null) return;
    await for (final staged in pending.list(followLinks: false)) {
      final id = p.basename(staged.path);
      if (staged is! Directory || !_safeId.hasMatch(id)) continue;
      if (await hasRecord(id)) {
        await staged.rename(p.join(root.path, id));
      } else {
        await staged.delete(recursive: true);
      }
    }
  }

  Future<void> deleteItem(GenerationItemRow item) async {
    final root = (await directory()).parent.path;
    for (final raw in [item.path, ?item.thumbnailPath]) {
      final parts = KelivoFileUri.decodeToSegments(raw);
      if (parts == null ||
          parts.length < 3 ||
          parts.first != 'generations' ||
          parts[1] != item.batchId) {
        continue;
      }
      final file = File(p.joinAll([root, ...parts]));
      if (await file.exists()) await file.delete();
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Preserve the original write/decode failure.
    }
  }
}

typedef _ImageInfo = ({
  int width,
  int height,
  String mime,
  Uint8List thumbnail,
});

_ImageInfo? _imageInfo(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoder = image.findDecoderForData(bytes);
  final decoded = decoder?.decode(bytes, frame: 0);
  if (decoder == null || decoded == null) return null;
  final mime = switch (decoder.format) {
    image.ImageFormat.jpg => 'image/jpeg',
    image.ImageFormat.webp => 'image/webp',
    image.ImageFormat.gif => 'image/gif',
    _ => 'image/png',
  };
  final scaled = image.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? 320 : null,
    height: decoded.width < decoded.height ? 320 : null,
  );
  return (
    width: decoded.width,
    height: decoded.height,
    mime: mime,
    thumbnail: image.encodeJpg(scaled, quality: 84),
  );
}
