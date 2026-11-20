import 'dart:convert';

import '../models/image_context.dart';
import '../models/message_part.dart';
import '../../utils/mcp_structured_image.dart';
import '../../utils/sandbox_path_resolver.dart';
import 'multimodal_input_utils.dart';

/// Only the built-in reader can retain authority to a conversation attachment.
({String sourceKey, String? contextKey, bool directAsset, String mime})?
readChatImageMetadata(String name, Map<String, dynamic>? metadata) {
  // Persisted observations keep the name recorded when they were created.
  // This only validates their image ownership; it does not expose a tool alias.
  if (name != 'view_image' && name != 'read_chat_image') return null;
  final image = metadata?['chatImage'];
  if (image case {
    'version': 1,
    'sourceKey': final String key,
    'directAsset': final bool direct,
    'mime': final String mime,
  }) {
    if (key.isNotEmpty && isImageMime(mime)) {
      final owner = image['contextKey'];
      return (
        sourceKey: key,
        contextKey: owner is String && owner.isNotEmpty ? owner : null,
        directAsset: direct,
        mime: mime,
      );
    }
  }
  return null;
}

/// Markdown handles use local paths. An exclusion must also survive restoring
/// a managed file into a different app container.
String chatImageExclusionKey(String key, String uri) {
  final separator = key.indexOf('|');
  if (separator < 1 || !key.startsWith('markdown:', separator + 1)) return key;
  if (uri.isEmpty) return key;
  return ContextImageIdentity.markdown(
    key.substring(0, separator),
    SandboxPathResolver.canonicalize(uri),
  ).key;
}

/// A copy changes the image's conversation identity but keeps the key used to
/// retrieve the original local snapshot.
Map<String, dynamic> remapChatImageEvent(
  Map<String, dynamic> event,
  Map<String, String> messageIds,
  Set<String> retainedOrigins,
) {
  final raw = event['metadata'];
  if (raw is! Map<String, dynamic>) return event;
  final image = readChatImageMetadata(event['name']?.toString() ?? '', raw);
  if (image == null) return event;
  final origin =
      image.contextKey ??
      chatImageExclusionKey(
        image.sourceKey,
        mcpResultImageUris(readMcpResultMetadata(raw)).firstOrNull ?? '',
      );
  final remapped = ContextImageIdentity.remapKey(origin, messageIds);
  if (remapped == null) {
    retainedOrigins.add(origin);
    return event;
  }
  if (remapped == image.contextKey) return event;
  return {
    ...event,
    'metadata': {
      ...raw,
      'chatImage': {...raw['chatImage'] as Map, 'contextKey': remapped},
    },
  };
}

String remapChatImagePayload(
  String payload,
  Map<String, String> messageIds,
  Set<String> retainedOrigins,
) {
  if (!payload.contains('"chatImage"')) return payload;
  try {
    final event = jsonDecode(payload);
    if (event is! Map<String, dynamic>) return payload;
    final mapped = remapChatImageEvent(event, messageIds, retainedOrigins);
    return identical(mapped, event) ? payload : jsonEncode(mapped);
  } on FormatException {
    return payload;
  }
}

/// These results own their local observation independently of its source.
/// Direct attachments still need managed-root and regular-file validation;
/// non-direct results keep the MCP snapshot gate during asset synchronization.
List<({String uri, bool directAsset})> chatImageAssetsFromToolEvent(
  Object? event,
) {
  if (event case {
    'name': final String name,
    'metadata': final Map<String, dynamic> metadata,
  }) {
    final source = readChatImageMetadata(name, metadata);
    if (source != null) {
      return [
        for (final uri in mcpResultImageUris(readMcpResultMetadata(metadata)))
          if (!isRemoteOrDataUri(uri))
            (uri: uri, directAsset: source.directAsset),
      ];
    }
  }
  return const [];
}

List<({String uri, bool directAsset})> chatImageAssetsFromPart(
  ToolCallPart part,
) {
  if (!part.payloadJson.contains('"chatImage"')) return const [];
  try {
    return chatImageAssetsFromToolEvent(jsonDecode(part.payloadJson));
  } on FormatException {
    return const [];
  }
}
