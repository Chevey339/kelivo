import '../../core/services/chat/document_text_extractor.dart';
import '../../l10n/app_localizations.dart';

extension AttachmentReadLabels on AttachmentReadError {
  String message(AppLocalizations l, {bool workspaceUnavailable = false}) {
    if (workspaceUnavailable && problem != AttachmentProblem.missing) {
      return l.attachmentRequiresWorkspace(name);
    }
    return switch (problem) {
      AttachmentProblem.encoding => l.attachmentEncodingUnrecognized(name),
      AttachmentProblem.notText => l.attachmentNotText(name),
      AttachmentProblem.tooLarge => l.attachmentDocumentTooLarge(name),
      AttachmentProblem.missing => l.composerDraftMissingFile,
      AttachmentProblem.workspace => l.attachmentRequiresWorkspace(name),
    };
  }

  String shortMessage(AppLocalizations l) => switch (problem) {
    AttachmentProblem.encoding => l.attachmentEncodingUnrecognizedShort,
    AttachmentProblem.notText => l.attachmentNotTextShort,
    AttachmentProblem.tooLarge => l.attachmentDocumentTooLargeShort,
    AttachmentProblem.missing => l.composerDraftMissingFile,
    AttachmentProblem.workspace => l.settingsPageWorkspace,
  };
}
