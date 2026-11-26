import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeFileSave {
  static const MethodChannel _channel = MethodChannel('app.file_save');

  static int _nextProgressId = 0;
  static final _progress = <int, void Function(int, int)>{};

  static Future<void> _receiveProgress(MethodCall call) async {
    if (call.method != 'saveProgress') return;
    final values = call.arguments as List;
    _progress[values[0]]?.call(values[1] as int, values[2] as int);
  }

  @visibleForTesting
  static bool debugForceAndroidForTest = false;

  /// Saves the encoded image to iOS Photos without requiring library read access.
  static Future<bool> saveImageToGallery({required String sourcePath}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('Native photo saving is only supported on iOS.');
    }
    return await _channel.invokeMethod<bool>('saveImageToGallery', {
          'sourcePath': sourcePath,
        }) ==
        true;
  }

  /// Lets Android choose a document first, then streams bytes through the
  /// platform channel. This avoids both a second full-size local file and
  /// reopening a SAF descriptor through `/proc/self/fd`, which some ROMs deny.
  static Future<bool> saveFileWithWriter({
    required String fileName,
    required Future<void> Function(
      Future<void> Function(Uint8List bytes) writeChunk,
    )
    write,
  }) async {
    if (!Platform.isAndroid && !debugForceAndroidForTest) {
      throw UnsupportedError(
        'Direct writable file destinations are only supported on Android.',
      );
    }

    final result = await _channel.invokeMethod<dynamic>('createWritableFile', {
      'fileName': fileName.trim(),
    });
    if (result == null) return false;
    if (result != true) {
      throw const FileSystemException('Android did not open a backup target.');
    }

    try {
      await write((bytes) async {
        if (bytes.isEmpty) return;
        await _channel.invokeMethod<void>('writeWritableFileChunk', bytes);
      });
      await _channel.invokeMethod<void>('completeWritableFile');
      return true;
    } catch (_) {
      try {
        await _channel.invokeMethod<void>('abortWritableFile');
      } catch (_) {
        // Preserve the backup error; destination cleanup is best-effort.
      }
      rethrow;
    }
  }

  static Future<bool> saveFileFromPath({
    required String sourcePath,
    String? fileName,
    bool requireOutsideAppContainer = false,
    String? dialogTitle,
    void Function(int written, int total)? onProgress,
    Future<void>? whenCancelled,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError(
        'Native file save is only supported on Android and iOS.',
      );
    }

    final id = onProgress == null ? null : ++_nextProgressId;
    if (id != null) {
      _channel.setMethodCallHandler(_receiveProgress);
      _progress[id] = onProgress!;
      if (whenCancelled != null) {
        unawaited(
          whenCancelled.then((_) async {
            if (!_progress.containsKey(id)) return;
            try {
              await _channel.invokeMethod<void>('cancelSave', id);
            } on PlatformException {
              // The original save call owns the result if its Activity detached.
            } on MissingPluginException {
              // The engine has already detached from the native picker.
            }
          }),
        );
      }
    }
    try {
      return await _channel.invokeMethod<bool>('saveFileFromPath', {
            'sourcePath': sourcePath,
            if (fileName != null && fileName.isNotEmpty) 'fileName': fileName,
            if (requireOutsideAppContainer &&
                defaultTargetPlatform == TargetPlatform.iOS)
              'requireOutsideAppContainer': true,
            if (dialogTitle != null) 'dialogTitle': dialogTitle,
            if (id != null) 'progressId': id,
          }) ==
          true;
    } on PlatformException catch (error) {
      if (id != null && error.code == 'cancelled') return false;
      rethrow;
    } finally {
      if (id != null) _progress.remove(id);
    }
  }
}
