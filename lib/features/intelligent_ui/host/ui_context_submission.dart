import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import '../models/ui_context_attachment.dart';
import '../protocol/ui_stream_parser.dart';
import '../protocol/ui_source_hash.dart';
import 'ui_source_selection.dart';
import 'ui_user_context_parts.dart';

/// The frozen payload and a localized omission notice travel to the final
/// write. Source validation happens there, after queued writes, never by
/// reading a live widget/controller or substituting a more recent snapshot.
final class UiContextSubmission {
  const UiContextSubmission(this.attachment, {required this.omittedText});
  final UiContextAttachment attachment;
  final String omittedText;

  List<MessagePart> resolve(
    List<MessagePart> body, {
    required bool sourceIsCurrent,
  }) {
    if (attachment.previouslySent || sourceIsCurrent) {
      return UiUserContextParts.attach(body, attachment.text);
    }
    // A stale chip never prevents sending, including a chip-only draft. The
    // visible notice is ordinary text, and contains none of the stale state.
    return [TextPart(omittedText), const TextPart('\n\n'), ...body];
  }
}

bool uiContextSourceMatches(
  UiContextSource source,
  ChatMessage? message, {
  required String? selectedRevisionId,
}) {
  if (message == null ||
      message.id != source.revisionId ||
      message.conversationId != source.conversationId ||
      selectedRevisionId != source.revisionId ||
      message.isStreaming ||
      message.generationState != GenerationRunState.completed) {
    return false;
  }
  for (final fence in uiEligibleFences(message)) {
    if (fence.surfaceKey != source.surfaceKey || !fence.node.closed) continue;
    final parsed = UiStreamParser().update(fence.body, closed: true);
    return !parsed.invalid && uiSourceHash(parsed.source) == source.sourceHash;
  }
  return false;
}
