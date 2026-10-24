import 'package:Kelivo/core/models/chat_message.dart';
import 'ui_generation_state.dart';
import 'ui_source_selection.dart';
import 'ui_persistence_binding.dart';
import '../storage/ui_state_repository.dart';
import 'package:flutter/widgets.dart';
import '../runtime/ui_interaction_controller.dart';
import '../runtime/ui_surface_controller.dart';
import '../runtime/ui_surface_state.dart';

/// Lives with the message list, above disposable Markdown and sliver children.
/// Durable bindings attach here; scrolling never owns a controller.
final class UiRuntimeRegistry {
  UiRuntimeRegistry({this.readOnly = false});
  final bool readOnly;
  final _entries = <(String, String), Map<String, UiRuntimeEntry>>{};
  final _sources = <(String, String), Object>{};
  int revision = 0;
  UiStateRepository? _store;
  bool Function(String)? _canPersist;

  void configurePersistence(
    UiStateRepository? store, {
    required bool Function(String) canPersist,
  }) {
    if (_store != null && !identical(_store, store)) {
      flush();
      _clearEntries();
    }
    _store = store;
    _canPersist = canPersist;
    for (final group in _entries.entries) {
      for (final entry in group.value.values) {
        entry.persistWith(
          canPersist(group.key.$1) ? store : null,
          group.key.$1,
        );
      }
    }
  }

  UiRuntimeEntry obtain(String conversationId, UiSurfaceOwner owner) {
    final group = _entries.putIfAbsent((
      conversationId,
      owner.revisionId,
    ), () => {});
    if (group[owner.surfaceKey]?.revoked ?? false) {
      group.remove(owner.surfaceKey)!.dispose();
    }
    final entry = group.putIfAbsent(
      owner.surfaceKey,
      () =>
          UiRuntimeEntry(UiSurfaceController(owner: owner, readOnly: readOnly)),
    );
    entry.persistWith(
      _canPersist?.call(conversationId) == true ? _store : null,
      conversationId,
    );
    return entry;
  }

  void flush() => _store?.flushQuietly();

  /// Freeze accepted values for an explicit copy before its source conversation
  /// is discarded. Unmounted cards are retained by this registry; unseen cards
  /// have no overrides and are reconstructed from their source declarations.
  List<UiSurfaceSnapshot> captureCopySnapshots(List<ChatMessage> messages) {
    final result = <UiSurfaceSnapshot>[];
    for (final message in messages) {
      reconcile(message);
      final entries = _entries[(message.conversationId, message.id)];
      if (entries == null) continue;
      for (final entry in entries.values) {
        if (!entry.revoked && entry.controller.canSnapshot) {
          result.add(entry.controller.captureSnapshot());
        }
      }
    }
    return result;
  }

  void leaveConversation(String? conversationId) {
    if (conversationId == null) return;
    flush();
    for (final key
        in _entries.keys.where((key) => key.$1 == conversationId).toList()) {
      for (final entry in _entries.remove(key)!.values) {
        entry.dispose();
      }
      _sources.remove(key);
    }
  }

  /// Original-source updates revoke disappeared fences; viewport unmount does
  /// not. Ordinary messages without registered state cost one map lookup only.
  void reconcile(ChatMessage message, {bool hasProviderReasoning = false}) {
    final owner = (message.conversationId, message.id);
    final entries = _entries[owner];
    if (entries == null) return;
    final proof = (
      message.parts,
      message.role,
      message.generationState,
      message.isStreaming,
      message.reasoningText,
      message.reasoningSegmentsJson,
      hasProviderReasoning,
    );
    if (_sources[owner] == proof) return;
    _sources[owner] = proof;
    final fences = {
      for (final fence in uiEligibleFences(
        message,
        hasProviderReasoning: hasProviderReasoning,
      ))
        fence.surfaceKey: fence,
    };
    for (final key in entries.keys.toList()) {
      final fence = fences[key];
      if (fence == null) {
        entries.remove(key)!.dispose();
      } else {
        entries[key]!.controller.updateSource(
          fence.body,
          closed: fence.node.closed,
          generation: uiGenerationStatus(message),
        );
      }
    }
    if (entries.isEmpty) {
      _entries.remove(owner);
      _sources.remove(owner);
    }
  }

  void _clearEntries() {
    revision++;
    for (final group in _entries.values) {
      for (final entry in group.values) {
        entry.dispose();
      }
    }
    _entries.clear();
    _sources.clear();
  }

  void dispose() {
    flush();
    _clearEntries();
  }
}

final class UiRuntimeEntry {
  UiRuntimeEntry(this.controller)
    : interactions = UiInteractionController(controller);
  final UiSurfaceController controller;
  final UiInteractionController interactions;
  UiPersistenceBinding? _persistence;
  bool get revoked => _persistence?.revoked ?? false;
  void persistWith(UiStateRepository? store, String conversationId) {
    if (_persistence?.store == store) return;
    _persistence?.dispose();
    _persistence = store == null
        ? null
        : UiPersistenceBinding(controller, store, conversationId);
  }

  void dispose() {
    _persistence?.dispose();
    interactions.dispose();
    controller.dispose();
  }
}

class UiRuntimeScope extends InheritedWidget {
  const UiRuntimeScope({
    super.key,
    required this.registry,
    this.revision = 0,
    required super.child,
  });
  final UiRuntimeRegistry registry;
  final int revision;
  static UiRuntimeRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiRuntimeScope>()?.registry;
  @override
  bool updateShouldNotify(UiRuntimeScope oldWidget) =>
      registry != oldWidget.registry || revision != oldWidget.revision;
}
