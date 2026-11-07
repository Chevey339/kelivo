import '../../models/native_compaction.dart';
import 'request_history_context.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../../features/intelligent_ui/host/ui_user_context_parts.dart';
import '../../models/chat_message.dart';
import '../../models/context_operation.dart';
import '../../models/image_context.dart';
import '../../models/request_budget.dart';
import '../../models/message_part.dart';
import '../../utils/multimodal_input_utils.dart';
import '../../utils/chat_image_result.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../mcp/mcp_image_snapshot.dart';
import 'chat_api_helpers.dart';

/// Kept out of prompts and removed before a provider serializes a request.
const imageContextOwnerKey = '_kelivo_image_owner';
const _referencePrefix = 'kelivo-image-ref:';

/// App requests identify persisted messages, while utility/API callers may
/// supply plain role/content maps. Injected lore must never receive the
/// composer's attachments or the preceding assistant's carried images.
bool isUserInputMessage(
  Map<String, dynamic> message, {
  required bool hasOwners,
}) {
  if (message['role'] != 'user') return false;
  if (!hasOwners) return true;
  final owner = message[imageContextOwnerKey];
  return owner is String &&
      owner.isNotEmpty &&
      !owner.startsWith(ContextOperation.summaryPrefix);
}

int lastUserInputIndex(List<Map<String, dynamic>> messages) {
  final hasOwners = messages.any((m) => m.containsKey(imageContextOwnerKey));
  return messages.lastIndexWhere(
    (message) => isUserInputMessage(message, hasOwners: hasOwners),
  );
}

class ChatContextImage {
  ChatContextImage({
    required this.identity,
    required this.uri,
    required this.source,
    required this.label,
    this.mime = '',
    this.toolCallId,
    this.workspaceSnapshot = false,
    this.unavailable = false,
    this.materializationKey,
    this.partOrdinal,
  });

  final ContextImageIdentity identity;
  final String uri;
  final ContextImageSource source;
  final String label;
  final String mime;
  final String? toolCallId;
  final bool workspaceSnapshot;
  final bool unavailable;
  final String? materializationKey;
  final int? partOrdinal;
  String get key => identity.key;
  String get handle => identity.handle;
  String get mediaType => mime.isNotEmpty
      ? mime
      : inferMediaMimeFromSource(uri, fallbackMime: 'image/png');
  String get reference => 'data:$mediaType;base64,$_referencePrefix$handle';
}

class ImageContextPreviewItem {
  const ImageContextPreviewItem(
    this.image, {
    required this.included,
    required this.pinned,
    this.bytes,
    this.sizeIsEstimate = false,
  });
  final ChatContextImage image;
  final bool included;
  final bool pinned;
  final int? bytes;
  final bool sizeIsEstimate;
}

/// A generation's immutable inputs plus a memoized asset reader. No eviction or
/// delivery state is persisted. Protocol histories retain references, so every
/// HTTP round can project old images again without mutating its source history.
class RequestImageContext {
  RequestImageContext({
    required this.settings,
    required List<ChatContextImage> images,
    this.latestUserId,
    this.targetMessageId = '',
    this.budget = const RequestBudget(),
    this.historyBudget = const RequestBudget(),
    bool canRecall = true,
    this.canImageInput = true,
    this.loader,
    this.inlineRemoteUsers = false,
    this.allowsRemoteUserImages = true,
    Map<String, String?> userTurns = const {},
    this.omitUserImages = false,
    this.viewImageUris = const {},
  }) : canRecall = canRecall && canImageInput && settings.allowRecall,
       images = List.of(images),
       _userTurns = Map.of(userTurns) {
    String? user;
    for (final image in images) {
      if (image.source == ContextImageSource.user) {
        user = image.identity.messageId;
      }
      _userTurns.putIfAbsent(image.identity.messageId, () => user);
      _byHandle[image.handle] = image;
    }
  }

  final ImageContextSettings settings;
  final List<ChatContextImage> images;
  final String? latestUserId;
  String targetMessageId;
  final RequestBudget budget;
  // Automatic retention stays conservative when users raise sending limits.
  // Lower sending limits also constrain retention, so old images can be trimmed.
  final RequestBudget historyBudget;
  final bool canRecall;
  bool get hasRecallableImages =>
      canRecall && images.any((image) => !_isUnavailable(image));
  final bool canImageInput;
  final bool inlineRemoteUsers;
  final bool allowsRemoteUserImages;
  final Map<String, String?> _userTurns;
  final bool omitUserImages;
  final Set<String> viewImageUris;
  final activeHandles = <String>{};
  final compressedOwners = <String>{};
  final Future<String?> Function(ChatContextImage)? loader;
  final _byHandle = <String, ChatContextImage>{};
  final _loads = <String, Future<String?>>{};
  final _sizes = <String, Future<int?>>{};
  final _unavailableSources = <String>{};
  final _parsedText = Expando<String>();

  bool _isUnavailable(ChatContextImage image) =>
      image.unavailable ||
      _unavailableSources.contains(image.materializationKey ?? image.key);
  static bool isRemoteHttpUrl(String value) =>
      Uri.tryParse(value)?.isScheme('https') == true ||
      Uri.tryParse(value)?.isScheme('http') == true;
  static final _zoneKey = Object();
  static RequestImageContext? get current =>
      Zone.current[_zoneKey] as RequestImageContext?;

  Stream<T> run<T>(Stream<T> Function() action) => _run(this, action);
  static Stream<T> without<T>(Stream<T> Function() action) =>
      _run(null, action);
  static Stream<T> _run<T>(
    RequestImageContext? context,
    Stream<T> Function() action,
  ) => Stream<T>.multi((controller) {
    late Zone requestZone;
    final subscription = runZoned(() {
      requestZone = Zone.current;
      return action().listen(
        controller.addSync,
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
    }, zoneValues: {_zoneKey: context});
    // Async stream generators resume in the caller's zone. Re-enter the
    // request scope when an await-for consumer applies backpressure.
    controller.onPause = () => requestZone.run(subscription.pause);
    controller.onResume = () => requestZone.run(subscription.resume);
    controller.onCancel = () => requestZone.run(subscription.cancel);
  });

  static List<ChatContextImage> collect(List<ChatMessage> messages) {
    final out = <ChatContextImage>[];
    for (final message in messages) {
      for (var ordinal = 0; ordinal < message.parts.length; ordinal++) {
        final part = message.parts[ordinal];
        if (part is ImagePart || part is FilePart) {
          final uri = part is ImagePart ? part.uri : (part as FilePart).uri;
          final mime = part is ImagePart ? part.mime : (part as FilePart).mime;
          if (part is FilePart &&
              !isImageMime(mime ?? inferMediaMimeFromSource(uri))) {
            continue;
          }
          out.add(
            ChatContextImage(
              identity: ContextImageIdentity(message.id, 'part:$ordinal'),
              partOrdinal: ordinal,
              uri: uri,
              mime: mime ?? '',
              source: message.role == 'user'
                  ? ContextImageSource.user
                  : ContextImageSource.assistant,
              label: part is FilePart
                  ? part.name
                  : uri.startsWith('data:')
                  ? 'Image ${ordinal + 1}'
                  : Uri.tryParse(uri)?.pathSegments.lastOrNull ??
                        'Image ${ordinal + 1}',
              unavailable: part is ImagePart
                  ? part.unavailable
                  : (part as FilePart).unavailable,
            ),
          );
        } else if (part is ToolCallPart) {
          try {
            final event = jsonDecode(part.payloadJson);
            if (event is! Map) continue;
            final rawMetadata = event['metadata'];
            final metadata = rawMetadata is Map
                ? rawMetadata.cast<String, dynamic>()
                : null;
            final name = (event['name'] ?? '').toString();
            final workspace = metadata?['workspace'];
            if (workspace != null &&
                (name != 'view_image' ||
                    workspace is! Map ||
                    workspace['status'] != 'ok' ||
                    workspace['tool'] != name)) {
              continue;
            }
            final uris = mcpResultImageUris(readMcpResultMetadata(metadata));
            final call = (event['id'] ?? 'part:$ordinal').toString();
            for (var i = 0; i < uris.length; i++) {
              final restored = readChatImageMetadata(name, metadata);
              if (name == 'read_chat_image' && restored == null) continue;
              out.add(
                ChatContextImage(
                  identity: ContextImageIdentity(message.id, 'tool:$call', i),
                  partOrdinal: ordinal,
                  uri: uris[i],
                  source: ContextImageSource.tool,
                  label: '$name · ${i + 1}',
                  toolCallId: call,
                  materializationKey: restored?.sourceKey,
                  mime: restored?.mime ?? '',
                  workspaceSnapshot:
                      workspace != null || restored?.directAsset == true,
                ),
              );
            }
          } on FormatException {
            // Malformed persisted tool records are not authority to read files.
          }
        }
      }
    }
    return out;
  }

  static Map<String, String?> userTurnsFor(List<ChatMessage> messages) {
    final turns = <String, String?>{};
    String? user;
    for (final message in messages) {
      if (message.role == 'user') user = message.id;
      turns[message.id] = user;
    }
    return turns;
  }

  /// Markdown observations belong to their original message and text-part
  /// positions, even after that message leaves the active request window.
  static Future<List<ChatContextImage>> collectHistory(
    List<ChatMessage> messages, {
    required bool parseMarkdownImages,
    required bool allowRemoteImages,
  }) async {
    if (!parseMarkdownImages) return collect(messages);
    final result = <ChatContextImage>[];
    for (final message in messages) {
      final items = collect([message]);
      final order = {
        for (final image in items) image.key: image.partOrdinal ?? 0,
      };
      if (message.content.contains('![')) {
        final parsed = await parseTextAndImages(
          message.content,
          literalText: message.role == 'user'
              ? UiUserContextParts.read(message.parts).context?.exactText
              : null,
          allowRemoteImages: allowRemoteImages,
          allowLocalImages: true,
          validateRemoteImages: false,
        );
        final source = message.role == 'user'
            ? ContextImageSource.user
            : ContextImageSource.assistant;
        final spans = <({int end, int ordinal})>[];
        var offset = 0;
        for (var i = 0; i < message.parts.length; i++) {
          if (message.parts[i] case TextPart(:final text)) {
            offset += text.length;
            spans.add((end: offset, ordinal: i));
          }
        }
        var span = 0;
        for (final ref in parsed.images) {
          while (span + 1 < spans.length &&
              (ref.offset ?? 0) >= spans[span].end) {
            span++;
          }
          final ordinal = spans.isEmpty ? 0 : spans[span].ordinal;
          final normalized = SandboxPathResolver.dedupeKey(ref.src);
          final existing = items
              .where(
                (im) =>
                    im.source == source &&
                    SandboxPathResolver.dedupeKey(im.uri) == normalized,
              )
              .firstOrNull;
          if (existing != null) {
            if (ordinal < order[existing.key]!) order[existing.key] = ordinal;
            continue;
          }
          final image = ChatContextImage(
            identity: ContextImageIdentity(
              message.id,
              'markdown:${base64Url.encode(utf8.encode(normalized))}',
            ),
            uri: ref.src,
            source: source,
            label: 'Image',
            partOrdinal: ordinal,
          );
          items.add(image);
          order[image.key] = ordinal;
        }
      }
      final rank = {for (var i = 0; i < items.length; i++) items[i].key: i};
      items.sort((a, b) {
        final position = order[a.key]!.compareTo(order[b.key]!);
        return position != 0 ? position : rank[a.key]!.compareTo(rank[b.key]!);
      });
      result.addAll(items);
    }
    return result;
  }

  ChatContextImage _add(ChatContextImage image) {
    final existing = _byHandle[image.handle];
    if (existing != null) return existing;
    _userTurns.putIfAbsent(
      image.identity.messageId,
      () => image.source == ContextImageSource.user
          ? image.identity.messageId
          : latestUserId,
    );
    images.add(image);
    _byHandle[image.handle] = image;
    return image;
  }

  ChatContextImage _userImage(
    String owner,
    String uri,
    String mime,
    ContextImageSource source,
  ) {
    final normalized = SandboxPathResolver.dedupeKey(uri);
    for (final image in images) {
      if (image.identity.messageId == owner &&
          image.source == source &&
          SandboxPathResolver.dedupeKey(image.uri) == normalized) {
        activeHandles.add(image.handle);
        return image;
      }
    }
    final added = _add(
      ChatContextImage(
        identity: ContextImageIdentity(
          owner,
          'markdown:${base64Url.encode(utf8.encode(normalized))}',
        ),
        uri: uri,
        mime: mime,
        source: source,
        label: 'Image',
      ),
    );
    activeHandles.add(added.handle);
    return added;
  }

  /// Runs after OCR and attachment descriptions, before any local inlining.
  /// The existing parser preserves code/literal blocks; no image regex rewrites
  /// user text. Metadata and side-channel paths resolve to the same occurrence.
  Future<List<String>> prepareMessages(
    List<Map<String, dynamic>> messages,
    List<String> userPaths, {
    required bool parseMarkdownImages,
    required bool allowRemoteImages,
  }) async {
    for (final message in messages) {
      if (message['role'] == 'tool') {
        final metadata = (message['metadata'] as Map?)?.cast<String, dynamic>();
        final workspace = metadata?['workspace'];
        final name = (message['name'] ?? '').toString();
        if (workspace == null ||
            (name == 'view_image' &&
                workspace is Map &&
                workspace['tool'] == name &&
                workspace['status'] == 'ok')) {
          for (final ref in toolReferences(
            name,
            mcpResultImageUris(readMcpResultMetadata(metadata)),
            metadata,
            message['tool_call_id']?.toString(),
          )) {
            activeHandles.add(referenceHandle(ref)!);
          }
        }
        continue;
      }
      final owner = message[imageContextOwnerKey]?.toString();
      if (owner == null) continue;
      final source = message['role'] == 'user'
          ? ContextImageSource.user
          : ContextImageSource.assistant;
      final raw = message['content'];
      if (raw is String && parseMarkdownImages) {
        final parsed = await parseTextAndImages(
          raw,
          literalText: internalLiteralText(message),
          allowLocalImages: true,
          allowRemoteImages: allowRemoteImages,
          validateRemoteImages: false,
        );
        if (parsed.images.isNotEmpty) {
          _parsedText[message] = parsed.text;
          message[multimodalInternalImageReferencesKey] = {
            for (final ref in parsed.images)
              ref.src: _userImage(owner, ref.src, '', source).reference,
          };
        }
      }
      final refs = parseInternalMediaRefs(
        message[multimodalInternalMediaPathsKey],
      );
      if (refs.isNotEmpty) {
        message[multimodalInternalMediaPathsKey] = [
          for (final ref in refs)
            {
              'uri':
                  isImageMime(mimeForInternalMediaRef(ref)) &&
                      (allowRemoteImages || !isRemoteHttpUrl(ref.uri))
                  ? _userImage(owner, ref.uri, ref.mime ?? '', source).reference
                  : ref.uri,
              'mime': ref.mime,
            },
        ];
      }
    }
    return preparePaths(userPaths, allowRemoteImages: allowRemoteImages);
  }

  /// The composer has a separate media channel. Resolve it to the same
  /// occurrence as message metadata so adapters deduplicate before encoding.
  List<String> preparePaths(
    List<String> paths, {
    bool allowRemoteImages = true,
  }) => [
    for (final uri in paths)
      (() {
        if (referenceHandle(uri) != null ||
            latestUserId == null ||
            (!allowRemoteImages && isRemoteHttpUrl(uri))) {
          return uri;
        }
        final knownImage = images.any(
          (image) =>
              image.source == ContextImageSource.user &&
              image.identity.messageId == latestUserId &&
              SandboxPathResolver.dedupeKey(image.uri) ==
                  SandboxPathResolver.dedupeKey(uri),
        );
        if (knownImage || isImageMime(inferMediaMimeFromSource(uri))) {
          return _userImage(
            latestUserId!,
            uri,
            '',
            ContextImageSource.user,
          ).reference;
        }
        return uri;
      })(),
  ];

  List<String> toolReferences(
    String name,
    List<String> uris,
    Map<String, dynamic>? metadata,
    String? callId,
  ) {
    final restored = readChatImageMetadata(name, metadata);
    if (name == 'read_chat_image' && restored == null) return [];
    final owner =
        metadata?[imageContextOwnerKey]?.toString() ?? targetMessageId;
    final call =
        metadata?['_kelivo_image_call']?.toString() ??
        callId ??
        '$name:${uris.join('|')}';
    return [
      for (var i = 0; i < uris.length; i++)
        _add(
          ChatContextImage(
            identity: ContextImageIdentity(owner, 'tool:$call', i),
            uri: uris[i],
            source: ContextImageSource.tool,
            label: '$name · ${i + 1}',
            toolCallId: call,
            materializationKey: restored?.sourceKey,
            mime: restored?.mime ?? '',
            workspaceSnapshot:
                metadata?['workspace'] != null || restored?.directAsset == true,
          ),
        ).reference,
    ];
  }

  /// Only an occurrence in this conversation after its clear boundary grants
  /// access. A caller cannot supply a filesystem path or a foreign asset ID.
  ClientToolResult readImage(
    String handle, {
    Set<String>? allowedMessages,
    int offset = 0,
  }) {
    if (!canRecall) {
      return const ClientToolResult(
        'Image recall is disabled for this request. Ask the user to attach the image again if needed.',
      );
    }
    if (handle.isEmpty) {
      final available = images
          .where(
            (image) =>
                !_isUnavailable(image) &&
                (allowedMessages == null ||
                    allowedMessages.contains(image.identity.messageId)),
          )
          .toList();
      final start = offset.clamp(0, available.length);
      final page = available.skip(start).take(30).toList();
      return ClientToolResult(
        jsonEncode({
          'images': [
            for (final image in page)
              {
                'image_id': image.handle,
                'source': image.source.name,
                'label': image.label,
              },
          ],
          if (start + page.length < available.length)
            'next_offset': start + page.length,
        }),
      );
    }
    final source = _byHandle[handle];
    if (source == null ||
        _isUnavailable(source) ||
        (allowedMessages != null &&
            !allowedMessages.contains(source.identity.messageId))) {
      return ClientToolResult(
        'Image is unavailable in the current conversation context. '
        '${hasRecallableImages ? 'Call read_chat_image without image_id to list available images.' : 'Ask the user to attach it again.'}',
      );
    }
    return ClientToolResult(
      'Image $handle',
      metadata: {
        kMcpResultMetadataKey: mcpResultMetadata([source.uri]),
        'chatImage': {
          'version': 1,
          'sourceKey': source.materializationKey ?? source.key,
          'directAsset':
              source.source != ContextImageSource.tool ||
              source.workspaceSnapshot,
          'mime': source.mediaType,
        },
      },
    );
  }

  static bool isReadImageResult(String name, Map<String, dynamic>? metadata) =>
      readChatImageMetadata(name, metadata) != null;

  bool ownsUri(String uri) => images.any(
    (image) =>
        !_isUnavailable(image) &&
        SandboxPathResolver.dedupeKey(image.uri) ==
            SandboxPathResolver.dedupeKey(uri),
  );

  String omittedText(String handle, {String? reason}) {
    if (reason == 'unavailable') {
      return '[Image $handle unavailable. Ask the user to attach it again.]';
    }
    final instruction =
        canImageInput && viewImageUris.contains(_byHandle[handle]?.uri)
        ? 'Use view_image on the attached Path when needed.'
        : hasRecallableImages
        ? 'Use read_chat_image with this image_id when needed.'
        : 'Ask the user to attach it again if needed.';
    return '[Image $handle omitted. $instruction]';
  }

  Future<String?> _load(ChatContextImage image) =>
      _loads.putIfAbsent(image.key, () async {
        final data = await _readPixels(image);
        if (data == null) {
          _unavailableSources.add(image.materializationKey ?? image.key);
        }
        return data;
      });

  Future<String?> _readPixels(ChatContextImage source) async {
    if (_isUnavailable(source)) return null;
    if (loader != null) return loader!(source);
    if (source.source == ContextImageSource.tool) {
      if (source.workspaceSnapshot) {
        if (source.uri.startsWith('data:')) return source.uri;
        if (isRemoteHttpUrl(source.uri)) {
          return McpImageSnapshot.readDataUrl(
            source.uri,
            cacheKey: source.materializationKey ?? source.key,
          );
        }
        return tryEncodeBase64DataUrl(
          source.uri,
          explicitMime: source.mediaType,
        );
      }
      return McpImageSnapshot.readDataUrl(
        source.uri,
        cacheKey: source.materializationKey ?? source.key,
      );
    }
    if (isRemoteHttpUrl(source.uri) && inlineRemoteUsers) {
      return McpImageSnapshot.readDataUrl(
        source.uri,
        cacheKey: source.materializationKey ?? source.key,
      );
    }
    if (source.uri.startsWith('data:') || isRemoteHttpUrl(source.uri)) {
      return source.uri;
    }
    return tryEncodeBase64DataUrl(source.uri, explicitMime: source.mediaType);
  }

  Future<File?> _localAssetFile(ChatContextImage image) async {
    final path = SandboxPathResolver.resolveForIo(image.uri);
    if (path == null) return null;
    if (image.source == ContextImageSource.tool && !image.workspaceSnapshot) {
      return McpImageSnapshot.localFile(image.uri);
    }
    return File(path);
  }

  Future<int?> estimatedBytes(
    ChatContextImage image,
  ) => _sizes.putIfAbsent(image.key, () async {
    if (_isUnavailable(image)) return null;
    if (image.uri.startsWith('data:')) return wireImageBytes(image.uri);
    if (isRemoteHttpUrl(image.uri)) {
      // Reserve a stable upper bound for inline URLs, including cold previews.
      return image.source == ContextImageSource.tool || inlineRemoteUsers
          ? math.min(budget.singleImageBytes, historyBudget.singleImageBytes)
          : 0;
    }
    final file = await _localAssetFile(image);
    if (file == null) return null;
    final stat = await file.stat();
    return stat.type == FileSystemEntityType.file
        ? ImageContextPlanner.base64Bytes(stat.size)
        : null;
  });

  Future<Set<String>> historyOmissions() async {
    if (!settings.automatic) return {};
    final candidates = <ImageContextCandidate>[];
    for (final image in images) {
      if (image.source != ContextImageSource.tool &&
          isRemoteHttpUrl(image.uri) &&
          !allowsRemoteUserImages) {
        continue;
      }
      if (omitUserImages &&
          image.source == ContextImageSource.user &&
          !activeHandles.contains(image.handle)) {
        continue;
      }
      candidates.add(
        ImageContextCandidate(
          key: image.key,
          source: image.source,
          encodedBytes: await estimatedBytes(image) ?? 0,
          userMessageId: image.source == ContextImageSource.user
              ? image.identity.messageId
              : null,
          userTurnId: _userTurns[image.identity.messageId],
          protected: settings.pinned.contains(image.key),
        ),
      );
    }
    return ImageContextPlanner.historyOmissions(
      candidates,
      maxBytes: math.min(budget.totalImageBytes, historyBudget.totalImageBytes),
      maxSingleBytes: math.min(
        budget.singleImageBytes,
        historyBudget.singleImageBytes,
      ),
      maxImages: math.min(budget.imageCount, historyBudget.imageCount),
      latestUserId: latestUserId,
    );
  }

  static String? referenceHandle(String value) {
    final marker = value.indexOf(_referencePrefix);
    if (marker < 0 || !(value.startsWith('data:') || marker == 0)) return null;
    return value.substring(marker + _referencePrefix.length);
  }

  static int wireImageBytes(String url) {
    if (!url.startsWith('data:')) return 0;
    final comma = url.indexOf(',');
    return comma < 0 ? 0 : url.length - comma - 1;
  }

  /// Only visits protocol-owned content arrays. Tool arguments, JSON tool
  /// output, thinking/signatures and user text are never interpreted as images.
  static dynamic _mapContent(
    dynamic value,
    dynamic Function(Map<String, dynamic>, String) image,
  ) {
    if (value is! List) return value;
    return [for (final part in value) _mapPart(part, image)];
  }

  static dynamic _mapPart(
    dynamic value,
    dynamic Function(Map<String, dynamic>, String) image,
  ) {
    if (value is! Map) return value;
    final part = Map<String, dynamic>.from(value);
    final source = part['source'];
    final inline = part['inlineData'] ?? part['inline_data'];
    if (part['type'] == 'image_url' && part['image_url'] is Map) {
      return image(part, (part['image_url']['url'] ?? '').toString());
    }
    if (part['type'] == 'input_image' && part['image_url'] is String) {
      return image(part, part['image_url'] as String);
    }
    if (part['type'] == 'image' &&
        source is Map &&
        source['type'] == 'base64') {
      return image(
        part,
        'data:${source['media_type']};base64,${source['data']}',
      );
    }
    if (inline is Map &&
        (inline['mimeType'] ?? inline['mime_type'] ?? '').toString().startsWith(
          'image/',
        )) {
      return image(
        part,
        'data:${inline['mimeType'] ?? inline['mime_type']};base64,${inline['data']}',
      );
    }
    if (part['type'] == 'tool_result') {
      part['content'] = _mapContent(part['content'], image);
    }
    return part;
  }

  static Map<String, dynamic> _mapBody(
    Map<String, dynamic> body,
    dynamic Function(Map<String, dynamic>, String) image, {
    void Function(String)? nativeImage,
  }) {
    final result = Map<String, dynamic>.from(body);
    for (final key in ['messages', 'input', 'contents']) {
      final messages = body[key];
      if (messages is! List) continue;
      result[key] = [
        for (final value in messages)
          if (value is Map)
            (() {
              final message = Map<String, dynamic>.from(value)
                ..remove(imageContextOwnerKey)
                ..remove(multimodalInternalImageReferencesKey);
              if (message[nativeCompactionWireKey] == true) {
                if (nativeImage != null) {
                  dynamic observe(Map<String, dynamic> part, String url) {
                    nativeImage(url);
                    return part;
                  }

                  for (final field in ['content', 'parts']) {
                    _mapContent(message[field], observe);
                  }
                  if (message['type'] == 'function_call_output') {
                    _mapContent(message['output'], observe);
                  }
                }
                return message;
              }
              for (final field in ['content', 'parts']) {
                if (message.containsKey(field)) {
                  message[field] = _mapContent(message[field], image);
                }
              }
              if (message['type'] == 'function_call_output') {
                message['output'] = _mapContent(message['output'], image);
              }
              return message;
            })()
          else
            value,
      ];
    }
    return result;
  }

  static Map<String, dynamic> _textPart(
    Map<String, dynamic> original,
    String text,
  ) => original.containsKey('inlineData') || original.containsKey('inline_data')
      ? {'text': text}
      : {
          'type': original['type'] == 'input_image' ? 'input_text' : 'text',
          'text': text,
          if (original.containsKey('cache_control'))
            'cache_control': original['cache_control'],
        };

  static Map<String, dynamic> _replaceImage(
    Map<String, dynamic> original,
    String url,
  ) {
    final part = Map<String, dynamic>.from(original);
    final comma = url.indexOf(',');
    final data = comma < 0 ? url : url.substring(comma + 1);
    final mime = url.startsWith('data:') ? mimeFromDataUrl(url) : 'image/png';
    if (part['type'] == 'image_url') {
      part['image_url'] = {...(part['image_url'] as Map), 'url': url};
    } else if (part['type'] == 'input_image') {
      part['image_url'] = url;
    } else if (part['type'] == 'image') {
      part['source'] = isRemoteHttpUrl(url)
          ? {'type': 'url', 'url': url}
          : {
              'type': 'base64',
              'media_type': normalizeClaudeImageMime(mime),
              'data': data,
            };
    } else if (isRemoteHttpUrl(url)) {
      // Gemini's user URL path is downloaded by its provider builder. Tools
      // always resolve to a local snapshot before reaching this boundary.
      return {
        'fileData': {'mimeType': mime, 'fileUri': url},
      };
    } else {
      final key = part.containsKey('inline_data')
          ? 'inline_data'
          : 'inlineData';
      final previous = part[key] as Map;
      part[key] = {
        ...previous,
        previous.containsKey('mime_type') ? 'mime_type' : 'mimeType': mime,
        'data': data,
      };
    }
    return part;
  }

  Future<Map<String, dynamic>> project(
    Map<String, dynamic> body, {
    Set<String> excludedOwners = const {},
    bool preserveSources = false,
  }) async {
    final handles = <String>{};
    final occurrences = <String, int>{};
    final external = <String, String>{};
    final wireKeys = <String>[];
    var externalIndex = 0;
    void addExternal(String url) {
      final key = 'external:${externalIndex++}';
      wireKeys.add(key);
      external[key] = url;
    }

    _mapBody(body, (part, url) {
      final handle = referenceHandle(url);
      if (handle != null && _byHandle.containsKey(handle)) {
        handles.add(handle);
        wireKeys.add(_byHandle[handle]!.key);
        occurrences.update(handle, (n) => n + 1, ifAbsent: () => 1);
      } else {
        addExternal(url);
      }
      return part;
    }, nativeImage: addExternal);
    final omittedByCount = {
      ...await historyOmissions(),
      for (final image in images)
        if (compressedOwners.contains(image.identity.messageId) ||
            excludedOwners.contains(image.identity.messageId))
          image.key,
    };
    final positions = <String, int>{};
    var position = 0;
    for (final key in wireKeys) {
      if (!omittedByCount.contains(key)) {
        final index = ++position;
        positions.putIfAbsent(key, () => index);
      }
    }
    void checkSingle(int bytes, String key) {
      if (bytes <= budget.singleImageBytes) return;
      throw ImageContextBudgetException(
        kind: ImageContextBudgetKind.singleImage,
        actual: bytes,
        limit: budget.singleImageBytes,
        imageIndex: positions[key],
        imageKey: key,
        pinned: settings.pinned.contains(key),
      );
    }

    final neededKeys = {
      for (final image in images)
        if (handles.contains(image.handle) &&
            !omittedByCount.contains(image.key))
          image.key,
    };
    _loads.removeWhere((key, _) => !neededKeys.contains(key));
    // Reject impossible pinned/current selections using file sizes before
    // allocating their Base64 strings. Remote pixels are checked after fetch.
    final estimates = <ImageContextCandidate>[];
    for (final entry in images) {
      if (!neededKeys.contains(entry.key)) continue;
      final size = isRemoteHttpUrl(entry.uri)
          ? 0
          : await estimatedBytes(entry) ?? 0;
      checkSingle(size, entry.key);
      estimates.add(
        ImageContextCandidate(
          key: entry.key,
          source: entry.source,
          encodedBytes: size * (occurrences[entry.handle] ?? 1),
          // References may be unreadable. Count only resolved pixels below.
          count: 0,
        ),
      );
    }
    for (final entry in external.entries) {
      final size = wireImageBytes(entry.value);
      checkSingle(size, entry.key);
      estimates.add(
        ImageContextCandidate(
          key: entry.key,
          source: ContextImageSource.user,
          encodedBytes: size,
        ),
      );
    }
    ImageContextPlanner.validateBudget(
      estimates,
      maxBytes: budget.totalImageBytes,
      maxImages: budget.imageCount,
      minimum: true,
    );
    final urls = <String, String?>{};
    final candidates = <ImageContextCandidate>[
      for (final item in external.entries)
        ImageContextCandidate(
          key: item.key,
          source: ContextImageSource.user,
          encodedBytes: wireImageBytes(item.value),
          protected: true,
        ),
    ];
    var resolvedBytes = candidates.fold<int>(
      0,
      (sum, image) => sum + image.encodedBytes,
    );
    var resolvedCount = candidates.length;
    final oversize = <String>{};
    for (final entry in images) {
      if (!handles.contains(entry.handle) ||
          omittedByCount.contains(entry.key)) {
        continue;
      }
      final url = urls[entry.handle] = await _load(entry);
      if (url == null) continue;
      final singleBytes = wireImageBytes(url);
      final protected =
          settings.pinned.contains(entry.key) ||
          (entry.source == ContextImageSource.user &&
              entry.identity.messageId == latestUserId);
      final limit = protected || !settings.automatic
          ? budget.singleImageBytes
          : math.min(budget.singleImageBytes, historyBudget.singleImageBytes);
      if (singleBytes > limit) {
        if (protected || !settings.automatic) {
          checkSingle(singleBytes, entry.key);
        }
        oversize.add(entry.key);
        continue;
      }
      final count = occurrences[entry.handle] ?? 1;
      candidates.add(
        ImageContextCandidate(
          key: entry.key,
          source: entry.source,
          count: count,
          encodedBytes: singleBytes * count,
          protected: protected,
        ),
      );
      resolvedBytes += singleBytes * count;
      resolvedCount += count;
      if (resolvedBytes > budget.totalImageBytes ||
          resolvedCount > budget.imageCount) {
        // Stop before reading more images. The diagnostic explicitly reports
        // a measured lower bound rather than pretending this is the full size.
        ImageContextPlanner.validateBudget(
          candidates,
          maxBytes: budget.totalImageBytes,
          maxImages: budget.imageCount,
          minimum: true,
        );
      }
    }
    final omitted = {...omittedByCount, ...oversize};
    // The deterministic history replay owns eviction. The final wire check is
    // a hard guard, so a changing text size cannot silently resurrect images.
    final toolNotes = <String, List<String>>{};
    final projected = _mapBody(body, (part, url) {
      final handle = referenceHandle(url);
      if (handle == null) return part;
      final entry = _byHandle[handle];
      final resolved = urls[handle];
      if (entry != null && !omitted.contains(entry.key) && resolved != null) {
        return _replaceImage(part, resolved);
      }
      final text = omittedText(
        handle,
        reason: entry != null && omitted.contains(entry.key)
            ? null
            : 'unavailable',
      );
      // Chat Completions injects tool images in a synthetic user message.
      // Put omissions back in their tool result and drop the synthetic row
      // when it has no pixels left. Other protocols keep native result parts.
      if (body['messages'] is List &&
          part['type'] == 'image_url' &&
          entry?.toolCallId != null) {
        toolNotes.putIfAbsent(entry!.toolCallId!, () => []).add(text);
        return <String, dynamic>{'_kelivo_omitted_tool_image': true};
      }
      return _textPart(part, text);
    });
    if (toolNotes.isNotEmpty && projected['messages'] is List) {
      final messages = (projected['messages'] as List)
          .cast<Map<String, dynamic>>();
      for (final message in messages) {
        if (message['role'] == 'tool') {
          final notes = toolNotes[message['tool_call_id']];
          if (notes != null) {
            message['content'] =
                '${message['content'] ?? ''}\n${notes.join('\n')}'.trim();
          }
        }
        final content = message['content'];
        if (content is List &&
            content.any(
              (p) => p is Map && p['_kelivo_omitted_tool_image'] == true,
            )) {
          final cleaned = <dynamic>[];
          var group = <dynamic>[];
          void flush() {
            final hasPixels = group.any(
              (p) => p is Map && p['type'] == 'image_url',
            );
            for (final part in group) {
              if (part is Map && part['_kelivo_omitted_tool_image'] == true) {
                continue;
              }
              if (!hasPixels &&
                  part is Map &&
                  part['type'] == 'text' &&
                  (part['text'] ?? '').toString().startsWith(
                    'Image returned by ',
                  )) {
                continue;
              }
              cleaned.add(part);
            }
            group = [];
          }

          for (final part in content) {
            if (part is Map &&
                part['type'] == 'text' &&
                (part['text'] ?? '').toString().startsWith(
                  'Image returned by ',
                )) {
              flush();
            }
            group.add(part);
          }
          flush();
          message['content'] = cleaned;
        }
      }
      messages.removeWhere(
        (m) =>
            m['role'] == 'user' &&
            m['content'] is List &&
            (m['content'] as List).isEmpty,
      );
      projected['messages'] = messages;
    }
    final projectedTools = _projectTools(projected, this);
    final request = RequestHistoryContext.stripSources(projectedTools);
    final byteCounter = _JsonByteCounter();
    final encoder = json.encoder
        .fuse(utf8.encoder)
        .startChunkedConversion(byteCounter);
    encoder.add(request);
    encoder.close();
    validateBodyBytes(byteCounter.length);
    // Compaction needs message ownership until it has selected which real
    // user items to retain. Always measure the clean wire representation.
    return preserveSources ? projectedTools : request;
  }

  /// Also checked after OAuth adapters add their final protocol fields.
  void validateBodyBytes(int bytes) {
    if (bytes <= budget.bodyBytes) return;
    throw ImageContextBudgetException(
      kind: ImageContextBudgetKind.requestBody,
      actual: bytes,
      limit: budget.bodyBytes,
    );
  }

  List<Map<String, dynamic>> withoutImageInput(
    List<Map<String, dynamic>> messages,
  ) => [
    for (final original in messages)
      (() {
        final message = Map<String, dynamic>.from(original);
        if (message['role'] == 'tool') return message;
        var text =
            _parsedText[original] ?? (message['content'] ?? '').toString();
        final seen = <String>{};
        for (final image in images) {
          final marker = '![](${image.reference})';
          if (text.contains(marker)) {
            text = text.replaceAll(marker, omittedText(image.handle));
            seen.add(image.handle);
          }
        }
        for (final reference in internalImageReferences(message).values) {
          final handle = referenceHandle(reference);
          if (handle != null && seen.add(handle)) {
            text += '\n${omittedText(handle)}';
          }
        }
        for (final ref in parseInternalMediaRefs(
          message[multimodalInternalMediaPathsKey],
        )) {
          final handle = referenceHandle(ref.uri);
          if (handle != null && seen.add(handle)) {
            text += '\n${omittedText(handle)}';
          }
        }
        message['content'] = text;
        return message;
      })(),
  ];

  /// Keep the candidates intact: a tool can return the first image after the
  /// initial request. Preview and every HTTP round use this same projection.
  static List<Map<String, dynamic>> toolsForRequest(
    List<Map<String, dynamic>> tools, {
    required RequestImageContext? imageContext,
  }) {
    if (imageContext?.hasRecallableImages == true) return tools;
    return [
      for (final tool in tools)
        if (_withoutRecallTool(tool) case final filtered?) filtered,
    ];
  }

  static bool _isRecallTool(Map tool) =>
      tool['name'] == 'read_chat_image' ||
      (tool['function'] is Map &&
          tool['function']['name'] == 'read_chat_image');

  static Map<String, dynamic>? _withoutRecallTool(Map<String, dynamic> tool) {
    if (_isRecallTool(tool)) return null;
    var result = tool;
    for (final key in ['function_declarations', 'functionDeclarations']) {
      final declarations = tool[key];
      if (declarations is! List ||
          !declarations.any((d) => d is Map && _isRecallTool(d))) {
        continue;
      }
      final filtered = [
        for (final declaration in declarations)
          if (declaration is! Map || !_isRecallTool(declaration)) declaration,
      ];
      result = {...result}..remove(key);
      if (filtered.isNotEmpty) result[key] = filtered;
    }
    return result.isEmpty ? null : result;
  }

  static Map<String, dynamic> _projectTools(
    Map<String, dynamic> body,
    RequestImageContext? imageContext,
  ) {
    final candidates = body['tools'];
    if (candidates is! List) return body;
    final tools = toolsForRequest(
      candidates.cast<Map<String, dynamic>>(),
      imageContext: imageContext,
    );
    if (tools.length == candidates.length &&
        Iterable<int>.generate(
          tools.length,
        ).every((i) => identical(tools[i], candidates[i]))) {
      return body;
    }
    final result = {...body};
    if (tools.isEmpty) {
      result.remove('tools');
      result.remove('tool_choice');
    } else {
      result['tools'] = tools;
      final choice = result['tool_choice'];
      if (choice is Map && _isRecallTool(choice)) {
        result.remove('tool_choice');
      }
    }
    final hasFunctions = tools.any(
      (tool) => [
        'function_declarations',
        'functionDeclarations',
      ].any((key) => tool[key] is List && (tool[key] as List).isNotEmpty),
    );
    if (!hasFunctions && result['toolConfig'] is Map) {
      final config = Map<String, dynamic>.from(result['toolConfig'] as Map)
        ..remove('function_calling_config')
        ..remove('functionCallingConfig')
        ..remove('includeServerSideToolInvocations');
      if (config.isEmpty) {
        result.remove('toolConfig');
      } else {
        result['toolConfig'] = config;
      }
    }
    return result;
  }

  static Future<String> encodeBody(Map<String, dynamic> body) async {
    final context = current;
    final history = RequestHistoryContext.current;
    final prepared = history == null ? body : await history.prepare(body);
    return jsonEncode(
      context == null
          ? RequestHistoryContext.stripSources(_projectTools(prepared, null))
          : await context.project(prepared),
    );
  }

  Map<String, dynamic> previewMessage(Map<String, dynamic> message) {
    final text = _parsedText[message];
    return text == null ? message : {...message, 'content': text};
  }

  Future<List<ImageContextPreviewItem>> preview() async {
    final omitted = await historyOmissions();
    final result = <ImageContextPreviewItem>[];
    for (final image in images) {
      final bytes = await estimatedBytes(image);
      result.add(
        ImageContextPreviewItem(
          image,
          included:
              canImageInput &&
              activeHandles.contains(image.handle) &&
              bytes != null &&
              !_isUnavailable(image) &&
              !omitted.contains(image.key),
          pinned: settings.pinned.contains(image.key),
          bytes: bytes,
          sizeIsEstimate:
              isRemoteHttpUrl(image.uri) &&
              (image.source == ContextImageSource.tool || inlineRemoteUsers),
        ),
      );
    }
    return result;
  }

  /// A preview may inspect an existing local image, but must not fetch or save
  /// pixels just because its row became visible. Keep the same MCP file gate
  /// as explicit reattachment.
  Future<String?> localAttachmentPath(String handle) async {
    final image = _byHandle[handle];
    if (image == null || _isUnavailable(image)) return null;
    final file = await _localAssetFile(image);
    return file != null && await file.exists() ? file.path : null;
  }

  Future<String?> attachmentPath(String handle) async {
    final image = _byHandle[handle];
    if (image == null || _isUnavailable(image)) return null;
    final local = await localAttachmentPath(handle);
    if (local != null) return local;
    final data = isRemoteHttpUrl(image.uri)
        ? await McpImageSnapshot.readDataUrl(
            image.uri,
            cacheKey: image.materializationKey ?? image.key,
          )
        : await _load(image);
    if (data == null || !data.startsWith('data:')) return null;
    final saved = await McpImageSnapshot.save(
      data.substring(data.indexOf(',') + 1),
    );
    return saved == null ? null : SandboxPathResolver.resolveForIo(saved);
  }
}

/// Count serialized UTF-8 bytes without retaining another full JSON string and
/// byte buffer alongside the image payload. encodeBody performs the final encode.
class _JsonByteCounter implements Sink<List<int>> {
  int length = 0;
  @override
  void add(List<int> data) => length += data.length;
  @override
  void close() {}
}
