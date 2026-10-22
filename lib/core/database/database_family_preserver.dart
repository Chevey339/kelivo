import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/backup/restore_durability.dart';

/// Keeps a complete, immutable SQLite family before retiring any live member.
/// Callers hold the business lease. The pending record is replayed before any
/// database is opened, so an interrupted retirement cannot expose a stale DB.
abstract final class DatabaseFamilyPreserver {
  static const pendingName = '.kelivo_database_preservation.json';
  static const manifestName = '.kelivo_database_family.json';
  static const directoryPrefix = 'kelivo.db.displaced-';
  static const suffixes = ['', '-wal', '-shm', '-journal'];
  static const failedRecoveryPhase = 'retiring failed database preservation';

  static bool isCopyDirectory(String name) =>
      RegExp(r'^kelivo\.db\.displaced-[0-9]+$').hasMatch(name);

  static Future<String?> preserve(
    File source, {
    required RestoreDurability durability,
  }) async {
    final root = source.parent;
    await resume(root, durability: durability);
    final entries = <String, Object>{};
    for (final suffix in suffixes) {
      final file = File('${source.path}$suffix');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('database_preservation_type');
      }
      entries[suffix] = await _fingerprint(file);
    }
    if (entries.isEmpty) return null;
    final stamp = DateTime.now().microsecondsSinceEpoch.toString().padLeft(
      16,
      '0',
    );
    final destination = Directory(p.join(root.path, '$directoryPrefix$stamp'));
    final staged = await root.createTemp('.kelivo-database-copy-');
    await durability.restrictDirectory(staged);
    for (final suffix in entries.keys) {
      final copy = await File(
        '${source.path}$suffix',
      ).copy(p.join(staged.path, 'kelivo.db$suffix'));
      await durability.restrictFile(copy);
      await durability.syncFile(copy, fullBarrier: true);
      await _requireMatch(copy, entries[suffix]);
    }
    for (final suffix in entries.keys) {
      await _requireMatch(File('${source.path}$suffix'), entries[suffix]);
    }
    final manifest = {
      'version': 1,
      'source': p.basename(source.path),
      'entries': entries,
    };
    await _write(File(p.join(staged.path, manifestName)), manifest, durability);
    await durability.syncDirectory(staged, fullBarrier: true);
    await durability.renameAndSync(
      source: staged,
      targetPath: destination.path,
    );
    // The complete copy is now visible. Original files are only moved after
    // the durable association record exists; no source member is deleted.
    await _write(File(p.join(root.path, pendingName)), {
      'version': 1,
      'directory': p.basename(destination.path),
    }, durability);
    await resume(root, durability: durability);
    return p.join(destination.path, 'kelivo.db');
  }

  static Future<void> resume(
    Directory root, {
    required RestoreDurability durability,
  }) async {
    final pending = File(p.join(root.path, pendingName));
    final type = await FileSystemEntity.type(pending.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    final record = await _read(pending);
    final name = record['directory'];
    if (name is! String || !isCopyDirectory(name)) {
      throw StateError('database_preservation_record');
    }
    final directory = Directory(p.join(root.path, name));
    final manifest = await _validate(directory);
    final sourceName = manifest['source'] as String;
    final entries = manifest['entries'] as Map;
    for (final suffix in entries.keys.cast<String>()) {
      final source = File(p.join(root.path, '$sourceName$suffix'));
      final original = File(
        p.join(directory.path, 'original-kelivo.db$suffix'),
      );
      final sourceType = await FileSystemEntity.type(
        source.path,
        followLinks: false,
      );
      if (sourceType == FileSystemEntityType.notFound) continue;
      await _requireMatch(source, entries[suffix]);
      if (await FileSystemEntity.type(original.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('database_preservation_conflict');
      }
      await durability.renameAndSync(source: source, targetPath: original.path);
    }
    await pending.delete();
    await durability.syncDirectory(root, fullBarrier: true);
  }

  /// Only for a confirmed reset or snapshot recovery under both leases and an
  /// already durable recovery barrier. Normal startup must still call resume.
  static Future<void> prepareExplicitRecovery(
    Directory root, {
    required File recoveryBarrier,
    required RestoreDurability durability,
    bool retireExistingFamilies = false,
  }) async {
    if (await FileSystemEntity.type(recoveryBarrier.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('database_preservation_recovery_barrier');
    }
    // The barrier's existence is authoritative. Unknown/truncated bytes from
    // an interrupted phase write conservatively require retiring all families.
    var retiring =
        await recoveryBarrier.length() > 512 ||
        utf8.decode(
              await recoveryBarrier.readAsBytes(),
              allowMalformed: true,
            ) !=
            'preparing snapshot recovery';
    if (retireExistingFamilies && !retiring) {
      await recoveryBarrier.writeAsString(failedRecoveryPhase, flush: true);
      await durability.syncFile(recoveryBarrier, fullBarrier: true);
      await durability.syncDirectory(root, fullBarrier: true);
      retiring = true;
    }
    try {
      await resume(root, durability: durability);
    } catch (_) {
      // Publish this phase before removing the broken association. A retry
      // must preserve remaining originals even if the pending file is gone.
      if (!retiring) {
        await recoveryBarrier.writeAsString(failedRecoveryPhase, flush: true);
        await durability.syncFile(recoveryBarrier, fullBarrier: true);
        await durability.syncDirectory(root, fullBarrier: true);
      }
      retiring = true;
      final pendingPath = p.join(root.path, pendingName);
      final type = await FileSystemEntity.type(pendingPath, followLinks: false);
      final FileSystemEntity pending;
      if (type == FileSystemEntityType.file) {
        pending = File(pendingPath);
      } else if (type == FileSystemEntityType.directory) {
        pending = Directory(pendingPath);
      } else {
        rethrow;
      }
      final archive = await root.createTemp('.kelivo_retained_preservation_');
      await durability.restrictDirectory(archive);
      await durability.syncDirectory(root, fullBarrier: true);
      await durability.renameAndSync(
        source: pending,
        targetPath: p.join(archive.path, pendingName),
      );
    }
    // Healthy snapshot restores keep the live database as their rollback
    // source. Explicit resets and failed preservation retire the raw originals.
    if (!retiring) return;
    final names = <String>{};
    final pattern = RegExp(
      r'^(kelivo\.db(?:\.previous|\.premigrate-v[0-9]+)?)(?:-(?:wal|shm|journal))?$',
    );
    await for (final entry in root.list(followLinks: false)) {
      final match = pattern.firstMatch(p.basename(entry.path));
      if (match != null) names.add(match.group(1)!);
    }
    for (final name in names.toList()..sort()) {
      await preserve(File(p.join(root.path, name)), durability: durability);
    }
  }

  /// Every reader of a published family checks all journals against its
  /// manifest, rather than accepting a readable main file with a missing WAL.
  static Future<void> validateSource(File source) async {
    if (p.basename(source.path) == 'kelivo.db' &&
        isCopyDirectory(p.basename(source.parent.path))) {
      await _validate(source.parent);
    }
  }

  static Future<Map<String, dynamic>> _validate(Directory directory) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('database_preservation_directory');
    }
    final manifest = await _read(File(p.join(directory.path, manifestName)));
    final name = manifest['source'];
    final entries = manifest['entries'];
    if (name is! String ||
        !RegExp(
          r'^kelivo\.db(?:\.previous|\.premigrate-v[0-9]+)?$',
        ).hasMatch(name) ||
        entries is! Map ||
        entries.isEmpty ||
        entries.keys.any((key) => !suffixes.contains(key))) {
      throw StateError('database_preservation_manifest');
    }
    for (final suffix in entries.keys.cast<String>()) {
      await _requireMatch(
        File(p.join(directory.path, 'kelivo.db$suffix')),
        entries[suffix],
      );
    }
    return manifest;
  }

  static Future<Map<String, Object>> _fingerprint(File file) async => {
    'bytes': await file.length(),
    'sha256': (await sha256.bind(file.openRead()).first).toString(),
  };

  static Future<void> _requireMatch(File file, Object? expected) async {
    if (expected is! Map ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        jsonEncode(await _fingerprint(file)) != jsonEncode(expected)) {
      throw StateError('database_preservation_changed');
    }
  }

  static Future<Map<String, dynamic>> _read(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > 16384) {
      throw StateError('database_preservation_record');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic> || value['version'] != 1) {
      throw StateError('database_preservation_record');
    }
    return value;
  }

  static Future<void> _write(
    File file,
    Object value,
    RestoreDurability io,
  ) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('database_preservation_conflict');
    }
    final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await io.restrictFile(temporary);
    await io.syncFile(temporary, fullBarrier: true);
    await io.renameAndSync(source: temporary, targetPath: file.path);
  }
}
