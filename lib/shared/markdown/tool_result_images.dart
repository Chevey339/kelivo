import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:markstream/markstream_core.dart';

import '../../utils/mcp_structured_image.dart';

/// Extract markdown images from a tool result.
///
/// Only `![alt](url)` lines that occupy an entire line are treated as
/// attachments. Images inside JSON strings, fenced code, or body paragraphs
/// stay in the text. Destinations may contain spaces and parentheses.
(String, List<String>) parseToolResultImages(
  String? content, {
  Map<String, dynamic>? metadata,
}) {
  if (content == null || content.isEmpty) {
    final typed = readMcpResultMetadata(metadata);
    if (typed != null) {
      return ('', dedupeImageUrisFirstSeen(mcpResultImageUris(typed)));
    }
    return ('', const []);
  }

  final typed = readMcpResultMetadata(metadata);
  if (typed != null) {
    final images = dedupeImageUrisFirstSeen(mcpResultImageUris(typed));
    return (_stripStandaloneToolImages(content), images);
  }

  final envelope = tryDecodeLegacyMcpToolResultEnvelope(content);
  if (envelope != null) {
    return (
      (envelope.legacyBody ?? envelope.markdown).trim(),
      dedupeImageUrisFirstSeen(envelope.imageUris),
    );
  }

  final images = <String>[];
  final seen = <String>{};
  final kept = <String>[];

  for (final entry in MarkdownStructure(content).lines) {
    final line = entry.line.text;
    // Old saved rows only. Typed ImageContent is never a private marker now.
    final structured = decodeMcpStructuredImageLine(line);
    if (structured != null) {
      if (seen.add(structured)) images.add(structured);
      continue;
    }
    if (_isIndentedCodeLine(line)) {
      kept.add(line);
      continue;
    }
    if (entry.code) {
      kept.add(line);
      continue;
    }
    final classified = _classifyStandaloneMarkdownImageLine(line.trim());
    switch (classified.kind) {
      case _ImageLineKind.image:
        final path = classified.path;
        if (path != null && seen.add(path)) images.add(path);
        continue;
      case _ImageLineKind.placeholder:
        continue;
      case _ImageLineKind.notImage:
        kept.add(line);
    }
  }
  return (kept.join('\n').trim(), images);
}

String _stripStandaloneToolImages(String content) {
  final kept = <String>[];
  for (final entry in MarkdownStructure(content).lines) {
    final line = entry.line.text;
    if (_isIndentedCodeLine(line) || entry.code) {
      kept.add(line);
      continue;
    }
    final classified = _classifyStandaloneMarkdownImageLine(line.trim());
    if (classified.kind == _ImageLineKind.notImage) {
      kept.add(line);
    }
  }
  return kept.join('\n').trim();
}

enum _ImageLineKind { notImage, placeholder, image }

class _ClassifiedImageLine {
  const _ClassifiedImageLine(this.kind, [this.path]);

  final _ImageLineKind kind;
  final String? path;
}

bool _isIndentedCodeLine(String line) => _leadingIndentColumns(line) >= 4;

int _leadingIndentColumns(String line) {
  var columns = 0;
  for (var i = 0; i < line.length; i++) {
    final unit = line.codeUnitAt(i);
    if (unit == 0x20) {
      columns += 1;
    } else if (unit == 0x09) {
      columns += 4 - (columns % 4);
    } else {
      break;
    }
  }
  return columns;
}

@visibleForTesting
({String? path, bool placeholder}) debugClassifyStandaloneImageLine(
  String trimmedLine,
) {
  final classified = _classifyStandaloneMarkdownImageLine(trimmedLine);
  return (
    path: classified.path,
    placeholder: classified.kind == _ImageLineKind.placeholder,
  );
}

_ClassifiedImageLine _classifyStandaloneMarkdownImageLine(String trimmedLine) {
  if (!trimmedLine.startsWith('![')) {
    return const _ClassifiedImageLine(_ImageLineKind.notImage);
  }
  final altClose = trimmedLine.indexOf('](');
  if (altClose == -1) {
    return const _ClassifiedImageLine(_ImageLineKind.notImage);
  }
  final destStart = altClose + 2;
  final parsed = _readMarkdownImageDestination(trimmedLine, destStart);
  if (parsed == null) {
    return const _ClassifiedImageLine(_ImageLineKind.notImage);
  }
  final raw = parsed.trim();
  if (raw.isEmpty || raw == 'generated') {
    return const _ClassifiedImageLine(_ImageLineKind.placeholder);
  }
  return _ClassifiedImageLine(
    _ImageLineKind.image,
    decodeMarkdownImageDestination(raw),
  );
}

/// Returns the raw destination (including `<>` if used) when the destination
/// occupies the rest of the line and closes at the final `)`.
String? _readMarkdownImageDestination(String line, int destStart) {
  if (destStart >= line.length) return null;
  if (line.codeUnitAt(destStart) == 0x3C) {
    var j = destStart + 1;
    while (j < line.length) {
      final ch = line.codeUnitAt(j);
      if (ch == 0x5C && j + 1 < line.length) {
        j += 2;
        continue;
      }
      if (ch == 0x3E) {
        if (j + 1 == line.length - 1 && line.codeUnitAt(j + 1) == 0x29) {
          return line.substring(destStart, j + 1);
        }
        return null;
      }
      j += 1;
    }
    return null;
  }
  var depth = 1;
  var j = destStart;
  while (j < line.length && depth > 0) {
    final ch = line.codeUnitAt(j);
    if (ch == 0x28 && !_isEscapedByOddBackslashes(line, j)) {
      depth += 1;
    } else if (ch == 0x29 && !_isEscapedByOddBackslashes(line, j)) {
      depth -= 1;
      if (depth == 0) break;
    }
    j += 1;
  }
  if (depth != 0 || j != line.length - 1) return null;
  return line.substring(destStart, j);
}

bool _isEscapedByOddBackslashes(String text, int index) {
  var slashes = 0;
  for (var i = index - 1; i >= 0 && text.codeUnitAt(i) == 0x5C; i--) {
    slashes += 1;
  }
  return slashes.isOdd;
}

/// Unescape destinations using the shared Markdown / Windows path codec.
@visibleForTesting
String unescapeMarkdownDestination(String raw) {
  return decodeMarkdownImageDestination(raw);
}
