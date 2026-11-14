import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'backup_cancel_token.dart';
import 'backup_partials.dart';
import 'backup_task_progress.dart';

/// Only this install's exact filenames enter its manifest. A crash between the
/// final rename and manifest replacement is repaired before the next prune.
class LocalFolderBackup {
  LocalFolderBackup(this.directory, this.installId, this.partials) {
    if (!RegExp(
      r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
    ).hasMatch(installId)) {
      throw const FormatException('Invalid backup installation ID');
    }
  }
  final Directory directory;
  final String installId;
  final BackupPartials partials;
  String get _prefix => 'kelivo_auto_${installId}_';
  late final _owned = RegExp(
    '^${RegExp.escape(_prefix)}[0-9]{16,20}\\.(zip|kbackup)\$',
  );
  bool _ownsPartial(String name) =>
      name.endsWith('.partial') &&
      _owned.hasMatch(name.substring(0, name.length - 8));
  String get _scope =>
      BackupPartials.scope(['local', directory.path, installId]);
  File _file(String name) => File(p.join(directory.path, name));
  File get _manifest => _file('.kelivo-autobackup-$installId.json');

  Future<void> _writeManifest(Set<String> names) async {
    final temp = File('${_manifest.path}.partial');
    // Never follow a link planted in the destination.
    if (await FileSystemEntity.type(temp.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      await temp.delete();
    }
    await temp.create(exclusive: true);
    try {
      await temp.writeAsString(
        jsonEncode({'files': names.toList()..sort()}),
        flush: true,
      );
      await temp.rename(_manifest.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<Set<String>> _reconcile() async {
    final found = <String>{};
    await for (final entry in directory.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (entry is File && _owned.hasMatch(name)) found.add(name);
    }
    Set<String> recorded = {};
    if (await FileSystemEntity.type(_manifest.path, followLinks: false) ==
        FileSystemEntityType.file) {
      try {
        final data = jsonDecode(await _manifest.readAsString());
        if (data is Map && data['files'] is List) {
          recorded = (data['files'] as List)
              .whereType<String>()
              .where(_owned.hasMatch)
              .toSet();
        }
      } on FormatException {
        /* Rebuild only from this installation's exact names. */
      }
    }
    if (found.length != recorded.length || !recorded.containsAll(found)) {
      await _writeManifest(found);
    }
    return found;
  }

  Future<void> cleanup() async {
    await partials.sweep(
      scope: _scope,
      owns: _ownsPartial,
      remove: (name) => _remove(name),
      list: () async {
        final entries = <String, DateTime?>{};
        await for (final entry in directory.list(followLinks: false)) {
          final name = p.basename(entry.path);
          if (entry is File && _ownsPartial(name)) {
            entries[name] = (await entry.stat()).modified;
          }
        }
        return entries;
      },
    );
    await _reconcile();
  }

  Future<void> _remove(String name) async {
    final file = _file(name);
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.file) {
      await file.delete();
    }
  }

  Future<void> publish(
    File source, {
    required int retention,
    BackupCancelToken? cancelToken,
    BackupProgressSink? onProgress,
    DateTime? now,
  }) async {
    final names = await _reconcile();
    final ext = p.extension(source.path);
    if (ext != '.zip' && ext != '.kbackup') {
      throw const FormatException('Invalid backup archive');
    }
    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch
        .toString()
        .padLeft(16, '0');
    final name = '$_prefix$stamp$ext';
    final temp = _file('$name.partial');
    if (await FileSystemEntity.type(_file(name).path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('Backup already exists', name);
    }
    var created = false;
    await partials.publish(
      scope: _scope,
      name: '$name.partial',
      removePartial: () async {
        if (created) await _remove('$name.partial');
      },
      write: () async {
        await temp.create(exclusive: true);
        created = true;
        final size = await source.length();
        final output = await temp.open(mode: FileMode.writeOnly);
        try {
          var copied = 0;
          await for (final chunk in source.openRead()) {
            cancelToken?.throwIfCancelled();
            await output.writeFrom(chunk);
            copied += chunk.length;
            onProgress?.call(
              BackupProgress(
                phase: BackupPhase.finalizing,
                processed: copied,
                total: size,
                unit: BackupProgressUnit.bytes,
              ),
            );
          }
          await output.flush();
        } finally {
          await output.close();
        }
        cancelToken?.throwIfCancelled();
        cancelToken?.setCancellable(false);
        onProgress?.call(
          BackupProgress(
            phase: BackupPhase.finalizing,
            processed: size,
            total: size,
            unit: BackupProgressUnit.bytes,
            cancellable: false,
          ),
        );
        await temp.rename(_file(name).path);
        names.add(name);
        await _writeManifest(names);
      },
    );

    if (retention <= 0 || names.length <= retention) return;
    final older = names.where((n) => n != name).toList()..sort();
    for (final old in older.take(names.length - retention)) {
      try {
        await _remove(old);
        names.remove(old);
      } on FileSystemException {
        /* Try after the next publication. */
      }
    }
    try {
      await _writeManifest(names);
    } on FileSystemException {
      /* Reconcile on next access. */
    }
  }
}
