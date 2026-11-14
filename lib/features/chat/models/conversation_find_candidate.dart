import '../../../core/database/generation_run.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../intelligent_ui/text/ui_search_text.dart';

/// Only fields needed by the timeline projection cross the worker boundary.
/// A live MessagePartSnapshot itself can retain an unsendable WeakReference.
final class ConversationFindCandidate {
  ConversationFindCandidate(ChatMessage message, {this.surfaces = const {}})
    : id = message.id,
      conversationId = message.conversationId,
      role = message.role,
      parts = List.of(message.parts),
      reasoning = message.reasoningText,
      segments = message.reasoningSegmentsJson,
      translation = message.translation,
      streaming = message.isStreaming,
      generation = message.generationState;

  final String id, conversationId, role;
  final List<MessagePart> parts;
  final String? reasoning, segments, translation;
  final bool streaming;
  final GenerationRunState? generation;
  final Map<String, UiSearchSurfaceText> surfaces;

  ChatMessage toMessage() => ChatMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    parts: parts,
    reasoningText: reasoning,
    reasoningSegmentsJson: segments,
    translation: translation,
    isStreaming: streaming,
  )..hydrateGenerationState(generation);
}
