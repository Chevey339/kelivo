import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';
import 'ui_generation_state.dart';
import 'ui_source_map.dart';
import 'package:flutter/widgets.dart';
import '../runtime/ui_interaction_controller.dart';
import '../runtime/ui_surface_controller.dart';
import '../runtime/ui_surface_state.dart';

/// Lives with the message list, above disposable Markdown and sliver children.
/// C11 attaches durable storage here; scrolling never owns a controller.
final class UiRuntimeRegistry {
  final _entries = <(String, String), Map<String, UiRuntimeEntry>>{};
  final _sources = <(String, String), Object>{};
  UiRuntimeEntry obtain(String conversationId, UiSurfaceOwner owner) => _entries
      .putIfAbsent((conversationId, owner.revisionId), () => {})
      .putIfAbsent(
        owner.surfaceKey,
        () => UiRuntimeEntry(UiSurfaceController(owner: owner)),
      );

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
      hasProviderReasoning,
    );
    if (_sources[owner] == proof) return;
    _sources[owner] = proof;
    final source = UiMessageSource.of(message.parts);
    final hidden =
        !hasProviderReasoning && !message.parts.any((p) => p is ReasoningPart)
        ? ThinkingTagParser.parseWithRanges(
            message.content,
            includeUnclosed: true,
            protectedRanges: source.protectedJoinedRanges,
          ).hiddenRanges
        : const <ThinkingTagHiddenRange>[];
    // Rendering owns the visible three-block limit. Historical split boundaries
    // can exclude an earlier raw fence, so raw ordinal is not that budget.
    final eligible = message.role == 'assistant'
        ? [
            for (final run in source.runs)
              for (final fence in run.fences)
                if (fence.topLevel &&
                    !hidden.any(
                      (h) =>
                          h.start < run.joinedStart + fence.node.span.end &&
                          h.end > run.joinedStart + fence.node.span.start,
                    ))
                  fence,
          ]
        : const <UiSourceFence>[];
    final fences = {for (final fence in eligible) fence.surfaceKey: fence};
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

  void dispose() {
    for (final group in _entries.values) {
      for (final entry in group.values) {
        entry.dispose();
      }
    }
    _entries.clear();
    _sources.clear();
  }
}

final class UiRuntimeEntry {
  UiRuntimeEntry(this.controller)
    : interactions = UiInteractionController(controller);
  final UiSurfaceController controller;
  final UiInteractionController interactions;
  void dispose() {
    interactions.dispose();
    controller.dispose();
  }
}

class UiRuntimeScope extends InheritedWidget {
  const UiRuntimeScope({
    super.key,
    required this.registry,
    required super.child,
  });
  final UiRuntimeRegistry registry;
  static UiRuntimeRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiRuntimeScope>()?.registry;
  @override
  bool updateShouldNotify(UiRuntimeScope oldWidget) =>
      registry != oldWidget.registry;
}
