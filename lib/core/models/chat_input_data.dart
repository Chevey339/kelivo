import 'composer_draft.dart' show DraftSubmission;
import 'quote_ref.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';

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
  final List<QuoteRef> quotes;
  final List<String> imagePaths; // absolute file paths or data URLs
  final List<DocumentAttachment> documents; // selected files
  final bool allowImagesApiRouting;
  final DraftSubmission? draftSubmission;
  final UiContextAttachment? uiContext;

  const ChatInputData({
    required this.text,
    this.quotes = const [],
    this.imagePaths = const [],
    this.documents = const [],
    this.allowImagesApiRouting = true,
    this.draftSubmission,
    this.uiContext,
  });

  String quotedText(String Function(int) quoteMarker) =>
      formatQuotedMessage(text, quotes, quoteMarker: quoteMarker);

  bool get isEmpty =>
      text.trim().isEmpty &&
      imagePaths.isEmpty &&
      documents.isEmpty &&
      uiContext == null;
}

enum ChatInputSubmissionResult { sent, queued, rejected }

class QueuedChatInput {
  final String conversationId;
  final ChatInputData input;

  const QueuedChatInput({required this.conversationId, required this.input});
}
