import 'dart:convert';

import '../../models/environment_variable.dart';
import '../../../utils/mcp_structured_image.dart';
import 'workspace_tool_metadata.dart';

/// Masks tool text sent to the model. Local previews and files stay unchanged.
/// Like OpenMinis, values shorter than five characters are excluded to avoid
/// replacing ubiquitous flags/numbers. Multiline values also match per line,
/// since read_file adds line numbers to saved command output.
class EnvironmentOutputRedactor {
  EnvironmentOutputRedactor(EnvironmentExecutionConfig config) {
    if (!config.privacyMode) return;
    final values = <String>{
      for (final value in config.variables.values) ...[
        if (value.length >= 5) value,
        ...const LineSplitter()
            .convert(value)
            .where((line) => line.length >= 5),
      ],
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    if (values.isNotEmpty) {
      _pattern = RegExp(values.map(RegExp.escape).join('|'));
    }
  }

  RegExp? _pattern;

  ClientToolResult redact(ClientToolResult result) {
    final pattern = _pattern;
    if (pattern == null) return result;
    String mask(String text) => text.replaceAll(pattern, '[REDACTED]');
    Object? maskJson(Object? value) {
      if (value is String) return mask(value);
      if (value is List) return value.map(maskJson).toList();
      if (value is Map) {
        return {
          for (final entry in value.entries)
            mask(entry.key.toString()): maskJson(entry.value),
        };
      }
      return value;
    }

    String content;
    try {
      // Decode first so quoted, backslash and Unicode values cannot escape
      // matching via JSON serialization. Preserve structured shell results.
      final decoded = jsonDecode(result.content);
      final masked = maskJson(decoded);
      if (jsonEncode(masked) == jsonEncode(decoded)) return result;
      if (masked is Map<String, dynamic>) {
        masked['privacy_notice'] =
            r'Environment variable values were redacted. Use $NAME references in shell commands; do not try to reveal them.';
      }
      content = jsonEncode(masked);
    } on FormatException {
      content = mask(result.content);
      if (content == result.content) return result;
      content +=
          '\n<system-reminder>Environment variable values were redacted. Use variable references in commands.</system-reminder>';
    }
    final metadata = {...?result.metadata};
    final workspace = metadata['workspace'];
    if (workspace is Map) {
      // Non-shell detail panels otherwise fall back to the model-facing text.
      metadata['workspace'] = {
        ...workspace,
        'stdoutPreview':
            workspace['stdoutPreview'] ??
            WorkspaceToolMetadata.capPreview(result.content),
      };
    }
    return ClientToolResult(content, metadata: metadata);
  }
}
