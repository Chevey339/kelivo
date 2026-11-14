import 'dart:convert';

import '../models/message_part.dart';
import '../../utils/mcp_structured_image.dart';
import 'multimodal_input_utils.dart';

/// Only the built-in reader can retain authority to a conversation attachment.
({String sourceKey, bool directAsset, String mime})? readChatImageMetadata(
  String name,
  Map<String, dynamic>? metadata,
) {
  // Persisted observations keep the name recorded when they were created.
  // This only validates their image ownership; it does not expose a tool alias.
  if (name != 'view_image' && name != 'read_chat_image') return null;
  if (metadata?['chatImage'] case {
    'version': 1,
    'sourceKey': final String key,
    'directAsset': final bool direct,
    'mime': final String mime,
  }) {
    if (key.isNotEmpty && isImageMime(mime)) {
      return (sourceKey: key, directAsset: direct, mime: mime);
    }
  }
  return null;
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
