import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../database/app_database.dart';
import '../../models/image_context.dart';
import '../../models/media_creation.dart';
import '../../models/message_part.dart';
import '../../providers/settings_provider.dart';
import '../api/request_image_context.dart';
import '../api/tool_call_cancellation.dart';
import '../chat/chat_service.dart';
import '../storage/attachment_file_lock.dart';
import '../tools/generate_image_tool.dart';
import '../tool_image.dart';
import '../workspace/workspace_image_download.dart';
import 'media_generation_runner.dart';
import 'media_models.dart';
import 'media_request.dart';

class ChatImageGenerationService {
  ChatImageGenerationService({
    required this.runner,
    required this.chat,
    required this.settings,
  });

  final MediaGenerationRunner runner;
  final ChatService chat;
  final SettingsProvider settings;

  static ClientToolResult error(String message, {String? batchId}) =>
      ClientToolResult(
        jsonEncode({'error': message}),
        metadata: batchId == null
            ? null
            : {GenerateImageTool.batchKey: batchId},
      );

  Future<ClientToolResult> run(
    Map<String, dynamic> args, {
    required String conversationId,
    required RequestImageContext context,
    required bool Function() enabled,
    String? toolCallId,
  }) async {
    final model = resolveDefaultImageModel(settings);
    if (model == null ||
        !enabled() ||
        chat.isTemporaryConversation(conversationId)) {
      return error(
        'The image generation tool is unavailable in this conversation.',
      );
    }
    final messageId = context.targetMessageId;
    final prompt = args['prompt'];
    final ids = args['image_ids'] ?? const <String>[];
    final limits = model.capabilities.referenceLimits(const {});
    if (messageId.isEmpty ||
        prompt is! String ||
        prompt.trim().isEmpty ||
        ids is! List ||
        ids.length > limits.max ||
        ids.length < limits.min ||
        ids.any((id) => id is! String || !_imageId.hasMatch(id)) ||
        args.keys.any((key) => key != 'prompt' && key != 'image_ids') ||
        args.containsKey('image_ids') && limits.max == 0) {
      return error(
        'Supply a prompt and supported conversation image identifiers.',
      );
    }
    final cancellation = ToolCallCancellation.current;
    final version = runner.repository.replacementVersion;
    String? batchId;
    Directory? downloadedReferences;
    try {
      final references = <MediaReference>[];
      if (ids.isNotEmpty) {
        final imageSettings = await chat.imageContextSettings(conversationId);
        final history = await chat.imageContextHistory(
          conversationId,
          throughMessageId: messageId,
        );
        final allowed = {for (final message in history) message.id};
        for (final id in ids.cast<String>().toSet()) {
          cancellation?.throwIfCancelled();
          final source = context.generationReference(
            id,
            allowedMessages: allowed,
            currentSettings: imageSettings,
          );
          if (source == null) {
            return error(
              'A reference image is unavailable in this conversation.',
            );
          }
          void checkAccess() {
            cancellation?.throwIfCancelled();
            if (!enabled() ||
                runner.repository.replacementVersion != version ||
                chat.getConversation(conversationId) == null) {
              throw StateError('Image generation is unavailable');
            }
          }

          if (source.creationUri case final original?) {
            if (!await runner.repository.ownsImage(original) ||
                await context.localAttachmentPath(source.handle) == null) {
              return error('This creation image is no longer available.');
            }
            checkAccess();
            references.add(MediaReference(original));
            continue;
          }
          final image = await _readReference(context, source, checkAccess);
          if (image == null) {
            return error(
              'A reference image is unavailable in this conversation.',
            );
          }
          checkAccess();
          final directory = downloadedReferences ??= await Directory.systemTemp
              .createTemp('kelivo-chat-reference-');
          final file = File(
            p.join(
              directory.path,
              '${references.length}.${AppDirectories.extFromMime(image.mime)}',
            ),
          );
          await file.writeAsBytes(image.bytes, flush: true);
          references.add(MediaReference(file.path));
        }
      }

      cancellation?.throwIfCancelled();
      bool available() =>
          cancellation?.isCancelled() != true &&
          enabled() &&
          runner.repository.replacementVersion == version &&
          chat.getConversation(conversationId) != null &&
          resolveDefaultImageModel(settings)?.key == model.key;
      final ratios = model.capabilities.aspectRatios;
      final ticket = await runner.enqueue(
        provider: model.provider,
        request: MediaRequest(
          modelId: model.spec.id,
          mode: MediaMode.image,
          prompt: prompt.trim(),
          aspectRatio: ratios.contains('auto') ? 'auto' : ratios.first,
          references: references,
          parameters: {
            if (toolCallId != null && toolCallId.isNotEmpty)
              GenerateImageTool.callIdParameter: toolCallId,
          },
        ),
        source: GenerationSource.chat,
        conversationId: conversationId,
        messageId: messageId,
        canEnqueue: available,
      );
      batchId = ticket.batchId;
      final unregister = cancellation?.onCancel(
        () => unawaited(runner.cancel(ticket.batchId)),
      );
      try {
        final status = await ticket.completed;
        if (status != GenerationStatus.succeeded &&
            status != GenerationStatus.partial) {
          return error(_failureMessage(status), batchId: batchId);
        }
        cancellation?.throwIfCancelled();
        final parts = await AttachmentFileLock.synchronized(() async {
          cancellation?.throwIfCancelled();
          if (chat.getConversation(conversationId) == null ||
              runner.repository.replacementVersion != version) {
            return const <ImagePart>[];
          }
          return _resultParts(ticket.batchId);
        });
        if (parts.isEmpty) {
          return error('The generated image is unavailable.', batchId: batchId);
        }
        return _result(
          ticket,
          model.spec.id,
          parts,
          parts.map(context.registerGeneratedImage).toList(),
          canView: context.canViewNewOutput,
        );
      } finally {
        unregister?.call();
      }
    } catch (exception) {
      return error(
        cancellation?.isCancelled() == true
            ? 'Image generation cancelled.'
            : exception is MediaFailure
            ? exception.message
            : 'Image generation could not be completed.',
        batchId: batchId,
      );
    } finally {
      try {
        await downloadedReferences?.delete(recursive: true);
      } on FileSystemException {
        // The operating system also clears process temporary files.
      }
    }
  }

  Future<ToolImage?> _readReference(
    RequestImageContext context,
    ChatContextImage source,
    void Function() checkAccess,
  ) async {
    checkAccess();
    final uri = source.uri;
    if (RequestImageContext.isRemoteHttpUrl(uri)) {
      final data = await downloadWorkspaceImage(
        Uri.parse(uri),
        logMediaRequest: true,
        checkAccess: checkAccess,
      );
      return ToolImage.fromNetworkBytes(data);
    }
    if (uri.startsWith('data:')) {
      if (uri.length > (ToolImage.maxFileBytes * 4 ~/ 3) + 256) return null;
      final bytes = await compute(
        (value) => UriData.parse(value).contentAsBytes(),
        uri,
      );
      return ToolImage.fromBytes(bytes);
    }
    if (source.identity.slot.startsWith('markdown:')) return null;
    final path = await context.localAttachmentPath(source.handle);
    if (path == null) return null;
    final root = await (await AppDirectories.getContentDirectory())
        .resolveSymbolicLinks();
    final resolved = await File(path).resolveSymbolicLinks();
    if (!p.isWithin(p.join(root, 'upload'), resolved) &&
        !p.isWithin(p.join(root, 'images'), resolved)) {
      return null;
    }
    return ToolImage.read(resolved);
  }

  /// A manual retry updates the original message after streaming ends. It
  /// keeps the stored model, prompt, and references from the original attempt.
  Future<bool> retry(GenerationBatchRow batch) async {
    final conversationId = batch.conversationId;
    final messageId = batch.messageId;
    final repository = chat.chatRepositoryOrNull;
    if (batch.source != GenerationSource.chat ||
        conversationId == null ||
        messageId == null ||
        repository == null) {
      return false;
    }
    final previous = await repository.getMessage(messageId);
    final provider = settings.providerConfigs[batch.providerId];
    if (previous == null || previous.isStreaming || provider == null) {
      return false;
    }
    final version = runner.repository.replacementVersion;
    final ticket = await runner.retry(batch.id, provider);
    if (ticket == null) return false;
    final status = await ticket.completed;
    if (status != GenerationStatus.succeeded &&
        status != GenerationStatus.partial) {
      return true;
    }
    final toolCallId = MediaRequest.fromBatch(
      batch,
    ).parameters[GenerateImageTool.callIdParameter];
    while (identical(chat.chatRepositoryOrNull, repository) &&
        await repository.waitForFinishedMessage(messageId)) {
      final applied = await AttachmentFileLock.synchronized<bool?>(() async {
        if (runner.repository.replacementVersion != version) return null;
        final generated = await _resultParts(batch.id);
        if (generated.isEmpty) return null;
        final handles = [
          for (final part in generated)
            ContextImageIdentity(
              messageId,
              'creation:${part.generationItemId}',
            ).handle,
        ];
        final result = _result(ticket, batch.modelId, generated, handles);
        return chat.updateFinishedMessageParts(messageId, (parts) {
          final existing = {
            for (final p in parts.whereType<ImagePart>()) p.generationItemId,
          };
          return [
            for (final part in parts)
              _replaceToolResult(
                part,
                batch.id,
                toolCallId is String ? toolCallId : null,
                result,
              ),
            for (final part in generated)
              if (!existing.contains(part.generationItemId)) part,
          ];
        });
      });
      if (applied != false) return applied ?? false;
    }
    return false;
  }

  Future<List<ImagePart>> _resultParts(String batchId) async => [
    for (final item in await runner.repository.itemsForBatch(batchId))
      if (item.status == GenerationItemStatus.ready &&
          item.mode == MediaMode.image &&
          KelivoFileUri.generationImageItemId(item.path) == item.id)
        ImagePart(uri: item.path, mime: item.mime, generationItemId: item.id),
  ];

  static ClientToolResult _result(
    MediaGenerationTicket ticket,
    String modelId,
    List<ImagePart> parts,
    List<String> handles, {
    bool canView = false,
  }) => ClientToolResult(
    jsonEncode({
      'images': [
        for (final handle in handles) {'image_id': handle},
      ],
      'location': 'Creation; already displayed in this conversation.',
      if (canView) 'view_image': {'image_id': handles.first},
      'usage': canView
          ? 'To inspect an image, pass its image_id to view_image. It is not a workspace file.'
          : 'The user can see the result. Do not search for a workspace file, embed an image link, or claim to have inspected the pixels. For an edit, pass image_ids if generate_image accepts references.',
      if (ticket.revisedPrompt case final prompt? when prompt.isNotEmpty)
        'revised_prompt': prompt,
      'model': modelId,
    }),
    metadata: {
      GenerateImageTool.batchKey: ticket.batchId,
      GenerateImageTool.attachmentKey: parts.length == 1
          ? parts.single.encodePayload()
          : [for (final part in parts) part.encodePayload()],
    },
  );

  static MessagePart _replaceToolResult(
    MessagePart part,
    String batchId,
    String? toolCallId,
    ClientToolResult result,
  ) {
    if (part is! ToolCallPart) return part;
    try {
      final payload = jsonDecode(part.payloadJson);
      if (payload is Map<String, dynamic> &&
          payload['name'] == GenerateImageTool.name) {
        final metadata = payload['metadata'];
        final storedBatch = metadata is Map
            ? metadata[GenerateImageTool.batchKey]
            : null;
        if (storedBatch != batchId &&
            (storedBatch != null ||
                toolCallId == null ||
                payload['id'] != toolCallId)) {
          return part;
        }
        return ToolCallPart(
          jsonEncode({
            ...payload,
            'content': result.content,
            'metadata': {if (metadata is Map) ...metadata, ...?result.metadata},
          }),
        );
      }
    } on FormatException {
      // The message can contain tool records without a completed result.
    }
    return part;
  }

  static String _failureMessage(GenerationStatus status) => switch (status) {
    GenerationStatus.cancelled => 'Image generation cancelled.',
    GenerationStatus.interrupted => 'Image generation interrupted.',
    _ => 'The image provider could not generate an image.',
  };

  static final _imageId = RegExp(GenerateImageTool.imageIdPattern);
}
