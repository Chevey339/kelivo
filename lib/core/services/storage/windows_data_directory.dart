import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../backup/restore_business_lease.dart';
import '../backup/restore_durability.dart';
import '../backup/restore_startup_gate.dart';
import '../workspace/network_path_check.dart';
import 'data_directory_paths.dart';
import '../../../utils/windows_file_path.dart';

final class DataDirectoryLocation {
  const DataDirectoryLocation(this.path, this.id);

  final String path;
  final String id;

  Map<String, String> toJson() => {'path': path, 'id': id};

  factory DataDirectoryLocation.fromJson(Object? value) {
    if (value is! Map ||
        value['path'] is! String ||
        !p.isAbsolute(value['path'] as String) ||
        value['id'] is! String ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(value['id'] as String)) {
      throw const FormatException('data_directory_settings');
    }
    return DataDirectoryLocation(
      value['path'] as String,
      value['id'] as String,
    );
  }
}

final class WindowsDataDirectoryState {
  const WindowsDataDirectoryState({
    this.active,
    this.pending,
    this.previous,
    this.confirmed = false,
  });

  final DataDirectoryLocation? active;
  final DataDirectoryLocation? pending;
  final DataDirectoryLocation? previous;
  final bool confirmed;

  Map<String, Object?> toJson() => {
    'version': 1,
    'active': active?.toJson(),
    'pending': pending?.toJson(),
    'previous': previous?.toJson(),
    'confirmed': confirmed,
  };

  factory WindowsDataDirectoryState.fromJson(Object? value) {
    if (value is! Map || value['version'] != 1 || value['confirmed'] is! bool) {
      throw const FormatException('data_directory_settings');
    }
    DataDirectoryLocation? location(String key) =>
        value[key] == null ? null : DataDirectoryLocation.fromJson(value[key]);
    final state = WindowsDataDirectoryState(
      active: location('active'),
      pending: location('pending'),
      previous: location('previous'),
      confirmed: value['confirmed'] as bool,
    );
    if ((state.previous != null || state.pending != null) &&
            state.active == null ||
        state.previous != null && state.pending != null) {
      throw const FormatException('data_directory_settings');
    }
    return state;
  }
}

/// The locator stays in the OS support directory. Business data can move.
/// All moves run on cold start, before opening SQLite or starting services.
final class WindowsDataDirectory {
  WindowsDataDirectory({
    required this.supportDirectory,
    RestoreDurability? durability,
  }) : _io = durability ?? RestorePlatformDurability();

  static Future<WindowsDataDirectory>? _instance;

  static Future<WindowsDataDirectory> get instance =>
      _instance ??= _createInstance();

  static Future<WindowsDataDirectory> _createInstance() async {
    try {
      final support = await getApplicationSupportDirectory();
      await support.create(recursive: true);
      return WindowsDataDirectory(
        supportDirectory: Directory(await support.resolveSymbolicLinks()),
      );
    } catch (_) {
      _instance = null;
      rethrow;
    }
  }

  static const controlName = '.kelivo_storage';
  static const identityName = '.kelivo_data_root.json';
  static const _preferencesName = 'shared_preferences.json';

  final Directory supportDirectory;
  final RestoreDurability _io;
  RestoreBusinessLease? _controlLease;
  WindowsDataDirectoryState? _state;
  Directory? _resolvedDirectory;
  int _sequence = 0;

  bool get ownsControlLease =>
      _controlLease != null && !_controlLease!.isClosed;

  void _requireControlLease() {
    if (!ownsControlLease) throw StateError('data_directory_not_initialized');
  }

  Directory get _control =>
      Directory(p.join(supportDirectory.path, controlName));

  Future<WindowsDataDirectoryState> get state async =>
      _state ??= await _readState();

  Future<Directory> get directory async {
    if (_resolvedDirectory != null) return _resolvedDirectory!;
    final active = (await state).active;
    if (active == null) return _resolvedDirectory = supportDirectory;
    await _requireIdentity(active);
    return _resolvedDirectory = Directory(active.path);
  }

  /// Also serializes launches across different selected data roots. The
  /// ordinary business lease remains owned by main for the selected root.
  Future<void> initialize({void Function()? onMoving}) async {
    _controlLease ??= await RestoreBusinessLease.acquire(
      appDataDirectory: _control,
    );
    _state = await _readState();
    _resolvedDirectory = null;
    await directory; // A missing configured root must never become an empty app.
    if ((await state).pending != null) {
      onMoving?.call();
      await _move();
    }
  }

  Future<void> schedule(Directory selected) async {
    _requireControlLease();
    final current = await state;
    if (current.pending != null || current.previous != null) {
      throw StateError('data_directory_finish_previous');
    }
    final source = await directory;
    if (await RestoreStartupGate.hasPendingWork(appDataDirectory: source)) {
      throw StateError('data_directory_pending_restore');
    }
    final target = await _validateTarget(selected, source);
    final staleIdentity = File(p.join(target.path, identityName));
    if (await staleIdentity.exists()) await staleIdentity.delete();
    // The default directory also gets an identity before it can be retained.
    final sourceMarker = File(p.join(source.path, identityName));
    final sourceLocation =
        current.active ??
        DataDirectoryLocation(
          source.path,
          await sourceMarker.exists()
              ? jsonDecode(await sourceMarker.readAsString())['id'] as String
              : const Uuid().v4(),
        );
    if (current.active == null) await _writeIdentity(sourceLocation);
    await _publish(
      WindowsDataDirectoryState(
        active: sourceLocation,
        pending: DataDirectoryLocation(target.path, const Uuid().v4()),
        confirmed: true,
      ),
    );
  }

  Future<Directory> _validateTarget(
    Directory selected,
    Directory source,
  ) async {
    final raw = selected.absolute.path;
    if (await networkTargetForApproval(raw, source.path) != null) {
      throw StateError('data_directory_local_only');
    }
    if (await FileSystemEntity.type(raw, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('data_directory_unavailable');
    }
    final target = Directory(await selected.resolveSymbolicLinks());
    final original = await source.resolveSymbolicLinks();
    final bootstrap = await supportDirectory.resolveSymbolicLinks();
    if (p.equals(target.path, p.dirname(target.path)) ||
        _overlaps(target.path, original) ||
        (!p.equals(target.path, bootstrap) &&
            _overlaps(target.path, bootstrap))) {
      throw StateError('data_directory_overlap');
    }
    await for (final child in target.list(followLinks: false)) {
      if (_excluded(target, p.basename(child.path))) continue;
      throw StateError('data_directory_not_empty');
    }
    final probe = File(
      p.join(target.path, '.kelivo-write-${const Uuid().v4()}'),
    );
    try {
      await probe.writeAsString('Kelivo', flush: true);
    } finally {
      if (await probe.exists()) await probe.delete();
    }
    return target;
  }

  Future<void> _move() async {
    final current = await state;
    final from = current.active!;
    final to = current.pending!;
    final source = Directory(from.path);
    final target = Directory(to.path);
    await _requireIdentity(from);
    final lease = await RestoreBusinessLease.acquire(appDataDirectory: source);
    try {
      if (await RestoreStartupGate.hasPendingWork(appDataDirectory: source)) {
        throw StateError('data_directory_pending_restore');
      }
      if (_overlaps(
        await source.resolveSymbolicLinks(),
        await target.resolveSymbolicLinks(),
      )) {
        throw StateError('data_directory_overlap');
      }
      if (!p.equals(target.path, await target.resolveSymbolicLinks())) {
        throw StateError('data_directory_unavailable');
      }
      final manifest = await _inventory(source);
      if (!manifest.containsKey('kelivo.db')) {
        throw StateError('data_directory_database_missing');
      }
      await _writeManifest(to.id, manifest);
      final marker = File(p.join(target.path, identityName));
      if (await marker.exists()) {
        await _requireIdentity(to);
      } else {
        await _validateTarget(target, source);
        await _writeIdentity(to);
      }
      // Source is closed and locked, so a retry can rebuild every changed
      // database sidecar before repeating the path rewrite transaction.
      await _requireOnlyKnownEntries(
        target,
        manifest,
        allowDatabaseSidecars: true,
      );
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final relative = 'kelivo.db$suffix';
        if (manifest.containsKey(relative)) continue;
        final extra = File(p.join(target.path, relative));
        if (await extra.exists()) await extra.delete();
      }
      final paths = DataDirectoryPaths(source.path, target.path);
      // Directories and files precede links, including links to a sibling that
      // sorts later. Windows needs the target to exist to infer its link type.
      const order = {'directory': 0, 'file': 1, 'link': 2};
      final entries = manifest.entries.toList()
        ..sort((a, b) {
          final kinds = order[a.value['kind']]!.compareTo(
            order[b.value['kind']]!,
          );
          return kinds == 0 ? a.key.compareTo(b.key) : kinds;
        });
      for (final entry in entries) {
        final relative = entry.key;
        final metadata = entry.value;
        final destination = p.join(target.path, relative);
        switch (metadata['kind']) {
          case 'directory':
            await Directory(destination).create(recursive: true);
          case 'link':
            final link = Link(destination);
            final next = paths.rewrite(metadata['target'] as String);
            if (await FileSystemEntity.type(destination, followLinks: false) !=
                FileSystemEntityType.notFound) {
              if (await FileSystemEntity.type(
                    destination,
                    followLinks: false,
                  ) !=
                  FileSystemEntityType.link) {
                throw StateError('data_directory_copy_changed');
              }
              if (await link.target() == next) continue;
              await link.delete();
            }
            await link.create(next);
          case 'file':
            final file = File(destination);
            if (await _matches(file, metadata)) {
              // A matching file may come from a copy interrupted before flush.
              await _io.syncFile(file, fullBarrier: true);
              continue;
            }
            final type = await FileSystemEntity.type(
              destination,
              followLinks: false,
            );
            if (type != FileSystemEntityType.notFound &&
                type != FileSystemEntityType.file) {
              throw StateError('data_directory_copy_changed');
            }
            await _copyFile(File(p.join(source.path, relative)), file);
            await _io.syncFile(file, fullBarrier: true);
            if (!await _matches(file, metadata)) {
              throw StateError('data_directory_copy_changed');
            }
        }
      }
      if (jsonEncode(manifest) != jsonEncode(await _inventory(source))) {
        throw StateError('data_directory_source_changed');
      }
      await paths.rewriteCopy(target);
      // SQLite checkpointing and browser state rewriting happen after the
      // byte-for-byte copy check. Flush those changes before publishing.
      for (final relative in [
        'kelivo.db',
        'kelivo.db-wal',
        'browser/state.json',
      ]) {
        final file = File(p.join(target.path, relative));
        if (await file.exists()) await _io.syncFile(file, fullBarrier: true);
      }
      for (final entry in entries.reversed) {
        if (entry.value['kind'] == 'directory') {
          await _io.syncDirectory(
            Directory(p.join(target.path, entry.key)),
            fullBarrier: true,
          );
        }
      }
      await _io.syncDirectory(target, fullBarrier: true);
      await _publish(WindowsDataDirectoryState(active: to, previous: from));
    } finally {
      await lease.close();
    }
  }

  /// Called only after the normal database admission and business load pass.
  Future<void> confirmStartup() async {
    _requireControlLease();
    final current = await state;
    if (current.active == null ||
        current.confirmed ||
        current.pending != null) {
      return;
    }
    await _publish(
      WindowsDataDirectoryState(
        active: current.active,
        previous: current.previous,
        confirmed: true,
      ),
    );
  }

  /// Cancelling only withdraws the move intent. The original directory stays
  /// authoritative, and partial destination files are retained for the user.
  /// An unavailable or externally edited destination cannot block cancellation.
  Future<void> cancel() async {
    _requireControlLease();
    final current = await state;
    final pending = current.pending;
    if (pending == null) return;
    await _requireIdentity(current.active!);
    await _publish(
      WindowsDataDirectoryState(active: current.active, confirmed: true),
    );
  }

  Future<void> _copyFile(File source, File destination) async {
    // File.copy on Windows retains READONLY and uses a random sibling temp
    // file. Direct writes leave only this manifest-owned path after a crash,
    // and the new copy is writable without altering source attributes.
    final output = await destination.open(mode: FileMode.write);
    try {
      await for (final bytes in source.openRead()) {
        await output.writeFrom(bytes);
      }
    } finally {
      await output.close();
    }
  }

  Future<void> cleanPrevious() async {
    _requireControlLease();
    final current = await state;
    final previous = current.previous;
    if (previous == null) return;
    if (!current.confirmed || current.pending != null) {
      throw StateError('data_directory_not_confirmed');
    }
    await _requireIdentity(current.active!);
    final source = Directory(previous.path);
    await _requireIdentity(previous);
    if (_overlaps(
      await source.resolveSymbolicLinks(),
      await (await directory).resolveSymbolicLinks(),
    )) {
      throw StateError('data_directory_overlap');
    }
    final lease = await RestoreBusinessLease.acquire(appDataDirectory: source);
    try {
      final manifest = await _readManifest(current.active!.id);
      await _requireOnlyKnownEntries(source, manifest);
      // Validate all remaining files before deleting any. Missing files allow
      // an interrupted cleanup to resume; changed files are never removed.
      for (final entry in manifest.entries) {
        final path = p.join(source.path, entry.key);
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        final metadata = entry.value;
        if (metadata['kind'] == 'file' &&
                !await _matches(File(path), metadata) ||
            metadata['kind'] == 'directory' &&
                type != FileSystemEntityType.directory ||
            metadata['kind'] == 'link' &&
                (type != FileSystemEntityType.link ||
                    await Link(path).target() != metadata['target'])) {
          throw StateError('data_directory_source_changed');
        }
      }
      await _deleteEntries(source, manifest);
      // Keep the identity so an interrupted cleanup can resume. A later move
      // into this now-empty folder replaces it when scheduling the move.
      await _publish(
        WindowsDataDirectoryState(active: current.active, confirmed: true),
      );
    } finally {
      await lease.close();
    }
  }

  bool _excluded(Directory root, String name) =>
      name == RestoreBusinessLease.leaseDirectoryName ||
      name == identityName ||
      (name.startsWith('$identityName.') && name.endsWith('.tmp')) ||
      (p.equals(root.path, supportDirectory.path) &&
          (name == controlName || name == _preferencesName));

  static bool _overlaps(String first, String second) =>
      p.equals(first, second) ||
      p.isWithin(first, second) ||
      p.isWithin(second, first);

  Future<Map<String, Map<String, Object>>> _inventory(Directory root) async {
    final result = <String, Map<String, Object>>{};
    Future<void> visit(Directory directory) async {
      final children = await directory.list(followLinks: false).toList();
      children.sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        final relative = p.relative(child.path, from: root.path);
        if (p.equals(directory.path, root.path) && _excluded(root, relative)) {
          continue;
        }
        if (child is Directory) {
          result[relative] = {'kind': 'directory'};
          await visit(child);
        } else if (child is File) {
          result[relative] = {
            'kind': 'file',
            'bytes': await child.length(),
            'sha256': (await sha256.bind(child.openRead()).first).toString(),
          };
        } else if (child is Link) {
          result[relative] = {'kind': 'link', 'target': await child.target()};
        } else {
          throw StateError('data_directory_file_type');
        }
      }
    }

    await visit(root);
    return result;
  }

  Future<bool> _matches(File file, Map<String, Object> metadata) async =>
      await FileSystemEntity.type(file.path, followLinks: false) ==
          FileSystemEntityType.file &&
      await file.length() == metadata['bytes'] &&
      (await sha256.bind(file.openRead()).first).toString() ==
          metadata['sha256'];

  Future<void> _requireOnlyKnownEntries(
    Directory root,
    Map<String, Map<String, Object>> manifest, {
    bool allowDatabaseSidecars = false,
  }) async {
    Future<void> visit(Directory directory) async {
      await for (final child in directory.list(followLinks: false)) {
        final relative = p.relative(child.path, from: root.path);
        if (p.equals(directory.path, root.path) && _excluded(root, relative)) {
          continue;
        }
        // SQLite may remove/create its sidecars while rewriting the copy.
        if (allowDatabaseSidecars &&
            const [
              'kelivo.db-wal',
              'kelivo.db-shm',
              'kelivo.db-journal',
            ].contains(relative)) {
          if (child is! File) throw StateError('data_directory_copy_changed');
          continue;
        }
        final kind = manifest[relative]?['kind'];
        if (kind == null ||
            (kind == 'directory' && child is! Directory) ||
            (kind == 'file' && child is! File) ||
            (kind == 'link' && child is! Link)) {
          throw StateError('data_directory_copy_changed');
        }
        if (child is Directory) await visit(child);
      }
    }

    await visit(root);
  }

  Future<void> _deleteEntries(
    Directory root,
    Map<String, Map<String, Object>> manifest,
  ) async {
    final paths = manifest.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final relative in paths) {
      final path = p.join(root.path, relative);
      switch (await FileSystemEntity.type(path, followLinks: false)) {
        case FileSystemEntityType.file:
          final file = File(path);
          // Only a verified retained source reaches here, after explicit user
          // confirmation. Windows refuses to delete READONLY files otherwise.
          _clearWindowsReadOnly(file);
          await file.delete();
        case FileSystemEntityType.link:
          await Link(path).delete();
        case FileSystemEntityType.directory:
          await Directory(path).delete();
        case FileSystemEntityType.notFound:
          break;
        default:
          throw StateError('data_directory_file_type');
      }
    }
  }

  static final _windows = DynamicLibrary.open('kernel32.dll');
  static final _getFileAttributes = _windows
      .lookupFunction<
        Uint32 Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)
      >('GetFileAttributesW');
  static final _setFileAttributes = _windows
      .lookupFunction<
        Int32 Function(Pointer<Utf16>, Uint32),
        int Function(Pointer<Utf16>, int)
      >('SetFileAttributesW');
  static final _lastWindowsError = _windows
      .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

  static void _clearWindowsReadOnly(File file) {
    if (!Platform.isWindows) return;
    final path = extendedWindowsFilePath(file.absolute.path).toNativeUtf16();
    try {
      final attributes = _getFileAttributes(path);
      const invalid = 0xffffffff;
      const readOnly = 0x1;
      const normal = 0x80;
      final writable = attributes & ~readOnly;
      if (attributes == invalid ||
          (attributes & readOnly != 0 &&
              _setFileAttributes(path, writable == 0 ? normal : writable) ==
                  0)) {
        throw FileSystemException(
          'Cannot clear read-only file attribute',
          file.path,
          OSError('Windows file attributes', _lastWindowsError()),
        );
      }
    } finally {
      calloc.free(path);
    }
  }

  Future<void> _requireIdentity(DataDirectoryLocation location) async {
    final root = Directory(location.path);
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('data_directory_unavailable');
    }
    if (!p.equals(root.path, await root.resolveSymbolicLinks())) {
      throw StateError('data_directory_unavailable');
    }
    final file = File(p.join(root.path, identityName));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        jsonDecode(await file.readAsString())['id'] != location.id) {
      throw StateError('data_directory_identity');
    }
  }

  Future<void> _writeIdentity(DataDirectoryLocation location) async {
    final file = File(p.join(location.path, identityName));
    if (await file.exists()) {
      await _requireIdentity(location);
      return;
    }
    await _writeNew(file, {'id': location.id});
  }

  Future<WindowsDataDirectoryState> _readState() async {
    if (!await _control.exists()) return const WindowsDataDirectoryState();
    final files = await _control
        .list(followLinks: false)
        .where(
          (entry) => RegExp(
            r'^state-[0-9]{12}\.json$',
          ).hasMatch(p.basename(entry.path)),
        )
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) return const WindowsDataDirectoryState();
    final latest = files.last;
    if (latest is! File) throw const FormatException('data_directory_settings');
    _sequence = int.parse(p.basename(latest.path).substring(6, 18));
    return WindowsDataDirectoryState.fromJson(
      jsonDecode(await latest.readAsString()),
    );
  }

  Future<void> _publish(WindowsDataDirectoryState next) async {
    _requireControlLease();
    await state;
    final file = File(
      p.join(
        _control.path,
        'state-${(_sequence + 1).toString().padLeft(12, '0')}.json',
      ),
    );
    try {
      await _writeNew(file, next.toJson());
      _sequence++;
      _state = next;
      _resolvedDirectory = null;
    } catch (_) {
      _state = null; // A late durability error can follow a successful rename.
      _resolvedDirectory = null;
      rethrow;
    }
  }

  Future<void> _writeManifest(
    String id,
    Map<String, Map<String, Object>> manifest,
  ) async {
    final file = File(p.join(_control.path, 'manifest-$id.json'));
    if (await file.exists()) {
      if (await file.readAsString() != jsonEncode(manifest)) {
        throw StateError('data_directory_source_changed');
      }
      return;
    }
    await _writeNew(file, manifest);
  }

  Future<Map<String, Map<String, Object>>> _readManifest(String id) async {
    final value =
        jsonDecode(
              await File(
                p.join(_control.path, 'manifest-$id.json'),
              ).readAsString(),
            )
            as Map;
    final result = <String, Map<String, Object>>{};
    for (final entry in value.entries) {
      final path = entry.key as String;
      if (path.isEmpty ||
          p.isAbsolute(path) ||
          p.split(path).contains('..') ||
          path == '.') {
        throw const FormatException('data_directory_manifest');
      }
      final metadata = Map<String, Object>.from(entry.value as Map);
      final valid = switch (metadata['kind']) {
        'directory' => metadata.length == 1,
        'file' =>
          metadata['bytes'] is int &&
              (metadata['bytes'] as int) >= 0 &&
              metadata['sha256'] is String &&
              RegExp(r'^[a-f0-9]{64}$').hasMatch(metadata['sha256'] as String),
        'link' => metadata['target'] is String,
        _ => false,
      };
      if (!valid) throw const FormatException('data_directory_manifest');
      result[path] = metadata;
    }
    return result;
  }

  Future<void> _writeNew(File file, Object value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await _io.syncFile(temporary, fullBarrier: true);
    await _io.renameAndSync(source: temporary, targetPath: file.path);
  }

  /// For lifecycle tests; production retains this lease until process exit.
  Future<void> close() async {
    await _controlLease?.close();
    _controlLease = null;
  }
}
