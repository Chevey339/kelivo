import 'composer_draft.dart' show DraftSubmission;
import 'composer_mention.dart';

class DocumentAttachment {
  final String path; // absolute file path
  final String fileName;
  final String mime; // e.g. application/pdf, text/plain

  const DocumentAttachment({
    required this.path,
    required this.fileName,
    required this.mime,
  });
}

class ChatInputData {
  final String text;

  /// Explicit composer selection; message text never determines routing.
  final String? recipientAssistantId;
  final ComposerMention? mention;
  final List<String> imagePaths; // absolute file paths or data URLs
  final List<DocumentAttachment> documents; // selected files
  final bool allowImagesApiRouting;
  final DraftSubmission? draftSubmission;

  const ChatInputData({
    required this.text,
    this.recipientAssistantId,
    this.mention,
    this.imagePaths = const [],
    this.documents = const [],
    this.allowImagesApiRouting = true,
    this.draftSubmission,
  });
}

enum ChatInputSubmissionResult { sent, queued, rejected }

class QueuedChatInput {
  final String conversationId;
  final ChatInputData input;

  const QueuedChatInput({required this.conversationId, required this.input});
}
