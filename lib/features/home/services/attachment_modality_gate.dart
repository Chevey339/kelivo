import '../../../core/models/chat_input_data.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/utils/multimodal_input_utils.dart';

const String attachmentUnsupportedErrorPrefix = 'attachment_unsupported:';

const List<Modality> _gatedDraftModalities = [
  Modality.image,
  Modality.audio,
  Modality.video,
];

/// Image / audio / video only. PDF and other documents are never gated.
Modality? gatedAttachmentModality(String mime) {
  if (isImageMime(mime)) return Modality.image;
  if (isAudioMime(mime)) return Modality.audio;
  if (isVideoMime(mime)) return Modality.video;
  return null;
}

/// Modalities present in [input] that [spec] does not accept.
///
/// `imagePaths` are always image. `documents` are classified by MIME
/// (`audio/*` / `video/*`); everything else — including PDF — is ignored.
List<Modality> unsupportedDraftModalities(ChatInputData input, ModelSpec spec) {
  final unsupported = <Modality>{};
  if (input.imagePaths.isNotEmpty && !spec.supportsImageInput) {
    unsupported.add(Modality.image);
  }
  for (final attachment in input.documents) {
    final modality = gatedAttachmentModality(
      resolveDocumentAttachmentMime(attachment),
    );
    if (modality == null) continue;
    if (!spec.input.contains(modality)) unsupported.add(modality);
  }
  return [
    for (final modality in _gatedDraftModalities)
      if (unsupported.contains(modality)) modality,
  ];
}

String attachmentUnsupportedErrorCode(Iterable<Modality> modalities) {
  return '$attachmentUnsupportedErrorPrefix'
      '${modalities.map((modality) => modality.name).join(',')}';
}
