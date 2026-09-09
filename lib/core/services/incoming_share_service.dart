import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/chat_input_data.dart';
import '../utils/multimodal_input_utils.dart';
import '../../utils/app_directories.dart';
import '../../utils/upload_dedupe.dart';

class ShareImportCancelled implements Exception {}

class ShareImportProgress {
  const ShareImportProgress({
    required this.id,
    required this.name,
    required this.index,
    required this.count,
    required this.bytes,
    this.total,
  });
  factory ShareImportProgress.fromMap(Map<dynamic, dynamic> map) =>
      ShareImportProgress(
        id: map['id'] as String,
        name: map['name'] as String,
        index: (map['index'] as num).toInt(),
        count: (map['count'] as num).toInt(),
        bytes: (map['bytes'] as num).toInt(),
        total: (map['total'] as num?)?.toInt(),
      );
  final String id;
  final String name;
  final int index;
  final int count;
  final int bytes;
  final int? total;
  double? get fraction =>
      total != null && total! > 0 ? (bytes / total!).clamp(0.0, 1.0) : null;
}

class IncomingShare {
  const IncomingShare({
    required this.id,
    required this.text,
    required this.files,
    this.failedFiles = 0,
  });

  factory IncomingShare.fromMap(Map<dynamic, dynamic> map) => IncomingShare(
    id: map['id'] as String,
    text: map['text'] as String? ?? '',
    files: [
      for (final file in map['files'] as List? ?? const [])
        DocumentAttachment(
          path: file['path'] as String,
          fileName: file['name'] as String,
          mime: file['mime'] as String? ?? 'application/octet-stream',
        ),
    ],
    failedFiles: map['failedFiles'] as int? ?? 0,
  );

  final String id;
  final String text;
  final List<DocumentAttachment> files;
  final int failedFiles;
}

/// Native inboxes retain a share until the chat composer accepts its own copies.
/// A change event is only a wake-up signal; it never consumes a delivery.
class IncomingShareService {
  IncomingShareService([
    this._channel = const MethodChannel('app.incoming_share'),
  ]);

  final MethodChannel _channel;
  final progress = ValueNotifier<ShareImportProgress?>(null);
  bool _preparing = false;
  bool _cancelled = false;
  bool _disposed = false;

  Future<void> refreshProgress() async {
    try {
      final value = await _channel.invokeMapMethod<dynamic, dynamic>(
        'getImportProgress',
      );
      if (!_preparing && !_disposed) {
        progress.value = value == null
            ? null
            : ShareImportProgress.fromMap(value);
      }
    } on MissingPluginException {
      // No native inbox in desktop/test hosts.
    }
  }

  Future<void> cancelImport() async {
    if (_preparing) {
      _cancelled = true;
    } else if (progress.value != null) {
      await _channel.invokeMethod<void>('cancelImport', progress.value!.id);
    }
  }

  void _report(ShareImportProgress value) {
    if (!_disposed) progress.value = value;
  }

  void listen({
    required void Function() onChanged,
    required void Function() onFailed,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress' && !_preparing && !_disposed) {
        progress.value = call.arguments == null
            ? null
            : ShareImportProgress.fromMap(call.arguments as Map);
      }
      if (call.method == 'changed') onChanged();
      if (call.method == 'failed') onFailed();
    });
    unawaited(refreshProgress());
  }

  Future<List<IncomingShare>> pending() async {
    final values = await _channel.invokeListMethod<dynamic>('getPendingShares');
    return [
      for (final value in values ?? const [])
        IncomingShare.fromMap(value as Map),
    ];
  }

  Future<void> acknowledge(List<IncomingShare> shares) =>
      _channel.invokeMethod<void>(
        'acknowledgeShares',
        shares.map((share) => share.id).toList(),
      );

  /// Use filesystem copying instead of buffering whole videos/documents in Dart.
  /// All destinations are newly reserved, so a failed batch can be rolled back.
  Future<ChatInputData> prepare(
    List<IncomingShare> shares, {
    Directory? uploadDirectory,
  }) async {
    final directory =
        uploadDirectory ?? await AppDirectories.getUploadDirectory();
    await directory.create(recursive: true);
    _preparing = true;
    _cancelled = false;
    final count = shares.fold<int>(
      0,
      (count, share) => count + share.files.length,
    );
    var index = 0;
    final copied = <File>[];
    final images = <String>[];
    final documents = <DocumentAttachment>[];
    try {
      for (final share in shares) {
        for (final file in share.files) {
          var name = file.fileName.replaceAll('\\', '/').split('/').last;
          if (name.isEmpty || name == '.' || name == '..') name = 'shared-file';
          final target = await UploadDedupe.reserveUniqueFile(directory, name);
          copied.add(target);
          final source = File(file.path);
          final total = await source.length();
          index++;
          var bytes = 0;
          void report() => _report(
            ShareImportProgress(
              id: 'prepare',
              name: name,
              index: index,
              count: count,
              bytes: bytes,
              total: total,
            ),
          );
          report();
          final output = await target.open(mode: FileMode.write);
          final clock = Stopwatch()..start();
          try {
            await for (final chunk in source.openRead()) {
              if (_cancelled || _disposed) throw ShareImportCancelled();
              await output.writeFrom(chunk);
              bytes += chunk.length;
              if (clock.elapsedMilliseconds >= 100) {
                report();
                clock.reset();
              }
            }
            if (_cancelled || _disposed) throw ShareImportCancelled();
            report();
          } finally {
            await output.close();
          }
          final mime = resolveDocumentAttachmentMime(file);
          if (isImageMime(mime)) {
            images.add(target.path);
          } else {
            documents.add(
              DocumentAttachment(
                path: target.path,
                fileName: p.basename(target.path),
                mime: mime,
              ),
            );
          }
        }
      }
      return ChatInputData(
        text: shares
            .map((share) => share.text)
            .where((text) => text.trim().isNotEmpty)
            .join('\n\n'),
        imagePaths: images,
        documents: documents,
      );
    } catch (_) {
      await _deleteUnsharedCopies(copied.map((file) => file.path));
      rethrow;
    } finally {
      _preparing = false;
      if (!_disposed) progress.value = null;
    }
  }

  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    progress.dispose();
  }

  /// Only for a prepared batch that has not been handed to the composer.
  Future<void> discardPrepared(ChatInputData input) async {
    await _deleteUnsharedCopies([
      ...input.imagePaths,
      ...input.documents.map((file) => file.path),
    ]);
  }

  Future<void> _deleteUnsharedCopies(Iterable<String> paths) async {
    for (final path in paths) {
      await UploadDedupe.deleteIfUnshared(path);
    }
  }
}
