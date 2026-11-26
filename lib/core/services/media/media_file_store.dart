import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../database/app_database.dart';
import '../../models/media_creation.dart';
import '../../models/request_budget.dart';
import '../../utils/multimodal_input_utils.dart' show sniffMimeFromFile;
import '../../../utils/safe_resize_image.dart';
import '../storage/attachment_file_lock.dart';
import '../network/media_http_log.dart';
import 'media_polling.dart';
import 'media_adapter.dart' show classifyMediaFailure;
import 'media_request.dart';

class MediaFileStore {
  const MediaFileStore({
    this.directory = AppDirectories.getGenerationsDirectory,
  });

  final Future<Directory> Function() directory;

  static const _maxFileBytes = 128 * 1024 * 1024;
  static const _referenceBudget = RequestBudget();

  Future<Directory> _batchDirectory(String id) async {
    if (!KelivoFileUri.isGenerationId(id)) {
      throw const FormatException('Invalid batch identifier');
    }
    return Directory(p.join((await directory()).path, id));
  }

  String _portable(Directory batch, String path) =>
      KelivoFileUri.encodeFromAbsolute(path, root: batch.parent.parent.path)!;

  Future<List<MediaReference>> snapshotReferences(
    String id,
    List<MediaReference> references, {
    required Future<bool> Function(String uri) ownsImage,
  }) async {
    if (references.isEmpty) return const [];
    final originals = await _referenceFiles(references);
    final batch = await _batchDirectory(id);
    final refs = Directory(p.join(batch.path, 'refs'));
    final stored = <MediaReference>[];
    for (var index = 0; index < originals.length; index++) {
      final file = originals[index];
      final original = KelivoFileUri.encodeFromAbsolute(
        file.path,
        root: batch.parent.parent.path,
      );
      if (original != null &&
          KelivoFileUri.generationImageItemId(original) != null) {
        if (!await ownsImage(original)) {
          throw const MediaFailure(
            MediaFailureKind.parameters,
            'The original creation image was deleted.',
          );
        }
        stored.add(
          MediaReference(
            original,
            role: references[index].role,
            parameterKey: references[index].parameterKey,
          ),
        );
        continue;
      }
      await refs.create(recursive: true);
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
      final file = source == null
          ? null
          : KelivoFileUri.generationImageItemId(ref.path) != null
          ? await SandboxPathResolver.managedFile(
              ref.path,
              contentRoot: (await directory()).parent.path,
            )
          : File(source);
      if (ref.unavailable || file == null || !await file.exists()) {
        throw const MediaFailure(
          MediaFailureKind.parameters,
          'Reference file unavailable',
        );
      }
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
    Future<void> Function(Duration) waitForDownloadRetry = Future<void>.delayed,
  }) async {
    final batch = await (await _batchDirectory(
      batchId,
    )).create(recursive: true);
    final id = const Uuid().v4();
    var pending = File(p.join(batch.path, '$id.part'));
    File? output;
    File? thumbnail;
    try {
      if (result.url case final url?
          when result.base64 == null && result.bytes == null) {
        await _download(
          downloadClient,
          url,
          result.downloadHeaders,
          pending,
          waitForRetry: waitForDownloadRetry,
        );
      } else {
        if (result.bytes case final bytes?) {
          if (bytes.isEmpty || bytes.length > _maxFileBytes) {
            throw const MediaFailure(
              MediaFailureKind.download,
              'Invalid media length',
            );
          }
          await pending.writeAsBytes(bytes, flush: true);
        } else {
          final encoded = result.base64!;
          final offset = result.base64Offset;
          if (offset < 0 ||
              offset >= encoded.length ||
              encoded.length - offset > ((_maxFileBytes + 2) ~/ 3) * 4) {
            throw const MediaFailure(
              MediaFailureKind.download,
              'Invalid media length',
            );
          }
          await compute(_writeInlineMedia, (
            path: pending.path,
            encoded: encoded,
            offset: offset,
          ));
          final length = await pending.length();
          if (length == 0 || length > _maxFileBytes) {
            throw const MediaFailure(
              MediaFailureKind.download,
              'Invalid media length',
            );
          }
        }
      }
      final info = mode == MediaMode.image
          ? await _inspectImage(pending.path)
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
      final mime = info?.mime ?? videoMime ?? result.mime;
      final ext = switch (mime) {
        'video/mp4' => 'mp4',
        'video/quicktime' => 'mov',
        'video/webm' => 'webm',
        _ => AppDirectories.extFromMime(mime),
      };
      Uint8List? thumbnailBytes = info?.thumbnail ?? cover?.thumbnail;
      var thumbnailExt = 'png';
      if (mode == MediaMode.video && thumbnailBytes == null) {
        // Native readers use the extension to select the container. Extract
        // before publication so slow codecs do not block all chat attachments.
        pending = await pending.rename(p.join(batch.path, '$id.part.$ext'));
        thumbnailBytes = await _withThumbnailDecoder(
          () => _extractFrame(pending),
        );
        thumbnailExt = 'jpg';
      }
      final preview = thumbnailBytes;
      return await AttachmentFileLock.synchronized(() async {
        try {
          final stored = await pending.rename(p.join(batch.path, '$id.$ext'));
          output = stored;
          if (preview != null) {
            final thumbs = await Directory(
              p.join(batch.path, 'thumbs'),
            ).create(recursive: true);
            thumbnail = await File(
              p.join(thumbs.path, '$id.$thumbnailExt'),
            ).writeAsBytes(preview, flush: true);
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

  // Native codecs can need an intermediate surface even when a target size
  // is supplied. Serialize thumbnail work, not downloads or database writes.
  static Future<void>? _activeDecoder;
  static Future<T?> _withThumbnailDecoder<T>(
    Future<T?> Function() decode,
  ) async {
    final elapsed = Stopwatch()..start();
    const deadline = Duration(seconds: 8);
    try {
      while (true) {
        final busy = _activeDecoder;
        if (busy == null) break;
        await busy.timeout(deadline - elapsed.elapsed);
        if (elapsed.elapsed >= deadline) return null;
      }
      final idle = Completer<void>();
      _activeDecoder = idle.future;
      // If the platform suspends its raster thread, return the original at
      // the deadline. The native job retains sole ownership until it settles.
      return await Future.sync(decode)
          .whenComplete(() {
            _activeDecoder = null;
            idle.complete();
          })
          .timeout(deadline - elapsed.elapsed);
    } on TimeoutException {
      return null;
    }
  }

  static Future<Uint8List?> _extractFrame(File video) async {
    try {
      if (Platform.isLinux) return await _extractLinuxFrame(video);
      return await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: video.path,
        width: 440,
        height: 440,
        quality: 84,
      );
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
      return await _inspectImage(pending.path);
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
        return ascii.decode(bytes.sublist(8), allowInvalid: true) == 'qt  '
            ? 'video/quicktime'
            : 'video/mp4';
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
    File file, {
    Future<void> Function(Duration)? waitForRetry,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await _downloadOnce(client, url, headers, file);
        return;
      } catch (error) {
        final failure = classifyMediaFailure(error);
        final status = failure.statusCode;
        final transient =
            failure.kind == MediaFailureKind.network ||
            status == 408 ||
            status == 429 ||
            status != null && status >= 500;
        if (!transient || attempt >= 2 || waitForRetry == null) rethrow;
        await waitForRetry(Duration(seconds: 1 << attempt));
      }
    }
  }

  static Future<void> _downloadOnce(
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
      await MediaHttpLog.discard(response);
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
    final encoding = response.headers[HttpHeaders.contentEncodingHeader];
    if ((encoding == null || encoding == 'identity') &&
        response.contentLength != null &&
        length != response.contentLength) {
      throw const MediaFailure(
        MediaFailureKind.network,
        'Incomplete media download',
      );
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
  Future<void> deleteBatchesAndRecords(
    Iterable<String> ids,
    Future<void> Function() deleteRecords,
  ) async {
    final staged = <Directory, Directory>{};
    try {
      for (final id in ids) {
        final batch = await _batchDirectory(id);
        if (!await batch.exists()) continue;
        final pending = (await _deletionDirectory(batch.parent, create: true))!;
        staged[batch] = await batch.rename(p.join(pending.path, id));
      }
      await deleteRecords();
    } catch (_) {
      for (final entry in staged.entries.toList().reversed) {
        await entry.value.rename(entry.key.path);
      }
      rethrow;
    }
    for (final dir in staged.values) {
      await dir.delete(recursive: true);
    }
  }

  static final _pendingOutput = RegExp(r'\.part(?:\.(?:mp4|mov|webm))?$');
  static final _generatedOutput = RegExp(
    r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\.(?:png|jpg|webp|gif|mp4|mov|webm)$',
  );

  Future<void> discardInterruptedWrites(
    String id,
    Set<String> referenced,
  ) async {
    final batch = await _batchDirectory(id);
    if (await FileSystemEntity.type(batch.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    Future<void> sweep(Directory directory) async {
      await for (final file in directory.list(followLinks: false)) {
        if (file is! File) continue;
        final name = p.basename(file.path);
        if ((_pendingOutput.hasMatch(name) ||
                _generatedOutput.hasMatch(name)) &&
            !referenced.contains(_portable(batch, file.path))) {
          await _delete(file);
        }
      }
    }

    await sweep(batch);
    final thumbs = Directory(p.join(batch.path, 'thumbs'));
    if (await FileSystemEntity.type(thumbs.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await sweep(thumbs);
    }
  }

  Future<void> recoverBatchDeletions(
    Future<bool> Function(String id) hasRecord,
    Future<bool> Function(String id) hasItem,
  ) async {
    final root = await directory();
    final itemTrash = Directory(p.join(root.path, '.pending-items'));
    if (await FileSystemEntity.type(itemTrash.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await for (final batch in itemTrash.list(followLinks: false)) {
        if (batch is! Directory ||
            !KelivoFileUri.isGenerationId(p.basename(batch.path))) {
          continue;
        }
        await for (final item in batch.list(followLinks: false)) {
          if (item is! Directory ||
              !KelivoFileUri.isGenerationId(p.basename(item.path))) {
            continue;
          }
          if (await hasItem(p.basename(item.path))) {
            await _restoreItemFiles(
              item,
              await _batchDirectory(p.basename(batch.path)),
            );
          }
          await item.delete(recursive: true);
        }
        await batch.delete();
      }
    }
    final pending = await _deletionDirectory(root);
    if (pending == null) return;
    await for (final staged in pending.list(followLinks: false)) {
      final id = p.basename(staged.path);
      if (staged is! Directory || !KelivoFileUri.isGenerationId(id)) continue;
      if (await hasRecord(id)) {
        await staged.rename(p.join(root.path, id));
      } else {
        await staged.delete(recursive: true);
      }
    }
  }

  Future<void> deleteItemAndRecord(
    GenerationItemRow item,
    Future<void> Function() deleteRecord,
  ) async {
    final batch = await _batchDirectory(item.batchId);
    if (!KelivoFileUri.isGenerationId(item.id)) {
      throw const FormatException('Invalid artwork identifier');
    }
    final staged = Directory(
      p.join(batch.parent.path, '.pending-items', item.batchId, item.id),
    );
    try {
      for (final raw in {item.path, ?item.thumbnailPath}) {
        if (!KelivoFileUri.isGenerationFile(raw, item.batchId)) continue;
        final parts = KelivoFileUri.decodeToSegments(raw)!.skip(2);
        final file = File(p.joinAll([batch.path, ...parts]));
        if (!await file.exists()) continue;
        final target = File(p.joinAll([staged.path, ...parts]));
        await target.parent.create(recursive: true);
        await file.rename(target.path);
      }
      await deleteRecord();
    } catch (_) {
      if (await staged.exists()) {
        await _restoreItemFiles(staged, batch);
        await staged.delete(recursive: true);
      }
      rethrow;
    }
    if (await staged.exists()) await staged.delete(recursive: true);
  }

  Future<void> _restoreItemFiles(Directory staged, Directory batch) async {
    await for (final file in staged.list(recursive: true, followLinks: false)) {
      if (file is! File) continue;
      final destination = File(
        p.join(batch.path, p.relative(file.path, from: staged.path)),
      );
      await destination.parent.create(recursive: true);
      await file.rename(destination.path);
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
  Uint8List? thumbnail,
});

Future<void> _writeInlineMedia(
  ({String path, String encoded, int offset}) input,
) async {
  Stream<String> chunks() async* {
    const size = 64 * 1024;
    for (
      var start = input.offset;
      start < input.encoded.length;
      start += size
    ) {
      yield input.encoded.substring(
        start,
        (start + size).clamp(0, input.encoded.length),
      );
    }
  }

  final output = File(input.path).openWrite();
  try {
    await output.addStream(chunks().transform(base64.decoder));
    await output.flush();
  } finally {
    await output.close();
  }
}

Future<_ImageInfo?> _inspectImage(String path) async {
  final mime = await sniffMimeFromFile(path);
  if (mime == null || !mime.startsWith('image/')) return null;
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  ui.ImageDescriptor? descriptor;
  late final int width, height;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    width = descriptor.width;
    height = descriptor.height;
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
  if (width < 1 || height < 1) return null;
  final thumbnail = width > maxCreationSourcePixels ~/ height
      ? null
      : await MediaFileStore._withThumbnailDecoder(
          () => _thumbnailPng(path, width, height),
        );
  return (width: width, height: height, mime: mime, thumbnail: thumbnail);
}

Future<Uint8List?> _thumbnailPng(String path, int width, int height) async {
  final state = defaultTargetPlatform == TargetPlatform.iOS
      ? SchedulerBinding.instance.lifecycleState
      : null;
  if (state == ui.AppLifecycleState.paused ||
      state == ui.AppLifecycleState.hidden) {
    return null;
  }
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? frame, resized;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final target = computeSafeResizeTarget(
      intrinsicWidth: width,
      intrinsicHeight: height,
      boxWidth: creationThumbnailEdge,
      boxHeight: creationThumbnailEdge,
      fit: SafeResizeFit.contain,
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: target.width,
      targetHeight: target.height,
    );
    frame = (await codec.getNextFrame()).image;
    try {
      if (frame.width != target.width || frame.height != target.height) {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          frame,
          ui.Rect.fromLTWH(
            0,
            0,
            frame.width.toDouble(),
            frame.height.toDouble(),
          ),
          ui.Rect.fromLTWH(
            0,
            0,
            target.width.toDouble(),
            target.height.toDouble(),
          ),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        try {
          resized = await picture.toImage(target.width, target.height);
        } finally {
          picture.dispose();
        }
      }
      final png = await (resized ?? frame).toByteData(
        format: ui.ImageByteFormat.png,
      );
      return png?.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } catch (_) {
      // The first frame is valid. A GPU readback failure should only omit its thumbnail.
      return null;
    }
  } finally {
    resized?.dispose();
    frame?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
