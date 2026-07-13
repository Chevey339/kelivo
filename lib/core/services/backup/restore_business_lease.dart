import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'restore_durability.dart';

/// Thrown when another business process or this Dart process already owns the
/// restore business lease.
final class RestoreBusinessLeaseUnavailable implements Exception {
  const RestoreBusinessLeaseUnavailable(this.path, {this.cause});

  final String path;
  final FileSystemException? cause;

  @override
  String toString() => 'Restore business lease is unavailable: $path';
}

/// A process-lifetime lease preventing restore cutover from overlapping an
/// already running business process.
///
/// The operating-system advisory lock is non-blocking. The process registry is
/// also required because POSIX advisory locks have process-wide semantics and
/// may otherwise allow the same Dart process to appear to acquire the lock
/// more than once.
final class RestoreBusinessLease {
  RestoreBusinessLease._({
    required this.lockFile,
    required this.instanceId,
    required this.processId,
    required this._processOwnerFile,
    required _ProcessOwnerProbe processOwnerProbe,
    required this._registryKey,
    required this._handle,
  }) : _processOwnerProbe = processOwnerProbe;

  static const leaseDirectoryName = '.kelivo_business_lease';
  static const lockFileName = 'lease.lock';
  static const _processOwnerPrefix = 'owner_';

  static final Map<String, RestoreBusinessLease?> _processLeases = {};

  final File lockFile;
  final String instanceId;

  /// Stable native process identity captured when this lease was acquired.
  ///
  /// Unlike [instanceId], reacquiring the lease in the same OS process keeps
  /// this value unchanged. It is intentionally part of cold-restart proof.
  final int processId;
  final File _processOwnerFile;
  final _ProcessOwnerProbe _processOwnerProbe;
  final String _registryKey;
  RandomAccessFile? _handle;

  bool get isClosed => _handle == null;

  /// Acquires the fixed AppData business lease without waiting.
  ///
  /// [RestoreBusinessLeaseUnavailable] means that the exact lease is already
  /// held. Other filesystem or durability failures are propagated unchanged.
  static Future<RestoreBusinessLease> acquire({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    final leaseDirectory = Directory(
      p.join(appDataDirectory.path, leaseDirectoryName),
    );
    final lockFile = File(p.join(leaseDirectory.path, lockFileName));
    final registryKey = p.normalize(p.absolute(lockFile.path));
    if (_processLeases.containsKey(registryKey)) {
      throw RestoreBusinessLeaseUnavailable(registryKey);
    }
    _processLeases[registryKey] = null;

    final resolvedDurability = durability ?? RestorePlatformDurability();
    RandomAccessFile? handle;
    var locked = false;
    var ownsProcessMarker = false;
    _ProcessOwnerProbe? processOwnerProbe;
    final instanceId = _newInstanceId();
    late final File processOwnerFile;
    try {
      await _ensureLeaseDirectory(
        appDataDirectory: appDataDirectory,
        leaseDirectory: leaseDirectory,
        durability: resolvedDurability,
      );
      final initialLockType = await FileSystemEntity.type(
        lockFile.path,
        followLinks: false,
      );
      if (initialLockType != FileSystemEntityType.notFound &&
          initialLockType != FileSystemEntityType.file) {
        throw StateError('restore_business_lease_lock_file');
      }

      handle = await lockFile.open(mode: FileMode.append);
      if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('restore_business_lease_lock_file');
      }
      await resolvedDurability.restrictFile(lockFile);
      try {
        await handle.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException catch (error) {
        if (_isLockUnavailable(error)) {
          throw RestoreBusinessLeaseUnavailable(registryKey, cause: error);
        }
        rethrow;
      }

      processOwnerFile = File(
        p.join(leaseDirectory.path, '$_processOwnerPrefix$pid'),
      );
      processOwnerProbe = await _ProcessOwnerProbe.open(instanceId);
      await _claimProcessOwner(
        ownerFile: processOwnerFile,
        registryKey: registryKey,
        instanceId: instanceId,
        processOwnerProbe: processOwnerProbe,
        durability: resolvedDurability,
      );
      ownsProcessMarker = true;

      await _removeStaleProcessOwners(
        leaseDirectory: leaseDirectory,
        currentOwner: processOwnerFile,
      );

      final lease = RestoreBusinessLease._(
        lockFile: lockFile,
        instanceId: instanceId,
        processId: pid,
        processOwnerFile: processOwnerFile,
        processOwnerProbe: processOwnerProbe,
        registryKey: registryKey,
        handle: handle,
      );
      handle = null;
      _processLeases[registryKey] = lease;
      return lease;
    } catch (_) {
      if (handle != null) {
        try {
          if (locked) await handle.unlock();
        } finally {
          await handle.close();
        }
      }
      await processOwnerProbe?.close();
      if (ownsProcessMarker) {
        await _deleteProcessOwner(processOwnerFile);
      }
      _processLeases.remove(registryKey);
      rethrow;
    }
  }

  /// Releases this lease. Repeated calls are harmless.
  Future<void> close() async {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;

    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await handle.unlock();
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await handle.close();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    try {
      await _deleteProcessOwner(_processOwnerFile);
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    try {
      await _processOwnerProbe.close();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    } finally {
      if (identical(_processLeases[_registryKey], this)) {
        _processLeases.remove(_registryKey);
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  static Future<void> _ensureLeaseDirectory({
    required Directory appDataDirectory,
    required Directory leaseDirectory,
    required RestoreDurability durability,
  }) async {
    final appDataType = await FileSystemEntity.type(
      appDataDirectory.path,
      followLinks: false,
    );
    if (appDataType == FileSystemEntityType.notFound) {
      await appDataDirectory.create(recursive: true);
    } else if (appDataType != FileSystemEntityType.directory) {
      throw StateError('restore_business_lease_app_data');
    }
    if (await FileSystemEntity.type(
          appDataDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_business_lease_app_data');
    }

    final leaseDirectoryType = await FileSystemEntity.type(
      leaseDirectory.path,
      followLinks: false,
    );
    if (leaseDirectoryType == FileSystemEntityType.notFound) {
      await leaseDirectory.create();
      await durability.restrictDirectory(leaseDirectory);
    } else if (leaseDirectoryType == FileSystemEntityType.directory) {
      await durability.restrictDirectory(leaseDirectory);
    } else {
      throw StateError('restore_business_lease_directory');
    }
    if (await FileSystemEntity.type(leaseDirectory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_business_lease_directory');
    }
  }

  static Future<void> _claimProcessOwner({
    required File ownerFile,
    required String registryKey,
    required String instanceId,
    required _ProcessOwnerProbe processOwnerProbe,
    required RestoreDurability durability,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final type = await FileSystemEntity.type(
        ownerFile.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound) {
        if (type == FileSystemEntityType.file) {
          if (await _ProcessOwnerProbe.isLive(ownerFile)) {
            throw RestoreBusinessLeaseUnavailable(registryKey);
          }
          // The OS lock has already been acquired and the same-PID isolate
          // probe is no longer live. This is the orphan left by hot restart or
          // Android engine recreation, so every build mode may reclaim it.
          await _deleteProcessOwner(ownerFile);
        } else {
          throw StateError('restore_business_lease_process_owner');
        }
      }
      try {
        await ownerFile.create(exclusive: true);
      } on FileSystemException {
        final collidedType = await FileSystemEntity.type(
          ownerFile.path,
          followLinks: false,
        );
        if (collidedType == FileSystemEntityType.file) {
          throw RestoreBusinessLeaseUnavailable(registryKey);
        }
        if (collidedType != FileSystemEntityType.notFound) {
          throw StateError('restore_business_lease_process_owner');
        }
        if (attempt == 1) rethrow;
        continue;
      }
      try {
        if (await FileSystemEntity.type(ownerFile.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('restore_business_lease_process_owner');
        }
        await durability.restrictFile(ownerFile);
        final identity = jsonEncode({
          'instanceId': instanceId,
          'probePort': processOwnerProbe.port,
        });
        await ownerFile.writeAsString(identity);
        if (await FileSystemEntity.type(ownerFile.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await ownerFile.readAsString() != identity) {
          throw StateError('restore_business_lease_process_owner_identity');
        }
        return;
      } catch (error, stackTrace) {
        try {
          await _deleteProcessOwner(ownerFile);
        } catch (_) {
          // Preserve the durability failure. A leftover marker is intentionally
          // fail-closed and will be cleaned by a later different process.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    throw StateError('restore_business_lease_process_owner');
  }

  static Future<void> _removeStaleProcessOwners({
    required Directory leaseDirectory,
    required File currentOwner,
  }) async {
    await for (final entity in leaseDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == lockFileName) {
        if (type != FileSystemEntityType.file) {
          throw StateError('restore_business_lease_lock_file');
        }
        continue;
      }
      if (!RegExp(r'^owner_[0-9]+$').hasMatch(name) ||
          type != FileSystemEntityType.file) {
        throw StateError('restore_business_lease_directory_entry');
      }
      if (p.equals(entity.path, currentOwner.path)) continue;
      await File(entity.path).delete();
    }
    // Owner markers coordinate live isolates only. The OS file lock remains
    // authoritative across processes, so stale-marker cleanup needs no
    // post-crash durability barrier.
  }

  static Future<void> _deleteProcessOwner(File ownerFile) async {
    final type = await FileSystemEntity.type(
      ownerFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('restore_business_lease_process_owner');
    }
    await ownerFile.delete();
  }

  static String _newInstanceId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final class _ProcessOwnerProbe {
  _ProcessOwnerProbe._(this._server, this._token);

  static const _timeout = Duration(milliseconds: 300);

  final ServerSocket _server;
  final String _token;

  int get port => _server.port;

  static Future<_ProcessOwnerProbe> open(String token) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final probe = _ProcessOwnerProbe._(server, token);
    server.listen(probe._answer, onError: (_) {});
    return probe;
  }

  static Future<bool> isLive(File ownerFile) async {
    try {
      final decoded = jsonDecode(await ownerFile.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      final token = decoded['instanceId'];
      final port = decoded['probePort'];
      if (token is! String || port is! int || port <= 0 || port > 65535) {
        return false;
      }
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: _timeout,
      );
      try {
        socket.writeln(token);
        await socket.flush();
        final response = await socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(_timeout);
        return response == 'alive';
      } finally {
        socket.destroy();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _answer(Socket socket) async {
    try {
      final request = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(_timeout);
      socket.writeln(request == _token ? 'alive' : 'denied');
      await socket.flush();
    } catch (_) {
      // A malformed probe is not a lease failure.
    } finally {
      await socket.close();
    }
  }

  Future<void> close() => _server.close();
}

bool _isLockUnavailable(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (code == null) return false;
  if (Platform.isWindows) {
    return code == 32 || code == 33;
  }
  return code == 11 || code == 13 || code == 35;
}
