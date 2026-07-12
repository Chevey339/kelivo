import '../../../core/models/chat_message.dart';

/// Immutable, precomputed input for one logical timeline slot.
///
/// Renderer code must not scan the full message list or sort revisions while
/// building an individual row.
final class MessageRenderModel {
  const MessageRenderModel({
    required this.slotId,
    required this.message,
    required this.versions,
    required this.selectedVersionIndex,
    required this.showContextDivider,
    required this.isLatestCompleteAssistant,
  });

  final String slotId;
  final ChatMessage message;
  final List<ChatMessage> versions;
  final int selectedVersionIndex;
  final bool showContextDivider;
  final bool isLatestCompleteAssistant;

  int get versionCount => versions.isEmpty ? 1 : versions.length;
}

final class MessageRenderModelProjector {
  const MessageRenderModelProjector._();

  static List<MessageRenderModel> project({
    required List<ChatMessage> messages,
    required Map<String, List<ChatMessage>> byGroup,
    required Map<String, int> versionSelections,
    required int contextDividerIndex,
  }) {
    var latestCompleteAssistantIndex = -1;
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      if (message.role == 'assistant' && !message.isStreaming) {
        latestCompleteAssistantIndex = index;
        break;
      }
    }

    return List<MessageRenderModel>.unmodifiable([
      for (final (index, message) in messages.indexed)
        _projectSlot(
          index: index,
          message: message,
          versions: byGroup[message.groupId ?? message.id],
          selectedVersion: versionSelections[message.groupId ?? message.id],
          contextDividerIndex: contextDividerIndex,
          latestCompleteAssistantIndex: latestCompleteAssistantIndex,
        ),
    ]);
  }

  static MessageRenderModel _projectSlot({
    required int index,
    required ChatMessage message,
    required List<ChatMessage>? versions,
    required int? selectedVersion,
    required int contextDividerIndex,
    required int latestCompleteAssistantIndex,
  }) {
    final sortedVersions = List<ChatMessage>.of(
      versions ?? const <ChatMessage>[],
    )..sort((left, right) => left.version.compareTo(right.version));
    final fallback = sortedVersions.isEmpty ? 0 : sortedVersions.length - 1;
    final selectedIndex = (selectedVersion ?? fallback).clamp(
      0,
      sortedVersions.isEmpty ? 0 : sortedVersions.length - 1,
    );
    return MessageRenderModel(
      slotId: message.groupId ?? message.id,
      message: message,
      versions: List<ChatMessage>.unmodifiable(sortedVersions),
      selectedVersionIndex: selectedIndex,
      showContextDivider:
          contextDividerIndex >= 0 && index == contextDividerIndex,
      isLatestCompleteAssistant: index == latestCompleteAssistantIndex,
    );
  }
}
