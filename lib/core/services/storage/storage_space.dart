import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'device_storage_probe.dart';

/// An interrupted write is not evidence that the user's data is corrupt.
final class InsufficientStorageSpace implements Exception {
  const InsufficientStorageSpace({
    required this.requiredBytes,
    required this.availableBytes,
  });

  final int requiredBytes;
  final int availableBytes;

  static Future<void> require(int bytes) async {
    final available = await DeviceStorageProbe.freeBytes();
    if (available != null && available < bytes) {
      throw InsufficientStorageSpace(
        requiredBytes: bytes,
        availableBytes: available,
      );
    }
  }

  static bool causedBy(Object error) {
    if (error is InsufficientStorageSpace) return true;
    if (error is DriftRemoteException) return causedBy(error.remoteCause);
    if (error is sqlite.SqliteException) return error.resultCode == 13;
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      return Platform.isWindows ? code == 112 || code == 39 : code == 28;
    }
    return error is StateError &&
        error.message == 'private_storage_insufficient_space';
  }

  @override
  String toString() =>
      'storage_insufficient_space: required=$requiredBytes available=$availableBytes';
}
