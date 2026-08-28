import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Private-use delimiters from an older persist format.
///
/// New results never write these. They remain so old saved conversations
/// still parse. Text that is not a typed image is escaped so these
/// characters cannot forge an attachment.
const int kMcpStructuredImageOpen = 0xE012;
const int kMcpStructuredImageClose = 0xE013;

const String kMcpToolResultKind = 'mcp_tool_result';
const String kMcpResultMetadataKey = 'mcpResult';
const int kMcpResultVersion = 1;

/// Compact prefix written by the previous JSON-in-content iteration.
///
/// Read-only. New writes never use this envelope as [ToolCallPart] content.
const String kMcpToolResultEnvelopePrefix = '{"kelivo":"mcp_tool_result"';

/// Flattened MCP tool result. [markdown] is already in original content order.
class McpToolResult {
  const McpToolResult({
    this.markdown = '',
    this.imageUris = const [],
    this.legacyBody,
  });

  /// Model / export / old-client view. Standard Markdown, no private JSON.
  final String markdown;

  /// First-seen image URIs for UI metadata. May omit duplicates.
  final List<String> imageUris;

  /// Original envelope `text` for old JSON rows. Null for new Markdown writes.
  final String? legacyBody;

  bool get hasImages => imageUris.isNotEmpty;

  String toMarkdown() => markdown;
}

/// Value stored at `metadata.mcpResult`. Image-less results still include
/// an empty [imageUris] list so type is never guessed from body text.
Map<String, dynamic> mcpResultMetadata(Iterable<String> imageUris) {
  return <String, dynamic>{
    'version': kMcpResultVersion,
    'imageUris': [for (final uri in imageUris) uri],
  };
}

Map<String, dynamic>? readMcpResultMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  final raw = metadata[kMcpResultMetadataKey];
  if (raw is! Map) return null;
  if (raw['version'] == null) return null;
  return Map<String, dynamic>.from(raw);
}

List<String> mcpResultImageUris(Map<String, dynamic>? mcpResult) {
  if (mcpResult == null) return const [];
  final raw = mcpResult['imageUris'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is String && item.isNotEmpty) item,
  ];
}

List<String> dedupeImageUrisFirstSeen(Iterable<String> uris) {
  final seen = <String>{};
  final out = <String>[];
  for (final uri in uris) {
    if (uri.isEmpty) continue;
    if (seen.add(uri)) out.add(uri);
  }
  return out;
}

Map<String, dynamic>? mergeToolResultMetadata(
  Map<String, dynamic>? callMetadata,
  Map<String, dynamic>? resultMetadata,
) {
  if (resultMetadata == null || resultMetadata.isEmpty) {
    return callMetadata == null || callMetadata.isEmpty ? null : callMetadata;
  }
  if (callMetadata == null || callMetadata.isEmpty) return resultMetadata;
  return <String, dynamic>{...callMetadata, ...resultMetadata};
}

/// Handler return: Markdown [content] plus optional result metadata.
///
/// [onToolCall] may still return a [String] (search / local tools).
class ClientToolResult {
  const ClientToolResult(this.content, {this.metadata});

  final String content;
  final Map<String, dynamic>? metadata;

  static ClientToolResult fromHandler(Object? raw) {
    if (raw is ClientToolResult) return raw;
    if (raw is McpToolResult) {
      return ClientToolResult(
        raw.markdown,
        metadata: <String, dynamic>{
          kMcpResultMetadataKey: mcpResultMetadata(raw.imageUris),
        },
      );
    }
    return ClientToolResult(toolResultContentForModel(raw?.toString()));
  }
}

/// Model / export string. Legacy envelope → Markdown. Complete PUA image
/// lines → Markdown. Anything else is unchanged.
String toolResultContentForModel(String? content) {
  if (content == null || content.isEmpty) return '';
  final envelope = tryDecodeLegacyMcpToolResultEnvelope(content);
  if (envelope != null) return envelope.toMarkdown();
  return convertLegacyMcpPrivateImageLinesToMarkdown(content);
}

/// @nodoc Kept for older call sites during the metadata migration.
String mcpToolResultForModel(String? content) =>
    toolResultContentForModel(content);

McpToolResult decodeMcpToolResult(String? content) {
  if (content == null || content.isEmpty) return const McpToolResult();
  final envelope = tryDecodeLegacyMcpToolResultEnvelope(content);
  if (envelope != null) return envelope;
  return McpToolResult(markdown: content);
}

/// Constant-time prefix check. Does not parse the body.
bool looksLikeLegacyMcpToolResultEnvelope(String content) {
  return content.trim().startsWith(kMcpToolResultEnvelopePrefix);
}

/// Read-only decoder for records written as
/// `{"kelivo":"mcp_tool_result",...}`. New writes must not produce this.
McpToolResult? tryDecodeLegacyMcpToolResultEnvelope(String content) {
  if (!looksLikeLegacyMcpToolResultEnvelope(content)) return null;
  try {
    final decoded = jsonDecode(content.trim());
    if (decoded is! Map) return null;
    if (decoded['kelivo'] != kMcpToolResultKind) return null;
    final text = (decoded['text'] ?? '').toString();
    final raw = decoded['imageUris'];
    final uris = <String>[
      if (raw is List)
        for (final item in raw)
          if (item is String && item.isNotEmpty) item,
    ];
    return McpToolResult(
      markdown: _concatLegacyEnvelopeMarkdown(text, uris),
      imageUris: uris,
      legacyBody: text,
    );
  } catch (_) {
    return null;
  }
}

String _concatLegacyEnvelopeMarkdown(String text, List<String> imageUris) {
  final buf = StringBuffer();
  if (text.isNotEmpty) buf.write(text);
  for (final uri in imageUris) {
    if (uri.isEmpty) continue;
    if (buf.isNotEmpty) buf.writeln();
    buf.write('![](${encodeMarkdownImageDestination(uri)})');
  }
  return buf.toString();
}

@visibleForTesting
String encodeLegacyMcpToolResultEnvelope({
  required String text,
  required List<String> imageUris,
}) {
  return jsonEncode({
    'kelivo': kMcpToolResultKind,
    'text': text,
    'imageUris': imageUris,
  });
}

String escapeMcpStructuredImageText(String text) {
  if (text.isEmpty) return text;
  final open = String.fromCharCode(kMcpStructuredImageOpen);
  final close = String.fromCharCode(kMcpStructuredImageClose);
  if (!text.contains(open) && !text.contains(close)) return text;
  return text.replaceAll(open, '').replaceAll(close, '');
}

/// Convert only complete old image lines. Body text that happens to contain
/// these PUA characters is left alone.
String convertLegacyMcpPrivateImageLinesToMarkdown(String content) {
  if (content.isEmpty) return content;
  if (!content.contains(String.fromCharCode(kMcpStructuredImageOpen))) {
    return content;
  }
  final buf = StringBuffer();
  var start = 0;
  var i = 0;
  while (i <= content.length) {
    final atEnd = i == content.length;
    final isBreak = !atEnd && _isLogicalLineBreak(content.codeUnitAt(i));
    if (!atEnd && !isBreak) {
      i++;
      continue;
    }
    final line = content.substring(start, i);
    final path = decodeMcpStructuredImageLine(line);
    if (path != null) {
      buf.write('![](${encodeMarkdownImageDestination(path)})');
    } else {
      buf.write(line);
    }
    if (atEnd) break;
    if (content.codeUnitAt(i) == 0x0D &&
        i + 1 < content.length &&
        content.codeUnitAt(i + 1) == 0x0A) {
      buf.write('\r\n');
      i += 2;
    } else {
      buf.writeCharCode(content.codeUnitAt(i));
      i += 1;
    }
    start = i;
  }
  return buf.toString();
}

bool _isLogicalLineBreak(int unit) =>
    unit == 0x0A || unit == 0x0D || unit == 0x2028 || unit == 0x2029;

String encodeMarkdownImageDestination(String uri) {
  if (uri.isEmpty) return uri;
  if (!_destinationNeedsAngleBrackets(uri)) return uri;
  return '<${_escapeAngleBracketDestination(uri)}>';
}

String decodeMarkdownImageDestination(String raw) {
  final dest = raw.trim();
  if (dest.length >= 2 && dest.startsWith('<') && dest.endsWith('>')) {
    return _unescapeAngleBracketDestination(dest.substring(1, dest.length - 1));
  }
  if (isWindowsImageDestination(dest)) return dest;
  return unescapeMarkdownDestination(dest);
}

bool isWindowsImageDestination(String dest) {
  if (dest.startsWith(r'\\')) return true;
  if (dest.length >= 3 &&
      dest.codeUnitAt(1) == 0x3A &&
      (dest.codeUnitAt(2) == 0x5C || dest.codeUnitAt(2) == 0x2F) &&
      _isDriveLetter(dest.codeUnitAt(0))) {
    return true;
  }
  return false;
}

/// Unescape only Markdown punctuation. Windows path backslashes stay.
@visibleForTesting
String unescapeMarkdownDestination(String raw) {
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final ch = raw.codeUnitAt(i);
    if (ch == 0x5C && i + 1 < raw.length) {
      final next = raw.codeUnitAt(i + 1);
      if (_isMarkdownAsciiPunctuation(next)) {
        buf.writeCharCode(next);
        i += 1;
        continue;
      }
    }
    buf.writeCharCode(ch);
  }
  return buf.toString();
}

bool _destinationNeedsAngleBrackets(String uri) {
  if (isWindowsImageDestination(uri)) return true;
  for (var i = 0; i < uri.length; i++) {
    final unit = uri.codeUnitAt(i);
    if (unit <= 0x20) return true;
    if (unit == 0x28 ||
        unit == 0x29 ||
        unit == 0x5C ||
        unit == 0x23 ||
        unit == 0x25 ||
        unit == 0x3C ||
        unit == 0x3E) {
      return true;
    }
    if (unit > 0x7E) return true;
  }
  return false;
}

String _escapeAngleBracketDestination(String uri) {
  final buf = StringBuffer();
  for (var i = 0; i < uri.length; i++) {
    final unit = uri.codeUnitAt(i);
    if (unit == 0x5C || unit == 0x3E) buf.writeCharCode(0x5C);
    buf.writeCharCode(unit);
  }
  return buf.toString();
}

String _unescapeAngleBracketDestination(String raw) {
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final unit = raw.codeUnitAt(i);
    if (unit == 0x5C && i + 1 < raw.length) {
      final next = raw.codeUnitAt(i + 1);
      if (next == 0x5C || next == 0x3E) {
        buf.writeCharCode(next);
        i += 1;
        continue;
      }
    }
    buf.writeCharCode(unit);
  }
  return buf.toString();
}

bool _isDriveLetter(int unit) {
  return (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);
}

bool _isMarkdownAsciiPunctuation(int unit) {
  return (unit >= 0x21 && unit <= 0x2F) ||
      (unit >= 0x3A && unit <= 0x40) ||
      (unit >= 0x5B && unit <= 0x60) ||
      (unit >= 0x7B && unit <= 0x7E);
}

String? decodeMcpStructuredImageLine(String line) {
  final trimmed = line.trim();
  if (trimmed.length < 3) return null;
  if (trimmed.codeUnitAt(0) != kMcpStructuredImageOpen) return null;
  if (trimmed.codeUnitAt(trimmed.length - 1) != kMcpStructuredImageClose) {
    return null;
  }
  final path = trimmed.substring(1, trimmed.length - 1);
  return path.isEmpty ? null : path;
}

/// Decode helper for conversations saved before structured `{text, imageUris}`.
String encodeMcpStructuredImage(String path) {
  return '${String.fromCharCode(kMcpStructuredImageOpen)}'
      '$path'
      '${String.fromCharCode(kMcpStructuredImageClose)}';
}

void writeMcpStructuredImage(StringBuffer buf, String uri) {
  buf.writeln(encodeMcpStructuredImage(uri));
}

@Deprecated('Content is Markdown; do not write the JSON envelope.')
String encodeMcpToolResult(McpToolResult result) => result.markdown;
