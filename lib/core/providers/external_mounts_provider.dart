import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/extension_entity_store.dart';
import '../models/external_mount.dart';
import '../models/workspace_directory_access.dart';
import '../services/sandbox/workspace_channel.dart';
import '../services/workspace/workspace_runtime.dart';
import '../services/workspace/workspace_paths.dart';

/// Environment-level mounts, independent of the current workspace or chat.
class ExternalMountsProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  ExternalMountsProvider({required this.store, WorkspaceChannel? channel})
    : channel = channel ?? WorkspaceChannel() {
    loaded = _load();
    WidgetsBinding.instance.addObserver(this);
  }

  static const kind = 'externalMounts';
  static const maxMounts = 10;
  final ExtensionEntityStore store;
  final WorkspaceChannel channel;
  late final Future<void> loaded;
  bool _disposed = false;
  List<ExternalMount> _entries = [];
  List<Mount> _active = [];
  Map<String, String> _errors = {};
  Future<void> _tail = Future.value();

  List<ExternalMount> get entries => List.unmodifiable(_entries);
  List<Mount> get activeMounts => List.unmodifiable(_active);
  String? errorFor(String id) => _errors[id];
  ExternalMount? byId(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> _load() async {
    final entity = await store.get(kind, 'global');
    _entries = [
      for (final raw in entity?.payload['mounts'] as List? ?? [])
        ExternalMount.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    await _resolve();
    _notify();
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      await loaded;
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<Mount>> resolveMounts() => _serial(() async {
    await _resolve();
    return activeMounts;
  });

  Future<void> _resolve({bool persist = true, String? validateId}) async {
    final active = <String, Mount>{};
    final errors = <String, String>{};
    var renewed = false;
    final oldEntries = _entries;
    final resolved = <ExternalMount>[];
    for (final entry in _entries) {
      try {
        if (!ExternalMount.validName(entry.name)) {
          throw StateError('Invalid mount name');
        }
        final directory = await channel.resolveDirectory(entry.access);
        final next = entry.copyWith(
          access: directory.access,
          sourcePath: directory.path,
        );
        resolved.add(next);
        renewed |=
            entry.access != next.access || entry.sourcePath != next.sourcePath;
        active[entry.id] = Mount(
          host: directory.path,
          guest: next.guestPath,
          readOnly: next.readOnly,
        );
      } catch (error) {
        errors[entry.id] = error.toString();
        resolved.add(entry);
      }
    }
    // Do not allow writable aliases of a read-only external directory.
    final candidates = active.entries.toList();
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final a = candidates[i];
        final b = candidates[j];
        if (_overlap(a.value.host, b.value.host)) {
          const error = WorkspaceChannelException(
            code: 'external_mount_overlap',
          );
          if (a.key == validateId || b.key == validateId) throw error;
          // Bookmarks can follow folders moved into another mount in Files.
          // Keep both entries editable, but deactivate conflicting bindings.
          errors[a.key] = errors[b.key] = error.toString();
          active.remove(a.key);
          active.remove(b.key);
        }
      }
    }
    await channel.setExternalMounts([
      for (final mount in active.values)
        BindMount(
          host: mount.host,
          guest: mount.guest,
          readOnly: mount.readOnly,
        ),
    ]);
    _active = active.values.toList();
    final statusChanged = !mapEquals(_errors, errors);
    _errors = errors;
    if (renewed) {
      if (persist) await _persist(resolved);
      _entries = resolved;
      if (persist) {
        for (final old in oldEntries) {
          await _releaseIfUnused(old.access);
        }
      }
    }
    if (renewed || statusChanged) _notify();
  }

  static bool _overlap(String a, String b) =>
      p.equals(a, b) || p.isWithin(a, b) || p.isWithin(b, a);

  Future<void> _persist(List<ExternalMount> entries) =>
      store.upsert(kind, 'global', {
        'mounts': [for (final entry in entries) entry.toJson()],
      });

  Future<void> _replace(List<ExternalMount> next, {String? validateId}) async {
    final previous = _entries;
    _entries = next;
    try {
      await _resolve(persist: false, validateId: validateId);
      await _persist(_entries);
    } catch (_) {
      _entries = previous;
      await _resolve(persist: false);
      rethrow;
    }
    for (final old in previous) {
      await _releaseIfUnused(old.access);
    }
    _notify();
  }

  void _validateName(String name, {String? excluding}) {
    if (!ExternalMount.validName(name)) {
      throw const WorkspaceChannelException(code: 'external_mount_name');
    }
    if (_entries.any(
      (m) => m.id != excluding && m.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const WorkspaceChannelException(code: 'external_mount_duplicate');
    }
  }

  Future<void> add(
    WorkspaceDirectory directory, {
    required String name,
    required bool readOnly,
  }) => _serial(() async {
    _validateName(name);
    if (_entries.length >= maxMounts) {
      throw const WorkspaceChannelException(code: 'external_mount_limit');
    }
    final id = const Uuid().v4();
    await _replace([
      ..._entries,
      ExternalMount(
        id: id,
        name: name,
        access: directory.access,
        sourcePath: directory.path,
        readOnly: readOnly,
      ),
    ], validateId: id);
  });

  Future<void> update(
    String id, {
    required String name,
    required bool readOnly,
    WorkspaceDirectory? directory,
  }) => _serial(() async {
    _validateName(name, excluding: id);
    final entry = byId(id);
    if (entry == null) throw StateError('Mount was removed');
    await _replace([
      for (final m in _entries)
        if (m.id != id)
          m
        else
          m.copyWith(
            name: name,
            readOnly: readOnly,
            access: directory?.access,
            sourcePath: directory?.path,
          ),
    ], validateId: directory == null ? null : id);
  });

  Future<void> remove(String id) => _serial(() async {
    await _replace(_entries.where((m) => m.id != id).toList());
  });

  Future<void> releaseIfUnused(WorkspaceDirectoryAccess access) =>
      _serial(() => _releaseIfUnused(access));

  /// Application file operations must also respect mounts reached via aliases.
  Future<void> requireWritableHostPaths(Iterable<String> paths) async {
    final mounts = await resolveMounts();
    final readOnly = mounts.where((mount) => mount.readOnly);
    if (readOnly.isEmpty) return;
    final targets = [
      for (final path in paths) await WorkspacePaths.resolveHostPath(path),
    ];
    for (final mount in readOnly) {
      final root = await WorkspacePaths.resolveHostPath(mount.host);
      if (targets.any(
        (path) => p.equals(root, path) || p.isWithin(root, path),
      )) {
        throw const WorkspaceChannelException(
          code: 'mount_readonly',
          message: 'This external mount is read-only',
        );
      }
    }
  }

  Future<void> _releaseIfUnused(WorkspaceDirectoryAccess access) async {
    if (_entries.any((m) => m.access == access)) return;
    try {
      await channel.releaseDirectory(access);
    } on WorkspaceChannelException catch (error) {
      debugPrint('External folder grant release failed: $error');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        resolveMounts().catchError((Object error) {
          debugPrint('External mount refresh failed: $error');
          return activeMounts;
        }),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
