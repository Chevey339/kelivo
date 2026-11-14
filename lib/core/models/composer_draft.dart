import 'image_edit_document.dart';
import 'image_upload_quality.dart';
import 'package:flutter/foundation.dart';
import 'chat_input_data.dart';
import 'quote_ref.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';

/// The editor value, before the send path trims text or filters attachments.
class ComposerDraftInput {
  const ComposerDraftInput({
    this.text = '',
    this.quotes = const [],
    this.selectionBase = -1,
    this.selectionExtent = -1,
    this.images = const [],
    this.documents = const [],
    this.allowImagesApiRouting = true,
    this.uiContext,
  });

  final String text;
  final List<QuoteRef> quotes;
  final int selectionBase;
  final int selectionExtent;
  final List<DraftImage> images;
  final List<DocumentAttachment> documents;
  final bool allowImagesApiRouting;
  final UiContextAttachment? uiContext;
  bool get isEmpty =>
      text.isEmpty && images.isEmpty && documents.isEmpty && uiContext == null;
  Iterable<String> get paths sync* {
    for (final image in images) {
      yield image.path;
      if (image.sourcePath != null) yield image.sourcePath!;
    }
    yield* documents.map((document) => document.path);
  }

  ComposerDraftInput copyWith({
    String? text,
    List<QuoteRef>? quotes,
    int? selectionBase,
    int? selectionExtent,
    List<DraftImage>? images,
    List<DocumentAttachment>? documents,
    UiContextAttachment? uiContext,
    bool clearUiContext = false,
  }) => ComposerDraftInput(
    text: text ?? this.text,
    quotes: quotes ?? this.quotes,
    selectionBase: selectionBase ?? this.selectionBase,
    selectionExtent: selectionExtent ?? this.selectionExtent,
    images: images ?? this.images,
    documents: documents ?? this.documents,
    allowImagesApiRouting: allowImagesApiRouting,
    uiContext: clearUiContext ? null : uiContext ?? this.uiContext,
  );

  ChatInputData toInput({DraftSubmission? submission}) => ChatInputData(
    text: text,
    quotes: quotes,
    imagePaths: images.map((image) => image.path).toList(),
    documents: documents,
    allowImagesApiRouting: allowImagesApiRouting,
    draftSubmission: submission,
    uiContext: uiContext,
  );

  factory ComposerDraftInput.fromInput(ChatInputData input) =>
      ComposerDraftInput(
        text: input.text,
        quotes: input.quotes,
        images: [for (final path in input.imagePaths) DraftImage(path: path)],
        documents: List.of(input.documents),
        allowImagesApiRouting: input.allowImagesApiRouting,
        uiContext: input.uiContext,
      );

  Map<String, dynamic> toJson() => {
    'text': text,
    'quotes': quotes.map((quote) => quote.toJson()).toList(),
    'selectionBase': selectionBase,
    'selectionExtent': selectionExtent,
    'images': images.map((image) => image.toJson()).toList(),
    'documents': [
      for (final doc in documents)
        {'path': doc.path, 'fileName': doc.fileName, 'mime': doc.mime},
    ],
    'allowImagesApiRouting': allowImagesApiRouting,
    'uiContext': uiContext?.toJson(),
  };

  factory ComposerDraftInput.fromJson(Map<String, dynamic> json) =>
      ComposerDraftInput(
        text: json['text'] as String,
        quotes: QuoteRef.decodeList(json['quotes']),
        selectionBase: json['selectionBase'] as int,
        selectionExtent: json['selectionExtent'] as int,
        images: [
          for (final value in json['images'] as List)
            DraftImage.fromJson(Map<String, dynamic>.from(value as Map)),
        ],
        documents: [
          for (final value in json['documents'] as List)
            DocumentAttachment(
              path: value['path'] as String,
              fileName: value['fileName'] as String,
              mime: value['mime'] as String,
            ),
        ],
        allowImagesApiRouting: json['allowImagesApiRouting'] as bool,
        uiContext: json['uiContext'] == null
            ? null
            : UiContextAttachment.fromJson(
                Map<String, dynamic>.from(json['uiContext'] as Map),
              ),
      );

  bool sameValue(ComposerDraftInput other) =>
      text == other.text &&
      listEquals(quotes, other.quotes) &&
      selectionBase == other.selectionBase &&
      selectionExtent == other.selectionExtent &&
      allowImagesApiRouting == other.allowImagesApiRouting &&
      uiContext == other.uiContext &&
      images.length == other.images.length &&
      Iterable<int>.generate(
        images.length,
      ).every((i) => images[i].sameValue(other.images[i])) &&
      listEquals(
        documents.map((doc) => (doc.path, doc.fileName, doc.mime)).toList(),
        other.documents
            .map((doc) => (doc.path, doc.fileName, doc.mime))
            .toList(),
      );
}

class DraftImage {
  const DraftImage({
    required this.path,
    this.sourcePath,
    bool? sourceIsOriginal,
    this.edits = const ImageEditDocument(),
    this.quality,
    this.customQuality,
    this.processing = false,
    this.failed = false,
  }) : sourceIsOriginal = sourceIsOriginal ?? (sourcePath != null);
  final String path;
  final String? sourcePath;
  final bool sourceIsOriginal;
  final ImageEditDocument edits;
  final ImageUploadQuality? quality;
  final int? customQuality;
  final bool processing;
  final bool failed;
  DraftImage copyWith({
    String? path,
    String? sourcePath,
    bool? sourceIsOriginal,
    ImageEditDocument? edits,
    ImageUploadQuality? quality,
    int? customQuality,
    bool? processing,
    bool? failed,
  }) => DraftImage(
    path: path ?? this.path,
    sourcePath: sourcePath ?? this.sourcePath,
    sourceIsOriginal: sourceIsOriginal ?? this.sourceIsOriginal,
    edits: edits ?? this.edits,
    quality: quality ?? this.quality,
    customQuality: customQuality ?? this.customQuality,
    processing: processing ?? this.processing,
    failed: failed ?? this.failed,
  );
  bool sameValue(DraftImage other) =>
      path == other.path &&
      sourcePath == other.sourcePath &&
      sourceIsOriginal == other.sourceIsOriginal &&
      quality == other.quality &&
      customQuality == other.customQuality &&
      processing == other.processing &&
      failed == other.failed &&
      edits.sameValue(other.edits);
  Map<String, dynamic> toJson() => {
    'path': path,
    'sourcePath': sourcePath,
    'sourceIsOriginal': sourceIsOriginal,
    'edits': edits.toJson(),
    'quality': quality?.name,
    'customQuality': customQuality,
    'processing': processing,
    'failed': failed,
  };
  factory DraftImage.fromJson(Map<String, dynamic> json) => DraftImage(
    path: json['path'] as String,
    sourcePath: json['sourcePath'] as String?,
    sourceIsOriginal: json['sourceIsOriginal'] as bool?,
    edits: json['edits'] == null
        ? const ImageEditDocument()
        : ImageEditDocument.fromJson(
            Map<String, dynamic>.from(json['edits'] as Map),
          ),
    quality: json['quality'] == null
        ? null
        : ImageUploadQuality.values.byName(json['quality'] as String),
    customQuality: json['customQuality'] as int?,
    processing: json['processing'] as bool,
    failed: json['failed'] as bool,
  );
}

/// Also used as the persisted user message ID: a committed message is the
/// durable receipt for this submission, including after a lost UI callback.
class DraftSubmission {
  const DraftSubmission({
    required this.conversationId,
    required this.id,
    this.editMessageId,
  });
  final String conversationId;
  final String id;
  final String? editMessageId;
}

class ComposerDraft {
  ComposerDraft({
    required this.conversationId,
    this.assistantId,
    this.compose = const ComposerDraftInput(),
    this.edit,
    this.editMessageId,
    this.pending,
    this.submissionId,
    this.submissionEditId,
    this.revision = 0,
  });
  final String conversationId;
  String? assistantId;
  ComposerDraftInput compose;
  ComposerDraftInput? edit;
  String? editMessageId;
  ComposerDraftInput? pending;
  String? submissionId;
  String? submissionEditId;
  int revision;
  ComposerDraftInput get active => edit ?? compose;
  ComposerDraftInput get recoveryTarget =>
      submissionEditId == null ? compose : edit ?? const ComposerDraftInput();
  bool get hasRecoveryConflict =>
      !recoveryTarget.isEmpty ||
      (submissionEditId != null &&
          editMessageId != null &&
          submissionEditId != editMessageId);
  bool get hasContent => !compose.isEmpty || edit != null || pending != null;
  Iterable<String> get paths sync* {
    yield* compose.paths;
    if (edit != null) yield* edit!.paths;
    if (pending != null) yield* pending!.paths;
  }

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'assistantId': assistantId,
    'compose': compose.toJson(),
    'edit': edit?.toJson(),
    'editMessageId': editMessageId,
    'pending': pending?.toJson(),
    'submissionId': submissionId,
    'submissionEditId': submissionEditId,
    'revision': revision,
  };
  factory ComposerDraft.fromJson(Map<String, dynamic> json) => ComposerDraft(
    conversationId: json['conversationId'] as String,
    assistantId: json['assistantId'] as String?,
    compose: ComposerDraftInput.fromJson(
      Map<String, dynamic>.from(json['compose'] as Map),
    ),
    edit: json['edit'] == null
        ? null
        : ComposerDraftInput.fromJson(
            Map<String, dynamic>.from(json['edit'] as Map),
          ),
    editMessageId: json['editMessageId'] as String?,
    pending: json['pending'] == null
        ? null
        : ComposerDraftInput.fromJson(
            Map<String, dynamic>.from(json['pending'] as Map),
          ),
    submissionId: json['submissionId'] as String?,
    submissionEditId: json['submissionEditId'] as String?,
    revision: json['revision'] as int,
  );
}
