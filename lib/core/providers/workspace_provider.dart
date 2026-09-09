import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../utils/app_directories.dart';
import '../database/extension_entity_store.dart';
import '../models/workspace.dart';
import '../services/workspace/workspace_binding_actions.dart';
import 'assistant_provider.dart';

class WorkspaceProvider extends ChangeNotifier {
  WorkspaceProvider({required this.store, this.assistants}) {
    loaded = _load();
  }

  final ExtensionEntityStore store;
  final AssistantProvider? assistants;
  final List<Workspace> _workspaces = <Workspace>[];

  late final Future<void> loaded;

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);

  Workspace? byId(String id) {
    for (final workspace in _workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final entities = await store.listByKind(
        ExtensionEntityStore.kindWorkspace,
      );
      _workspaces
        ..clear()
        ..addAll([
          for (final entity in entities) Workspace.fromJson(entity.payload),
        ]);
    } catch (e) {
      debugPrint('Failed to load workspaces: $e');
      _workspaces.clear();
    }
    notifyListeners();
  }

  Future<Workspace> create({
    required String name,
    WorkspaceKind kind = WorkspaceKind.managed,
    String? hostPath,
  }) async {
    await loaded;
    final now = DateTime.now().toUtc();
    final workspace = Workspace(
      id: const Uuid().v4(),
      name: name,
      kind: kind,
      hostPath: kind == WorkspaceKind.linked ? hostPath : null,
      createdAt: now,
      updatedAt: now,
    );
    if (kind == WorkspaceKind.managed) {
      await AppDirectories.workspaceFilesDir(workspace.id);
    }
    await store.upsert(
      ExtensionEntityStore.kindWorkspace,
      workspace.id,
      workspace.toJson(),
      sortOrder: _workspaces.length,
    );
    _workspaces.add(workspace);
    notifyListeners();
    return workspace;
  }

  Future<void> update(Workspace workspace) async {
    await loaded;
    final next = workspace.copyWith(updatedAt: DateTime.now().toUtc());
    final index = _workspaces.indexWhere((item) => item.id == next.id);
    await store.upsert(
      ExtensionEntityStore.kindWorkspace,
      next.id,
      next.toJson(),
      sortOrder: index >= 0 ? index : null,
    );
    if (index >= 0) {
      _workspaces[index] = next;
    } else {
      _workspaces.add(next);
    }
    notifyListeners();
  }

  Future<void> delete(String id, {bool deleteFiles = true}) async {
    await loaded;
    final existing = byId(id);
    await store.delete(ExtensionEntityStore.kindWorkspace, id);
    _workspaces.removeWhere((workspace) => workspace.id == id);
    if (deleteFiles &&
        existing != null &&
        existing.kind == WorkspaceKind.managed) {
      final root = await AppDirectories.getWorkspacesDirectory();
      final dir = Directory('${root.path}/$id');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    final assistants = this.assistants;
    if (assistants != null) {
      await clearAssistantDefaultsForDeletedWorkspace(
        assistants,
        workspaceId: id,
      );
    }
    notifyListeners();
  }

  Future<void> touchLastUsed(String id) async {
    await loaded;
    final existing = byId(id);
    if (existing == null) return;
    await update(existing.copyWith(lastUsedAt: DateTime.now().toUtc()));
  }

  Future<String> hostRootFor(Workspace workspace) async {
    if (workspace.kind == WorkspaceKind.linked) {
      final path = workspace.hostPath;
      if (path == null || path.isEmpty) {
        throw StateError('linked workspace missing hostPath');
      }
      return path;
    }
    final dir = await AppDirectories.workspaceFilesDir(workspace.id);
    return dir.path;
  }
}
