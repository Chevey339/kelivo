import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeFileSave {
  static const MethodChannel _channel = MethodChannel('app.file_save');

  @visibleForTesting
  static bool debugForceAndroidForTest = false;

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
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Native file save is only supported on Android and iOS.',
      );
    }

    final result = await _channel.invokeMethod<dynamic>('saveFileFromPath', {
      'sourcePath': sourcePath,
      if (fileName != null && fileName.trim().isNotEmpty)
        'fileName': fileName.trim(),
    });
    if (result is bool) return result;
    return result == true;
  }
}
